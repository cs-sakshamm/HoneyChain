# HoneyChain Synthetic Indian Hive Telemetry Dataset v1.0

SYNTHETIC ONLY — NOT A REAL FIELD DATASET.

Rows: 172,800
Hives: 10
Duration: 120 days/hive
Sampling: 10 minutes
Signals: temperature, humidity, weight, acoustic frequency
Excluded: CO2, O2, pH

## Intended use
Develop and test the HoneyChain preprocessing, anomaly-detection, risk-scoring and MQTT inference pipeline.

## Important
NORMAL/ATTENTION/ALERT are synthetic scenario labels, NOT disease ground truth.
Anomaly types include temperature stress, humidity stress, weight decline, acoustic shift, colony weakening, forage reduction, possible swarm-related disturbance and sensor disturbance.

## Research basis
Krishnasamy et al. (2023), Sociobiology:
https://periodicos.uefs.br/index.php/sociobiology/article/view/9352

Geetha, Theerthagiri & Devi (2025), Indian Journal of Entomology:
https://eurekamag.com/research/102/788/102788528.php

The Indian 2023 study measured Apis cerana indica colonies in Bengaluru and related in-hive temperature/RH to forager activity and colony strength. The 2025 Andhra Pradesh study reports monitoring temperature, humidity, hive weight, sound and vibration. The accessible sources do not provide the full raw Andhra observation table, so this release does not claim to reproduce it.

## ML recommendation
Use temperature_c, humidity_pct, weight_kg, acoustics_hz and derived temporal features as model inputs.
Do not use condition/risk_level/anomaly_type as inputs to an unsupervised anomaly model.
Use the provided hive-level train/validation/test split to avoid leakage.

Real HoneyChain ESP32 data should eventually replace/calibrate the synthetic data.
