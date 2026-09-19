"""
Live end-to-end verification of the HoneyChain telemetry pipeline
(outside ai_ml/ — ai_ml components are executed, never modified).

Flow verified:
  simulator (ESP32 stand-in) -> honeychain/hive/telemetry -> Mosquitto
  -> EXISTING ai_ml.mqtt.mqtt_processor -> honeychain/hive/processed
  -> backend MQTT consumer -> PostgreSQL/SQLite -> REST API

Usage (from project root, backend venv):
  backend/.venv/Scripts/python.exe scripts/verify_mqtt_e2e.py

Database: by default the authoritative Supabase PostgreSQL (DATABASE_URL from
backend/.env). Set E2E_DB=sqlite for an offline SQLite run instead.

Requires Mosquitto on localhost:1883.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

# Default target: the authoritative Supabase PostgreSQL database (DATABASE_URL
# is loaded from backend/.env by backend.database). No SQLite fallback unless
# explicitly requested with E2E_DB=sqlite.
if os.environ.get("E2E_DB", "postgres").lower() == "sqlite":
    os.environ["DEV_OFFLINE_SQLITE"] = "true"
    os.environ["ENV"] = "test"
os.environ["MQTT_HOST"] = os.environ.get("MQTT_HOST", "localhost")
os.environ["MQTT_PORT"] = os.environ.get("MQTT_PORT", "1883")

# Dedicated E2E device: keeps the demo device SIH_HIVE_MVP_01 history
# untouched. Legacy rows for MVP_01 contain duplicate timestamps, and the
# (unmodified) AI feature builder requires 145 DISTINCT-timestamp readings,
# so verification runs on a clean device->hive mapping.
DEVICE_ID = os.environ.get("E2E_DEVICE_ID", "SIH_HIVE_E2E_01")
PYTHON = sys.executable


def log(step: str, message: str) -> None:
    print(f"[E2E {step}] {message}", flush=True)


def main() -> int:
    log("1", "Initializing isolated database...")
    from backend.database import SessionLocal, init_db
    from backend.models import Hive, HiveAIAnalysis, HiveTelemetry, User
    from backend.services.mqtt_consumer import mqtt_consumer

    init_db()
    db = SessionLocal()
    engine_name = db.get_bind().dialect.name
    log("1", f"Database engine in use: {engine_name}")
    suffix = str(int(time.time()))

    # Reuse the existing device->hive->user mapping when present (spec §5:
    # never create conflicting IDs or duplicate device records).
    hive = db.query(Hive).filter(Hive.device_id == DEVICE_ID).first()
    if hive is None:
        user = User(
            name="E2E Harvester",
            email=f"e2e_harvester@honeychain.test",
            role="HARVESTER",
            is_verified=True,
        )
        existing_user = db.query(User).filter(User.email == user.email).first()
        if existing_user:
            user = existing_user
        else:
            db.add(user)
            db.flush()
        hive = Hive(
            user_id=user.id,
            device_id=DEVICE_ID,
            hive_code=f"HIVE-E2E-{DEVICE_ID}",
            name="E2E Verification Hive",
            apiary_location="E2E Apiary",
        )
        db.add(hive)
        db.commit()
        db.refresh(hive)
    user = db.query(User).filter(User.id == hive.user_id).first()
    log("1", f"Hive {hive.hive_code} mapped to device {DEVICE_ID} (user {user.email})")

    # Seed/top-up 145 readings (the AI feature-builder history requirement)
    # so the processor's AI_HISTORY_RELOAD preloads history from the SAME
    # database and produces a full analysis for the first fresh reading.
    # Re-running against Supabase: only insert what is missing (readings are
    # idempotent on device_id+timestamp, never duplicated).
    HISTORY_REQUIRED = 145
    existing_rows = db.query(HiveTelemetry).filter_by(hive_id=hive.id).count()
    need = max(0, HISTORY_REQUIRED - existing_rows)
    now = int(time.time())
    newest = (
        db.query(HiveTelemetry.timestamp)
        .filter_by(hive_id=hive.id)
        .order_by(HiveTelemetry.timestamp.desc())
        .first()
    )
    base_ts = max(now, (newest[0] + 600) if newest else now)
    log("2", f"Seeding historical readings (have {existing_rows}, adding {need})...")
    for i in range(need):
        ts = base_ts - (need - i) * 600
        mqtt_consumer.process_raw_telemetry_payload({
            "device_id": DEVICE_ID,
            "timestamp": ts,
            "sensors": {"temperature_c": 34.2, "humidity_pct": 61.5, "weight_kg": 3.25, "acoustics_hz": 245},
            "diagnostics": {"battery_v": 4.12, "wifi_rssi_dbm": -68},
        })
    count = db.query(HiveTelemetry).filter_by(hive_id=hive.id).count()
    db.commit()
    log("2", f"Seeded telemetry rows: {count} total (target {HISTORY_REQUIRED})")

    # Baselines: the run passes only when BOTH exceed these, so pre-existing
    # rows in a long-lived database (e.g. Supabase) cannot fake a pass.
    baseline_analyses = db.query(HiveAIAnalysis).filter_by(hive_id=hive.id).count()
    baseline_ts_row = (
        db.query(HiveTelemetry.timestamp)
        .filter_by(hive_id=hive.id)
        .order_by(HiveTelemetry.timestamp.desc())
        .first()
    )
    baseline_ts = baseline_ts_row[0] if baseline_ts_row else 0
    log("2", f"Baselines: analyses={baseline_analyses} latest_telemetry_ts={baseline_ts}")

    # Start the backend MQTT consumer against the real broker.
    log("3", "Starting backend MQTT consumer (localhost:1883)...")
    received_events: list[dict] = []
    mqtt_consumer.add_listener(lambda data: received_events.append(data))
    mqtt_consumer.start()

    # Terminal 1 equivalent: the EXISTING, unmodified AI processor.
    # stdout goes to an unbuffered file: Windows TerminateProcess discards
    # pipe buffers, so this is the only reliable way to see its logs.
    ai_proc_log = PROJECT_ROOT / "scripts" / "ai_processor_last_run.log"
    log("4", "Launching existing AI/ML processor (ai_ml.mqtt.mqtt_processor)...")
    with ai_proc_log.open("w", encoding="utf-8") as ai_proc_file:
        ai_proc = subprocess.Popen(
            [PYTHON, "-m", "ai_ml.mqtt.mqtt_processor"],
            cwd=str(PROJECT_ROOT),
            env={**os.environ, "MQTT_BROKER": "localhost", "AI_HISTORY_RELOAD": "true", "PYTHONUNBUFFERED": "1"},
            stdout=ai_proc_file,
            stderr=subprocess.STDOUT,
            text=True,
        )

    try:
        # Terminal 3 equivalent: the EXISTING, unmodified simulator.
        time.sleep(10)  # allow model load + AI history reload from Supabase
        log("5", "Launching existing simulator (ai_ml.tests.mqtt_simulator)...")
        sim = subprocess.run(
            [
                PYTHON, "-m", "ai_ml.tests.mqtt_simulator",
                "--host", "localhost", "--port", "1883",
                "--topic", "honeychain/hive/telemetry",
                "--device-id", DEVICE_ID,
                "--count", "4", "--interval", "0.5",
            ],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            timeout=60,
        )
        log("5", f"Simulator finished (rc={sim.returncode})")

        # Wait for NEW processed output AND the matching raw telemetry row.
        # The consumer handles processed (AI) messages on a priority queue,
        # so the raw telemetry row can lag the analysis by a moment — wait
        # for BOTH before declaring success.
        deadline = time.time() + 40
        analyses = baseline_analyses
        new_ts = baseline_ts
        while time.time() < deadline:
            db.expire_all()
            analyses = (
                db.query(HiveAIAnalysis)
                .filter_by(hive_id=hive.id)
                .count()
            )
            ts_row = (
                db.query(HiveTelemetry.timestamp)
                .filter_by(hive_id=hive.id)
                .order_by(HiveTelemetry.timestamp.desc())
                .first()
            )
            new_ts = ts_row[0] if ts_row else 0
            if analyses > baseline_analyses and new_ts > baseline_ts:
                break
            time.sleep(1)

        log("6", f"Stored AI analyses for hive: {analyses} (baseline {baseline_analyses})")
        new_telemetry = (
            db.query(HiveTelemetry)
            .filter_by(hive_id=hive.id)
            .order_by(HiveTelemetry.timestamp.desc())
            .first()
        )
        if analyses <= baseline_analyses or new_telemetry is None or new_telemetry.timestamp <= baseline_ts:
            log("FAIL", "Pipeline did not produce NEW stored AI results in time.")
            return 1

        latest_analysis = (
            db.query(HiveAIAnalysis)
            .filter_by(hive_id=hive.id)
            .order_by(HiveAIAnalysis.timestamp.desc())
            .first()
        )
        log("6", (
            f"Latest AI result: status={latest_analysis.status} "
            f"risk={latest_analysis.risk_level} "
            f"anomaly={latest_analysis.anomaly_detected} "
            f"score={latest_analysis.anomaly_score}"
        ))
        log("6", f"New telemetry timestamp: {new_telemetry.timestamp} (baseline {baseline_ts})")
        log("6", (
            f"Latest telemetry: temp={new_telemetry.temperature_c}C "
            f"hum={new_telemetry.humidity_pct}% weight={new_telemetry.weight_kg}kg "
            f"acoustics={new_telemetry.acoustics_hz}Hz battery={new_telemetry.battery_v}V"
        ))
        assert latest_analysis.status in ("HEALTHY", "ATTENTION", "ALERT")
        assert latest_analysis.risk_level in ("LOW", "MEDIUM", "HIGH")

        # REST API layer with the harvester's JWT.
        log("7", "Querying REST API as the owning harvester...")
        from fastapi.testclient import TestClient
        from backend.main import app, create_access_token

        token = create_access_token({"sub": user.id, "email": user.email, "role": "HARVESTER"})
        headers = {"Authorization": f"Bearer {token}"}
        with TestClient(app) as client:  # lifespan wires WS bridge; consumer already running
            latest = client.get(f"/api/hives/{hive.id}/telemetry/latest", headers=headers)
            assert latest.status_code == 200, latest.text
            body = latest.json()
            assert body["hasTelemetry"] is True
            assert body["telemetry"]["temperature"] == new_telemetry.temperature_c
            assert body["aiStatus"]["status"] == latest_analysis.status
            assert body["aiStatus"]["riskLevel"] == latest_analysis.risk_level
            log("7", f"GET /api/hives/{{id}}/telemetry/latest -> {json.dumps({k: body[k] for k in ('hasTelemetry', 'hasAiAnalysis')})}")

            history = client.get(f"/api/hives/{hive.id}/telemetry?limit=10", headers=headers)
            assert history.status_code == 200
            log("7", f"GET /api/hives/{{id}}/telemetry -> count={history.json()['count']}")

            status = client.get(f"/api/hives/{hive.id}/status", headers=headers)
            assert status.status_code == 200
            assert status.json()["aiStatus"]["status"] == latest_analysis.status
            log("7", f"GET /api/hives/{{id}}/status -> {status.json()['aiStatus']['status']}/{status.json()['aiStatus']['riskLevel']}")

            # Authorization: another (real) user must be denied. Reused across
            # runs (fixed email) to avoid piling up test users.
            intruder_email = "e2e_intruder@honeychain.test"
            intruder = db.query(User).filter(User.email == intruder_email).first()
            if not intruder:
                intruder = User(
                    name="E2E Intruder",
                    email=intruder_email,
                    role="HARVESTER",
                    is_verified=True,
                )
                db.add(intruder)
                db.commit()
                db.refresh(intruder)
            intruder_token = create_access_token({"sub": intruder.id, "email": intruder.email, "role": "HARVESTER"})
            denied = client.get(
                f"/api/hives/{hive.id}/telemetry/latest",
                headers={"Authorization": f"Bearer {intruder_token}"},
            )
            assert denied.status_code == 403, f"expected 403, got {denied.status_code}"
            log("7", "Cross-user access correctly rejected with 403")

        log("8", f"WebSocket bridge events received: {len(received_events)}")
        if received_events:
            ev = received_events[-1]
            log("8", f"Last broadcast event: {ev.get('event')} status={ev.get('status')} risk={ev.get('risk_level')}")

        log("OK", "END-TO-END PIPELINE VERIFIED")
        return 0
    finally:
        ai_proc.terminate()
        try:
            ai_proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            ai_proc.kill()
        try:
            tail = ai_proc_log.read_text(encoding="utf-8", errors="replace")[-1500:]
            if tail.strip():
                log("AI-PROC", f"processor log tail: {' '.join(tail.split())}")
        except OSError:
            pass
        mqtt_consumer.stop()
        db.close()


if __name__ == "__main__":
    sys.exit(main())
