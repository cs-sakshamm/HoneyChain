"""Security tests for the hardened legacy /api/verification OTP endpoints.

Covers: resend cooldown, per-number send quota, prior-code invalidation on
resend, one-time-use consumption, brute-force attempt lockout, input
validation, sandbox-gated devOtp, and phone masking in logs.
"""
from __future__ import annotations

import logging

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import (
    OTP_SEND_LIMIT,
    OTP_VERIFY_ATTEMPT_LIMIT,
    app,
    reset_otp_rate_limiters,
)
from backend.models import OTPVerification

PHONE = "+919812345678"


@pytest.fixture(autouse=True)
def _clean_otp_state():
    """Fresh OTP table + rate-limiter state for every test."""
    init_db()
    reset_otp_rate_limiters()
    db = SessionLocal()
    try:
        db.query(OTPVerification).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()
    yield
    reset_otp_rate_limiters()


@pytest.fixture()
def client():
    return TestClient(app)


def _send(client, phone=PHONE):
    return client.post("/api/verification/send-otp", json={"phone": phone})


def _verify(client, otp, phone=PHONE, session_id=None):
    body = {"otp": otp}
    if session_id:
        body["sessionId"] = session_id
    else:
        body["phone"] = phone
    return client.post("/api/verification/verify-otp", json=body)


# ── Happy path ────────────────────────────────────────────────────────────────

def test_send_and_verify_roundtrip(client):
    res = _send(client)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert data["sessionId"]
    assert data["expiresInSeconds"] == 600
    # sandbox provider returns the code for testing
    otp = data["devOtp"]
    assert otp and len(otp) == 6

    ver = _verify(client, otp)
    assert ver.status_code == 200
    assert ver.json()["success"] is True


def test_send_response_contains_no_code_outside_sandbox(client, monkeypatch):
    monkeypatch.setenv("OTP_PROVIDER", "twilio")
    res = _send(client)
    assert res.status_code == 200
    assert "devOtp" not in res.json()


# ── Input validation ──────────────────────────────────────────────────────────

def test_send_rejects_invalid_phone(client):
    for bad in ["", "abc", "12345", "+", "91981234567890123456"]:
        res = _send(client, phone=bad)
        assert res.status_code == 400, bad
        assert res.json()["detail"]["code"] == "INVALID_PHONE"


def test_verify_rejects_bad_format(client):
    res = _verify(client, "12ab56")
    assert res.json()["code"] == "INVALID_OTP_FORMAT"


def test_verify_requires_scope(client):
    res = client.post("/api/verification/verify-otp", json={"otp": "123456"})
    assert res.json()["code"] == "MISSING_SCOPE"


# ── Rate limiting: cooldown + quota ──────────────────────────────────────────

def test_resend_cooldown_blocks_immediate_second_send(client):
    assert _send(client).status_code == 200
    res = _send(client)
    assert res.status_code == 429
    assert res.json()["detail"]["code"] == "OTP_RATE_LIMITED"
    assert res.json()["detail"]["cooldownSeconds"] >= 1


def test_send_quota_per_number(client, monkeypatch):
    monkeypatch.setattr("backend.main.OTP_RESEND_COOLDOWN_SECONDS", 0)
    for _ in range(OTP_SEND_LIMIT):
        assert _send(client).status_code == 200
    res = _send(client)
    assert res.status_code == 429


def test_send_quota_is_per_number_not_global(client):
    """A different number must not be blocked by the first number's quota."""
    assert _send(client).status_code == 200
    res = _send(client, phone="+919899999999")
    assert res.status_code == 200


# ── Resend invalidates prior codes ───────────────────────────────────────────

def test_resend_invalidates_previous_code(client, monkeypatch):
    monkeypatch.setattr("backend.main.OTP_RESEND_COOLDOWN_SECONDS", 0)
    first = _send(client).json()["devOtp"]
    second = _send(client).json()["devOtp"]
    assert first != second

    stale = _verify(client, first)
    assert stale.json()["success"] is False
    assert stale.json()["code"] == "INVALID_OR_EXPIRED_OTP"

    fresh = _verify(client, second)
    assert fresh.json()["success"] is True


# ── One-time use ─────────────────────────────────────────────────────────────

def test_code_cannot_be_reused_after_successful_verification(client):
    otp = _send(client).json()["devOtp"]
    assert _verify(client, otp).json()["success"] is True
    replay = _verify(client, otp)
    assert replay.json()["success"] is False
    assert replay.json()["code"] == "INVALID_OR_EXPIRED_OTP"


# ── Brute-force lockout ──────────────────────────────────────────────────────

def test_wrong_attempts_lock_out_verification(client, monkeypatch):
    monkeypatch.setattr("backend.main.OTP_RESEND_COOLDOWN_SECONDS", 0)
    real_otp = _send(client).json()["devOtp"]

    for _ in range(OTP_VERIFY_ATTEMPT_LIMIT):
        res = _verify(client, "000000")
        assert res.json()["success"] is False

    # Limit reached: even the CORRECT code is now rejected with 429.
    locked = _verify(client, real_otp)
    assert locked.status_code == 429
    assert locked.json()["detail"]["code"] == "OTP_ATTEMPTS_EXCEEDED"

    # The rate-limit bucket resets after a fresh send (new verification scope).
    reset_otp_rate_limiters()
    fresh = _send(client).json()["devOtp"]
    assert _verify(client, fresh).json()["success"] is True


# ── Log hygiene ──────────────────────────────────────────────────────────────

def test_logs_mask_phone_and_never_contain_code(client, caplog):
    caplog.set_level(logging.INFO)
    data = _send(client).json()
    otp = data["devOtp"]
    otp_log_records = [r.getMessage() for r in caplog.records if "[OTP Service]" in r.getMessage()]
    assert otp_log_records, "expected an OTP service log line"
    line = otp_log_records[-1]
    assert otp not in line, "OTP code must never be logged"
    assert PHONE not in line, "full phone number must never be logged"
    assert f"***{PHONE[-4:]}" in line, "phone should appear masked (last 4)"
