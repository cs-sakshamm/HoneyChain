"""Tests for POST /api/auth/google (Firebase Google sign-in session exchange).

Regression coverage for the "server session could not be created" bug: the
endpoint used to call google.auth.jwt.decode(certs_url=...) — an invalid
keyword argument — so EVERY Firebase ID token failed verification with a
TypeError and the endpoint returned 401 INVALID_GOOGLE_TOKEN.

The verifier is stubbed (google.oauth2.id_token.verify_firebase_token) so no
real Firebase project or network is required; everything downstream — claim
extraction, user lookup/creation, duplicate prevention, JWT issuance — runs
against the real code paths on the isolated SQLite test database.
"""
from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, decode_token
from backend.models import User

FAKE_ISS = "https://securetoken.google.com/honeychain-40065"


def _stub_verified_google_token(monkeypatch, *, email: str, name: str = "Google Beekeeper", uid: str = "fb-google-uid"):
    """Make /api/auth/google accept a fake Firebase ID token for `email`.

    verify_oauth2_token (Google-native token path) is made to raise so the
    endpoint falls through to the Firebase verifier, mirroring what happens
    with real Flutter/Firebase ID tokens.
    """
    import google.oauth2.id_token as google_id_token

    def raise_oauth2(*args, **kwargs):
        raise ValueError("not a Google-native OAuth2 token")

    def fake_verify_firebase(id_token, request, audience=None, clock_skew_in_seconds=0):
        assert id_token, "endpoint must post an idToken"
        assert audience == "honeychain-40065", "Firebase audience (project id) must be enforced"
        return {
            "sub": uid,
            "email": email,
            "email_verified": True,
            "name": name,
            "picture": "https://lh3.googleusercontent.com/a/test",
            "iss": FAKE_ISS,
            "aud": audience,
        }

    monkeypatch.setattr(google_id_token, "verify_oauth2_token", raise_oauth2)
    monkeypatch.setattr(google_id_token, "verify_firebase_token", fake_verify_firebase)


def _stub_rejected_token(monkeypatch):
    """Make both verification paths fail (simulates an invalid/expired token)."""
    import google.oauth2.id_token as google_id_token

    def raise_error(*args, **kwargs):
        raise ValueError("Invalid token")

    monkeypatch.setattr(google_id_token, "verify_oauth2_token", raise_error)
    monkeypatch.setattr(google_id_token, "verify_firebase_token", raise_error)


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


def _cleanup(email: str) -> None:
    db = SessionLocal()
    try:
        db.query(User).filter(User.email == email).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def test_new_google_user_creates_verified_account(client, monkeypatch):
    """Regression: a valid Firebase ID token must create the user and issue a
    backend JWT — not 401 'Google ID token could not be verified.'"""
    email = f"google_new_{uuid.uuid4().hex[:8]}@gmail.com"
    _cleanup(email)
    _stub_verified_google_token(monkeypatch, email=email)

    res = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
    assert res.status_code == 200, res.text

    body = res.json()
    assert body["success"] is True
    assert body["user"]["email"] == email
    assert body["user"]["authProvider"] == "google"
    assert body["user"]["isVerified"] is True
    assert body["token"]

    # Session JWT resolves to the created account.
    payload = decode_token(body["token"])
    assert payload["sub"] == body["user"]["id"]
    assert payload["role"] == "HARVESTER"

    # Firebase UID + verified email + photo persisted.
    db = SessionLocal()
    try:
        row = db.query(User).filter(User.email == email, User.role == "HARVESTER").one()
        assert row.firebase_id == "fb-google-uid"
        assert row.google_photo_url == "https://lh3.googleusercontent.com/a/test"
        assert row.is_verified is True
        assert row.beekeeper_id and row.beekeeper_id.startswith("HC-BK-")
    finally:
        db.close()
    _cleanup(email)


def test_repeat_google_login_does_not_duplicate_user(client, monkeypatch):
    email = f"google_dup_{uuid.uuid4().hex[:8]}@gmail.com"
    _cleanup(email)
    _stub_verified_google_token(monkeypatch, email=email)

    first = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
    assert first.status_code == 200
    second = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
    assert second.status_code == 200

    assert first.json()["user"]["id"] == second.json()["user"]["id"]

    db = SessionLocal()
    try:
        rows = db.query(User).filter(User.email == email, User.role == "HARVESTER").all()
        assert len(rows) == 1
    finally:
        db.close()
    _cleanup(email)


def test_invalid_google_token_rejected_with_401(client, monkeypatch):
    """A token that fails verification must be rejected — never trusted via
    the client-supplied email."""
    _stub_rejected_token(monkeypatch)
    res = client.post(
        "/api/auth/google",
        json={"idToken": "forged", "email": "attacker@example.com", "role": "HARVESTER"},
    )
    assert res.status_code == 401
    assert res.json()["detail"]["code"] == "INVALID_GOOGLE_TOKEN"

    db = SessionLocal()
    try:
        assert db.query(User).filter(User.email == "attacker@example.com").first() is None
    finally:
        db.close()


def test_same_google_email_different_role_is_separate_account(client, monkeypatch):
    """Mirrors the phone-auth semantics: accounts are scoped by (email, role)."""
    email = f"google_roles_{uuid.uuid4().hex[:8]}@gmail.com"
    _cleanup(email)
    _stub_verified_google_token(monkeypatch, email=email)

    harvester = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
    lab = client.post("/api/auth/google", json={"idToken": "fake", "role": "LAB"})
    assert harvester.status_code == 200 and lab.status_code == 200
    assert harvester.json()["user"]["id"] != lab.json()["user"]["id"]
    assert harvester.json()["user"]["role"] == "HARVESTER"
    assert lab.json()["user"]["role"] == "LAB"
    _cleanup(email)


def test_google_user_is_not_blocked_by_profile_verification(client, monkeypatch):
    """Google-authenticated harvesters must be immediately usable: verified,
    profile-complete by harvester rules (phone is NOT required)."""
    email = f"google_flow_{uuid.uuid4().hex[:8]}@gmail.com"
    _cleanup(email)
    _stub_verified_google_token(monkeypatch, email=email)

    res = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
    assert res.status_code == 200
    user = res.json()["user"]
    assert user["isVerified"] is True
    assert user["isProfileComplete"] is True  # name + email only; no phone gate

    # The issued session can actually call an authed endpoint (hive creation
    # is ownership-tested elsewhere; here we prove the token authenticates).
    me = client.get(
        "/api/profile",
        headers={"Authorization": f"Bearer {res.json()['token']}"},
    )
    assert me.status_code == 200, me.text
    assert me.json()["user"]["id"] == user["id"]
    _cleanup(email)


def test_existing_local_account_linked_not_overwritten(client, monkeypatch):
    """A pre-existing email/password account signing in with Google for the
    first time keeps its profile and gains the Firebase identity link."""
    email = f"preexisting_google_{uuid.uuid4().hex[:8]}@example.com"
    db = SessionLocal()
    try:
        existing = User(
            name="Pre Existing Google",
            email=email,
            password_hash="irrelevant",
            role="HARVESTER",
        )
        db.add(existing)
        db.commit()
        existing_id = existing.id
    finally:
        db.close()

    try:
        _stub_verified_google_token(monkeypatch, email=email, name="Evil Overwrite Attempt")
        res = client.post("/api/auth/google", json={"idToken": "fake", "role": "HARVESTER"})
        assert res.status_code == 200
        assert res.json()["user"]["id"] == existing_id

        db = SessionLocal()
        try:
            row = db.query(User).filter(User.id == existing_id).first()
            assert row.name == "Pre Existing Google"      # profile NOT overwritten
            assert row.firebase_id == "fb-google-uid"     # identity linked
            assert row.password_hash == "irrelevant"      # credentials untouched
        finally:
            db.close()
    finally:
        _cleanup(email)
