from __future__ import annotations

import json
from pathlib import Path

import joblib
import pandas as pd

from .feature_builder import MODEL_FEATURE_COLUMNS


class AnomalyDetector:
    """
    HoneyChain Isolation Forest inference engine.
    """

    def __init__(
        self,
        model_path: str | Path,
        threshold_path: str | Path,
    ):
        self.model_path = Path(model_path)
        self.threshold_path = Path(threshold_path)

        self.model = joblib.load(self.model_path)

        with open(self.threshold_path, "r", encoding="utf-8") as file:
            threshold_data = json.load(file)

        self.threshold = float(threshold_data["threshold"])

    def predict(self, features: dict) -> dict:

        missing = [
            column
            for column in MODEL_FEATURE_COLUMNS
            if column not in features
        ]

        if missing:
            raise ValueError(
                f"Missing model features: {missing}"
            )

        dataframe = pd.DataFrame(
            [[features[column] for column in MODEL_FEATURE_COLUMNS]],
            columns=MODEL_FEATURE_COLUMNS,
        )

        # The trained model is a pipeline.
        # decision_function gives larger values to more normal observations.
        score = float(
            self.model.decision_function(dataframe)[0]
        )

        anomaly = score < self.threshold

        return {
            "anomaly_score": round(score, 6),
            "anomaly_detected": bool(anomaly),
        }