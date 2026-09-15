"""
HoneyChain Model v2
LSTM Autoencoder for temporal hive anomaly detection.

Training:
    NORMAL sequences from training hives only.

Sequence:
    36 observations
    10 minutes each
    = 6 hours

Sensors:
    temperature
    humidity
    weight
    acoustic frequency

IMPORTANT:
Synthetic labels are used only for evaluation.
They are NOT disease ground truth.
"""

from pathlib import Path
import json
import sys

import joblib
import numpy as np
import pandas as pd
import torch

from sklearn.metrics import (
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    average_precision_score,
    confusion_matrix,
)
from sklearn.preprocessing import RobustScaler


# ============================================================
# IMPORT PROJECT MODULE
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

sys.path.insert(
    0,
    str(PROJECT_ROOT / "ai_ml"),
)

from src.lstm_autoencoder import LSTMAutoencoder


# ============================================================
# PATHS
# ============================================================

DATA_DIR = (
    PROJECT_ROOT
    / "ai_ml"
    / "data"
    / "HoneyChain_Synthetic_Indian_Hive_Dataset_v1"
)

MODEL_DIR = (
    PROJECT_ROOT
    / "ai_ml"
    / "models"
)

DATA_FILE = (
    DATA_DIR
    / "honeychain_synthetic_hive_telemetry.csv"
)

MODEL_DIR.mkdir(
    parents=True,
    exist_ok=True,
)


# ============================================================
# CONFIGURATION
# ============================================================

FEATURES = [
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",
]

SEQUENCE_LENGTH = 36

# 36 × 10 minutes = 6 hours

STRIDE = 6

HIDDEN_SIZE = 64

LATENT_SIZE = 32

EPOCHS = 15

BATCH_SIZE = 256

LEARNING_RATE = 0.001

RANDOM_STATE = 42


# ============================================================
# REPRODUCIBILITY
# ============================================================

np.random.seed(
    RANDOM_STATE
)

torch.manual_seed(
    RANDOM_STATE
)


# ============================================================
# LOAD DATA
# ============================================================

def load_dataset():

    print("=" * 70)
    print("Loading HoneyChain telemetry")
    print("=" * 70)

    if not DATA_FILE.exists():

        raise FileNotFoundError(
            f"Dataset not found:\n{DATA_FILE}"
        )

    df = pd.read_csv(
        DATA_FILE
    )

    # IMPORTANT:
    # Dataset timestamp is ISO-8601,
    # not Unix epoch.

    df["timestamp"] = pd.to_datetime(
        df["timestamp"],
        utc=True,
    )

    df = df.sort_values(
        [
            "device_id",
            "timestamp",
        ]
    ).reset_index(
        drop=True
    )

    print(
        f"Rows: {len(df):,}"
    )

    return df


# ============================================================
# FIT SCALER
# ============================================================

def fit_scaler(train):

    normal_train = train[
        train["condition"] == "NORMAL"
    ]

    scaler = RobustScaler()

    scaler.fit(
        normal_train[
            FEATURES
        ].astype(float)
    )

    return scaler


# ============================================================
# CREATE SEQUENCES
# ============================================================

def create_sequences(
    df,
    scaler,
    normal_only=False,
):

    sequences = []

    metadata = []

    for device_id, hive in df.groupby(
        "device_id",
        sort=False,
    ):

        hive = hive.sort_values(
            "timestamp"
        ).reset_index(
            drop=True
        )

        values = scaler.transform(
            hive[
                FEATURES
            ].astype(float)
        )

        # ----------------------------------------------------
        # Sliding window
        # ----------------------------------------------------

        for start in range(
            0,
            len(hive)
            - SEQUENCE_LENGTH
            + 1,
            STRIDE,
        ):

            end = (
                start
                + SEQUENCE_LENGTH
            )

            window = hive.iloc[
                start:end
            ]

            # For training we only accept
            # completely normal windows.

            if normal_only:

                if not (
                    window["condition"]
                    == "NORMAL"
                ).all():

                    continue

            sequences.append(
                values[
                    start:end
                ]
            )

            metadata.append(
                {
                    "device_id": device_id,

                    "timestamp": (
                        window.iloc[-1]
                        ["timestamp"]
                        .isoformat()
                    ),

                    "condition": (
                        window.iloc[-1]
                        ["condition"]
                    ),

                    "risk_level": (
                        window.iloc[-1]
                        ["risk_level"]
                    ),

                    "anomaly_type": (
                        window.iloc[-1]
                        ["anomaly_type"]
                    ),
                }
            )

    return (
        np.asarray(
            sequences,
            dtype=np.float32,
        ),
        pd.DataFrame(
            metadata
        ),
    )


# ============================================================
# TRAIN
# ============================================================

def train_model(
    X_train,
    device,
):

    model = LSTMAutoencoder(
        n_features=len(FEATURES),
        hidden_size=HIDDEN_SIZE,
        latent_size=LATENT_SIZE,
    )

    model = model.to(
        device
    )

    optimizer = torch.optim.Adam(
        model.parameters(),
        lr=LEARNING_RATE,
    )

    loss_function = torch.nn.MSELoss()

    dataset = torch.utils.data.TensorDataset(
        torch.from_numpy(
            X_train
        )
    )

    loader = torch.utils.data.DataLoader(
        dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
    )

    history = []

    for epoch in range(
        1,
        EPOCHS + 1,
    ):

        model.train()

        total_loss = 0.0

        total_samples = 0

        for batch_tuple in loader:

            batch = batch_tuple[0]

            batch = batch.to(
                device
            )

            optimizer.zero_grad()

            reconstructed, _ = model(
                batch
            )

            loss = loss_function(
                reconstructed,
                batch,
            )

            loss.backward()

            torch.nn.utils.clip_grad_norm_(
                model.parameters(),
                1.0,
            )

            optimizer.step()

            total_loss += (
                loss.item()
                * len(batch)
            )

            total_samples += len(
                batch
            )

        epoch_loss = (
            total_loss
            / total_samples
        )

        history.append(
            {
                "epoch": epoch,
                "loss": epoch_loss,
            }
        )

        print(
            f"Epoch "
            f"{epoch:02d}/{EPOCHS} "
            f"- loss={epoch_loss:.6f}"
        )

    return model, history


# ============================================================
# CALCULATE RECONSTRUCTION ERROR
# ============================================================

def reconstruction_errors(
    model,
    sequences,
    device,
):

    model.eval()

    errors = []

    with torch.no_grad():

        for start in range(
            0,
            len(sequences),
            BATCH_SIZE,
        ):

            batch = torch.from_numpy(
                sequences[
                    start:
                    start + BATCH_SIZE
                ]
            )

            batch = batch.to(
                device
            )

            reconstructed, _ = model(
                batch
            )

            error = (
                (
                    reconstructed
                    - batch
                )
                ** 2
            ).mean(
                dim=(1, 2)
            )

            errors.extend(
                error.cpu().numpy()
            )

    return np.asarray(
        errors
    )


# ============================================================
# EVALUATION
# ============================================================

def evaluate(
    errors,
    metadata,
    threshold,
    name,
):

    actual = (
        metadata["condition"]
        != "NORMAL"
    ).astype(int).to_numpy()

    predicted = (
        errors >= threshold
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
                errors,
            )
        ),

        "average_precision": float(
            average_precision_score(
                actual,
                errors,
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

    print(
        f"{name.upper()} RESULTS"
    )

    print("=" * 70)

    print(
        f"Precision: "
        f"{metrics['precision']:.4f}"
    )

    print(
        f"Recall: "
        f"{metrics['recall']:.4f}"
    )

    print(
        f"F1: "
        f"{metrics['f1']:.4f}"
    )

    print(
        f"ROC-AUC: "
        f"{metrics['roc_auc']:.4f}"
    )

    print(
        f"Average Precision: "
        f"{metrics['average_precision']:.4f}"
    )

    print("\nConfusion matrix:")

    print(
        np.array(
            metrics[
                "confusion_matrix"
            ]
        )
    )

    return (
        metrics,
        predicted,
    )


# ============================================================
# MAIN
# ============================================================

def main():

    df = load_dataset()

    # --------------------------------------------------------
    # Dataset splits
    # --------------------------------------------------------

    train = df[
        df["split"] == "train"
    ].copy()

    validation = df[
        df["split"] == "validation"
    ].copy()

    test = df[
        df["split"] == "test"
    ].copy()

    print("\nSplits:")

    print(
        f"Train: "
        f"{len(train):,}"
    )

    print(
        f"Validation: "
        f"{len(validation):,}"
    )

    print(
        f"Test: "
        f"{len(test):,}"
    )

    # --------------------------------------------------------
    # Scaler
    # --------------------------------------------------------

    scaler = fit_scaler(
        train
    )

    scaler_path = (
        MODEL_DIR
        / "lstm_scaler.joblib"
    )

    joblib.dump(
        scaler,
        scaler_path,
    )

    # --------------------------------------------------------
    # Training sequences
    # --------------------------------------------------------

    print(
        "\nCreating normal training sequences..."
    )

    X_train, train_meta = (
        create_sequences(
            train,
            scaler,
            normal_only=True,
        )
    )

    print(
        f"Training sequences: "
        f"{len(X_train):,}"
    )

    # --------------------------------------------------------
    # Validation sequences
    # --------------------------------------------------------

    print(
        "\nCreating validation sequences..."
    )

    X_validation, validation_meta = (
        create_sequences(
            validation,
            scaler,
        )
    )

    print(
        f"Validation sequences: "
        f"{len(X_validation):,}"
    )

    # --------------------------------------------------------
    # Test sequences
    # --------------------------------------------------------

    print(
        "\nCreating test sequences..."
    )

    X_test, test_meta = (
        create_sequences(
            test,
            scaler,
        )
    )

    print(
        f"Test sequences: "
        f"{len(X_test):,}"
    )

    # --------------------------------------------------------
    # Device
    # --------------------------------------------------------

    device = torch.device(
        "cuda"
        if torch.cuda.is_available()
        else "cpu"
    )

    print(
        f"\nTraining device: "
        f"{device}"
    )

    # --------------------------------------------------------
    # Train
    # --------------------------------------------------------

    model, history = train_model(
        X_train,
        device,
    )

    # --------------------------------------------------------
    # Reconstruction errors
    # --------------------------------------------------------

    print(
        "\nCalculating reconstruction errors..."
    )

    train_errors = (
        reconstruction_errors(
            model,
            X_train,
            device,
        )
    )

    validation_errors = (
        reconstruction_errors(
            model,
            X_validation,
            device,
        )
    )

    test_errors = (
        reconstruction_errors(
            model,
            X_test,
            device,
        )
    )

    # --------------------------------------------------------
    # Threshold
    # --------------------------------------------------------

    validation_normal = (
        validation_meta[
            "condition"
        ].to_numpy()
        == "NORMAL"
    )

    normal_validation_errors = (
        validation_errors[
            validation_normal
        ]
    )

    threshold = float(
        np.quantile(
            normal_validation_errors,
            0.975,
        )
    )

    print(
        f"\nSelected threshold: "
        f"{threshold:.6f}"
    )

    # --------------------------------------------------------
    # Evaluate
    # --------------------------------------------------------

    validation_metrics, _ = evaluate(
        validation_errors,
        validation_meta,
        threshold,
        "Validation",
    )

    test_metrics, test_predictions = (
        evaluate(
            test_errors,
            test_meta,
            threshold,
            "Test",
        )
    )

    # --------------------------------------------------------
    # Save model
    # --------------------------------------------------------

    model_path = (
        MODEL_DIR
        / "honeychain_lstm_autoencoder.pt"
    )

    torch.save(
        {
            "model_state_dict":
                model.state_dict(),

            "n_features":
                len(FEATURES),

            "hidden_size":
                HIDDEN_SIZE,

            "latent_size":
                LATENT_SIZE,

            "sequence_length":
                SEQUENCE_LENGTH,

            "stride":
                STRIDE,

            "features":
                FEATURES,
        },
        model_path,
    )

    # --------------------------------------------------------
    # Save threshold
    # --------------------------------------------------------

    threshold_path = (
        MODEL_DIR
        / "lstm_threshold.json"
    )

    with open(
        threshold_path,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            {
                "threshold":
                    threshold,

                "sequence_length":
                    SEQUENCE_LENGTH,

                "sequence_hours":
                    6,

                "interval_minutes":
                    10,
            },
            file,
            indent=2,
        )

    # --------------------------------------------------------
    # Save metrics
    # --------------------------------------------------------

    metrics_path = (
        MODEL_DIR
        / "lstm_metrics.json"
    )

    with open(
        metrics_path,
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            {
                "model":
                    "LSTM Autoencoder",

                "features":
                    FEATURES,

                "sequence_length":
                    SEQUENCE_LENGTH,

                "sequence_hours":
                    6,

                "stride":
                    STRIDE,

                "epochs":
                    EPOCHS,

                "batch_size":
                    BATCH_SIZE,

                "hidden_size":
                    HIDDEN_SIZE,

                "latent_size":
                    LATENT_SIZE,

                "learning_rate":
                    LEARNING_RATE,

                "threshold":
                    threshold,

                "validation":
                    validation_metrics,

                "test":
                    test_metrics,

                "note":
                    (
                        "Synthetic labels are "
                        "evaluation labels only. "
                        "They are not real disease "
                        "ground truth."
                    ),
            },
            file,
            indent=2,
        )

    # --------------------------------------------------------
    # Save training history
    # --------------------------------------------------------

    with open(
        MODEL_DIR
        / "lstm_training_history.json",
        "w",
        encoding="utf-8",
    ) as file:

        json.dump(
            history,
            file,
            indent=2,
        )

    # --------------------------------------------------------
    # Save predictions
    # --------------------------------------------------------

    prediction_df = (
        test_meta.copy()
    )

    prediction_df[
        "reconstruction_error"
    ] = test_errors

    prediction_df[
        "predicted_anomaly"
    ] = test_predictions

    prediction_df[
        "actual_anomaly"
    ] = (
        prediction_df[
            "condition"
        ] != "NORMAL"
    ).astype(int)

    prediction_df.to_csv(
        MODEL_DIR
        / "lstm_test_predictions.csv",
        index=False,
    )

    # --------------------------------------------------------
    # Done
    # --------------------------------------------------------

    print("\n" + "=" * 70)

    print(
        "HONEYCHAIN MODEL V2 COMPLETE"
    )

    print("=" * 70)

    print(
        f"\nModel saved to:\n"
        f"{model_path}"
    )

    print(
        f"\nScaler saved to:\n"
        f"{scaler_path}"
    )

    print(
        f"\nThreshold saved to:\n"
        f"{threshold_path}"
    )

    print(
        f"\nMetrics saved to:\n"
        f"{metrics_path}"
    )


if __name__ == "__main__":

    main()