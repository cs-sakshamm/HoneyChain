from __future__ import annotations

from collections import defaultdict, deque
from typing import Dict

import pandas as pd


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


# Data arrives every 10 minutes.
# 1 hour  = 6 readings
# 6 hours = 36 readings
# 24 hours = 144 readings
HISTORY_REQUIRED = 145


class HiveHistory:
    """
    Maintains recent telemetry for one hive/device.
    """

    def __init__(self, max_length: int = HISTORY_REQUIRED):
        self.data = deque(maxlen=max_length)

    def add(self, reading: dict) -> None:
        self.data.append(reading)

    def size(self) -> int:
        return len(self.data)

    def dataframe(self) -> pd.DataFrame:
        return pd.DataFrame(list(self.data))


class FeatureBuilder:
    """
    Converts raw MQTT sensor history into the exact feature structure
    expected by the HoneyChain Isolation Forest model.
    """

    def __init__(self):
        self.histories: Dict[str, HiveHistory] = defaultdict(HiveHistory)

    def add_reading(
        self,
        device_id: str,
        timestamp: int,
        sensors: dict,
    ) -> None:

        reading = {
            "timestamp": timestamp,
            "device_id": device_id,
            "temperature_c": float(sensors["temperature_c"]),
            "humidity_pct": float(sensors["humidity_pct"]),
            "weight_kg": float(sensors["weight_kg"]),
            "acoustics_hz": float(sensors["acoustics_hz"]),
        }

        self.histories[device_id].add(reading)

    def get_history_size(self, device_id: str) -> int:
        return self.histories[device_id].size()

    def build_latest_features(self, device_id: str) -> dict | None:

        if device_id not in self.histories:
            return None

        history = self.histories[device_id].data

        if len(history) == 0:
            return None

        df = pd.DataFrame(list(history))

        df["timestamp"] = pd.to_datetime(
            df["timestamp"],
            unit="s",
            utc=True,
        )

        df = df.sort_values("timestamp").reset_index(drop=True)

        # 1-hour changes
        steps_1h = 6

        df["temperature_c_delta_1h"] = (
            df["temperature_c"] -
            df["temperature_c"].shift(steps_1h)
        ).bfill().fillna(0.0)

        df["humidity_pct_delta_1h"] = (
            df["humidity_pct"] -
            df["humidity_pct"].shift(steps_1h)
        ).bfill().fillna(0.0)

        df["weight_kg_delta_1h"] = (
            df["weight_kg"] -
            df["weight_kg"].shift(steps_1h)
        ).bfill().fillna(0.0)

        df["acoustics_hz_delta_1h"] = (
            df["acoustics_hz"] -
            df["acoustics_hz"].shift(steps_1h)
        ).bfill().fillna(0.0)

        # 6-hour rolling means
        window_6h = 36

        df["temperature_c_rolling_mean_6h"] = (
            df["temperature_c"]
            .rolling(window=window_6h, min_periods=1)
            .mean()
        )

        df["humidity_pct_rolling_mean_6h"] = (
            df["humidity_pct"]
            .rolling(window=window_6h, min_periods=1)
            .mean()
        )

        df["weight_kg_rolling_mean_6h"] = (
            df["weight_kg"]
            .rolling(window=window_6h, min_periods=1)
            .mean()
        )

        df["acoustics_hz_rolling_mean_6h"] = (
            df["acoustics_hz"]
            .rolling(window=window_6h, min_periods=1)
            .mean()
        )

        # 24-hour weight change
        steps_24h = 144

        df["weight_delta_24h"] = (
            df["weight_kg"] -
            df["weight_kg"].shift(steps_24h)
        ).bfill().fillna(0.0)

        latest = df.iloc[-1]

        if latest[MODEL_FEATURE_COLUMNS].isna().any():
            return None

        return {
            column: float(latest[column])
            for column in MODEL_FEATURE_COLUMNS
        }