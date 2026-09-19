from __future__ import annotations

from uuid import uuid4

from backend.database import SessionLocal, init_db
from backend.models import Hive, HiveAIAnalysis, HiveAlert, HiveTelemetry, User
from backend.services.mqtt_consumer import mqtt_consumer


def test_canonical_and_legacy_packets_are_idempotent() -> None:
    init_db()
    db = SessionLocal()
    suffix = uuid4().hex[:12]
    device_id = f"test-device-{suffix}"
    timestamp = 1_700_000_000
    try:
        user = User(name="MQTT Test", email=f"mqtt-{suffix}@example.test", role="HARVESTER")
        db.add(user)
        db.flush()
        hive = Hive(
            user_id=user.id,
            device_id=device_id,
            hive_code=f"HIVE-{suffix}",
            name="MQTT Test Hive",
            apiary_location="Test Apiary",
        )
        db.add(hive)
        db.commit()

        canonical = {
            "device_id": device_id,
            "timestamp": timestamp,
            "sensors": {"temperature_c": 34.2, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245},
            "diagnostics": {"battery_v": 4.12, "wifi_rssi_dbm": -68},
        }
        mqtt_consumer.process_raw_telemetry_payload(canonical)
        mqtt_consumer.process_raw_telemetry_payload(canonical)

        processed = {
            **canonical,
            "hive_status": {"risk_level": "LOW", "status": "HEALTHY", "anomaly_detected": False, "anomaly_score": 0.1},
            "analysis": {},
            "alerts": [],
            "analysis_summary": {"reasons": []},
        }
        mqtt_consumer.process_processed_payload(processed)
        mqtt_consumer.process_processed_payload(processed)

        assert db.query(HiveTelemetry).filter_by(hive_id=hive.id, timestamp=timestamp).count() == 1
        assert db.query(HiveAIAnalysis).filter_by(hive_id=hive.id, timestamp=timestamp).count() == 1

        alert_payload = {
            **processed,
            "timestamp": timestamp + 1200,
            "hive_status": {"risk_level": "HIGH", "status": "ALERT", "anomaly_detected": True, "anomaly_score": 0.9},
            "alerts": [{"message": "Temperature above reference range.", "type": "TEMPERATURE", "severity": "MEDIUM"}],
        }
        mqtt_consumer.process_processed_payload(alert_payload)
        mqtt_consumer.process_processed_payload(alert_payload)
        assert db.query(HiveAlert).filter_by(hive_id=hive.id, device_id=device_id).count() == 1

        # Legacy flat packets (no nested sensors object) are rejected under the
        # strict ESP32 telemetry contract: real telemetry only, no fabricated
        # defaults for missing sensor channels (spec §18).
        legacy_timestamp = timestamp + 600
        mqtt_consumer.process_raw_telemetry_payload({
            "deviceId": device_id,
            "timestamp": legacy_timestamp,
            "temperature": 35.0,
            "humidity": 60.0,
            "weight": 3.4,
            "acoustics": 240,
        })
        assert db.query(HiveTelemetry).filter_by(hive_id=hive.id, timestamp=legacy_timestamp).count() == 0
    finally:
        db.close()


def test_malformed_processed_payload_does_not_raise() -> None:
    mqtt_consumer.process_processed_payload({})
    mqtt_consumer.process_raw_telemetry_payload({"timestamp": "bad"})
