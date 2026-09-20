"""
Authentication failure tests (spec §15E/§15F).

Expired, tampered, and invalid tokens must be rejected with the correct
error codes; duplicate signups must be refused; failures must not leak
whether an email exists.
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


def _mk_user(tag: str, role: str = "HARVESTER") -> User:
    sfx = f"{uuid.uuid4().hex[:6]}{tag}"
    db = SessionLocal()
    try:
        user = User(
            name=f"TokUser {sfx}",
            email=f"tok_{sfx}@example.test",
            phone=f"+9191500{sfx[-6:]}",
            role=role,
            is_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


class TestTokenSecurity:
    def test_expired_token_rejected_with_token_expired(self, client):
        from datetime import timedelta

        user = _mk_user("exp")
        expired = create_access_token(
            {"sub": user.id, "email": user.email, "role": user.role},
            expires_delta=timedelta(minutes=-10),
        )
        res = client.get("/api/telemetry/alerts", headers=_headers(expired))
        assert res.status_code == 401
        assert res.json()["detail"]["code"] == "TOKEN_EXPIRED"

    def test_tampered_token_signature_rejected(self, client):
        user = _mk_user("tam")
        token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
        # Flip a payload character without re-signing.
        header, body, sig = token.split(".")
        tampered_body = body[:-2] + ("AA" if body[-2:] != "AA" else "BB")
        res = client.get("/api/telemetry/alerts", headers=_headers(f"{header}.{tampered_body}.{sig}"))
        assert res.status_code == 401
        assert res.json()["detail"]["code"] == "INVALID_TOKEN"

    def test_wrong_secret_token_rejected(self, client):
        import jwt as pyjwt

        user = _mk_user("wsec")
        foreign = pyjwt.encode(
            {"sub": user.id, "email": user.email, "role": user.role},
            "completely-wrong-secret",
            algorithm="HS256",
        )
        res = client.get("/api/telemetry/alerts", headers=_headers(foreign))
        assert res.status_code == 401
        assert res.json()["detail"]["code"] == "INVALID_TOKEN"

    def test_garbage_and_empty_tokens_rejected(self, client):
        for token in ("not-a-jwt", "", "   "):
            res = client.get(
                "/api/telemetry/alerts",
                headers={"Authorization": f"Bearer {token}"} if token else {"Authorization": "Bearer"},
            )
            assert res.status_code == 401, f"token {token!r} not rejected"

    def test_valid_token_still_accepted(self, client):
        user = _mk_user("ok")
        res = client.get("/api/telemetry/alerts", headers=_headers(create_access_token(
            {"sub": user.id, "email": user.email, "role": user.role}
        )))
        assert res.status_code == 200


class TestDuplicateSignup:
    def test_duplicate_registration_rejected_409(self, client):
        email = f"dupsign_{uuid.uuid4().hex[:6]}@example.test"
        payload = {
            "name": "Dup User", "email": email, "phone": "+919199001122",
            "password": "Str0ngPass!", "role": "HARVESTER",
        }
        first = client.post("/api/auth/register", json=payload)
        assert first.status_code in (200, 201), first.text

        second = client.post("/api/auth/register", json={**payload, "name": "Dup Again"})
        assert second.status_code == 409, second.text
        assert second.json()["detail"]["code"] == "ROLE_ACCOUNT_EXISTS"

    def test_wrong_password_rejected_safely(self, client):
        email = f"safe_{uuid.uuid4().hex[:6]}@example.test"
        client.post("/api/auth/register", json={
            "name": "Safe User", "email": email, "phone": "+919199003344",
            "password": "CorrectHorse1!", "role": "HARVESTER",
        })
        wrong = client.post("/api/auth/login", json={"email": email, "password": "WrongPassword1!"})
        assert wrong.status_code == 401, wrong.text
        # Safe error: must not reveal which half was wrong.
        msg = str(wrong.json())
        assert "email" not in msg.lower() or "invalid email or password" in msg.lower()
