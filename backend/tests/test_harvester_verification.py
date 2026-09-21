"""Harvester verification endpoint tests.

Covers the scope items:
1. Government ID verification — format validation, honest states
   ("Format Valid", never "Verified" without a real verification mechanism).
2. FSSAI verification — 14-digit format validation, honest states.
3. Persistence — submitted values survive a reload (PostgreSQL-backed).
4. Authentication — all endpoints require a Bearer token; a user may only
   manage their own verification (IDOR guard).
"""
from __future__ import annotations

import json
import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app
from backend.models import Profile, User


@pytest.fixture(scope="module")
def client():
    init_db()
    db = SessionLocal()
    try:
        for email in ("hv_a@example.com", "hv_b@example.com"):
            db.query(User).filter(User.email == email).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()
    return TestClient(app)


def _register_and_login(client: TestClient, email: str, role: str = "HARVESTER") -> dict:
    client.post("/api/auth/register", json={
        "name": "HV User", "email": email, "password": "TestPass2026!", "role": role,
    })
    r = client.post("/api/auth/login", json={
        "emailOrPhone": email, "password": "TestPass2026!", "role": role,
    })
    assert r.status_code == 200, r.text
    data = r.json()
    return {"token": data["token"], "id": data["user"]["id"],
            "headers": {"Authorization": f"Bearer {data['token']}"}}


# ── Authentication ───────────────────────────────────────────────────────────

def test_government_id_requires_auth(client):
    r = client.post("/api/verification/harvester/government-id",
                    json={"documentType": "AADHAAR", "documentNumber": "234567890123"})
    assert r.status_code == 401, f"expected 401, got {r.status_code}"


def test_fssai_requires_auth(client):
    r = client.post("/api/verification/harvester/fssai", json={"fssaiLicense": "12345678901234"})
    assert r.status_code == 401, f"expected 401, got {r.status_code}"


def test_government_id_rejects_other_users_id(client):
    """IDOR guard: a harvester cannot write to another user's verification."""
    a = _register_and_login(client, "hv_a@example.com")
    b = _register_and_login(client, "hv_b@example.com")

    r = client.post("/api/verification/harvester/government-id",
                    json={"harvesterId": b["id"], "documentType": "AADHAAR",
                          "documentNumber": "234567890123"},
                    headers=a["headers"])
    assert r.status_code == 403, f"expected 403, got {r.status_code}: {r.text}"

    # Own account is allowed.
    r = client.post("/api/verification/harvester/government-id",
                    json={"harvesterId": a["id"], "documentType": "AADHAAR",
                          "documentNumber": "234567890123"},
                    headers=a["headers"])
    assert r.status_code == 200, r.text


# ── Government ID format validation ─────────────────────────────────────────

def test_government_id_rejects_bad_format(client):
    a = _register_and_login(client, "hv_a@example.com")

    # AADHAAR starting with 0/1 is invalid, as is a 10-digit number.
    for bad in ("023456789012", "1234", "23456789012X"):
        r = client.post("/api/verification/harvester/government-id",
                        json={"documentType": "AADHAAR", "documentNumber": bad},
                        headers=a["headers"])
        assert r.status_code == 422, f"{bad}: expected 422, got {r.status_code}"
        detail = r.json()["detail"]
        assert detail["code"] == "GOV_ID_INVALID_FORMAT"
        # Error must guide the user with the expected format (example, not real ID).
        assert "12 digits" in detail["message"]
        assert "example" in detail["message"].lower()


def test_government_id_accepts_valid_format_with_honest_state(client):
    a = _register_and_login(client, "hv_a@example.com")

    r = client.post("/api/verification/harvester/government-id",
                    json={"documentType": "AADHAAR", "documentNumber": "2345 6789 0123"},
                    headers=a["headers"])
    assert r.status_code == 200, r.text
    body = r.json()
    ver = body["verification"]

    # Honest state: format is valid, but no government registry was contacted.
    assert ver["governmentIdVerified"] == "Format Valid"
    assert ver["governmentIdType"] == "AADHAAR"
    # Reference is masked — the full number never round-trips to the client.
    assert ver["governmentIdReference"].startswith("*")
    assert "2345" not in ver["governmentIdReference"]

    db = SessionLocal()
    try:
        row = db.query(Profile).filter(Profile.user_id == a["id"]).first()
        assert row is not None
        assert row.kyc_status == "Format Valid"
        assert row.government_id_reference == "234567890123"  # stored clean
    finally:
        db.close()


def test_government_id_pan_format(client):
    a = _register_and_login(client, "hv_a@example.com")

    r = client.post("/api/verification/harvester/government-id",
                    json={"documentType": "PAN", "documentNumber": "ABCDE1234F"},
                    headers=a["headers"])
    assert r.status_code == 200, r.text
    assert r.json()["verification"]["governmentIdVerified"] == "Format Valid"

    r = client.post("/api/verification/harvester/government-id",
                    json={"documentType": "PAN", "documentNumber": "12ABCDE34F"},
                    headers=a["headers"])
    assert r.status_code == 422
    assert r.json()["detail"]["code"] == "GOV_ID_INVALID_FORMAT"


# ── FSSAI format validation ──────────────────────────────────────────────────

def test_fssai_rejects_bad_format(client):
    a = _register_and_login(client, "hv_a@example.com")

    for bad in ("1234567890123", "123456789012345", "FSSAI12345678", "1234567890123a"):
        r = client.post("/api/verification/harvester/fssai",
                        json={"fssaiLicense": bad}, headers=a["headers"])
        assert r.status_code == 422, f"{bad}: expected 422, got {r.status_code}"
        detail = r.json()["detail"]
        assert detail["code"] == "FSSAI_INVALID_FORMAT"
        assert "14 digits" in detail["message"]
        assert "example" in detail["message"].lower()


def test_fssai_accepts_valid_format_with_honest_state(client):
    a = _register_and_login(client, "hv_a@example.com")

    r = client.post("/api/verification/harvester/fssai",
                    json={"fssaiLicense": "12345678901234"}, headers=a["headers"])
    assert r.status_code == 200, r.text
    ver = r.json()["verification"]
    assert ver["fssaiLicenseVerified"] == "Format Valid"
    assert ver["fssaiLicense"] == "12345678901234"


# ── Persistence: state survives a "reload" (fresh DB read + status fetch) ───

def test_verification_state_persists(client):
    a = _register_and_login(client, "hv_a@example.com")

    client.post("/api/verification/harvester/government-id",
                json={"documentType": "AADHAAR", "documentNumber": "234567890123"},
                headers=a["headers"])
    client.post("/api/verification/harvester/fssai",
                json={"fssaiLicense": "12345678901234"}, headers=a["headers"])

    # Fresh DB session — what PostgreSQL actually stored.
    db = SessionLocal()
    try:
        row = db.query(Profile).filter(Profile.user_id == a["id"]).first()
        assert row is not None
        assert row.kyc_status == "Format Valid"
        notes = json.loads(row.review_notes or "{}")
        assert notes.get("fssaiLicense") == "12345678901234"
        assert notes.get("fssaiStatus") == "Format Valid"
    finally:
        db.close()

    # Status endpoint reflects the same persisted state (no logout/login).
    r = client.get(f"/api/verification/HARVESTER/status/{a['id']}", headers=a["headers"])
    assert r.status_code == 200, r.text
    ver = r.json()["verification"]
    assert ver["governmentIdVerified"] == "Format Valid"
    assert ver["fssaiLicenseVerified"] == "Format Valid"
    assert ver["fssaiLicense"] == "12345678901234"
    # Component states stay honest — a format match is never reported as
    # government/official verification.
    assert ver["governmentIdVerified"] != "Verified"
    assert ver["fssaiLicenseVerified"] != "Verified"


def test_status_endpoint_masks_government_id(client):
    a = _register_and_login(client, "hv_a@example.com")
    r = client.get(f"/api/verification/HARVESTER/status/{a['id']}", headers=a["headers"])
    assert r.status_code == 200
    ref = r.json()["verification"]["governmentIdReference"]
    assert ref is None or ref.startswith("*")
