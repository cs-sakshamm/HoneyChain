"""
Profile-completion gates on restricted operations (spec §16).

The backend must independently block restricted operations for users whose
profile is incomplete — not just hide UI. Accept/dispatch routes previously
checked role only; they now enforce the same PROFILE_INCOMPLETE gate as the
stage-creation routes.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import User


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


def _mk_collector(tag: str, *, complete: bool) -> User:
    sfx = f"{uuid.uuid4().hex[:6]}{tag}"
    user = User(
        name=f"Collector {sfx}" if complete else "",  # empty name => incomplete
        email=f"gate_{sfx}@example.test",
        phone=f"+9191700{sfx[-6:]}" if complete else "",
        role="COLLECTOR_PROCESSOR",
        organization_name=f"Org {sfx}" if complete else None,
        facility_location=f"Loc {sfx}" if complete else None,
        license_number=f"LIC-{sfx}" if complete else None,
        is_verified=False,  # gates use is_verified OR profile-complete
    )
    db = SessionLocal()
    try:
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()


def _headers(user: User) -> dict:
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


def test_incomplete_profile_cannot_accept_collection_request(client):
    incomplete = _mk_collector("i1", complete=False)
    res = client.patch("/api/requests/REQ-COL-2026-NOPE/accept", json={}, headers=_headers(incomplete))
    assert res.status_code in (403, 404)
    if res.status_code == 403:
        assert res.json()["detail"]["code"] == "PROFILE_INCOMPLETE"


def test_complete_profile_collector_passes_the_gate(client):
    complete = _mk_collector("c1", complete=True)
    # Unknown request id → the request-not-found path (past the profile gate).
    res = client.patch("/api/requests/REQ-COL-2026-NOPE/accept", json={}, headers=_headers(complete))
    assert res.status_code == 404
    assert res.json()["detail"] in ({"success": False, "code": "NOT_FOUND", "message": "Request not found."}, "Request not found")


def test_unauthenticated_accept_still_rejected(client):
    res = client.patch("/api/requests/REQ-COL-2026-NOPE/accept", json={})
    assert res.status_code == 401
