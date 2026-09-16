"""
MQTT Consumer Service for HoneyChain FastAPI backend.
Subscribes to 'honeychain/hive/processed', validates payloads, stores telemetry,
AI analysis, and alerts into PostgreSQL, and broadcasts real-time updates via WebSockets.
"""
from __future__ import annotations

import json
import logging
import os
import queue
import threading
from datetime import datetime
from typing import Dict, Any, Callable, List, Optional

import paho.mqtt.client as mqtt

try:
    from backend.database import SessionLocal
    from backend.models import Hive, HiveTelemetry, HiveAIAnalysis, HiveAlert, User
except ImportError:
    from database import SessionLocal
    from models import Hive, HiveTelemetry, HiveAIAnalysis, HiveAlert, User

logger = logging.getLogger("MQTTConsumer")

MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME") or None
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD") or None
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
        # HC-006: DB persistence is decoupled from the paho network loop AND
        # split by priority. Synchronous cloud-DB writes inside on_message
        # blocked the socket reader, so during a telemetry burst the AI
        # 'processed' messages sat behind minutes of queued telemetry packets.
        # Two FIFO queues guarantee processed (AI insight) messages are always
        # handled before the raw telemetry backlog — per-topic order preserved.
        self._processed_queue: "queue.Queue[Dict[str, Any]]" = queue.Queue()
        self._telemetry_queue: "queue.Queue[Dict[str, Any]]" = queue.Queue()
        self._worker: Optional[threading.Thread] = None

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
        except Exception as err:
            logger.error(f"Error decoding MQTT message on {msg.topic}: {err}")
            return
        # Never block the network loop: hand off to the worker immediately.
        if msg.topic == PROCESSED_TOPIC:
            self._processed_queue.put(payload)
        elif msg.topic == TELEMETRY_TOPIC:
            self._telemetry_queue.put(payload)

    def _handle(self, topic: str, payload: Dict[str, Any]):
        if topic == PROCESSED_TOPIC:
            self.process_processed_payload(payload)
        elif topic == TELEMETRY_TOPIC:
            self.process_raw_telemetry_payload(payload)

    def _worker_loop(self):
        while self.is_running or not self._processed_queue.empty() or not self._telemetry_queue.empty():
            # Priority 1: AI-processed insights (small volume, high value,
            # time-sensitive for alerts/dashboards). Drain without waiting.
            handled = False
            try:
                payload = self._processed_queue.get_nowait()
                handled = True
                try:
                    self._handle(PROCESSED_TOPIC, payload)
                except Exception as err:
                    logger.error(f"Error handling processed message: {err}")
                finally:
                    self._processed_queue.task_done()
            except queue.Empty:
                pass

            # Priority 2: raw telemetry history (bulk). Block-wait here so the
            # worker sleeps when idle.
            if not handled:
                try:
                    payload = self._telemetry_queue.get(timeout=0.5)
                    try:
                        self._handle(TELEMETRY_TOPIC, payload)
                    except Exception as err:
                        logger.error(f"Error handling telemetry message: {err}")
                    finally:
                        self._telemetry_queue.task_done()
                except queue.Empty:
                    continue

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
            # 1. Resolve Hive by device_id or hive_code
            hive = db.query(Hive).filter((Hive.device_id == device_id) | (Hive.hive_code == device_id)).first()
            if not hive:
                logger.warning(f"Telemetry received for unmapped device/hive: {device_id}. Skipping processing.")
                return

            recorded_dt = datetime.utcfromtimestamp(ts) if isinstance(ts, (int, float)) else datetime.utcnow()

            # 2. Persist Telemetry
            telemetry = HiveTelemetry(
                hive_id=hive.id,
                device_id=device_id,
                timestamp=int(ts),
                temperature_c=float(sensors.get("temperature_c", 0.0)),
                humidity_pct=float(sensors.get("humidity_pct", 0.0)),
                weight_kg=float(sensors.get("weight_kg", 0.0)),
                acoustics_hz=float(sensors.get("acoustics_hz", 0.0)),
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

    def process_raw_telemetry_payload(self, payload: Dict[str, Any]):
        device_id = payload.get("device_id") or payload.get("deviceId")
        if not device_id:
            logger.warning("Rejected raw MQTT telemetry payload: missing device_id")
            return

        db = SessionLocal()
        try:
            hive = db.query(Hive).filter((Hive.device_id == device_id) | (Hive.hive_code == device_id)).first()
            if not hive:
                logger.debug(f"Raw telemetry for unmapped device {device_id}; skipping direct persistence.")
                return

            ts = payload.get("timestamp", int(datetime.utcnow().timestamp()))
            rec_time = datetime.utcfromtimestamp(ts) if isinstance(ts, (int, float)) else datetime.utcnow()

            temp = payload.get("temperature") or payload.get("temperature_c") or 34.5
            humidity = payload.get("humidity") or payload.get("humidity_pct") or 55.0
            weight = payload.get("weight") or payload.get("weight_kg") or 22.0
            acoustics = payload.get("acoustics") or payload.get("sound_frequency") or payload.get("acoustics_hz") or 240.0
            battery = payload.get("battery") or payload.get("battery_v") or 4.1
            rssi = payload.get("wifi_rssi") or payload.get("signal_strength") or payload.get("wifi_rssi_dbm") or -65.0

            telemetry = HiveTelemetry(
                hive_id=hive.id,
                device_id=device_id,
                timestamp=int(rec_time.timestamp()),
                temperature_c=float(temp),
                humidity_pct=float(humidity),
                weight_kg=float(weight),
                acoustics_hz=float(acoustics),
                battery_v=float(battery),
                wifi_rssi_dbm=float(rssi),
                recorded_at=rec_time,
            )
            db.add(telemetry)
            db.commit()
            logger.info(f"Persisted raw telemetry for hive {hive.hive_code} (device: {device_id})")

            # Broadcast to listeners
            broadcast_data = {
                "type": "raw_telemetry",
                "device_id": device_id,
                "hive_code": hive.hive_code,
                "temperature": float(temp),
                "humidity": float(humidity),
                "weight": float(weight),
                "timestamp": int(rec_time.timestamp()),
            }
            for listener in list(self.listeners):
                try:
                    listener(broadcast_data)
                except Exception as e:
                    logger.debug(f"Error in telemetry listener: {e}")
        except Exception as err:
            db.rollback()
            logger.error(f"Error persisting raw MQTT telemetry: {err}")
        finally:
            db.close()

    def start(self):
        if self.is_running:
            return

        self.is_running = True
        self._worker = threading.Thread(target=self._worker_loop, daemon=True, name="mqtt-db-worker")
        self._worker.start()

        def _runner():
            try:
                self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2 if hasattr(mqtt, "CallbackAPIVersion") else None)
                self.client.on_connect = self.on_connect
                self.client.on_message = self.on_message
                if MQTT_USERNAME and MQTT_PASSWORD:
                    self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
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
        if self._worker:
            try:
                self._worker.join(timeout=10)  # drain queued messages before exit
            except Exception:
                pass
        if self.client:
            try:
                self.client.disconnect()
            except Exception:
                pass


mqtt_consumer = MQTTConsumer()
