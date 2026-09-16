# HoneyChain — IoT Edge Telemetry & Hardware Specification

The `iot` module specifies the firmware architecture, sensor wiring, and communication protocol for edge monitoring nodes deployed within HoneyChain apiaries. Each node is powered by an ESP32 microcontroller that periodically measures environmental and colony metrics and publishes them to the HoneyChain MQTT message broker.

---

## 1. Hardware Architecture

Each smart hive monitoring unit includes:

* **Microcontroller:** Espressif ESP32-WROOM-32 (2.4 GHz Wi-Fi + Bluetooth, 32-bit dual-core CPU).
* **Temperature & Humidity Sensor:** DHT22 (AM2302) placed inside the hive brood chamber.
* **Weight Monitoring Scale:** 4-wire strain gauge load cell with an HX711 24-bit precision ADC module placed underneath the hive base.
* **Colony Acoustic Sensor:** INMP441 I2S digital MEMS microphone recording hive frequency characteristics (Hz) for swarming and colony activity detection.
* **Power Source:** 3.7V 18650 rechargeable Li-ion cell connected via a TP4056 charging module with deep-sleep power management.

---

## 2. Sensor Pinout Reference

| Sensor / Module | ESP32 Pin | Signal Type | Description |
| :--- | :--- | :--- | :--- |
| **DHT22 Data** | `GPIO 4` | Digital 1-Wire | Brood chamber temperature (°C) and humidity (%) |
| **HX711 DOUT** | `GPIO 18` | Digital Serial | 24-bit ADC weight data output |
| **HX711 SCK** | `GPIO 19` | Clock | ADC clock signal |
| **INMP441 SD** | `GPIO 22` | I2S Serial Data | Acoustic frequency audio stream |
| **INMP441 WS** | `GPIO 25` | I2S Word Select| Left/Right audio channel select |
| **INMP441 SCK** | `GPIO 26` | I2S Bit Clock | Serial bit clock |
| **Battery ADC** | `GPIO 34` | Analog (ADC1) | Voltage divider (100kΩ / 100kΩ) measuring battery voltage |

---

## 3. Telemetry Data Contract

The ESP32 firmware formats sensor readings into the following JSON payload and publishes to MQTT:

* **MQTT Topic:** `honeychain/hive/telemetry`
* **QoS Level:** `1` (At least once delivery)
* **Production Interval:** Every 10 minutes (600 seconds)

### JSON Payload Schema

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

### Field Definitions

* `device_id` *(string, required)*: Globally unique identifier for the physical hive monitoring unit (e.g., `SIH_HIVE_MVP_01`).
* `timestamp` *(integer, required)*: Current Unix epoch timestamp in seconds.
* `sensors.weight_kg` *(float, required)*: Gross weight of the hive in kilograms.
* `sensors.temperature_c` *(float, required)*: Brood temperature in degrees Celsius (normal range: 30°C–36°C).
* `sensors.humidity_pct` *(float, required)*: Relative humidity inside the hive (normal range: 50%–70%).
* `sensors.acoustics_hz` *(integer, required)*: Dominant colony acoustic frequency in Hertz.
* `diagnostics.battery_v` *(float, optional)*: Current battery voltage (typically 3.5V to 4.2V).
* `diagnostics.wifi_rssi_dbm` *(integer, optional)*: Wi-Fi signal strength in dBm.

---

## 4. Firmware Configuration Checklist

When configuring or flashing an ESP32 device, specify the following parameters:

```cpp
// Wi-Fi Configuration
const char* WIFI_SSID     = "Apiary_Field_Network";
const char* WIFI_PASSWORD = "SecretPassword123";

// MQTT Broker Configuration
// NOTE: Set to the LAN IP of the computer/server running Mosquitto (NOT localhost)
const char* MQTT_HOST     = "192.168.1.100";
const int   MQTT_PORT     = 1883;

// Device & Topic Identifiers
const char* DEVICE_ID     = "SIH_HIVE_MVP_01";
const char* TELEMETRY_TOPIC = "honeychain/hive/telemetry";

// Transmission Interval (600 seconds = 10 minutes)
const unsigned long PUBLISH_INTERVAL_MS = 600000;
```

---

## 5. Testing & Verification

### Testing via Mosquitto CLI

To verify broker connectivity and publish a mock sensor packet from the command line:

```bash
# On Linux / macOS or Windows Mosquitto CLI:
mosquitto_pub -h localhost -p 1883 -t "honeychain/hive/telemetry" -m '{"device_id":"SIH_HIVE_MVP_01","timestamp":1725879172,"sensors":{"weight_kg":3.25,"temperature_c":34.2,"humidity_pct":61.5,"acoustics_hz":245},"diagnostics":{"battery_v":4.12,"wifi_rssi_dbm":-68}}'
```

### Testing Without Hardware (Using the Simulator)

If physical ESP32 nodes are unavailable, run the pre-built telemetry simulator:

```bash
python -m ai_ml.tests.mqtt_simulator
```

The simulator pulls actual historical readings from `ai_ml/data/` and streams ESP32-compliant JSON messages to Mosquitto every second.
