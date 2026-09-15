"""
HoneyChain ML feature configuration.

These are the actual sensor and temporal features used by the
HoneyChain anomaly-detection models.
"""

SENSOR_FEATURES = [
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",
]

TEMPORAL_FEATURES = [
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

ML_FEATURES = SENSOR_FEATURES + TEMPORAL_FEATURES


# These columns are labels/metadata.
# They must NEVER be used as model inputs.
EXCLUDED_FROM_MODEL = [
    "timestamp",
    "device_id",
    "colony_strength",
    "condition",
    "risk_level",
    "anomaly_type",
    "event_context",
    "split",
]


# Current HoneyChain reference ranges.
# These are operational attention ranges, NOT disease diagnoses.
TEMPERATURE_MIN_C = 30.0
TEMPERATURE_MAX_C = 36.0

HUMIDITY_MIN_PCT = 50.0
HUMIDITY_MAX_PCT = 70.0