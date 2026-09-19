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

try:
    from backend.time_utils import utcfromtimestamp_naive
except ImportError:  # pragma: no cover - bare import from backend/ cwd
    from time_utils import utcfromtimestamp_naive
from typing import Dict, Any, Callable, List, Optional

import paho.mqtt.client as mqtt

try:
    from backend.database import SessionLocal
    from backend.models import Hive, HiveTelemetry, HiveAIAnalysis, HiveAlert, User
except ImportError:
    from database import SessionLocal
    from models import Hive, HiveTelemetry, HiveAIAnalysis, HiveAlert, User

logger = logging.getLogger("MQTTConsumer")


def _utcfromtimestamp(ts: float) -> datetime:
    """Naive UTC datetime from an epoch (see :mod:`backend.time_utils`)."""
    return utcfromtimestamp_naive(ts)

MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USERNAME = os.getenv("MQTT_USERNAME") or None
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD") or None
PROCESSED_TOPIC = os.getenv("MQTT_OUTPUT_TOPIC", "honeychain/hive/processed")
TELEMETRY_TOPIC = os.getenv("MQTT_INPUT_TOPIC", "honeychain/hive/telemetry")

# Required sensor channels for the HoneyChain ESP32 telemetry contract.
# A message missing any of these is rejected rather than stored with
# fabricated defaults (real telemetry only — no dummy fallback values).
REQUIRED_SENSOR_FIELDS = ("temperature_c", "humidity_pct", "weight_kg", "acoustics_hz")


def _extract_required_sensors(payload: Dict[str, Any], context: str) -> Dict[str, float]:
    """Validate and coerce the four required sensor channels to floats.

    Returns {} when the payload is malformed. Numeric strings produced by some
    gateways are accepted; nulls, missing keys and non-numeric values are not.
    """
    raw = payload.get("sensors")
    if not isinstance(raw, dict):
        logger.warning(f"[VALIDATION] {context} payload has no sensors object")
        return {}
    sensors: Dict[str, float] = {}
    for field in REQUIRED_SENSOR_FIELDS:
        value = raw.get(field)
        if value is None:
            logger.warning(f"[VALIDATION] {context} payload missing/null sensor field: {field}")
            return {}
        try:
            coerced = float(value)
        except (TypeError, ValueError):
            logger.warning(f"[VALIDATION] {context} payload has non-numeric {field}: {value!r}")
            return {}
        sensors[field] = coerced
    return sensors


def _safe_timestamp(payload: Dict[str, Any], context: str) -> Optional[int]:
    """Validate the epoch timestamp; None when absent/invalid (never guessed)."""
    ts = payload.get("timestamp")
    if ts is None:
        logger.warning(f"[VALIDATION] {context} payload missing timestamp")
        return None
    try:
        timestamp = int(ts)
    except (TypeError, ValueError):
        logger.warning(f"[VALIDATION] {context} payload has invalid timestamp: {ts!r}")
        return None
    return timestamp


def _coerce_optional_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


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
        self._stop_event = threading.Event()

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
        if not device_id or not isinstance(device_id, str) or not device_id.strip():
            logger.warning("Rejected MQTT payload: missing device_id")
            return
        device_id = device_id.strip()

        # Spec: reject malformed messages instead of storing fabricated zeros.
        sensors = _extract_required_sensors(payload, "processed")
        if not sensors:
            return
        timestamp = _safe_timestamp(payload, "processed")
        if timestamp is None:
            return

        hive_status = payload.get("hive_status", {})
        diagnostics = payload.get("diagnostics", {})
        analysis = payload.get("analysis", {})
        alerts = payload.get("alerts", [])
        summary = payload.get("analysis_summary", {})

        db = SessionLocal()
        try:
            # 1. Resolve Hive by device_id or hive_code
            hive = db.query(Hive).filter((Hive.device_id == device_id) | (Hive.hive_code == device_id)).first()
            if not hive:
                logger.warning(f"Telemetry received for unmapped device/hive: {device_id}. Skipping processing.")
                return

            recorded_dt = _utcfromtimestamp(timestamp)

            # 2. The raw packet normally reaches this consumer before AI output.
            # Reuse it so one physical reading is represented by one telemetry row.
            telemetry = (
                db.query(HiveTelemetry)
                .filter(
                    HiveTelemetry.hive_id == hive.id,
                    HiveTelemetry.device_id == device_id,
                    HiveTelemetry.timestamp == timestamp,
                )
                .first()
            )
            if telemetry is None:
                telemetry = HiveTelemetry(
                    hive_id=hive.id,
                    device_id=device_id,
                    timestamp=timestamp,
                    recorded_at=recorded_dt,
                )
                db.add(telemetry)

            telemetry.temperature_c = sensors["temperature_c"]
            telemetry.humidity_pct = sensors["humidity_pct"]
            telemetry.weight_kg = sensors["weight_kg"]
            telemetry.acoustics_hz = sensors["acoustics_hz"]
            telemetry.battery_v = _coerce_optional_float(diagnostics.get("battery_v"))
            telemetry.wifi_rssi_dbm = _coerce_optional_float(diagnostics.get("wifi_rssi_dbm"))
            db.flush()

            # 3. QoS 1 can redeliver a processed message.  Keep its analysis
            # attached to the same physical telemetry row rather than creating
            # duplicate dashboard history for one sensor timestamp.
            ai_analysis = (
                db.query(HiveAIAnalysis)
                .filter(HiveAIAnalysis.telemetry_id == telemetry.id)
                .first()
            )
            is_new_analysis = ai_analysis is None
            if is_new_analysis:
                ai_analysis = HiveAIAnalysis(
                    hive_id=hive.id,
                    telemetry_id=telemetry.id,
                    device_id=device_id,
                    timestamp=timestamp,
                )
                db.add(ai_analysis)

            ai_analysis.risk_level = hive_status.get("risk_level", "LOW")
            ai_analysis.status = hive_status.get("status", "HEALTHY")
            ai_analysis.anomaly_detected = bool(hive_status.get("anomaly_detected", False))
            ai_analysis.anomaly_score = float(hive_status.get("anomaly_score", 0.0))
            ai_analysis.temperature_status = analysis.get("temperature", {}).get("status", "NORMAL")
            ai_analysis.humidity_status = analysis.get("humidity", {}).get("status", "NORMAL")
            ai_analysis.weight_status = analysis.get("weight", {}).get("status", "STABLE")
            ai_analysis.weight_trend = analysis.get("weight", {}).get("trend", "STABLE")
            ai_analysis.acoustic_status = analysis.get("acoustics", {}).get("status", "NORMAL")
            ai_analysis.reasons_json = json.dumps(summary.get("reasons", []))
            ai_analysis.alerts_json = json.dumps(alerts)
            ai_analysis.raw_output_json = json.dumps(payload)

            # 4. Generate alerts once per physical reading. QoS 1 redelivery
            # must not stack duplicate ACTIVE rows for the same timestamp.
            if is_new_analysis and (
                hive_status.get("anomaly_detected")
                or hive_status.get("risk_level") in ("MEDIUM", "HIGH")
                or len(alerts) > 0
            ):
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
            # Include the AI analysis detail so Flutter can render the full
            # dashboard state directly from one real-time message.
            broadcast_payload = {
                "analysis": {
                    "temperature": analysis.get("temperature"),
                    "humidity": analysis.get("humidity"),
                    "weight": analysis.get("weight"),
                    "acoustics": analysis.get("acoustics"),
                },
                "alerts": alerts,
                "anomaly_score": hive_status.get("anomaly_score"),
                "diagnostics": {
                    "battery_v": diagnostics.get("battery_v"),
                    "wifi_rssi_dbm": diagnostics.get("wifi_rssi_dbm"),
                },
                "reasons": summary.get("reasons", []),
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
        if not device_id or not isinstance(device_id, str) or not str(device_id).strip():
            logger.warning("Rejected raw MQTT telemetry payload: missing device_id")
            return
        device_id = str(device_id).strip()

        # Validation first (spec §18): reject rather than fabricate.
        sensors = _extract_required_sensors(payload, "raw telemetry")
        timestamp = _safe_timestamp(payload, "raw telemetry")
        if not sensors or timestamp is None:
            return

        db = SessionLocal()
        try:
            hive = db.query(Hive).filter((Hive.device_id == device_id) | (Hive.hive_code == device_id)).first()
            if not hive:
                logger.debug(f"Raw telemetry for unmapped device {device_id}; skipping direct persistence.")
                return

            rec_time = _utcfromtimestamp(timestamp)

            # Flat legacy aliases for diagnostics only. Sensor values are
            # never defaulted: a missing channel means a malformed packet.
            diagnostics = payload.get("diagnostics") if isinstance(payload.get("diagnostics"), dict) else {}
            temp = sensors["temperature_c"]
            humidity = sensors["humidity_pct"]
            weight = sensors["weight_kg"]
            acoustics = sensors["acoustics_hz"]
            battery = diagnostics.get("battery_v", payload.get("battery_v"))
            rssi = diagnostics.get("wifi_rssi_dbm", payload.get("wifi_rssi_dbm"))

            # A processed insight can arrive before this lower-priority raw
            # queue item. Reuse that row to keep the reading idempotent.
            telemetry = (
                db.query(HiveTelemetry)
                .filter(
                    HiveTelemetry.hive_id == hive.id,
                    HiveTelemetry.device_id == device_id,
                    HiveTelemetry.timestamp == timestamp,
                )
                .first()
            )
            if telemetry is None:
                telemetry = HiveTelemetry(
                    hive_id=hive.id,
                    device_id=device_id,
                    timestamp=timestamp,
                    recorded_at=rec_time,
                )
                db.add(telemetry)
            telemetry.temperature_c = temp
            telemetry.humidity_pct = humidity
            telemetry.weight_kg = weight
            telemetry.acoustics_hz = acoustics
            telemetry.battery_v = _coerce_optional_float(battery)
            telemetry.wifi_rssi_dbm = _coerce_optional_float(rssi)
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

    def on_disconnect(self, client, userdata, disconnect_flags, rc, properties=None):
        # loop_forever(retry_first_connection=True) reconnects automatically;
        # this handler only records the event and keeps the client reference
        # current so stop() can always disconnect cleanly.
        logger.warning(f"[MQTT] Disconnected (rc={rc}); auto-reconnect pending.")
        self.client = client

    def start(self):
        if self.is_running:
            return

        self.is_running = True
        self.client = None
        self._stop_event.clear()
        self._worker = threading.Thread(target=self._worker_loop, daemon=True, name="mqtt-db-worker")
        self._worker.start()

        def _runner():
            # Reconnect loop: retries until stop() is requested, so a broker
            # outage never crashes FastAPI and never leaves the consumer dead.
            while not self._stop_event.is_set():
                try:
                    self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2 if hasattr(mqtt, "CallbackAPIVersion") else None)
                    self.client.on_connect = self.on_connect
                    self.client.on_disconnect = self.on_disconnect
                    self.client.on_message = self.on_message
                    if MQTT_USERNAME and MQTT_PASSWORD:
                        self.client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
                    logger.info(f"[MQTT] Connecting to broker at {self.host}:{self.port}...")
                    self.client.connect(self.host, self.port, 60)
                    logger.info("[MQTT] Connected")
                    # loop_forever(retry_first_connection=True) also covers a
                    # broker that drops mid-session (auto-reconnect).
                    self.client.loop_forever(retry_first_connection=True)
                except Exception as e:
                    logger.warning(f"[MQTT] Connection failed to {self.host}:{self.port} ({e}). Reconnecting in 5 seconds.")
                    self._stop_event.wait(5)

        self._thread = threading.Thread(target=_runner, daemon=True)
        self._thread.start()

    def stop(self):
        self.is_running = False
        self._stop_event.set()
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
