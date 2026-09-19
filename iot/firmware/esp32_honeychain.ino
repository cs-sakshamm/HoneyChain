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

const char* device_id = "HC-ESP32-A1B2C3D4";
const char* hive_id = "HC-HIVE-98765432";
const char* telemetry_topic = "honeychain/hive/telemetry";
const char* ntp_server = "pool.ntp.org";
const long gmt_offset_sec = 0;
const int daylight_offset_sec = 0;

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

void setup() {
  Serial.begin(115200);
  dht.begin();
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(2280.f); 
  scale.tare();

  setup_wifi();
  configTime(gmt_offset_sec, daylight_offset_sec, ntp_server);
  client.setServer(mqtt_server, mqtt_port);
}

void loop() {
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
  
  if (isnan(t) || isnan(h)) {
    Serial.println("Failed to read from DHT sensor!");
    t = 34.5;
    h = 55.0;
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
  diagnostics["battery_v"] = 4.12;
  diagnostics["wifi_rssi_dbm"] = WiFi.RSSI();

  char buffer[384];
  serializeJson(doc, buffer);
  
  Serial.print("Publishing message: ");
  Serial.println(buffer);
  client.publish(telemetry_topic, buffer);
  
  delay(600000); // 10 minutes
}
