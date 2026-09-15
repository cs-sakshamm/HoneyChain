import json
import time
from datetime import datetime

import pandas as pd
import paho.mqtt.client as mqtt


# ============================================================
# CONFIGURATION
# ============================================================

BROKER_HOST = "localhost"
BROKER_PORT = 1883

MQTT_TOPIC = "honeychain/hive/telemetry"

DATASET_PATH = (
    "ai_ml/data/"
    "HoneyChain_Synthetic_Indian_Hive_Dataset_v1/"
    "honeychain_synthetic_hive_telemetry.csv"
)

# Number of readings to simulate
NUMBER_OF_READINGS = 300

# Delay between simulated ESP32 readings
# 1 second = one simulated 10-minute sensor reading
DELAY_SECONDS = 1


# ============================================================
# TIMESTAMP CONVERSION
# ============================================================

def convert_timestamp(value):
    """
    Convert dataset timestamp into Unix timestamp.
    Supports ISO timestamps and Unix timestamps.
    """

    if isinstance(value, (int, float)):
        return int(value)

    text = str(value).strip()

    try:
        return int(float(text))
    except ValueError:
        dt = datetime.fromisoformat(text)

        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=None)

        return int(dt.timestamp())


# ============================================================
# LOAD DATASET
# ============================================================

print("=" * 60)
print("HoneyChain MQTT Simulator")
print("=" * 60)

print("\n[DATA] Loading dataset...")

df = pd.read_csv(DATASET_PATH)

print(f"[DATA] Total dataset rows: {len(df):,}")

# Select one hive
device_id = df["device_id"].iloc[0]

print(f"[DATA] Selected hive: {device_id}")

# Select only this hive and first 300 readings
hive_df = (
    df[df["device_id"] == device_id]
    .sort_values("timestamp")
    .head(NUMBER_OF_READINGS)
    .copy()
)

print(f"[DATA] Readings selected for simulation: {len(hive_df)}")


# ============================================================
# MQTT SETUP
# ============================================================

client = mqtt.Client()

print("\n[MQTT] Connecting to broker...")

client.connect(BROKER_HOST, BROKER_PORT, 60)

print("[MQTT] Connected successfully")
print(f"[MQTT] Publishing to: {MQTT_TOPIC}")

print("\n" + "=" * 60)
print("Starting ESP32 simulation")
print("=" * 60)


# ============================================================
# PUBLISH READINGS
# ============================================================

for index, row in hive_df.iterrows():

    payload = {
        "device_id": str(row["device_id"]),

        "timestamp": convert_timestamp(row["timestamp"]),

        "sensors": {
            "weight_kg": float(row["weight_kg"]),
            "temperature_c": float(row["temperature_c"]),
            "humidity_pct": float(row["humidity_pct"]),
            "acoustics_hz": float(row["acoustics_hz"])
        },

        "diagnostics": {
            "battery_v": 4.12,
            "wifi_rssi_dbm": -68
        }
    }

    message = json.dumps(payload)

    client.publish(
        MQTT_TOPIC,
        message,
        qos=1
    )

    reading_number = list(hive_df.index).index(index) + 1

    print(
        f"[ESP32] Reading "
        f"{reading_number:03d}/{len(hive_df)} | "
        f"Temp: {payload['sensors']['temperature_c']:.2f}°C | "
        f"Humidity: {payload['sensors']['humidity_pct']:.2f}% | "
        f"Weight: {payload['sensors']['weight_kg']:.2f} kg | "
        f"Acoustic: {payload['sensors']['acoustics_hz']:.2f} Hz"
    )

    # Simulate time between sensor readings
    time.sleep(DELAY_SECONDS)


# ============================================================
# FINISHED
# ============================================================

client.disconnect()

print("\n" + "=" * 60)
print("Simulation completed")
print(f"Total readings sent: {len(hive_df)}")
print(f"MQTT topic: {MQTT_TOPIC}")
print("=" * 60)