# HoneyChain — Mosquitto MQTT Message Broker

The `mosquitto` module configures and manages the central publish/subscribe MQTT event broker for HoneyChain. It serves as the asynchronous communication backbone connecting physical hive IoT sensors, the AI/ML anomaly detection processor, and the FastAPI backend service.

---

## 1. Module Overview

* **Broker Software:** Eclipse Mosquitto (v2.0+)
* **Standard Port:** `1883` (TCP / Plaintext for local development and edge telemetry)
* **Configuration File:** `mosquitto.conf`
* **Container Orchestration:** Deployed as the `honeychain-mosquitto` service in `docker-compose.yml`

---

## 2. Directory Structure

```text
mosquitto/
├── mosquitto.conf      # Mosquitto broker configuration (port, listener, authentication)
├── .gitignore          # Ignores persistence DB, broker logs, and TLS credentials
├── README.md           # Broker documentation (this file)
└── REQUIREMENT.txt     # Service and CLI toolchain requirements
```

---

## 3. MQTT Topic Architecture

The HoneyChain ecosystem uses two standardized MQTT topics:

```text
┌─────────────────┐       honeychain/hive/telemetry       ┌──────────────────┐
│   IoT / ESP32   │ ────────────────────────────────────► │  Mosquitto MQTT  │
│  (Edge Sensors) │                                       │      Broker      │
└─────────────────┘                                       └────────┬─────────┘
                                                                   │
                                  ┌────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────┐       honeychain/hive/processed      ┌──────────────────┐
│   AI/ML Engine   │ ────────────────────────────────────►│  Mosquitto MQTT  │
│ (IsolationForest)│                                      │      Broker      │
└──────────────────┘                                      └────────┬─────────┘
                                                                   │
                                                                   ▼
                                                          ┌──────────────────┐
                                                          │  FastAPI Backend │
                                                          │  (MQTT Consumer) │
                                                          └──────────────────┘
```

### Topic 1: Raw Telemetry Stream
* **Topic:** `honeychain/hive/telemetry`
* **Publisher:** ESP32 edge microcontroller or `ai_ml.tests.mqtt_simulator`
* **Subscribers:**
  * `ai_ml.mqtt.mqtt_processor` (computes rolling features and anomaly scores)
  * `backend.services.mqtt_consumer` (persists raw sensor telemetry)
* **Payload Structure:**
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

### Topic 2: Processed AI Telemetry Stream
* **Topic:** `honeychain/hive/processed`
* **Publisher:** `ai_ml.mqtt.mqtt_processor`
* **Subscribers:**
  * `backend.services.mqtt_consumer` (commits AI analysis and triggers WebSocket alerts)
* **Payload Structure:**
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
      "temperature": { "status": "NORMAL", "value": 34.2 },
      "humidity": { "status": "NORMAL", "value": 61.5 },
      "weight": { "status": "STABLE", "trend": "STABLE", "value_kg": 3.25 },
      "acoustics": { "status": "NORMAL", "value_hz": 245 }
    },
    "alerts": [],
    "diagnostics": {
      "battery_v": 4.12,
      "wifi_rssi_dbm": -68
    }
  }
  ```

---

## 4. Configuration Details (`mosquitto.conf`)

The development configuration enables an unauthenticated TCP listener on port 1883:

```text
listener 1883
allow_anonymous true
```

* For production deployments with remote field devices, configure TLS/SSL listeners on port 8883 with certificate verification and username/password access control lists (ACLs).

---

## 5. Running the Broker

### Method 1: Running via Docker Compose (Recommended)

From the project root:

```bash
docker-compose up -d mosquitto
```

To view broker logs:
```bash
docker logs -f honeychain-mosquitto
```

### Method 2: Running Locally on Windows / Linux

If Mosquitto is installed directly on the host machine:

```powershell
# Windows (PowerShell)
& "C:\Program Files\Mosquitto\mosquitto.exe" -c mosquitto\mosquitto.conf -v

# Linux / macOS
mosquitto -c mosquitto/mosquitto.conf -v
```

---

## 6. Testing & Debugging with Mosquitto CLI

### 1. Check Broker Connectivity
```powershell
Test-NetConnection localhost -Port 1883
```

### 2. Subscribe to All HoneyChain Topics
```bash
mosquitto_sub -h localhost -p 1883 -t "honeychain/#" -v
```

### 3. Publish a Test Sensor Reading
```bash
mosquitto_pub -h localhost -p 1883 -t "honeychain/hive/telemetry" -m '{"device_id":"SIH_HIVE_MVP_01","timestamp":1725879172,"sensors":{"weight_kg":3.25,"temperature_c":34.2,"humidity_pct":61.5,"acoustics_hz":245},"diagnostics":{"battery_v":4.12,"wifi_rssi_dbm":-68}}'
```
