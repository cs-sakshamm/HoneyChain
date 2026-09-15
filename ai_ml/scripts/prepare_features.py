"""
HoneyChain Feature Preparation

Creates temporal ML features independently for each hive.

Input:
    honeychain_synthetic_hive_telemetry.csv

Output:
    honeychain_ml_features.csv
"""

from pathlib import Path

import pandas as pd


# ============================================================
# PATHS
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

DATA_DIR = (
    PROJECT_ROOT
    / "ai_ml"
    / "data"
    / "HoneyChain_Synthetic_Indian_Hive_Dataset_v1"
)

INPUT_FILE = (
    DATA_DIR
    / "honeychain_synthetic_hive_telemetry.csv"
)

OUTPUT_FILE = (
    DATA_DIR
    / "honeychain_ml_features.csv"
)


# ============================================================
# CONFIGURATION
# ============================================================

TIME_INTERVAL_MINUTES = 10

STEPS_1H = 60 // TIME_INTERVAL_MINUTES
STEPS_6H = 6 * 60 // TIME_INTERVAL_MINUTES
STEPS_24H = 24 * 60 // TIME_INTERVAL_MINUTES


# ============================================================
# LOAD DATA
# ============================================================

def load_data():

    print("=" * 70)
    print("Loading HoneyChain telemetry")
    print("=" * 70)

    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input dataset not found:\n{INPUT_FILE}"
        )

    df = pd.read_csv(INPUT_FILE)

    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    return df


# ============================================================
# PREPARE TIMESTAMP
# ============================================================

def prepare_timestamp(df):

    # Dataset uses ISO-8601 timestamps such as:
    #
    # 2026-01-01T00:00:00+0530

    df["timestamp"] = pd.to_datetime(
        df["timestamp"],
        utc=True,
    )

    df = df.sort_values(
        [
            "device_id",
            "timestamp",
        ]
    ).reset_index(drop=True)

    return df


# ============================================================
# CREATE TEMPORAL FEATURES
# ============================================================

def create_features(df):

    print("\nCreating hive-specific temporal features...")

    grouped = df.groupby(
        "device_id",
        group_keys=False,
    )

    # --------------------------------------------------------
    # 1-HOUR DELTAS
    # --------------------------------------------------------

    df["temperature_c_delta_1h"] = grouped[
        "temperature_c"
    ].transform(
        lambda x: x - x.shift(STEPS_1H)
    )

    df["humidity_pct_delta_1h"] = grouped[
        "humidity_pct"
    ].transform(
        lambda x: x - x.shift(STEPS_1H)
    )

    df["weight_kg_delta_1h"] = grouped[
        "weight_kg"
    ].transform(
        lambda x: x - x.shift(STEPS_1H)
    )

    df["acoustics_hz_delta_1h"] = grouped[
        "acoustics_hz"
    ].transform(
        lambda x: x - x.shift(STEPS_1H)
    )

    # --------------------------------------------------------
    # 6-HOUR ROLLING MEANS
    # --------------------------------------------------------

    df["temperature_c_rolling_mean_6h"] = grouped[
        "temperature_c"
    ].transform(
        lambda x: x.rolling(
            STEPS_6H,
            min_periods=STEPS_6H,
        ).mean()
    )

    df["humidity_pct_rolling_mean_6h"] = grouped[
        "humidity_pct"
    ].transform(
        lambda x: x.rolling(
            STEPS_6H,
            min_periods=STEPS_6H,
        ).mean()
    )

    df["weight_kg_rolling_mean_6h"] = grouped[
        "weight_kg"
    ].transform(
        lambda x: x.rolling(
            STEPS_6H,
            min_periods=STEPS_6H,
        ).mean()
    )

    df["acoustics_hz_rolling_mean_6h"] = grouped[
        "acoustics_hz"
    ].transform(
        lambda x: x.rolling(
            STEPS_6H,
            min_periods=STEPS_6H,
        ).mean()
    )

    # --------------------------------------------------------
    # 24-HOUR WEIGHT CHANGE
    # --------------------------------------------------------

    df["weight_delta_24h"] = grouped[
        "weight_kg"
    ].transform(
        lambda x: x - x.shift(STEPS_24H)
    )

    return df


# ============================================================
# HANDLE STARTUP ROWS
# ============================================================

def remove_incomplete_history(df):

    temporal_features = [
        "temperature_c_delta_1h",
        "humidity_pct_delta_1h",
        "weight_kg_delta_1h",
        "acoustics_hz_delta_1h",

        "temperature_c_rolling_mean_6h",
        "humidity_pct_rolling_mean_6h",
        "weight_kg_rolling_mean_6h",
        "acoustics_hz_rolling_mean_6h",

        "weight_delta_24h",
    ]

    before = len(df)

    df = df.dropna(
        subset=temporal_features
    ).reset_index(drop=True)

    after = len(df)

    print("\nRemoved rows without sufficient history:")
    print(f"Before: {before:,}")
    print(f"After:  {after:,}")
    print(f"Removed: {before - after:,}")

    return df


# ============================================================
# VALIDATE
# ============================================================

def validate(df):

    temporal_features = [
        "temperature_c_delta_1h",
        "humidity_pct_delta_1h",
        "weight_kg_delta_1h",
        "acoustics_hz_delta_1h",

        "temperature_c_rolling_mean_6h",
        "humidity_pct_rolling_mean_6h",
        "weight_kg_rolling_mean_6h",
        "acoustics_hz_rolling_mean_6h",

        "weight_delta_24h",
    ]

    print("\nChecking temporal features...")

    missing = df[temporal_features].isnull().sum()

    if missing.any():

        print("\nRemaining missing values:")

        print(
            missing[missing > 0]
        )

        raise ValueError(
            "Temporal feature generation failed."
        )

    print(
        "✓ No missing temporal feature values."
    )


# ============================================================
# SAVE
# ============================================================

def save_data(df):

    df.to_csv(
        OUTPUT_FILE,
        index=False,
    )

    print("\nFeature dataset saved:")
    print(OUTPUT_FILE)

    print(
        f"\nFinal rows: {len(df):,}"
    )

    print(
        f"Final columns: {len(df.columns)}"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    df = load_data()

    df = prepare_timestamp(df)

    df = create_features(df)

    df = remove_incomplete_history(df)

    validate(df)

    save_data(df)

    print("\n" + "=" * 70)
    print("FEATURE PREPARATION COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    main()