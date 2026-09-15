from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd
from datetime import datetime


# Allow imports from ai_ml/src
AI_ML_ROOT = Path(__file__).resolve().parents[1]

sys.path.insert(
    0,
    str(AI_ML_ROOT),
)

from src.feature_builder import FeatureBuilder
from src.anomaly_detector import AnomalyDetector
from src.risk_engine import RiskEngine
from src.output_formatter import build_app_json


PROJECT_ROOT = AI_ML_ROOT.parent

DATASET_PATH = (
    AI_ML_ROOT
    / "data"
    / "HoneyChain_Synthetic_Indian_Hive_Dataset_v1"
    / "honeychain_synthetic_hive_telemetry.csv"
)

MODEL_PATH = (
    AI_ML_ROOT
    / "models"
    / "honeychain_isolation_forest.joblib"
)

THRESHOLD_PATH = (
    AI_ML_ROOT
    / "models"
    / "threshold.json"
)
def convert_timestamp(value) -> int:
    """
    Convert either a Unix timestamp or an ISO-8601 timestamp
    into Unix seconds.
    """

    # Already numeric
    if isinstance(value, (int, float)):
        return int(value)

    value = str(value)

    # Try Unix timestamp represented as text
    try:
        return int(float(value))
    except ValueError:
        pass

    # Try ISO-8601 timestamp
    dt = datetime.fromisoformat(
        value.replace("Z", "+00:00")
    )

    return int(dt.timestamp())

def main():

    print("Loading dataset...")

    df = pd.read_csv(
        DATASET_PATH
    )

    device_id = df["device_id"].iloc[0]

    hive_df = (
        df[
            df["device_id"] == device_id
        ]
        .sort_values("timestamp")
        .head(145)
    )

    print(
        f"Testing device: {device_id}"
    )

    feature_builder = FeatureBuilder()

    for _, row in hive_df.iterrows():

        feature_builder.add_reading(
            device_id=device_id,
            timestamp=convert_timestamp(row["timestamp"]),
            sensors={
                "temperature_c": row["temperature_c"],
                "humidity_pct": row["humidity_pct"],
                "weight_kg": row["weight_kg"],
                "acoustics_hz": row["acoustics_hz"],
            },
        )

    features = (
        feature_builder.build_latest_features(
            device_id
        )
    )

    if features is None:
        raise RuntimeError(
            "Could not generate ML features."
        )

    detector = AnomalyDetector(
        MODEL_PATH,
        THRESHOLD_PATH,
    )

    ml_result = detector.predict(
        features
    )

    risk_engine = RiskEngine()

    latest = hive_df.iloc[-1]

    sensors = {
        "temperature_c": float(
            latest["temperature_c"]
        ),
        "humidity_pct": float(
            latest["humidity_pct"]
        ),
        "weight_kg": float(
            latest["weight_kg"]
        ),
        "acoustics_hz": float(
            latest["acoustics_hz"]
        ),
    }

    risk_result = risk_engine.analyze(
        sensors=sensors,
        ml_result=ml_result,
        features=features,
    )

    result = build_app_json(
        device_id=device_id,
        timestamp=convert_timestamp(latest["timestamp"]),
        sensors=sensors,
        diagnostics={
            "battery_v": 4.12,
            "wifi_rssi_dbm": -68,
        },
        ml_result=ml_result,
        risk_result=risk_result,
    )

    print("\n========================================")
    print(" FINAL APP JSON")
    print("========================================")

    print(
        json.dumps(
            result,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()