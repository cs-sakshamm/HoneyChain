from __future__ import annotations

import json
import os
from pathlib import Path

import paho.mqtt.client as mqtt

from ai_ml.src.feature_builder import FeatureBuilder
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

    client.subscribe(
        MQTT_INPUT_TOPIC
    )

    print(
        f"[MQTT] Subscribed to: "
        f"{MQTT_INPUT_TOPIC}"
    )


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

    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2
    )

    client.on_connect = on_connect
    client.on_message = on_message

    print("\n[MQTT] Connecting...")

    client.connect(
        MQTT_BROKER,
        MQTT_PORT,
        60,
    )

    client.loop_forever()


if __name__ == "__main__":
    main()