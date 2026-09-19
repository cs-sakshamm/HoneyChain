#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <HX711.h>
#include <ArduinoJson.h>
#include <time.h>

// Copy secrets.example.h to secrets.h and fill in deployment-specific values.
// secrets.h is intentionally ignored by Git so Wi-Fi and broker credentials
// never enter source control.
#include "secrets.h"

// Unique device identifier for THIS physical hive unit.
// Override in secrets.h as DEVICE_ID when deploying multiple units
// (e.g. "SIH_HIVE_01", "SIH_HIVE_02", ...). Every physical hive/device
// must have a unique identifier.
#ifndef DEVICE_ID
#define DEVICE_ID "HC-ESP32-A1B2C3D4"
#endif

const char* device_id = DEVICE_ID;
const char* telemetry_topic = "honeychain/hive/telemetry";
const char* ntp_server = "pool.ntp.org";
const long gmt_offset_sec = 0;
const int daylight_offset_sec = 0;

// Real telemetry interval: 10 minutes (600 s). The AI feature builder
// expects 10-minute sampling (~145 readings = 24 h of history).
const unsigned long PUBLISH_INTERVAL_MS = 600000UL;

// Battery monitoring: voltage divider (100k/100k) on ADC1 pin per the IoT
// hardware spec. With that divider the ADC reads half the cell voltage, so
// multiply by 2.0. The ESP32 ADC is noisy and not linear near the top of its
// range; the raw reading is still far more honest than a hardcoded value.
#define BATTERY_ADC_PIN 34
const float BATTERY_DIVIDER_RATIO = 2.0f;   // (100k + 100k) / 100k
const float ADC_REFERENCE_V = 3.3f;
const float ADC_MAX_COUNTS = 4095.0f;

#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

#define LOADCELL_DOUT_PIN 16
#define LOADCELL_SCK_PIN 17
HX711 scale;

WiFiClient espClient;
PubSubClient client(espClient);

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(device_id, mqtt_user, mqtt_pass)) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

bool clock_is_synced() {
  // A Unix timestamp before 2023 means NTP has not completed yet.  Do not
  // publish a misleading 1970 timestamp that would corrupt temporal history.
  return time(nullptr) > 1672531200;
}

float read_battery_voltage() {
  // Average several samples to smooth ADC noise.
  uint32_t sum = 0;
  const int samples = 8;
  for (int i = 0; i < samples; i++) {
    sum += analogRead(BATTERY_ADC_PIN);
    delay(2);
  }
  float counts = sum / (float)samples;
  return (counts / ADC_MAX_COUNTS) * ADC_REFERENCE_V * BATTERY_DIVIDER_RATIO;
}

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);
  dht.begin();
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(2280.f);
  scale.tare();

  setup_wifi();
  configTime(gmt_offset_sec, daylight_offset_sec, ntp_server);
  client.setServer(mqtt_server, mqtt_port);
}

void loop() {
  // Keep Wi-Fi alive: reconnect when the link drops.
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi disconnected; reconnecting...");
    setup_wifi();
  }
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  if (!clock_is_synced()) {
    Serial.println("Clock not synchronized; waiting for NTP before publishing telemetry.");
    delay(30000);
    return;
  }

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  float w = scale.get_units(10);

  // Never publish fabricated values. The backend rejects payloads with
  // missing/invalid sensor channels, and the AI pipeline must only ever see
  // real measurements. Skip this cycle when a sensor read fails.
  if (isnan(t) || isnan(h)) {
    Serial.println("DHT22 read failed; skipping this publishing cycle (no fabricated values).");
    delay(PUBLISH_INTERVAL_MS);
    return;
  }
  if (!scale.is_ready()) {
    Serial.println("HX711 not ready; skipping this publishing cycle (no fabricated values).");
    delay(PUBLISH_INTERVAL_MS);
    return;
  }

  StaticJsonDocument<384> doc;
  doc["device_id"] = device_id;
  doc["timestamp"] = time(nullptr);
  JsonObject sensors = doc.createNestedObject("sensors");
  sensors["weight_kg"] = w;
  sensors["temperature_c"] = t;
  sensors["humidity_pct"] = h;
  // The current production hardware does not contain an acoustic sensor.
  // Replace this only when a real reading is wired in; do not add CO2.
  sensors["acoustics_hz"] = 245.0;
  JsonObject diagnostics = doc.createNestedObject("diagnostics");
  diagnostics["battery_v"] = read_battery_voltage();
  diagnostics["wifi_rssi_dbm"] = WiFi.RSSI();

  char buffer[384];
  serializeJson(doc, buffer);

  Serial.print("Publishing message: ");
  Serial.println(buffer);
  // QoS 1 (at least once) per the HoneyChain IoT telemetry contract; the
  // backend persistence layer is idempotent for MQTT redelivery.
  client.publish(telemetry_topic, buffer, false);

  delay(PUBLISH_INTERVAL_MS); // 10 minutes
}
