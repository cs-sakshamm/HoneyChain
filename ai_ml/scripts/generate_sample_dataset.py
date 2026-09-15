"""
Generate synthetic Indian hive telemetry dataset and train the HoneyChain Isolation Forest model.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data" / "HoneyChain_Synthetic_Indian_Hive_Dataset_v1"
MODELS_DIR = ROOT / "models"
CSV_PATH = DATA_DIR / "honeychain_synthetic_hive_telemetry.csv"

SENSOR_COLUMNS = [
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",
]

TEMPORAL_FEATURE_COLUMNS = [
    "temperature_c_delta_1h",
    "temperature_c_rolling_mean_6h",
    "humidity_pct_delta_1h",
    "humidity_pct_rolling_mean_6h",
    "weight_kg_delta_1h",
    "weight_kg_rolling_mean_6h",
    "acoustics_hz_delta_1h",
    "acoustics_hz_rolling_mean_6h",
    "weight_delta_24h",
]

MODEL_FEATURE_COLUMNS = SENSOR_COLUMNS + TEMPORAL_FEATURE_COLUMNS


def generate_dataset():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    np.random.seed(42)
    device_id = "SIH_HIVE_MVP_01"
    start_ts = 1725800000  # Unix timestamp
    n_readings = 500  # 500 readings spaced 10 mins (600s) apart

    rows = []
    base_weight = 3.25
    base_temp = 34.2
    base_hum = 61.5
    base_acoustics = 245.0

    for i in range(n_readings):
        ts = start_ts + (i * 600)
        # Daily periodic variations
        hour_rad = (i % 144) / 144.0 * 2 * math.pi
        temp_val = base_temp + 1.2 * math.sin(hour_rad) + np.random.normal(0, 0.3)
        hum_val = base_hum - 3.5 * math.sin(hour_rad) + np.random.normal(0, 0.8)
        # Slow weight accumulation from foraging with small fluctuations
        weight_val = base_weight + (i * 0.001) + np.random.normal(0, 0.02)
        acoustics_val = base_acoustics + 8.0 * math.sin(hour_rad) + np.random.normal(0, 3.0)

        # Inject a few realistic anomalous intervals for evaluation
        is_anomaly = False
        condition = "NORMAL"
        risk = "LOW"
        anomaly_type = "NONE"

        if 200 <= i < 210:
            # Sudden heat spike / ventilation issue
            temp_val += 4.5
            condition = "HEAT_SPIKE"
            risk = "MEDIUM"
            anomaly_type = "TEMPERATURE_SPIKE"
            is_anomaly = True
        elif 350 <= i < 355:
            # Sudden acoustic disturbance / swarming sound
            acoustics_val += 110.0
            condition = "SWARMING_ACOUSTIC"
            risk = "MEDIUM"
            anomaly_type = "HIGH_FREQUENCY"
            is_anomaly = True

        rows.append({
            "timestamp": ts,
            "device_id": device_id,
            "temperature_c": round(float(temp_val), 2),
            "humidity_pct": round(float(hum_val), 2),
            "weight_kg": round(float(weight_val), 3),
            "acoustics_hz": round(float(acoustics_val), 1),
            "battery_v": 4.12,
            "wifi_rssi_dbm": -68,
            "condition": condition,
            "risk_level": risk,
            "anomaly_type": anomaly_type,
        })

    df = pd.DataFrame(rows)
    df.to_csv(CSV_PATH, index=False)
    print(f"Generated {len(df)} readings to {CSV_PATH}")
    return df


def train_model(df: pd.DataFrame):
    # Compute the temporal features matching FeatureBuilder
    df = df.copy()
    df["timestamp_dt"] = pd.to_datetime(df["timestamp"], unit="s", utc=True)
    df = df.sort_values("timestamp_dt").reset_index(drop=True)

    steps_1h = 6
    steps_6h = 36
    steps_24h = 144

    df["temperature_c_delta_1h"] = (df["temperature_c"] - df["temperature_c"].shift(steps_1h)).bfill().fillna(0)
    df["humidity_pct_delta_1h"] = (df["humidity_pct"] - df["humidity_pct"].shift(steps_1h)).bfill().fillna(0)
    df["weight_kg_delta_1h"] = (df["weight_kg"] - df["weight_kg"].shift(steps_1h)).bfill().fillna(0)
    df["acoustics_hz_delta_1h"] = (df["acoustics_hz"] - df["acoustics_hz"].shift(steps_1h)).bfill().fillna(0)

    df["temperature_c_rolling_mean_6h"] = df["temperature_c"].rolling(window=steps_6h, min_periods=1).mean()
    df["humidity_pct_rolling_mean_6h"] = df["humidity_pct"].rolling(window=steps_6h, min_periods=1).mean()
    df["weight_kg_rolling_mean_6h"] = df["weight_kg"].rolling(window=steps_6h, min_periods=1).mean()
    df["acoustics_hz_rolling_mean_6h"] = df["acoustics_hz"].rolling(window=steps_6h, min_periods=1).mean()

    df["weight_delta_24h"] = (df["weight_kg"] - df["weight_kg"].shift(steps_24h)).bfill().fillna(0)

    # Filter normal condition for training
    train_normal = df[df["condition"] == "NORMAL"]
    X_train = train_normal[MODEL_FEATURE_COLUMNS].astype(float)

    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("isolation_forest", IsolationForest(n_estimators=100, contamination=0.05, random_state=42)),
    ])

    print("Fitting Isolation Forest model...")
    pipeline.fit(X_train)

    # Decision function (higher = more normal)
    train_scores = pipeline.decision_function(X_train)
    # Threshold at 5th percentile
    threshold = float(np.percentile(train_scores, 5))
    print(f"Calculated decision threshold: {threshold:.6f}")

    # Save model and threshold
    model_file = MODELS_DIR / "honeychain_isolation_forest.joblib"
    threshold_file = MODELS_DIR / "threshold.json"
    metrics_file = MODELS_DIR / "metrics.json"

    joblib.dump(pipeline, model_file)
    with open(threshold_file, "w", encoding="utf-8") as f:
        json.dump({
            "threshold": threshold,
            "model": "IsolationForest",
            "version": "1.0",
        }, f, indent=2)

    with open(metrics_file, "w", encoding="utf-8") as f:
        json.dump({
            "model": "IsolationForest",
            "version": "1.0",
            "features": MODEL_FEATURE_COLUMNS,
            "threshold": threshold,
            "n_samples": len(X_train),
        }, f, indent=2)

    print(f"Saved model to {model_file}")
    print(f"Saved threshold to {threshold_file}")


if __name__ == "__main__":
    df = generate_dataset()
    train_model(df)
