"""
Integration tests for the IoT + MQTT telemetry API layer (outside ai_ml/).

Covers spec requirements:
- REST: latest telemetry, history, AI status, alerts
- Authorization: users cannot read another user's hive telemetry by ID swap
- Empty state: a hive with no telemetry returns hasTelemetry=false (no fake data)
- MQTT consumer: validation of malformed payloads, idempotent persistence
"""
from __future__ import annotations

import time
import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import Hive, User
from backend.services.mqtt_consumer import mqtt_consumer


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


@pytest.fixture(scope="module")
def db():
    init_db()
    session = SessionLocal()
    yield session
    session.close()


def _make_harvester(db, suffix: str) -> User:
    user = User(
        name=f"Harvester {suffix}",
        email=f"tel_harvester_{suffix}@example.test",
        phone=f"+91919000{suffix[-6:]}",
        role="HARVESTER",
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _make_hive(db, user: User, suffix: str, device_id: str | None = None) -> Hive:
    hive = Hive(
        user_id=user.id,
        device_id=device_id,
        hive_code=f"HIVE-TEL-{suffix}",
        name=f"Telemetry Hive {suffix}",
        apiary_location="Test Apiary",
    )
    db.add(hive)
    db.commit()
    db.refresh(hive)
    return hive


def _headers(user: User) -> dict:
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


def test_latest_telemetry_empty_state_has_no_fabricated_data(client, db):
    suffix = uuid.uuid4().hex[:8]
    user = _make_harvester(db, suffix)
    hive = _make_hive(db, user, suffix, device_id=f"SIH_TEL_EMPTY_{suffix}")

    res = client.get(f"/api/hives/{hive.id}/telemetry/latest", headers=_headers(user))
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert body["hasTelemetry"] is False
    assert body["telemetry"] is None
    assert body["hasAiAnalysis"] is False
    assert body["aiStatus"] is None
    # Honest readiness toward the AI 145-reading history requirement.
    assert body["aiReadiness"]["requiredReadings"] == 145
    assert body["aiReadiness"]["ready"] is False
    assert "Collecting telemetry history" in body["aiReadiness"]["message"]


def test_latest_and_history_and_status_after_processed_mqtt(client, db):
    suffix = uuid.uuid4().hex[:8]
    user = _make_harvester(db, suffix)
    device_id = f"SIH_TEL_LIVE_{suffix}"
    hive = _make_hive(db, user, suffix, device_id=device_id)

    timestamp = int(time.time())
    processed = {
        "device_id": device_id,
        "timestamp": timestamp,
        "hive_status": {
            "risk_level": "MEDIUM",
            "status": "ATTENTION",
            "anomaly_detected": True,
            "anomaly_score": 0.6341,
        },
        "sensors": {"temperature_c": 34.2, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245},
        "analysis": {
            "temperature": {"status": "NORMAL", "value": 34.2, "reference_range": {"min": 30.0, "max": 36.0}},
            "humidity": {"status": "NORMAL", "value": 61.5, "reference_range": {"min": 50.0, "max": 70.0}},
            "weight": {"status": "STABLE", "trend": "STABLE", "value_kg": 3.25},
            "acoustics": {"status": "NORMAL", "value_hz": 245},
        },
        "alerts": [{"severity": "MEDIUM", "type": "ANOMALY", "message": "Multivariate hive telemetry shows an unusual pattern."}],
        "analysis_summary": {"reasons": ["multivariate ML anomaly detected"]},
        "diagnostics": {"battery_v": 4.12, "wifi_rssi_dbm": -68},
    }
    mqtt_consumer.process_processed_payload(processed)

    # Latest endpoint exposes real values + AI status (attention case).
    latest = client.get(f"/api/hives/{hive.id}/telemetry/latest", headers=_headers(user))
    assert latest.status_code == 200
    body = latest.json()
    assert body["hasTelemetry"] is True
    assert body["telemetry"]["temperature"] == 34.2
    assert body["telemetry"]["humidity"] == 61.5
    assert body["telemetry"]["weightKg"] == 3.25
    assert body["telemetry"]["acousticsHz"] == 245
    assert body["telemetry"]["batteryLevel"] == 4.12
    assert body["telemetry"]["signalStrength"] == -68
    assert body["hasAiAnalysis"] is True
    assert body["aiStatus"]["status"] == "ATTENTION"
    assert body["aiStatus"]["riskLevel"] == "MEDIUM"
    assert body["aiStatus"]["anomalyDetected"] is True
    assert body["aiStatus"]["alerts"][0]["message"].startswith("Multivariate")
    assert body["aiReadiness"]["ready"] is True

    # History endpoint returns the stored reading.
    history = client.get(f"/api/hives/{hive.id}/telemetry", headers=_headers(user))
    assert history.status_code == 200
    hbody = history.json()
    assert hbody["success"] is True
    assert hbody["count"] == 1
    assert hbody["telemetry"][0]["timestamp"] == timestamp

    # Status endpoint mirrors the AI result.
    status = client.get(f"/api/hives/{hive.id}/status", headers=_headers(user))
    assert status.status_code == 200
    sbody = status.json()
    assert sbody["hasAnalysis"] is True
    assert sbody["aiStatus"]["status"] == "ATTENTION"
    assert sbody["aiReadiness"]["ready"] is True

    # Alerts were persisted from the real AI output.
    alerts = client.get("/api/telemetry/alerts", headers=_headers(user))
    assert alerts.status_code == 200
    assert any(a["message"].startswith("Multivariate") for a in alerts.json()["alerts"])


def test_user_cannot_read_another_users_hive_telemetry(client, db):
    suffix = uuid.uuid4().hex[:8]
    owner = _make_harvester(db, suffix)
    intruder = _make_harvester(db, "other" + suffix)
    hive = _make_hive(db, owner, suffix, device_id=f"SIH_TEL_IDOR_{suffix}")

    for path in (
        f"/api/hives/{hive.id}/telemetry/latest",
        f"/api/hives/{hive.id}/telemetry",
        f"/api/hives/{hive.id}/status",
        f"/api/hives/{hive.id}",
    ):
        res = client.get(path, headers=_headers(intruder))
        assert res.status_code == 403, f"{path} returned {res.status_code}"

    # Device-id resolution is guarded too.
    res = client.get(f"/api/hives/{hive.device_id}/telemetry/latest", headers=_headers(intruder))
    assert res.status_code == 403


def test_telemetry_endpoints_require_authentication(client, db):
    suffix = uuid.uuid4().hex[:8]
    user = _make_harvester(db, suffix)
    hive = _make_hive(db, user, suffix)

    for path in (
        f"/api/hives/{hive.id}/telemetry/latest",
        f"/api/hives/{hive.id}/telemetry",
        f"/api/hives/{hive.id}/status",
        "/api/telemetry/alerts",
    ):
        res = client.get(path)
        assert res.status_code == 401, f"{path} returned {res.status_code}"


def test_mqtt_consumer_rejects_malformed_payloads_without_storing(client, db):
    suffix = uuid.uuid4().hex[:8]
    user = _make_harvester(db, suffix)
    device_id = f"SIH_TEL_BAD_{suffix}"
    hive = _make_hive(db, user, suffix, device_id=device_id)

    from backend.models import HiveAIAnalysis, HiveTelemetry

    # Missing sensors object entirely.
    mqtt_consumer.process_processed_payload({"device_id": device_id, "timestamp": int(time.time())})
    # Null sensor field.
    mqtt_consumer.process_raw_telemetry_payload({
        "device_id": device_id,
        "timestamp": int(time.time()),
        "sensors": {"temperature_c": None, "humidity_pct": 55.0, "weight_kg": 2.0, "acoustics_hz": 240},
    })
    # Non-numeric sensor value.
    mqtt_consumer.process_raw_telemetry_payload({
        "device_id": device_id,
        "timestamp": int(time.time()),
        "sensors": {"temperature_c": "hot", "humidity_pct": 55.0, "weight_kg": 2.0, "acoustics_hz": 240},
    })
    # Missing timestamp.
    mqtt_consumer.process_raw_telemetry_payload({
        "device_id": device_id,
        "sensors": {"temperature_c": 34.0, "humidity_pct": 55.0, "weight_kg": 2.0, "acoustics_hz": 240},
    })

    assert db.query(HiveTelemetry).filter_by(hive_id=hive.id).count() == 0
    assert db.query(HiveAIAnalysis).filter_by(hive_id=hive.id).count() == 0

    # The on_message JSON error path is also safe.
    class _Msg:
        topic = "honeychain/hive/processed"
        payload = b"{not-json"

    mqtt_consumer.on_message(None, None, _Msg())  # must not raise


def test_out_of_order_timestamps_are_stored_with_their_own_timestamp(db):
    suffix = uuid.uuid4().hex[:8]
    user = _make_harvester(db, suffix)
    device_id = f"SIH_TEL_ORD_{suffix}"
    hive = _make_hive(db, user, suffix, device_id=device_id)

    from backend.models import HiveTelemetry

    base = 1_700_000_000
    for ts in (base + 1200, base, base + 600):  # deliberately out of order
        mqtt_consumer.process_raw_telemetry_payload({
            "device_id": device_id,
            "timestamp": ts,
            "sensors": {"temperature_c": 34.0 + (ts - base) / 1e6, "humidity_pct": 60.0, "weight_kg": 3.0, "acoustics_hz": 240},
        })

    stored = {t.timestamp for t in db.query(HiveTelemetry).filter_by(hive_id=hive.id).all()}
    assert stored == {base, base + 600, base + 1200}
