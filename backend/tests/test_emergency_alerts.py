"""
Emergency hive-alert system (spec §1–§15 of the alert spec).

Pins the full lifecycle:
  telemetry → detection (AI/ML output + sudden-change) → persistent HiveAlert
  → WebSocket emergency event → acknowledgment (authorized, idempotent)
  → permanent history.

No dummy values: alerts must carry real previous/current sensor readings.
"""
from __future__ import annotations

import time
import uuid

import pytest
from fastapi.testclient import TestClient

from backend.database import SessionLocal, init_db
from backend.main import app, create_access_token
from backend.models import Hive, HiveAlert, HiveTelemetry, User
from backend.services.mqtt_consumer import mqtt_consumer


@pytest.fixture(scope="module")
def client():
    init_db()
    return TestClient(app)


@pytest.fixture()
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def _harvester(db, tag: str) -> User:
    sfx = f"{uuid.uuid4().hex[:6]}{tag}"
    user = User(
        name=f"AlertHarv {sfx}",
        email=f"alert_{sfx}@example.test",
        phone=f"+9191800{sfx[-6:]}",
        role="HARVESTER",
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _hive(db, user: User, tag: str, device_id: str | None = None) -> Hive:
    sfx = f"{uuid.uuid4().hex[:6]}{tag}"
    hive = Hive(
        user_id=user.id,
        device_id=device_id or f"SIH_ALERT_{sfx}",
        hive_code=f"HIVE-ALERT-{sfx}",
        name=f"Alert Hive {sfx}",
        apiary_location="Alert Apiary",
    )
    db.add(hive)
    db.commit()
    db.refresh(hive)
    return hive


def _headers(user: User) -> dict:
    token = create_access_token({"sub": user.id, "email": user.email, "role": user.role})
    return {"Authorization": f"Bearer {token}"}


# ============================================================
# Detection from the EXISTING AI/ML output (consumer path)
# ============================================================

class TestAiProcessedAlerts:
    def test_ai_alert_stores_real_previous_and_current_values(self, db):
        user = _harvester(db, "a1")
        hive = _hive(db, user, "a1")
        base = 1_700_000_000

        # Normal reading first (becomes the real baseline).
        mqtt_consumer.process_processed_payload({
            "device_id": hive.device_id,
            "timestamp": base,
            "hive_status": {"risk_level": "LOW", "status": "HEALTHY", "anomaly_detected": False, "anomaly_score": 0.001},
            "sensors": {"temperature_c": 34.2, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245},
            "analysis": {}, "alerts": [], "analysis_summary": {"reasons": []},
            "diagnostics": {},
        })
        # Sudden abnormal temperature on the next reading.
        mqtt_consumer.process_processed_payload({
            "device_id": hive.device_id,
            "timestamp": base + 600,
            "hive_status": {"risk_level": "HIGH", "status": "ALERT", "anomaly_detected": True, "anomaly_score": 0.62},
            "sensors": {"temperature_c": 41.8, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245},
            "analysis": {},
            "alerts": [{"type": "TEMPERATURE", "severity": "CRITICAL", "message": "Sudden abnormal temperature change detected."}],
            "analysis_summary": {"reasons": ["temperature out of range"]},
            "diagnostics": {},
        })

        alert = (
            db.query(HiveAlert)
            .filter(HiveAlert.hive_id == hive.id, HiveAlert.parameter == "Temperature")
            .order_by(HiveAlert.detected_at.desc())
            .first()
        )
        assert alert is not None
        assert alert.previous_value == "34.2°C"   # real stored baseline
        assert alert.current_value == "41.8°C"    # real current reading
        assert alert.change_value == "+7.6°C"
        assert alert.severity == "CRITICAL"
        assert alert.status == "ACTIVE"
        assert "temperature" in alert.message.lower()

    def test_multivariate_alert_does_not_fabricate_a_delta(self, db):
        user = _harvester(db, "a2")
        hive = _hive(db, user, "a2")
        base = 1_700_100_000

        mqtt_consumer.process_processed_payload({
            "device_id": hive.device_id,
            "timestamp": base,
            "hive_status": {"risk_level": "MEDIUM", "status": "ATTENTION", "anomaly_detected": True, "anomaly_score": 0.4},
            "sensors": {"temperature_c": 34.0, "humidity_pct": 60.0, "weight_kg": 3.0, "acoustics_hz": 240},
            "analysis": {},
            "alerts": [{"type": "ANOMALY", "severity": "CRITICAL", "message": "Multivariate hive telemetry shows an unusual pattern."}],
            "analysis_summary": {"reasons": ["multivariate anomaly"]},
            "diagnostics": {},
        })

        alert = db.query(HiveAlert).filter(HiveAlert.hive_id == hive.id).order_by(HiveAlert.detected_at.desc()).first()
        assert alert is not None
        assert alert.parameter == "Anomaly"
        assert alert.previous_value is None       # no single-channel baseline invented
        assert alert.change_value is None
        assert "Multivariate" in alert.message    # the AI reason, verbatim

    def test_qos_redelivery_does_not_duplicate_alert_rows(self, db):
        user = _harvester(db, "a3")
        hive = _hive(db, user, "a3")
        base = 1_700_200_000
        packet = {
            "device_id": hive.device_id,
            "timestamp": base,
            "hive_status": {"risk_level": "HIGH", "status": "ALERT", "anomaly_detected": True, "anomaly_score": 0.5},
            "sensors": {"temperature_c": 40.0, "humidity_pct": 60.0, "weight_kg": 3.0, "acoustics_hz": 240},
            "analysis": {},
            "alerts": [{"type": "TEMPERATURE", "severity": "CRITICAL", "message": "Hot."}],
            "analysis_summary": {"reasons": []},
            "diagnostics": {},
        }

        mqtt_consumer.process_processed_payload(packet)
        mqtt_consumer.process_processed_payload(packet)  # QoS 1 redelivery

        assert db.query(HiveAlert).filter_by(hive_id=hive.id).count() == 1

    def test_critical_alert_broadcasts_websocket_emergency_event(self, db):
        received = []
        mqtt_consumer.listeners.append(received.append)
        try:
            user = _harvester(db, "a4")
            hive = _hive(db, user, "a4")
            mqtt_consumer.process_processed_payload({
                "device_id": hive.device_id,
                "timestamp": int(time.time()),
                "hive_status": {"risk_level": "HIGH", "status": "ALERT", "anomaly_detected": True, "anomaly_score": 0.7},
                "sensors": {"temperature_c": 42.5, "humidity_pct": 60.0, "weight_kg": 3.0, "acoustics_hz": 240},
                "analysis": {},
                "alerts": [{"type": "TEMPERATURE", "severity": "CRITICAL", "message": "Spike."}],
                "analysis_summary": {"reasons": []},
                "diagnostics": {},
            })
        finally:
            mqtt_consumer.listeners.remove(received.append)

        assert received, "critical alert must broadcast to WebSocket listeners"
        emergency = [r for r in received if r.get("emergency")]
        assert emergency, f"expected emergency payload in broadcast, got: {received[-1].keys() if received else None}"
        payload = emergency[-1]
        assert payload["emergency"]["severity"] == "CRITICAL"
        assert payload["emergency"]["hiveId"] == hive.id
        assert payload["alertIds"], "broadcast must carry the DB alert IDs for acknowledgment"

    def test_humidty_alert_maps_to_humidity_channel(self, db):
        user = _harvester(db, "a5")
        hive = _hive(db, user, "a5")
        base = 1_700_300_000

        mqtt_consumer.process_processed_payload({
            "device_id": hive.device_id,
            "timestamp": base,
            "hive_status": {"risk_level": "MEDIUM", "status": "ATTENTION", "anomaly_detected": False, "anomaly_score": 0.2},
            "sensors": {"temperature_c": 34.0, "humidity_pct": 85.0, "weight_kg": 3.0, "acoustics_hz": 240},
            "analysis": {},
            "alerts": [{"type": "HUMIDITY", "severity": "WARNING", "message": "Humidity out of range."}],
            "analysis_summary": {"reasons": []},
            "diagnostics": {},
        })

        alert = db.query(HiveAlert).filter(HiveAlert.hive_id == hive.id).order_by(HiveAlert.detected_at.desc()).first()
        assert alert is not None
        assert alert.parameter == "Humidity"
        assert alert.unit == "%"
        assert alert.current_value == "85.0%"


# ============================================================
# Direct ingest path: sudden change, real baseline, dedup, auth
# ============================================================

class TestIngestSuddenChange:
    def test_normal_telemetry_creates_no_alert(self, client, db):
        user = _harvester(db, "b1")
        hive = _hive(db, user, "b1")
        res = client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 34.5, "humidity": 60.0, "weightKg": 3.0,
        }, headers=_headers(user))
        assert res.status_code == 200
        assert res.json()["alerts"] == []
        assert db.query(HiveAlert).filter_by(hive_id=hive.id).count() == 0

    def test_first_ever_reading_cannot_claim_a_sudden_change(self, client, db):
        user = _harvester(db, "b2")
        hive = _hive(db, user, "b2")
        res = client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 45.0, "humidity": 60.0, "weightKg": 3.0,
        }, headers=_headers(user))
        assert res.status_code == 200
        # No previous reading exists → no previous→current story to tell.
        assert res.json()["alerts"] == []

    def test_sudden_change_creates_critical_alert_with_real_values(self, client, db):
        user = _harvester(db, "b3")
        hive = _hive(db, user, "b3")
        h = _headers(user)
        assert client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 34.2, "humidity": 60.0, "weightKg": 3.0,
        }, headers=h).status_code == 200

        res = client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 41.8, "humidity": 60.0, "weightKg": 3.0,
        }, headers=h)
        assert res.status_code == 200
        alerts = res.json()["alerts"]
        assert len(alerts) == 1
        a = alerts[0]
        assert a["severity"] == "CRITICAL"
        assert a["parameter"] == "Temperature"
        assert a["previousValue"] == "34.2°C"
        assert a["currentValue"] == "41.8°C"
        assert a["changeValue"] == "+7.6°C"
        assert a["id"], "alert payload must carry the DB id"

    def test_duplicate_event_does_not_stack_alerts(self, client, db):
        user = _harvester(db, "b4")
        hive = _hive(db, user, "b4")
        h = _headers(user)
        client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 34.2, "humidity": 60.0, "weightKg": 3.0,
        }, headers=h)
        spike = {"hiveId": hive.id, "temperature": 41.8, "humidity": 60.0, "weightKg": 3.0}
        first = client.post("/api/telemetry/ingest", json=spike, headers=h)
        second = client.post("/api/telemetry/ingest", json=spike, headers=h)

        assert len(first.json()["alerts"]) == 1
        assert second.json()["alerts"] == []  # same event → deduped
        assert db.query(HiveAlert).filter_by(hive_id=hive.id).count() == 1

    def test_ingest_requires_authentication(self, client, db):
        user = _harvester(db, "b5")
        hive = _hive(db, user, "b5")
        res = client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 34.0, "humidity": 60.0, "weightKg": 3.0,
        })
        assert res.status_code == 401

    def test_ingest_for_another_users_hive_is_forbidden(self, client, db):
        owner = _harvester(db, "b6")
        intruder = _harvester(db, "b6x")
        hive = _hive(db, owner, "b6")
        res = client.post("/api/telemetry/ingest", json={
            "hiveId": hive.id, "temperature": 34.0, "humidity": 60.0, "weightKg": 3.0,
        }, headers=_headers(intruder))
        assert res.status_code == 403


# ============================================================
# Acknowledgment: authorized, idempotent, permanent history
# ============================================================

def _mk_alert(db, hive: Hive) -> HiveAlert:
    alert = HiveAlert(
        hive_id=hive.id,
        hive_code=hive.hive_code,
        device_id=hive.device_id,
        parameter="Temperature",
        previous_value="34.2°C",
        current_value="41.8°C",
        change_value="+7.6°C",
        unit="°C",
        severity="CRITICAL",
        message="Sudden abnormal temperature change detected: 34.2°C → 41.8°C",
        status="ACTIVE",
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert


class TestAcknowledgment:
    def test_owner_acknowledge_updates_state_and_returns_alert(self, client, db):
        user = _harvester(db, "c1")
        hive = _hive(db, user, "c1")
        alert = _mk_alert(db, hive)

        res = client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={}, headers=_headers(user))
        assert res.status_code == 200
        body = res.json()
        assert body["success"] is True
        returned = body["alert"]
        assert returned["status"] == "ACKNOWLEDGED"
        assert returned["acknowledgedBy"] == user.id
        assert returned["acknowledgedAt"]
        # Original alert data preserved — only acknowledgment state changed.
        assert returned["previousValue"] == "34.2°C"
        assert returned["currentValue"] == "41.8°C"
        assert returned["message"] == alert.message

    def test_acknowledge_is_idempotent_first_ack_wins(self, client, db):
        user = _harvester(db, "c2")
        hive = _hive(db, user, "c2")
        alert = _mk_alert(db, hive)
        h = _headers(user)

        first = client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={}, headers=h)
        second = client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={}, headers=h)

        assert first.status_code == 200 and second.status_code == 200
        db.refresh(alert)
        assert alert.status == "ACKNOWLEDGED"
        assert alert.acknowledged_by == user.id  # unchanged by the second call

    def test_non_owner_cannot_acknowledge(self, client, db):
        owner = _harvester(db, "c3")
        intruder = _harvester(db, "c3x")
        hive = _hive(db, owner, "c3")
        alert = _mk_alert(db, hive)

        res = client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={}, headers=_headers(intruder))
        assert res.status_code == 403
        db.refresh(alert)
        assert alert.status == "ACTIVE"  # untouched

    def test_acknowledge_requires_authentication(self, client, db):
        user = _harvester(db, "c4")
        hive = _hive(db, user, "c4")
        alert = _mk_alert(db, hive)
        res = client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={})
        assert res.status_code == 401

    def test_unknown_alert_is_404_not_500(self, client, db):
        user = _harvester(db, "c5")
        res = client.post(f"/api/telemetry/alerts/{uuid.uuid4()}/acknowledge", json={}, headers=_headers(user))
        assert res.status_code == 404

    def test_acknowledged_alert_stays_in_history_and_off_active(self, client, db):
        user = _harvester(db, "c6")
        hive = _hive(db, user, "c6")
        alert = _mk_alert(db, hive)
        h = _headers(user)
        client.post(f"/api/telemetry/alerts/{alert.id}/acknowledge", json={}, headers=h)

        active = client.get("/api/telemetry/alerts", params={"status": "ACTIVE"}, headers=h).json()["alerts"]
        history = client.get("/api/telemetry/alerts", params={"status": "ACKNOWLEDGED"}, headers=h).json()["alerts"]
        assert all(a["id"] != alert.id for a in active)
        match = [a for a in history if a["id"] == alert.id]
        assert match, "acknowledged alert must remain in permanent history"
        assert match[0]["acknowledgedBy"] == user.id
        assert match[0]["acknowledgedAt"]

    def test_multiple_hives_keep_alerts_isolated(self, client, db):
        user = _harvester(db, "c7")
        hive_a = _hive(db, user, "c7a")
        hive_b = _hive(db, user, "c7b")
        _mk_alert(db, hive_a)
        _mk_alert(db, hive_b)

        only_a = client.get("/api/telemetry/alerts", params={"hive_id": hive_a.id}, headers=_headers(user)).json()["alerts"]
        assert only_a and all(a["hiveId"] == hive_a.id for a in only_a)
