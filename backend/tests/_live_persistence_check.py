"""LIVE verification of the remaining checklist items against real PostgreSQL.

Covers: duplicate-request count in DB, persistence across server restart and
logout/login (fresh token), and the harvester's hive-card linkage (hiveId).
Run: python backend/tests/_live_persistence_check.py
"""
from __future__ import annotations

import os
import sys

os.environ.pop("ENV", None)
os.environ.pop("DEV_OFFLINE_SQLITE", None)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient  # noqa: E402

from main import app  # noqa: E402
from database import SessionLocal  # noqa: E402
from models import CollectionRequest  # noqa: E402

PW = "TestPass2026!"
HARV_EMAIL = "b1_harvester@example.com"
COLL_EMAIL = "b4_collector@example.com"
REQ_ID = "REQ-COL-2026-476BAF"  # accepted by the previous live run
HIVE_ID = None  # filled from DB

client = TestClient(app)


def login(email: str, role: str):
    r = client.post("/api/auth/login", json={"emailOrPhone": email, "password": PW, "role": role})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


def main() -> None:
    # 1. DB durability: the accepted request survived (server "restart" = this
    #    fresh process against the same database).
    db = SessionLocal()
    row = db.query(CollectionRequest).filter(CollectionRequest.request_id == REQ_ID).first()
    assert row is not None, f"{REQ_ID} missing from DB!"
    print("1. DB row after restart:", row.status)
    HIVE_ID = row.hive_id
    n = db.query(CollectionRequest).filter(
        CollectionRequest.harvester_id == row.harvester_id,
        CollectionRequest.batch_id == row.batch_id,
    ).count()
    print("2. rows for (harvester, batch):", n, "(expect 1 — no duplicates)")
    db.close()

    # 2. Fresh login (logout/login equivalent) -> harvester still sees ACCEPTED
    harv_h = login(HARV_EMAIL, "HARVESTER")
    r = client.get("/api/requests", headers=harv_h)
    match = [x for x in r.json() if x.get("requestId") == REQ_ID]
    print("3. harvester after re-login:", match[0]["status"] if match else "NOT FOUND")
    print("4. hive linkage intact:", match[0].get("hiveId") == HIVE_ID if match else False)

    ok = (
        row.status == "ACCEPTED"
        and n == 1
        and match
        and match[0]["status"] == "ACCEPTED"
        and match[0].get("hiveId") == HIVE_ID
    )
    print("PERSISTENCE CHECK:", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
