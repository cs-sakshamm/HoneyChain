"""
MQTT Consumer Service for HoneyChain FastAPI backend.
Subscribes to 'honeychain/hive/processed', validates payloads, stores telemetry,
AI analysis, and alerts into PostgreSQL, and broadcasts real-time updates via WebSockets.
"""
from __future__ import annotations

import json
import logging
import os
import threading
from datetime import datetime
from typing import Dict, Any, Callable, List, Optional

import paho.mqtt.client as mqtt

from backend.database import SessionLocal
from backend.models import Hive, HiveTelemetry, HiveAIAnalysis, HiveAlert, User

logger = logging.getLogger("MQTTConsumer")

MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
PROCESSED_TOPIC = os.getenv("MQTT_OUTPUT_TOPIC", "honeychain/hive/processed")
TELEMETRY_TOPIC = os.getenv("MQTT_INPUT_TOPIC", "honeychain/hive/telemetry")


class MQTTConsumer:
    def __init__(self):
        self.host = MQTT_HOST
        self.port = MQTT_PORT
        self.client = None
        self.is_running = False
        self.listeners: List[Callable[[Dict[str, Any]], None]] = []
        self._thread: Optional[threading.Thread] = None

    def add_listener(self, callback: Callable[[Dict[str, Any]], None]):
        self.listeners.append(callback)

    def _notify_listeners(self, data: Dict[str, Any]):
        for listener in self.listeners:
            try:
                listener(data)
            except Exception as e:
                logger.error(f"Listener error: {e}")

    def on_connect(self, client, userdata, flags, rc, properties=None):
        logger.info(f"MQTT Consumer connected with result code: {rc}")
        client.subscribe(PROCESSED_TOPIC, qos=1)
        client.subscribe(TELEMETRY_TOPIC, qos=1)
        logger.info(f"Subscribed to '{PROCESSED_TOPIC}' and '{TELEMETRY_TOPIC}'")

    def on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            if msg.topic == PROCESSED_TOPIC:
                self.process_processed_payload(payload)
            elif msg.topic == TELEMETRY_TOPIC:
                logger.debug(f"Direct raw telemetry received for device: {payload.get('device_id')}")
        except Exception as err:
            logger.error(f"Error handling MQTT message on {msg.topic}: {err}")

    def process_processed_payload(self, payload: Dict[str, Any]):
        device_id = payload.get("device_id")
        if not device_id:
            logger.warning("Rejected MQTT payload: missing device_id")
            return

        sensors = payload.get("sensors", {})
        hive_status = payload.get("hive_status", {})
        diagnostics = payload.get("diagnostics", {})
        analysis = payload.get("analysis", {})
        alerts = payload.get("alerts", [])
        summary = payload.get("analysis_summary", {})
        ts = payload.get("timestamp", int(datetime.utcnow().timestamp()))

        db = SessionLocal()
        try:
            # 1. Resolve Hive by device_id or create placeholder if new hardware
            hive = db.query(Hive).filter(Hive.device_id == device_id).first()
            if not hive:
                # Try resolving by hive_code or find first harvester hive
                hive = db.query(Hive).filter(Hive.hive_code == device_id).first()
                if not hive:
                    # Get or create default harvester
                    user = db.query(User).filter(User.role == "HARVESTER").first()
                    if not user:
                        user = User(name="Default Harvester", email="harvester@honeychain.io", role="HARVESTER")
                        db.add(user)
                        db.commit()
                        db.refresh(user)

                    hive = Hive(
                        user_id=user.id,
                        device_id=device_id,
                        hive_code=f"HIVE-{device_id[-6:].upper()}",
                        name=f"Hive ({device_id})",
                        apiary_location="Cascade Valley Apiary, Sector 4",
                    )
                    db.add(hive)
                    db.commit()
                    db.refresh(hive)
                    logger.info(f"Auto-registered new hive for device {device_id}: {hive.hive_code}")

            recorded_dt = datetime.utcfromtimestamp(ts) if isinstance(ts, (int, float)) else datetime.utcnow()

            # 2. Persist Telemetry
            telemetry = HiveTelemetry(
                hive_id=hive.id,
                device_id=device_id,
                timestamp=int(ts),
                temperature_c=float(sensors.get("temperature_c", 34.2)),
                humidity_pct=float(sensors.get("humidity_pct", 61.5)),
                weight_kg=float(sensors.get("weight_kg", 3.25)),
                acoustics_hz=float(sensors.get("acoustics_hz", 245.0)),
                battery_v=float(diagnostics.get("battery_v", 4.12)) if diagnostics.get("battery_v") is not None else None,
                wifi_rssi_dbm=float(diagnostics.get("wifi_rssi_dbm", -68)) if diagnostics.get("wifi_rssi_dbm") is not None else None,
                recorded_at=recorded_dt,
            )
            db.add(telemetry)
            db.commit()
            db.refresh(telemetry)

            # 3. Persist AI Analysis
            ai_analysis = HiveAIAnalysis(
                hive_id=hive.id,
                telemetry_id=telemetry.id,
                device_id=device_id,
                timestamp=int(ts),
                risk_level=hive_status.get("risk_level", "LOW"),
                status=hive_status.get("status", "HEALTHY"),
                anomaly_detected=bool(hive_status.get("anomaly_detected", False)),
                anomaly_score=float(hive_status.get("anomaly_score", 0.0)),
                temperature_status=analysis.get("temperature", {}).get("status", "NORMAL"),
                humidity_status=analysis.get("humidity", {}).get("status", "NORMAL"),
                weight_status=analysis.get("weight", {}).get("status", "STABLE"),
                weight_trend=analysis.get("weight", {}).get("trend", "STABLE"),
                acoustic_status=analysis.get("acoustics", {}).get("status", "NORMAL"),
                reasons_json=json.dumps(summary.get("reasons", [])),
                alerts_json=json.dumps(alerts),
                raw_output_json=json.dumps(payload),
            )
            db.add(ai_analysis)

            # 4. Generate unignorable Alerts if anomaly detected or abnormal conditions
            if hive_status.get("anomaly_detected") or hive_status.get("risk_level") in ("MEDIUM", "HIGH") or len(alerts) > 0:
                for alert_item in alerts:
                    msg_text = alert_item.get("message", "Unusual hive telemetry detected.")
                    param = alert_item.get("type", "ANOMALY").capitalize()
                    sev = alert_item.get("severity", "CRITICAL")
                    db_alert = HiveAlert(
                        hive_id=hive.id,
                        hive_code=hive.hive_code,
                        device_id=device_id,
                        parameter=param,
                        previous_value="Baseline",
                        current_value=str(sensors.get("temperature_c" if param == "Temperature" else "humidity_pct", "")),
                        change_value="Shift",
                        unit="°C" if param == "Temperature" else "%",
                        severity=sev,
                        message=msg_text,
                        status="ACTIVE",
                    )
                    db.add(db_alert)

            # Update hive overall health
            hive.overall_health = hive_status.get("status", "Healthy").capitalize()
            db.commit()

            # 5. Broadcast to live WebSockets
            broadcast_payload = {
                "event": "TELEMETRY_UPDATE",
                "hive_id": hive.id,
                "hive_code": hive.hive_code,
                "device_id": device_id,
                "status": hive.overall_health,
                "risk_level": hive_status.get("risk_level", "LOW"),
                "sensors": sensors,
                "anomaly_detected": hive_status.get("anomaly_detected", False),
                "recorded_at": recorded_dt.isoformat(),
            }
            self._notify_listeners(broadcast_payload)
            logger.info(f"Successfully processed & stored telemetry for hive {hive.hive_code} (Risk: {hive_status.get('risk_level')})")

        except Exception as err:
            db.rollback()
            logger.error(f"Error persisting MQTT telemetry to DB: {err}")
        finally:
            db.close()

    def start(self):
        if self.is_running:
            return

        def _runner():
            try:
                self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2 if hasattr(mqtt, "CallbackAPIVersion") else None)
                self.client.on_connect = self.on_connect
                self.client.on_message = self.on_message
                logger.info(f"Connecting to MQTT Broker at {self.host}:{self.port}...")
                self.client.connect(self.host, self.port, 60)
                self.is_running = True
                self.client.loop_forever()
            except Exception as e:
                logger.warning(f"MQTT Consumer could not connect to {self.host}:{self.port} ({e}). Will retry or operate in REST ingest mode.")
                self.is_running = False

        self._thread = threading.Thread(target=_runner, daemon=True)
        self._thread.start()

    def stop(self):
        self.is_running = False
        if self.client:
            try:
                self.client.disconnect()
            except Exception:
                pass


mqtt_consumer = MQTTConsumer()
