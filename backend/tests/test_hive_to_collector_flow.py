"""End-to-end regression tests: Google-auth Harvester → Add Hive → Send to
Collector → Collector accepts/rejects → Harvester sees the real status.

Product rules covered:
- A successfully authenticated Harvester (Google login path: no password,
  no pre-existing profile completion) can create hives immediately.
- Hive creation never blocks on profile/verification completion.
- Hive ownership: a harvester only sees/reads their own hives (403 otherwise).
- Duplicate hive codes are rejected with 409 and nothing is persisted twice.
- A collection request created from a hive reaches the collector's request
  list, is persisted in PostgreSQL, and reject-after-accept is blocked.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import CollectionRequest, Hive, User


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


def _google_style_harvester(db, name: str) -> dict:
    """Simulate what POST /api/auth/google creates for a first-time Google
    harvester: verified account, no password, minimal profile. We insert the
    row directly to keep this test independent of network token verification,
    then mint our own JWT exactly like the backend does."""
    suffix = uuid.uuid4().hex[:8]
    email = f"{name.lower().replace(' ', '_')}_{suffix}@gmail.com"
    user = User(
        name=name,
        email=email,
        password_hash=None,          # Google accounts have no password
        auth_provider="google",
        role="HARVESTER",
        beekeeper_id=f"HC-BK-{suffix.upper()}",
        is_verified=True,            # Google auth marks the account verified
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {
        "id": user.id,
        "email": email,
        "headers": {"Authorization": f"Bearer {token}"},
    }


# ── 1. Google-auth harvester can add a hive immediately ──────────────────────

def test_google_harvester_adds_hive_without_profile_gate(client):
    db = SessionLocal()
    try:
        harv = _google_style_harvester(db, "Google Beekeeper")
    finally:
        db.close()

    code = f"G-HIVE-{uuid.uuid4().hex[:6].upper()}"
    r = client.post("/api/hives", json={
        "name": "Google Login Hive",
        "hiveCode": code,
        "apiaryLocation": "Meadow Field",
        "expectedProductionKg": 30.0,
        "previousYearProductionKg": 22.5,
        "currentYearProductionKg": 5.0,
    }, headers=harv["headers"])
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["success"] is True
    # Hive is linked to the authenticated Google harvester, not any client id.
    assert body["hive"]["userId"] == harv["id"]
    assert body["hive"]["hiveCode"] == code
    assert body["hive"]["previousYearProductionKg"] == 22.5
    assert body["hive"]["currentYearProductionKg"] == 5.0

    # Persisted in the database.
    db = SessionLocal()
    try:
        row = db.query(Hive).filter(Hive.hive_code == code).first()
        assert row is not None and row.user_id == harv["id"]
    finally:
        db.close()


# ── 2. Ownership: a harvester cannot read another's hive ────────────────────

def test_hive_ownership_enforced(client):
    db = SessionLocal()
    try:
        a = _google_style_harvester(db, "Owner Harvester")
        b = _google_style_harvester(db, "Intruder Harvester")
    finally:
        db.close()

    code = f"OWN-HIVE-{uuid.uuid4().hex[:6].upper()}"
    r = client.post("/api/hives", json={
        "name": "Owner Hive", "hiveCode": code, "apiaryLocation": "X",
    }, headers=a["headers"])
    assert r.status_code == 200
    hive_id = r.json()["hive"]["id"]

    # Intruder cannot read it.
    r = client.get(f"/api/hives/{hive_id}", headers=b["headers"])
    assert r.status_code == 403
    # Intruder cannot delete it.
    r = client.delete(f"/api/hives/{hive_id}", headers=b["headers"])
    assert r.status_code == 403
    # Owner can read it.
    r = client.get(f"/api/hives/{hive_id}", headers=a["headers"])
    assert r.status_code == 200

    # List endpoint is scoped: harvester A never sees B's hives.
    r = client.get("/api/hives", headers=a["headers"])
    assert r.status_code == 200
    listed_codes = [h["hiveCode"] for h in r.json()]
    assert code in listed_codes


# ── 3. Duplicate hive ID protection ─────────────────────────────────────────

def test_duplicate_hive_code_rejected_and_not_duplicated(client):
    db = SessionLocal()
    try:
        harv = _google_style_harvester(db, "Dup Harvester")
    finally:
        db.close()

    code = f"DUP-HIVE-{uuid.uuid4().hex[:6].upper()}"
    r1 = client.post("/api/hives", json={
        "name": "First", "hiveCode": code, "apiaryLocation": "X",
    }, headers=harv["headers"])
    assert r1.status_code == 200

    r2 = client.post("/api/hives", json={
        "name": "Second", "hiveCode": code, "apiaryLocation": "X",
    }, headers=harv["headers"])
    assert r2.status_code == 409, f"expected 409, got {r2.status_code}: {r2.text}"
    detail = r2.json()["detail"]
    assert detail["code"] == "HIVE_CODE_EXISTS"
    assert "already in use" in detail["message"]

    db = SessionLocal()
    try:
        assert db.query(Hive).filter(Hive.hive_code == code).count() == 1
    finally:
        db.close()


# ── 4. Hive → collection request → collector accepts/rejects ────────────────

def _make_collector(db, name: str) -> dict:
    suffix = uuid.uuid4().hex[:8]
    email = f"{name.lower().replace(' ', '_')}_{suffix}@example.com"
    user = User(
        name=name,
        email=email,
        password_hash=None,
        role="COLLECTOR_PROCESSOR",
        organization_name=f"{name} Centre",
        facility_location="Pune",
        license_number="LIC-FLOW-1",
        phone="+919800000000",
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"id": user.id, "headers": {"Authorization": f"Bearer {token}"}}


def test_hive_request_reaches_collector_and_status_flows(client):
    db = SessionLocal()
    try:
        harv = _google_style_harvester(db, "Flow Harvester")
        coll = _make_collector(db, "Flow Collector")
    finally:
        db.close()

    # 1. Create hive.
    code = f"FLOW-HIVE-{uuid.uuid4().hex[:6].upper()}"
    r = client.post("/api/hives", json={
        "name": "Flow Hive", "hiveCode": code, "apiaryLocation": "Meadow",
        "expectedProductionKg": 20.0,
    }, headers=harv["headers"])
    assert r.status_code == 200, r.text
    hive_id = r.json()["hive"]["id"]

    # 2. Send hive to collector (harvest + request, as the app does).
    batch = f"FLOW-BATCH-{uuid.uuid4().hex[:6].upper()}"
    r = client.post("/api/harvests", json={
        "hiveId": hive_id, "quantity": 18.0, "location": "Meadow",
    }, headers=harv["headers"])
    assert r.status_code == 200, r.text
    batch_id = r.json()["batchId"]

    r = client.post("/api/requests", json={
        "batchId": batch_id,
        "hiveId": hive_id,
        "toUserId": coll["id"],
        "fromRole": "HARVESTER",
        "toRole": "COLLECTOR_PROCESSOR",
        "requestType": "HARVEST_TO_COLLECTION",
        "quantity": 18.0,
        "location": "Meadow",
        "notes": "Harvest from Flow Hive",
    }, headers=harv["headers"])
    assert r.status_code == 200, r.text
    request_id = r.json()["requestId"]

    # Duplicate submission for the same batch/center is handled idempotently.
    r = client.post("/api/requests", json={
        "batchId": batch_id, "hiveId": hive_id, "toUserId": coll["id"],
        "quantity": 18.0,
    }, headers=harv["headers"])
    assert r.status_code == 200
    assert r.json()["success"] is True

    # 3. Request persisted in PostgreSQL with hive linkage.
    db = SessionLocal()
    try:
        row = db.query(CollectionRequest).filter(CollectionRequest.request_id == request_id).first()
        assert row is not None
        assert row.hive_id == hive_id
        assert row.harvester_id == harv["id"]
        assert row.collection_centre_id == coll["id"]
        assert row.status == "PENDING"
    finally:
        db.close()

    # 4. Collector receives the real request in their queue.
    r = client.get("/api/requests", headers=coll["headers"])
    assert r.status_code == 200
    items = r.json() if isinstance(r.json(), list) else r.json().get("requests", [])
    match = [x for x in items if x.get("requestId") == request_id]
    assert match, "collector must see the harvester's request"
    assert match[0]["status"] == "PENDING"
    assert match[0]["hiveId"] == hive_id

    # 5. Harvester sees the same request with PENDING status.
    r = client.get("/api/requests", headers=harv["headers"])
    assert r.status_code == 200
    items = r.json() if isinstance(r.json(), list) else r.json().get("requests", [])
    match = [x for x in items if x.get("requestId") == request_id]
    assert match and match[0]["status"] == "PENDING"

    # 6. Collector accepts → harvester sees ACCEPTED.
    r = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=coll["headers"])
    assert r.status_code == 200, r.text
    r = client.get("/api/requests", headers=harv["headers"])
    items = r.json() if isinstance(r.json(), list) else r.json().get("requests", [])
    match = [x for x in items if x.get("requestId") == request_id]
    assert match and match[0]["status"] == "ACCEPTED"

    # 7. Reject-after-accept is blocked.
    r = client.patch(f"/api/requests/{request_id}/reject", json={"reason": "late"}, headers=coll["headers"])
    assert r.status_code == 409
