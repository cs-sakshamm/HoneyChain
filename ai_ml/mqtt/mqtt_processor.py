from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path

import paho.mqtt.client as mqtt

from ai_ml.src.feature_builder import FeatureBuilder
from ai_ml.src.history_loader import reload_history
from ai_ml.src.anomaly_detector import AnomalyDetector
from ai_ml.src.risk_engine import RiskEngine
from ai_ml.src.output_formatter import build_app_json


# ============================================================
# MQTT CONFIGURATION
# ============================================================

MQTT_BROKER = os.getenv(
    "MQTT_BROKER",
    "localhost",
)

MQTT_PORT = int(
    os.getenv(
        "MQTT_PORT",
        "1883",
    )
)

MQTT_INPUT_TOPIC = os.getenv(
    "MQTT_INPUT_TOPIC",
    "honeychain/hive/telemetry",
)

MQTT_OUTPUT_TOPIC = os.getenv(
    "MQTT_OUTPUT_TOPIC",
    "honeychain/hive/processed",
)

MQTT_USERNAME = os.getenv("MQTT_USERNAME") or None
MQTT_PASSWORD = os.getenv("MQTT_PASSWORD") or None
MQTT_RECONNECT_DELAY_SECONDS = float(os.getenv("MQTT_RECONNECT_DELAY_SECONDS", "5"))
DATABASE_URL = os.getenv("DATABASE_URL", "")
AI_HISTORY_RELOAD = os.getenv("AI_HISTORY_RELOAD", "true").lower() in {"true", "1", "yes"}

logger = logging.getLogger("HoneyChainAIMQTT")


# ============================================================
# MODEL PATHS
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

MODEL_PATH = (
    PROJECT_ROOT
    / "ai_ml"
    / "models"
    / "honeychain_isolation_forest.joblib"
)

THRESHOLD_PATH = (
    PROJECT_ROOT
    / "ai_ml"
    / "models"
    / "threshold.json"
)


# ============================================================
# AI COMPONENTS
# ============================================================

feature_builder = FeatureBuilder()

anomaly_detector = AnomalyDetector(
    model_path=MODEL_PATH,
    threshold_path=THRESHOLD_PATH,
)

risk_engine = RiskEngine()


# ============================================================
# MQTT CALLBACKS
# ============================================================

def on_connect(
    client,
    userdata,
    flags,
    reason_code,
    properties=None,
):

    print(
        f"[MQTT] Connected with result code: "
        f"{reason_code}"
    )
    client.subscribe(MQTT_INPUT_TOPIC)

    print(
        f"[MQTT] Subscribed to: "
        f"{MQTT_INPUT_TOPIC}"
    )


def on_disconnect(client, userdata, disconnect_flags, reason_code, properties=None):
    """Log disconnects; loop_forever reconnects after transient failures."""
    if reason_code:
        logger.warning("MQTT disconnected (reason=%s); reconnecting.", reason_code)
    else:
        logger.info("MQTT disconnected cleanly.")


def on_message(
    client,
    userdata,
    message,
):

    try:

        payload = json.loads(
            message.payload.decode("utf-8")
        )

        print("\n[MQTT] Received:")
        print(
            json.dumps(
                payload,
                indent=2,
            )
        )

        # ----------------------------------------------------
        # Validate basic structure
        # ----------------------------------------------------

        device_id = payload["device_id"]
        timestamp = int(payload["timestamp"])

        sensors = payload["sensors"]

        diagnostics = payload.get(
            "diagnostics",
            {},
        )

        required_sensor_fields = [
            "temperature_c",
            "humidity_pct",
            "weight_kg",
            "acoustics_hz",
        ]

        for field in required_sensor_fields:

            if field not in sensors:
                raise ValueError(
                    f"Missing sensor field: {field}"
                )

        # ----------------------------------------------------
        # Add reading to hive history
        # ----------------------------------------------------

        feature_builder.add_reading(
            device_id=device_id,
            timestamp=timestamp,
            sensors=sensors,
        )

        history_size = (
            feature_builder.get_history_size(
                device_id
            )
        )

        print(
            f"[AI] History for {device_id}: "
            f"{history_size} readings"
        )

        # ----------------------------------------------------
        # Build ML features
        # ----------------------------------------------------

        features = (
            feature_builder.build_latest_features(
                device_id
            )
        )

        # We need 24h history before the model
        # can generate all temporal features.

        if features is None:

            print(
                "[AI] Waiting for enough history "
                "before running ML inference."
            )

            return

        # ----------------------------------------------------
        # Isolation Forest
        # ----------------------------------------------------

        ml_result = anomaly_detector.predict(
            features
        )

        print(
            "[AI] Anomaly:",
            ml_result,
        )

        # ----------------------------------------------------
        # Risk engine
        # ----------------------------------------------------

        risk_result = risk_engine.analyze(
            sensors=sensors,
            ml_result=ml_result,
            features=features,
        )

        print(
            "[AI] Risk:",
            risk_result["risk_level"]
        )

        # ----------------------------------------------------
        # Build app JSON
        # ----------------------------------------------------

        app_json = build_app_json(
            device_id=device_id,
            timestamp=timestamp,
            sensors=sensors,
            diagnostics=diagnostics,
            ml_result=ml_result,
            risk_result=risk_result,
        )

        output = json.dumps(
            app_json,
            indent=2,
        )

        print("\n[AI] Processed JSON:")
        print(output)

        # ----------------------------------------------------
        # Publish processed JSON
        # ----------------------------------------------------

        client.publish(
            MQTT_OUTPUT_TOPIC,
            output,
            qos=1,
        )

        print(
            f"[MQTT] Published to: "
            f"{MQTT_OUTPUT_TOPIC}"
        )

    except Exception as exc:

        print(
            f"[ERROR] Processing failed: {exc}"
        )


# ============================================================
# MAIN
# ============================================================

def build_client() -> mqtt.Client:
    """Construct a configured client so reconnect behaviour is testable."""
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message

    if MQTT_USERNAME and MQTT_PASSWORD:
        client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    return client


def run_client_once(client: mqtt.Client) -> None:
    """Connect and service MQTT until paho returns from its network loop."""
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_forever(retry_first_connection=True)


def main():

    print("========================================")
    print(" HoneyChain AI MQTT Processor")
    print("========================================")

    print(
        f"Broker : {MQTT_BROKER}:{MQTT_PORT}"
    )

    print(
        f"Input  : {MQTT_INPUT_TOPIC}"
    )

    print(
        f"Output : {MQTT_OUTPUT_TOPIC}"
    )

    print(
        f"Model  : {MODEL_PATH}"
    )

    if AI_HISTORY_RELOAD:
        loaded = reload_history(feature_builder, DATABASE_URL)
        print(f"[AI] Reloaded {loaded} telemetry readings from database history.")

    # loop_forever handles broker drops after a connection.  The outer loop
    # also covers a broker that is unavailable when this long-running service
    # starts, rather than exiting after one failed connect.
    while True:
        client = build_client()
        try:
            print("\n[MQTT] Connecting...")
            run_client_once(client)
        except (OSError, mqtt.MQTTException) as exc:
            logger.warning(
                "MQTT connection to %s:%s failed (%s); retrying in %ss.",
                MQTT_BROKER,
                MQTT_PORT,
                exc,
                MQTT_RECONNECT_DELAY_SECONDS,
            )
        time.sleep(MQTT_RECONNECT_DELAY_SECONDS)


if __name__ == "__main__":
    main()
