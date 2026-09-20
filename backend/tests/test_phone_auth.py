"""Tests for POST /api/auth/phone (Firebase Phone-Auth session exchange).

These tests stub `google.auth.jwt.decode` (the Firebase ID-token verifier) so
no real Firebase project, network, or SMS is required. Everything downstream —
phone extraction from token claims, E.164 enforcement, user creation/dedup,
JWT session issuance — runs against the real code paths on the isolated SQLite
test database (forced by the repo-root conftest).
"""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, decode_token
from backend.models import User

FAKE_ISS = "https://securetoken.google.com/honeychain-40065"


def _stub_firebase_token(monkeypatch, *, phone: str, uid: str = "fb-uid-test"):
    """Make /api/auth/phone accept a fake Firebase ID token for `phone`."""
    import google.auth.jwt as gjwt

    def fake_decode(id_token, **kwargs):
        assert id_token, "endpoint must post an idToken"
        return {"sub": uid, "phone_number": phone, "iss": FAKE_ISS, "aud": "honeychain-40065"}

    monkeypatch.setattr(gjwt, "decode", fake_decode)


@pytest.fixture(scope="module")
def client():
    init_db()
    # The offline test database persists across runs, so remove rows created by
    # a previous run of this module to keep every test deterministic.
    db = SessionLocal()
    try:
        db.query(User).filter(
            (User.phone.like("+919000000%")) | (User.email == "preexisting_phone_auth@example.com")
        ).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()
    return TestClient(app)


def _phone_rows(phone: str):
    db = SessionLocal()
    try:
        return db.query(User).filter(User.phone == phone).all()
    finally:
        db.close()


def test_new_phone_user_creates_account(client, monkeypatch):
    """Regression: first-time phone signup used to crash with
    'NOT NULL constraint failed: users.email' because the endpoint inserted
    email=None while users.email is NOT NULL."""
    _stub_firebase_token(monkeypatch, phone="+919000000001")
    res = client.post("/api/auth/phone", json={"idToken": "fake", "role": "HARVESTER"})
    assert res.status_code == 200, res.text

    body = res.json()
    assert body["success"] is True
    assert body["user"]["phone"] == "+919000000001"
    assert body["user"]["authProvider"] == "phone"
    assert body["token"]

    payload = decode_token(body["token"])
    assert payload["phone"] == "+919000000001"
    assert payload["role"] == "HARVESTER"

    rows = _phone_rows("+919000000001")
    assert len(rows) == 1
    # Placeholder email satisfies the NOT NULL + unique(email, role) constraint
    # without colliding with any real account.
    assert rows[0].email == "phone-919000000001@phone.honeychain.local"
    assert rows[0].auth_provider == "phone"


def test_repeat_login_does_not_duplicate_user(client, monkeypatch):
    _stub_firebase_token(monkeypatch, phone="+919000000002")
    first = client.post("/api/auth/phone", json={"idToken": "fake", "role": "HARVESTER"})
    assert first.status_code == 200
    second = client.post("/api/auth/phone", json={"idToken": "fake", "role": "HARVESTER"})
    assert second.status_code == 200
    # Same account returned both times — no duplicate rows.
    assert first.json()["user"]["id"] == second.json()["user"]["id"]
    assert len(_phone_rows("+919000000002")) == 1


def test_same_phone_different_role_is_separate_account(client, monkeypatch):
    """HoneyChain scopes accounts by (phone, role) — one person may be both a
    harvester and a lab tester, mirroring the email-login role semantics."""
    _stub_firebase_token(monkeypatch, phone="+919000000003")
    harvester = client.post("/api/auth/phone", json={"idToken": "fake", "role": "HARVESTER"})
    lab = client.post("/api/auth/phone", json={"idToken": "fake", "role": "LAB"})
    assert harvester.status_code == 200 and lab.status_code == 200
    assert harvester.json()["user"]["id"] != lab.json()["user"]["id"]
    assert harvester.json()["user"]["role"] == "HARVESTER"
    assert lab.json()["user"]["role"] == "LAB"


def test_missing_role_falls_back_to_existing_account_any_role(client, monkeypatch):
    """A client that omits `role` must still land on the existing account."""
    _stub_firebase_token(monkeypatch, phone="+919000000004")
    created = client.post("/api/auth/phone", json={"idToken": "fake", "role": "PACKAGING"})
    assert created.status_code == 200

    _stub_firebase_token(monkeypatch, phone="+919000000004", uid="fb-uid-again")
    fallback = client.post("/api/auth/phone", json={"idToken": "fake"})
    assert fallback.status_code == 200
    assert fallback.json()["user"]["id"] == created.json()["user"]["id"]


def test_client_supplied_phone_is_ignored_token_wins(client, monkeypatch):
    """SECURITY: the request body must never override the Firebase-verified
    phone claim, or anyone could sign in as any number."""
    _stub_firebase_token(monkeypatch, phone="+919000000005")
    res = client.post(
        "/api/auth/phone",
        json={"idToken": "fake", "role": "HARVESTER", "phone": "+918888888888"},
    )
    assert res.status_code == 200
    assert res.json()["user"]["phone"] == "+919000000005"
    assert _phone_rows("+918888888888") == []


def test_non_e164_phone_in_token_rejected(client, monkeypatch):
    _stub_firebase_token(monkeypatch, phone="919000000006")  # missing '+'
    res = client.post("/api/auth/phone", json={"idToken": "fake", "role": "HARVESTER"})
    assert res.status_code == 401
    assert res.json()["detail"]["code"] == "INVALID_PHONE_FORMAT"


def test_missing_id_token_rejected(client):
    res = client.post("/api/auth/phone", json={"role": "HARVESTER"})
    assert res.status_code == 400
    assert res.json()["detail"]["code"] == "ID_TOKEN_REQUIRED"


def test_existing_email_user_gets_firebase_id_linked_not_overwritten(client, monkeypatch):
    """An account that already exists (registered via email/password) must be
    associated with the Firebase identity without any profile overwrite."""
    db = SessionLocal()
    try:
        existing = User(
            name="Pre Existing",
            email="preexisting_phone_auth@example.com",
            phone="+919000000007",
            password_hash="irrelevant",
            role="HARVESTER",
        )
        db.add(existing)
        db.commit()
        existing_id = existing.id
    finally:
        db.close()

    _stub_firebase_token(monkeypatch, phone="+919000000007", uid="fb-uid-link")
    res = client.post(
        "/api/auth/phone",
        json={"idToken": "fake", "role": "HARVESTER", "name": "Evil Overwrite Attempt"},
    )
    assert res.status_code == 200
    assert res.json()["user"]["id"] == existing_id

    db = SessionLocal()
    try:
        row = db.query(User).filter(User.id == existing_id).first()
        assert row.name == "Pre Existing"          # profile NOT overwritten
        assert row.firebase_id == "fb-uid-link"    # identity linked
        assert row.auth_provider == "local"        # original provider preserved
    finally:
        db.close()
