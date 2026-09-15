# HoneyChain AI/ML + IoT + MQTT — Developer README

## 1. Purpose

This document explains the HoneyChain AI/ML + MQTT subsystem for beginners.

It is written for three developers:

- **IoT developer:** sends hive telemetry from ESP32.
- **AI/ML developer:** receives telemetry, analyzes it, and publishes processed results.
- **Flutter developer:** consumes the processed data through the backend and displays it in the app.

The AI/ML service is designed so the Flutter application does **not** need to run the ML model itself.

## 2. System Architecture

```text
ESP32
  |
  | MQTT JSON
  v
MQTT Broker
  |
  | honeychain/hive/telemetry
  v
HoneyChain AI/ML Processor
  |
  +-- Feature Builder
  +-- Isolation Forest
  +-- Reference Rules
  +-- Risk Engine
  |
  v
Processed JSON
  |
  | honeychain/hive/processed
  v
FastAPI Backend
  |
  v
PostgreSQL
  |
  v
Flutter App
```

## 3. Project Structure

```text
HoneyChain/
|
+-- ai_ml/
|   +-- data/
|   +-- models/
|   +-- mqtt/
|   |   +-- __init__.py
|   |   +-- mqtt_processor.py
|   +-- src/
|   |   +-- feature_builder.py
|   |   +-- anomaly_detector.py
|   |   +-- risk_engine.py
|   |   +-- output_formatter.py
|   +-- tests/
|       +-- __init__.py
|       +-- test_pipeline.py
|       +-- mqtt_simulator.py
|
+-- backend/
+-- mobile_app/
+-- iot/
+-- blockchain/
+-- docs/
+-- shared/
```

## 4. Requirements

For the current AI/ML MQTT prototype:

- Python 3.11 recommended
- Mosquitto MQTT broker
- Python dependencies from `ai_ml/requirements.txt`
- Trained model files in `ai_ml/models/`

From the HoneyChain root:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain
.\.venv\Scripts\Activate.ps1
pip install -r ai_ml\requirements.txt
```

## 5. MQTT Configuration

### Development

```text
Broker host: localhost
Broker port: 1883
```

### Input topic

ESP32 publishes here:

```text
honeychain/hive/telemetry
```

### Output topic

AI processor publishes here:

```text
honeychain/hive/processed
```

These are MQTT topics, not Windows folders.

### Important for ESP32

`localhost` means the ESP32 itself. A physical ESP32 normally needs the **IP address/hostname of the computer running the MQTT broker**, for example:

```text
MQTT_HOST = 192.168.1.100
MQTT_PORT = 1883
```

## 6. Recommended Real ESP32 Interval

MQTT does not determine the publishing interval. The ESP32 firmware does.

For HoneyChain, the recommended real-device interval is:

```text
1 telemetry message every 10 minutes
```

This matches the temporal resolution used by the current synthetic data and feature pipeline.

Therefore:

```text
1 hour  = 6 readings
6 hours = 36 readings
24 hours = 144 readings
```

### Simulator interval

The development simulator intentionally uses:

```text
1 second per reading
```

This is only compressed time for testing. It does **not** mean the physical ESP32 should publish every second.

## 7. ESP32 Hardware/Data Contract

Current main telemetry signals:

```text
Temperature
Humidity
Hive weight
Acoustic frequency
```

Current hardware concept:

```text
ESP32
 |
 +-- DHT22
 |    +-- temperature
 |    +-- humidity
 |
 +-- HX711 + load cell
 |    +-- weight
 |
 +-- INMP441
      +-- acoustic signal
```

Diagnostics:

```text
battery_v
wifi_rssi_dbm
```

CO2 is currently excluded from the deployed telemetry contract.

## 8. ESP32 JSON Format

The ESP32 must publish JSON similar to:

```json
{
  "device_id": "SIH_HIVE_MVP_01",
  "timestamp": 1725879172,
  "sensors": {
    "weight_kg": 3.25,
    "temperature_c": 34.2,
    "humidity_pct": 61.5,
    "acoustics_hz": 245
  },
  "diagnostics": {
    "battery_v": 4.12,
    "wifi_rssi_dbm": -68
  }
}
```

### Required fields

```text
device_id
timestamp
sensors.weight_kg
sensors.temperature_c
sensors.humidity_pct
sensors.acoustics_hz
```

Diagnostics are recommended.

### device_id

Every physical hive/device must have a unique ID:

```text
SIH_HIVE_01
SIH_HIVE_02
SIH_HIVE_03
```

The AI service keeps history separately for each device.

### timestamp

Use a Unix timestamp representing when the measurement was taken.

## 9. Sensor Meaning

### Temperature

```json
"temperature_c": 34.2
```

Unit: °C

Current prototype reference:

```text
30°C–36°C
```

This is an operational reference range, not a universal disease threshold.

### Humidity

```json
"humidity_pct": 61.5
```

Unit: %

Current prototype reference:

```text
50%–70%
```

### Weight

```json
"weight_kg": 3.25
```

Unit: kg

HoneyChain primarily evaluates weight **as a trend over time**, rather than declaring a hive healthy/unhealthy from one absolute weight.

### Acoustics

```json
"acoustics_hz": 245
```

Unit: Hz

This is a frequency-domain acoustic feature.

**Hz is not dB.** It cannot be directly converted to dB.

The current system does not use one universal Hz value as a disease threshold. Acoustic information contributes to multivariate anomaly detection.

## 10. How the AI System Starts

Use three terminals during local testing.

### Terminal 1 — AI processor

From the HoneyChain root:

```powershell
python -m ai_ml.mqtt.mqtt_processor
```

Expected:

```text
HoneyChain AI MQTT Processor
Broker : localhost:1883
Input  : honeychain/hive/telemetry
Output : honeychain/hive/processed
Model  : ...\ai_ml\models\honeychain_isolation_forest.joblib

[MQTT] Connecting...
[MQTT] Connected with result code: Success
[MQTT] Subscribed to: honeychain/hive/telemetry
```

Keep this terminal running.

**The AI processor does not read the 172,800-row CSV during normal MQTT operation.** It waits for MQTT messages.

### Terminal 2 — watch processed output

```powershell
& "C:\Program Files\Mosquitto\mosquitto_sub.exe" `
-h localhost `
-p 1883 `
-t "honeychain/hive/processed" `
-v
```

Keep it running.

### Terminal 3 — simulate ESP32

```powershell
python -m ai_ml.tests.mqtt_simulator
```

The simulator:

- reads the synthetic dataset,
- selects one hive,
- uses 300 readings,
- publishes them in ESP32-compatible JSON,
- waits 1 second between readings.

This means 300 test readings take roughly 5 minutes.

## 11. Why the AI Waits for 145 Readings

The current feature builder uses temporal information:

```text
1-hour changes
6-hour rolling statistics
24-hour weight change
```

At 10-minute sampling:

```text
1 hour = 6 readings
6 hours = 36 readings
24 hours = 144 intervals
```

The current live feature builder therefore needs approximately:

```text
145 readings
```

before the complete model feature vector is available.

With a real 10-minute interval, this is approximately one day of history.

With the simulator's 1-second interval, it is approximately 145 seconds.

## 12. AI Model

Current live baseline:

```text
Isolation Forest
```

Files:

```text
ai_ml/models/honeychain_isolation_forest.joblib
ai_ml/models/threshold.json
ai_ml/models/metrics.json
```

The model uses:

```text
temperature_c
humidity_pct
weight_kg
acoustics_hz

temperature_c_delta_1h
temperature_c_rolling_mean_6h

humidity_pct_delta_1h
humidity_pct_rolling_mean_6h

weight_kg_delta_1h
weight_kg_rolling_mean_6h

acoustics_hz_delta_1h
acoustics_hz_rolling_mean_6h

weight_delta_24h
```

Labels such as `condition`, `risk_level` and `anomaly_type` are not model inputs.

The current baseline was trained primarily on normal observations and is used for anomaly detection.

## 13. LSTM Model

An LSTM Autoencoder was also evaluated.

Current decision:

```text
Isolation Forest = live baseline
LSTM Autoencoder = experimental/research model
```

Do not replace the live model without re-evaluation.

## 14. Risk Engine

HoneyChain combines:

```text
ML anomaly detection
+
temperature reference rules
+
humidity reference rules
+
weight trend analysis
```

Possible risk levels:

```text
LOW
MEDIUM
HIGH
```

Possible statuses:

```text
HEALTHY
ATTENTION
ALERT
```

The system is an early-warning system, not a veterinary disease diagnosis system.

## 15. Processed MQTT JSON

The AI processor publishes a response similar to:

```json
{
  "device_id": "SIH_HIVE_MVP_01",
  "timestamp": 1725879172,
  "hive_status": {
    "risk_level": "LOW",
    "status": "HEALTHY",
    "anomaly_detected": false,
    "anomaly_score": 0.0048
  },
  "sensors": {
    "temperature_c": 34.2,
    "humidity_pct": 61.5,
    "weight_kg": 3.25,
    "acoustics_hz": 245
  },
  "analysis": {
    "temperature": {
      "status": "NORMAL",
      "value": 34.2,
      "reference_range": {
        "min": 30.0,
        "max": 36.0
      }
    },
    "humidity": {
      "status": "NORMAL",
      "value": 61.5,
      "reference_range": {
        "min": 50.0,
        "max": 70.0
      }
    },
    "weight": {
      "status": "STABLE",
      "trend": "STABLE",
      "value_kg": 3.25
    },
    "acoustics": {
      "status": "NORMAL",
      "value_hz": 245
    }
  },
  "alerts": [],
  "analysis_summary": {
    "reasons": []
  },
  "diagnostics": {
    "battery_v": 4.12,
    "wifi_rssi_dbm": -68
  }
}
```

## 16. Flutter Integration — Prabhakar Gupta

The Flutter application should normally receive application data from the backend, rather than implementing the ML algorithm.

Recommended path:

```text
ESP32
  ↓
MQTT
  ↓
AI Processor
  ↓
FastAPI
  ↓
PostgreSQL
  ↓
Flutter
```

The important processed MQTT topic is:

```text
honeychain/hive/processed
```

The backend can subscribe to this topic, validate the JSON, store readings in PostgreSQL, and expose REST/WebSocket APIs to Flutter.

Flutter can then display:

```text
Hive ID
Status
Risk level
Temperature
Humidity
Weight
Acoustic frequency
Anomaly state
Anomaly score
Alerts
Battery
Wi-Fi signal
```

Example dashboard:

```text
Hive SIH_HIVE_MVP_01

Status: HEALTHY
Risk: LOW

Temperature: 34.2 °C
Humidity:    61.5 %
Weight:       3.25 kg
Acoustic:       245 Hz

Battery:       4.12 V
Wi-Fi:         -68 dBm
```

For an attention result:

```text
Status: ATTENTION
Risk: MEDIUM

Alert:
Multivariate hive telemetry
shows an unusual pattern.
```

## 17. If Flutter Needs Data Before Hardware Exists

The Flutter developer does not have to wait for the ESP32.

Run:

```powershell
python -m ai_ml.mqtt.mqtt_processor
```

then:

```powershell
& "C:\Program Files\Mosquitto\mosquitto_sub.exe" `
-h localhost `
-p 1883 `
-t "honeychain/hive/processed" `
-v
```

and:

```powershell
python -m ai_ml.tests.mqtt_simulator
```

The simulator behaves like an ESP32 publisher.

This lets backend and Flutter development continue without physical hardware.

## 18. Testing One ESP32 Message Manually

Before using physical hardware:

```powershell
& "C:\Program Files\Mosquitto\mosquitto_pub.exe" `
-h localhost `
-p 1883 `
-t "honeychain/hive/telemetry" `
-m '{"device_id":"SIH_HIVE_MVP_01","timestamp":1725879172,"sensors":{"weight_kg":3.25,"temperature_c":34.2,"humidity_pct":61.5,"acoustics_hz":245},"diagnostics":{"battery_v":4.12,"wifi_rssi_dbm":-68}}'
```

It should appear in Terminal 1.

## 19. IoT Developer Configuration Checklist

The IoT developer should configure:

```text
Wi-Fi SSID
Wi-Fi password

MQTT broker IP/hostname
MQTT port

Unique device_id

Input topic:
honeychain/hive/telemetry

Publish interval:
600 seconds / 10 minutes
```

For example:

```text
WIFI_SSID = "MyNetwork"
WIFI_PASSWORD = "MyPassword"

MQTT_HOST = "192.168.1.100"
MQTT_PORT = 1883

DEVICE_ID = "SIH_HIVE_01"

MQTT_TOPIC = "honeychain/hive/telemetry"

PUBLISH_INTERVAL = 600
```

The ESP32 should also implement MQTT/Wi-Fi reconnect handling.

## 20. What the IoT Developer Delivers

The IoT developer is responsible for:

```text
1. Read sensors.
2. Connect ESP32 to Wi-Fi.
3. Connect to MQTT broker.
4. Create the required JSON.
5. Publish to honeychain/hive/telemetry.
6. Repeat every 10 minutes.
7. Reconnect after connection loss.
```

The AI developer does not need to know the ESP32's sensor wiring as long as the JSON contract remains correct.

## 21. What the AI/ML Package Contains

A developer receiving the AI/ML package should expect the following core components:

```text
ai_ml/
|
+-- models/
|   +-- honeychain_isolation_forest.joblib
|   +-- threshold.json
|   +-- metrics.json
|   +-- threshold_tuning.csv
|   +-- test_predictions.csv
|
+-- src/
|   +-- feature_builder.py
|   +-- anomaly_detector.py
|   +-- risk_engine.py
|   +-- output_formatter.py
|
+-- mqtt/
|   +-- mqtt_processor.py
|
+-- tests/
    +-- test_pipeline.py
    +-- mqtt_simulator.py
```

The most important runtime files are:

```text
mqtt/mqtt_processor.py
src/feature_builder.py
src/anomaly_detector.py
src/risk_engine.py
src/output_formatter.py
models/honeychain_isolation_forest.joblib
models/threshold.json
```

## 22. What the Flutter Developer Receives

The Flutter developer does not need the model `.joblib` file.

They need the **application data contract**.

In production, that should normally be provided through FastAPI.

Conceptually:

```text
AI Processor
     ↓
processed JSON
     ↓
FastAPI
     ↓
REST / WebSocket
     ↓
Flutter
```

The Flutter app should not depend on internal Python filenames or model implementation details.

## 23. Troubleshooting

### MQTT connection failed

Check:

```powershell
Test-NetConnection localhost -Port 1883
```

You want:

```text
TcpTestSucceeded : True
```

Make sure Mosquitto is running.

### `mosquitto` command not found

Use:

```powershell
& "C:\Program Files\Mosquitto\mosquitto_pub.exe"
```

and:

```powershell
& "C:\Program Files\Mosquitto\mosquitto_sub.exe"
```

### No processed messages

Check:

1. Mosquitto is running.
2. AI processor is running.
3. Terminal 2 is subscribed to `honeychain/hive/processed`.
4. ESP32/simulator publishes to `honeychain/hive/telemetry`.
5. The processor has enough history.

### No AI result immediately

This can be expected before the history reaches approximately 145 readings.

### ESP32 cannot connect to `localhost`

Do not use `localhost` from a physical ESP32 unless the broker is actually running on the ESP32, which it normally is not.

Use the LAN IP of the computer/server running Mosquitto.

## 24. Synthetic Dataset

The project contains a large synthetic dataset of approximately:

```text
172,800 rows
```

It is used for model development/testing.

The MQTT processor does not need to stream all of those rows.

The simulator intentionally selects only:

```text
300 readings
```

from one hive.

The real ESP32 becomes the live telemetry source.

## 25. Scientific/Production Limitations

The current model was trained and evaluated using synthetic data.

Therefore:

```text
Synthetic anomaly-detection performance
does NOT equal
real-world disease-diagnosis accuracy.
```

HoneyChain should be described as an **early-warning/anomaly detection system**, not as a guaranteed disease diagnostic system.

Important limitations:

- Temperature reference values are operational prototype references.
- Humidity reference values are operational prototype references.
- Weight is interpreted mainly through temporal trends.
- Acoustic Hz is not dB.
- A detected anomaly does not prove a specific disease.
- Real-world deployment should collect real hive telemetry and recalibrate/validate the model.

## 26. Recommended Production Flow

```text
                    ┌───────────────┐
                    │     ESP32     │
                    │               │
                    │ DHT22         │
                    │ Load Cell     │
                    │ INMP441       │
                    └───────┬───────┘
                            |
                       MQTT / JSON
                            |
                            v
                    ┌───────────────┐
                    │ MQTT Broker   │
                    └───────┬───────┘
                            |
                            v
                  ┌─────────────────────┐
                  │ HoneyChain AI/ML    │
                  │                     │
                  │ Feature Builder     │
                  │ Isolation Forest    │
                  │ Risk Engine         │
                  └──────────┬──────────┘
                             |
                       Processed JSON
                             |
                             v
                    ┌───────────────┐
                    │    FastAPI    │
                    └───────┬───────┘
                            |
                   ┌────────┴────────┐
                   v                 v
              PostgreSQL        Flutter App
```

Blockchain and QR traceability are separate HoneyChain modules and do not need to be running for the AI/MQTT telemetry pipeline to operate.

## 27. Quick Start

From the HoneyChain root:

### Terminal 1

```powershell
.\.venv\Scripts\Activate.ps1
python -m ai_ml.mqtt.mqtt_processor
```

### Terminal 2

```powershell
& "C:\Program Files\Mosquitto\mosquitto_sub.exe" -h localhost -p 1883 -t "honeychain/hive/processed" -v
```

### Terminal 3

```powershell
.\.venv\Scripts\Activate.ps1
python -m ai_ml.tests.mqtt_simulator
```

Expected flow:

```text
Simulator
   ↓
honeychain/hive/telemetry
   ↓
AI Processor
   ↓
Isolation Forest + Rules
   ↓
honeychain/hive/processed
   ↓
Backend
   ↓
Flutter
```

## 28. Final Mental Model

### IoT developer

> "I read the sensors and publish correctly formatted JSON to `honeychain/hive/telemetry`."

### AI/ML developer

> "I receive telemetry, maintain history, analyze it and publish processed JSON to `honeychain/hive/processed`."

### Flutter developer

> "I consume the application data from the backend and display the hive state, sensor values, trends and alerts."

As long as these interfaces remain stable, the three teams can develop independently.
