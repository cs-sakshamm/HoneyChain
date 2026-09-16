from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent

DATA_DIR = BASE_DIR / "data"
RAW_DATA_DIR = DATA_DIR / "raw"
PROCESSED_DATA_DIR = DATA_DIR / "processed"

MODEL_DIR = BASE_DIR / "models"

MQTT_BROKER = "localhost"
MQTT_PORT = 1883

# NOTE: The live pipeline (ai_ml/mqtt/mqtt_processor.py) subscribes to
# "honeychain/hive/telemetry" and publishes to "honeychain/hive/processed".
# MQTT_TOPIC below is only a legacy training-data collection topic and is
# intentionally kept in sync with the standard HoneyChain topic namespace.
MQTT_TOPIC = "honeychain/hive/telemetry"

MODEL_PATH = MODEL_DIR / "hive_anomaly_model.joblib"

FEATURE_COLUMNS = [
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",
]

DIAGNOSTIC_COLUMNS = [
    "battery_v",
    "wifi_rssi_dbm",
]


for directory in [
    RAW_DATA_DIR,
    PROCESSED_DATA_DIR,
    MODEL_DIR,
]:
    directory.mkdir(parents=True, exist_ok=True)