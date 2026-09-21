"""LIVE repro (run manually, not part of the pytest suite).

Simulates the exact HTTP calls the Flutter app makes:
1. Login as an existing harvester (b1_harvester@example.com) and collector
   (b4_collector@example.com).
2. GET /api/centers/nearest as the harvester (Flutter 'Select Centre' screen).
3. POST /api/harvests then POST /api/requests (createHarvestAndRequest).
4. GET /api/requests as collector -> expect the PENDING request.
5. PATCH /api/requests/{id}/accept as collector.
6. GET /api/requests as harvester -> expect ACCEPTED.

Run: python backend/tests/_live_repro_request_chain.py
"""
from __future__ import annotations

import os
import sys
from datetime import datetime

# Point at the REAL database: never let backend/tests/conftest.py defaults leak in.
os.environ.pop("ENV", None)
os.environ.pop("DEV_OFFLINE_SQLITE", None)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient  # noqa: E402

from main import app  # noqa: E402
from database import is_postgres, SessionLocal  # noqa: E402
from models import CollectionRequest, User  # noqa: E402

client = TestClient(app)


def login(email: str, password: str, role: str):
    r = client.post("/api/auth/login", json={"emailOrPhone": email, "password": password, "role": role})
    if r.status_code != 200:
        print(f"LOGIN FAIL {email}: {r.status_code} {r.text[:300]}")
        sys.exit(1)
    return {"Authorization": f"Bearer {r.json()['token']}"}


def main() -> None:
    print("is_postgres:", is_postgres)
    assert is_postgres, "NOT running against PostgreSQL!"

    PW = "TestPass2026!"
    HARV_EMAIL = "b1_harvester@example.com"
    COLL_EMAIL = "b4_collector@example.com"

    def _login_with_fallback(email: str, role: str):
        r = client.post("/api/auth/login", json={"emailOrPhone": email, "password": PW, "role": role})
        if r.status_code != 200:
            # account exists in the real DB from an earlier manual run with a
            # different password: register is a no-op, so try registering.
            client.post("/api/auth/register", json={
                "name": "Live Repro", "email": email, "password": PW, "role": role,
            })
            r = client.post("/api/auth/login", json={"emailOrPhone": email, "password": PW, "role": role})
        if r.status_code != 200:
            print(f"LOGIN FAIL {email}: {r.status_code} {r.text[:300]}")
            sys.exit(1)
        return {"Authorization": f"Bearer {r.json()['token']}"}

    harv_h = _login_with_fallback(HARV_EMAIL, "HARVESTER")
    coll_h = _login_with_fallback(COLL_EMAIL, "COLLECTOR_PROCESSOR")

    # 0. Baseline: how many PENDING rows exist for this harvester?
    db = SessionLocal()
    harv_id = db.query(User).filter(User.email == HARV_EMAIL).first().id
    coll_id = db.query(User).filter(User.email == COLL_EMAIL).first().id
    db.close()

    # 1. Nearest centres (what the Flutter Select Centre screen shows)
    r = client.get("/api/centers/nearest?role=COLLECTOR_PROCESSOR", headers=harv_h)
    print("nearest centres:", r.status_code, r.json().get("total"))
    centres = r.json().get("centers", [])
    target = None
    for c in centres:
        print("  -", c["id"][:10], c["name"][:40], "-> userId:", str(c.get("userId"))[:10])
        if c.get("userId") == coll_id or c.get("id") == coll_id:
            target = c
    if target is None:
        # Flutter sends center['id'] as toUserId — pick the first centre and see what happens
        target = centres[0] if centres else None
    if target is None:
        print("NO CENTRES FOUND — collector would get nothing to accept")
        return
    print("target centre id:", target["id"])

    # 2. Create harvest (Flutter Step 1)
    r = client.post("/api/harvests", json={
        "quantity": 7.5,
        "location": "LiveRepro Apiary",
        "notes": "live repro harvest",
    }, headers=harv_h)
    print("harvest:", r.status_code)
    if r.status_code != 200:
        print(r.text[:400])
        sys.exit(1)
    batch_id = r.json()["batchId"]

    # 3. Create request (Flutter Step 2) — body exactly as workflow_controller sends it
    r = client.post("/api/requests", json={
        "batchId": batch_id,
        "harvesterId": "B1 Harvester",
        "toUserId": target["id"],
        "fromRole": "HARVESTER",
        "toRole": "COLLECTOR_PROCESSOR",
        "requestType": "HARVEST_TO_COLLECTION",
        "quantity": 7.5,
        "notes": "live repro request",
    }, headers=harv_h)
    print("create request:", r.status_code)
    if r.status_code != 200:
        print(r.text[:400])
        sys.exit(1)
    request_id = r.json()["requestId"]
    print("requestId:", request_id)

    # DB check: one row, PENDING, receiver mapped to the collector user
    db = SessionLocal()
    row = db.query(CollectionRequest).filter(CollectionRequest.request_id == request_id).first()
    print("DB row: status =", row.status, "| centre_id =", row.collection_centre_id)
    print("centre_id == collector user id?", row.collection_centre_id == coll_id)
    n = db.query(CollectionRequest).filter(
        CollectionRequest.harvester_id == harv_id,
        CollectionRequest.batch_id == batch_id,
        CollectionRequest.status == "PENDING",
    ).count()
    print("pending rows for batch:", n)
    db.close()

    # 4. Collector sees it
    r = client.get("/api/requests", headers=coll_h)
    items = r.json()
    match = [x for x in items if x.get("requestId") == request_id]
    print("collector GET /api/requests ->", r.status_code, "| found:", bool(match), "| status:", match[0]["status"] if match else None)
    if not match:
        print(">>> BUG: request invisible to collector")
        sys.exit(1)

    # 5. Collector accepts
    r = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=coll_h)
    print("accept:", r.status_code, r.json().get("message", r.text[:200]))
    if r.status_code != 200:
        sys.exit(1)

    # 6. Harvester sees ACCEPTED
    r = client.get("/api/requests", headers=harv_h)
    items = r.json()
    match = [x for x in items if x.get("requestId") == request_id]
    print("harvester GET /api/requests -> found:", bool(match), "| status:", match[0]["status"] if match else None)

    # 7. Duplicate protection
    r = client.post("/api/requests", json={
        "batchId": batch_id,
        "toUserId": target["id"],
        "quantity": 7.5,
    }, headers=harv_h)
    print("duplicate create:", r.status_code, "(expect 409)")

    # 8. Duplicate accept protection
    r = client.patch(f"/api/requests/{request_id}/accept", json={}, headers=coll_h)
    print("duplicate accept:", r.status_code, "(expect 409)")

    ok = match and match[0]["status"] == "ACCEPTED"
    print("LIVE FLOW:", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
