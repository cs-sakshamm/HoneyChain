"""
HoneyChain Model v1
Isolation Forest anomaly detector.

Training strategy:
- Train only on NORMAL observations from training hives.
- Use validation hives to select the anomaly threshold.
- Keep the test hive completely held out until final evaluation.

IMPORTANT:
The current dataset is synthetic. Evaluation labels are synthetic
scenario labels and are NOT real disease ground truth.
"""

from pathlib import Path
import json

import joblib
import numpy as np
import pandas as pd

from sklearn.ensemble import IsolationForest
from sklearn.metrics import (
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import RobustScaler


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

MODEL_DIR = PROJECT_ROOT / "ai_ml" / "models"

MODEL_DIR.mkdir(parents=True, exist_ok=True)


DATA_FILE = DATA_DIR / "honeychain_ml_features.csv"


# ============================================================
# FEATURES
# ============================================================

FEATURES = [
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",

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


# ============================================================
# CONFIGURATION
# ============================================================

RANDOM_STATE = 42

N_ESTIMATORS = 300

# Candidate normal-tail percentages used to select the threshold.
THRESHOLD_CANDIDATES = [
    0.01,
    0.015,
    0.02,
    0.025,
    0.03,
    0.04,
    0.05,
    0.07,
    0.10,
]


# ============================================================
# LOAD DATA
# ============================================================

def load_dataset():
    print("=" * 70)
    print("Loading HoneyChain dataset")
    print("=" * 70)

    if not DATA_FILE.exists():
        raise FileNotFoundError(
            f"Dataset not found:\n{DATA_FILE}\n\n"
            "Make sure the dataset is extracted into:\n"
            "ai_ml/data/HoneyChain_Synthetic_Indian_Hive_Dataset_v1/"
        )

    df = pd.read_csv(DATA_FILE)

    print(f"Dataset rows: {len(df):,}")
    print(f"Dataset columns: {len(df.columns)}")

    return df


# ============================================================
# VALIDATE DATA
# ============================================================

def validate_dataset(df):
    required_columns = FEATURES + [
        "condition",
        "risk_level",
        "anomaly_type",
        "split",
        "device_id",
        "timestamp",
    ]

    missing = [
        column
        for column in required_columns
        if column not in df.columns
    ]

    if missing:
        raise ValueError(
            "Dataset is missing required columns:\n"
            + "\n".join(missing)
        )

    null_counts = df[FEATURES].isnull().sum()

    if null_counts.any():
        raise ValueError(
            "Missing values detected:\n"
            f"{null_counts[null_counts > 0]}"
        )

    print("\nDataset validation passed.")


# ============================================================
# CREATE TRAIN / VALIDATION / TEST SETS
# ============================================================

def split_dataset(df):

    train = df[df["split"] == "train"].copy()

    validation = df[
        df["split"] == "validation"
    ].copy()

    test = df[
        df["split"] == "test"
    ].copy()

    print("\nDataset split:")
    print(f"Train:      {len(train):,}")
    print(f"Validation: {len(validation):,}")
    print(f"Test:       {len(test):,}")

    return train, validation, test


# ============================================================
# TRAIN MODEL
# ============================================================

def train_model(train):

    normal_train = train[
        train["condition"] == "NORMAL"
    ].copy()

    print("\nNormal training observations:")
    print(f"{len(normal_train):,}")

    X_train = normal_train[FEATURES].astype(float)

    pipeline = Pipeline(
        steps=[
            (
                "scaler",
                RobustScaler(),
            ),

            (
                "model",
                IsolationForest(
                    n_estimators=N_ESTIMATORS,
                    max_samples="auto",
                    contamination="auto",
                    random_state=RANDOM_STATE,
                    n_jobs=-1,
                ),
            ),
        ]
    )

    print("\nTraining Isolation Forest...")

    pipeline.fit(X_train)

    print("Training complete.")

    return pipeline


# ============================================================
# ANOMALY SCORE
# ============================================================

def calculate_anomaly_score(model, df):

    X = df[FEATURES].astype(float)

    # IsolationForest decision_function:
    # higher = more normal
    #
    # We invert it so:
    # higher HoneyChain anomaly score = more anomalous
    score = -model.decision_function(X)

    return score


# ============================================================
# THRESHOLD SELECTION
# ============================================================

def select_threshold(
    model,
    train,
    validation,
):

    normal_train = train[
        train["condition"] == "NORMAL"
    ].copy()

    train_scores = calculate_anomaly_score(
        model,
        normal_train,
    )

    validation_scores = calculate_anomaly_score(
        model,
        validation,
    )

    y_validation = (
        validation["condition"] != "NORMAL"
    ).astype(int).to_numpy()

    results = []

    for tail_fraction in THRESHOLD_CANDIDATES:

        threshold = float(
            np.quantile(
                train_scores,
                1.0 - tail_fraction,
            )
        )

        predictions = (
            validation_scores >= threshold
        ).astype(int)

        precision = precision_score(
            y_validation,
            predictions,
            zero_division=0,
        )

        recall = recall_score(
            y_validation,
            predictions,
            zero_division=0,
        )

        f1 = f1_score(
            y_validation,
            predictions,
            zero_division=0,
        )

        results.append(
            {
                "normal_tail_fraction": tail_fraction,
                "threshold": threshold,
                "precision": precision,
                "recall": recall,
                "f1": f1,
            }
        )

    results_df = pd.DataFrame(results)

    results_df = results_df.sort_values(
        "f1",
        ascending=False,
    )

    best = results_df.iloc[0]

    threshold = float(best["threshold"])

    print("\nThreshold tuning:")
    print(results_df.to_string(index=False))

    print(
        f"\nSelected threshold: {threshold:.6f}"
    )

    return threshold, results_df


# ============================================================
# EVALUATION
# ============================================================

def evaluate(
    model,
    df,
    threshold,
    name,
):

    scores = calculate_anomaly_score(
        model,
        df,
    )

    actual = (
        df["condition"] != "NORMAL"
    ).astype(int).to_numpy()

    predicted = (
        scores >= threshold
    ).astype(int)

    metrics = {
        "precision": float(
            precision_score(
                actual,
                predicted,
                zero_division=0,
            )
        ),

        "recall": float(
            recall_score(
                actual,
                predicted,
                zero_division=0,
            )
        ),

        "f1": float(
            f1_score(
                actual,
                predicted,
                zero_division=0,
            )
        ),

        "roc_auc": float(
            roc_auc_score(
                actual,
                scores,
            )
        ),

        "average_precision": float(
            average_precision_score(
                actual,
                scores,
            )
        ),

        "confusion_matrix": (
            confusion_matrix(
                actual,
                predicted,
            ).tolist()
        ),
    }

    print("\n" + "=" * 70)
    print(f"{name.upper()} RESULTS")
    print("=" * 70)

    print(
        f"Precision: {metrics['precision']:.4f}"
    )

    print(
        f"Recall:    {metrics['recall']:.4f}"
    )

    print(
        f"F1:        {metrics['f1']:.4f}"
    )

    print(
        f"ROC-AUC:   {metrics['roc_auc']:.4f}"
    )

    print(
        f"Average Precision: "
        f"{metrics['average_precision']:.4f}"
    )

    print("\nConfusion matrix:")

    print(
        np.array(
            metrics["confusion_matrix"]
        )
    )

    return metrics, scores, predicted


# ============================================================
# MAIN
# ============================================================

def main():

    df = load_dataset()

    validate_dataset(df)

    train, validation, test = split_dataset(df)

    model = train_model(train)

    threshold, tuning_results = select_threshold(
        model,
        train,
        validation,
    )

    validation_metrics, _, _ = evaluate(
        model,
        validation,
        threshold,
        "Validation",
    )

    test_metrics, test_scores, test_predictions = evaluate(
        model,
        test,
        threshold,
        "Test",
    )

    # ========================================================
    # SAVE MODEL
    # ========================================================

    model_path = (
        MODEL_DIR
        / "honeychain_isolation_forest.joblib"
    )

    joblib.dump(
        model,
        model_path,
    )

    # ========================================================
    # SAVE THRESHOLD
    # ========================================================

    threshold_path = (
        MODEL_DIR
        / "threshold.json"
    )

    with open(
        threshold_path,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            {
                "threshold": threshold,
                "model": "IsolationForest",
                "version": "1.0",
            },
            file,
            indent=2,
        )

    # ========================================================
    # SAVE METRICS
    # ========================================================

    metrics_path = (
        MODEL_DIR
        / "metrics.json"
    )

    with open(
        metrics_path,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            {
                "model": "IsolationForest",
                "version": "1.0",
                "features": FEATURES,
                "n_estimators": N_ESTIMATORS,
                "random_state": RANDOM_STATE,
                "threshold": threshold,
                "validation": validation_metrics,
                "test": test_metrics,
                "note": (
                    "Evaluation labels are synthetic "
                    "scenario labels, not real disease "
                    "ground truth."
                ),
            },
            file,
            indent=2,
        )

    # ========================================================
    # SAVE THRESHOLD TUNING
    # ========================================================

    tuning_results.to_csv(
        MODEL_DIR
        / "threshold_tuning.csv",
        index=False,
    )

    # ========================================================
    # SAVE TEST PREDICTIONS
    # ========================================================

    predictions = test[
        [
            "timestamp",
            "device_id",
            "condition",
            "risk_level",
            "anomaly_type",
        ]
    ].copy()

    predictions[
        "anomaly_score"
    ] = test_scores

    predictions[
        "predicted_anomaly"
    ] = test_predictions

    predictions.to_csv(
        MODEL_DIR
        / "test_predictions.csv",
        index=False,
    )

    # ========================================================
    # COMPLETE
    # ========================================================

    print("\n" + "=" * 70)
    print("MODEL SAVED")
    print("=" * 70)

    print(f"\nModel:")
    print(model_path)

    print(f"\nThreshold:")
    print(threshold_path)

    print(f"\nMetrics:")
    print(metrics_path)

    print("\nHoneyChain Model v1 training complete.")


if __name__ == "__main__":
    main()