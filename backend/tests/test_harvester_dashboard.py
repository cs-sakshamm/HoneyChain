"""Regression tests for the Harvester dashboard stabilization fixes.

Covers:
- B1: POST /api/hives rejects user-supplied duplicate hive codes (409)
      instead of silently renaming them.
- B2: GET /api/requests/nearest-centers requires authentication.
- B3: GET /api/verification/{role}/status/{user_id} requires authentication
      and only allows self/admin access (IDOR guard).
- B4: GET /api/requests works for collectors (regression: NameError: or_).
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app
from backend.models import CollectionRequest, Hive, User


@pytest.fixture(scope="module")
def client():
    init_db()
    db = SessionLocal()
    try:
        # Remove rows from previous runs of this module (test DB persists).
        for email in ("b1_harvester@example.com", "b3_harvester@example.com",
                      "b3_other@example.com", "b4_collector@example.com"):
            db.query(User).filter(User.email == email).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()
    return TestClient(app)


def _register_and_login(client: TestClient, name: str, email: str, role: str) -> dict:
    # Tolerate re-registration (tests in this module share fixed emails);
    # what must succeed is the login.
    client.post("/api/auth/register", json={
        "name": name, "email": email, "password": "TestPass2026!", "role": role,
    })
    r = client.post("/api/auth/login", json={
        "emailOrPhone": email, "password": "TestPass2026!", "role": role,
    })
    assert r.status_code == 200, r.text
    data = r.json()
    return {"token": data["token"], "id": data["user"]["id"], "headers": {"Authorization": f"Bearer {data['token']}"}}


# ── B1: duplicate hive code must be rejected, not renamed ──

def test_create_hive_rejects_duplicate_code(client):
    harv = _register_and_login(client, "B1 Harvester", "b1_harvester@example.com", "HARVESTER")
    code = f"B1-DUP-{uuid.uuid4().hex[:6].upper()}"

    r1 = client.post("/api/hives", json={"name": "First", "hiveCode": code, "apiaryLocation": "X"},
                     headers=harv["headers"])
    assert r1.status_code == 200, r1.text

    r2 = client.post("/api/hives", json={"name": "Second", "hiveCode": code, "apiaryLocation": "X"},
                     headers=harv["headers"])
    assert r2.status_code == 409, f"expected 409, got {r2.status_code}: {r2.text}"
    detail = r2.json()["detail"]
    assert detail["code"] == "HIVE_CODE_EXISTS"

    # Exactly one hive with that code exists (no silent rename).
    db = SessionLocal()
    try:
        assert db.query(Hive).filter(Hive.hive_code == code).count() == 1
    finally:
        db.close()


# ── B2: nearest-centers requires authentication ──

def test_nearest_centers_requires_auth(client):
    r = client.get("/api/requests/nearest-centers?targetRole=LAB")
    assert r.status_code == 401, f"expected 401, got {r.status_code}"

    harv = _register_and_login(client, "B3 Harvester", "b3_harvester@example.com", "HARVESTER")
    r = client.get("/api/requests/nearest-centers?targetRole=LAB", headers=harv["headers"])
    assert r.status_code == 200
    body = r.json()
    assert body.get("success") is True
    assert isinstance(body.get("centers"), list)


# ── B3: verification status IDOR guard ──

def test_verification_status_idor_guard(client):
    harv = _register_and_login(client, "B3 Harvester", "b3_harvester@example.com", "HARVESTER")
    other = _register_and_login(client, "B3 Other", "b3_other@example.com", "HARVESTER")

    # Unauthenticated access rejected.
    r = client.get(f"/api/verification/HARVESTER/status/{harv['id']}")
    assert r.status_code == 401

    # Reading someone else's status rejected.
    r = client.get(f"/api/verification/HARVESTER/status/{other['id']}", headers=harv["headers"])
    assert r.status_code == 403

    # Own status allowed.
    r = client.get(f"/api/verification/HARVESTER/status/{harv['id']}", headers=harv["headers"])
    assert r.status_code == 200


# ── B4: collector can list requests (regression: NameError: or_) ──

def test_collector_sees_harvester_request(client):
    harv = _register_and_login(client, "B1 Harvester", "b1_harvester@example.com", "HARVESTER")
    coll = _register_and_login(client, "B4 Collector", "b4_collector@example.com", "COLLECTOR_PROCESSOR")

    batch = f"B4-BATCH-{uuid.uuid4().hex[:6].upper()}"
    r = client.post("/api/requests", json={
        "batchId": batch, "collectionCentreId": coll["id"],
        "quantity": 5.0, "location": "Test Apiary",
    }, headers=harv["headers"])
    assert r.status_code == 200, r.text

    r = client.get("/api/requests", headers=coll["headers"])
    assert r.status_code == 200, f"collector request list failed: {r.status_code}"
    items = r.json() if isinstance(r.json(), list) else r.json().get("requests", [])
    assert any((x.get("batchId") or x.get("batch_id")) == batch for x in items)

    # Harvester still sees own request and the row landed in the DB.
    r = client.get("/api/requests", headers=harv["headers"])
    assert r.status_code == 200
    items = r.json() if isinstance(r.json(), list) else r.json().get("requests", [])
    assert any((x.get("batchId") or x.get("batch_id")) == batch for x in items)
    db = SessionLocal()
    try:
        assert db.query(CollectionRequest).filter(CollectionRequest.batch_id == batch).count() == 1
    finally:
        db.close()
