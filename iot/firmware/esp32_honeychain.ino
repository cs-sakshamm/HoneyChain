#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <HX711.h>
#include <ArduinoJson.h>

const char* ssid = "WIFI_SSID";
const char* password = "WIFI_PASSWORD";

const char* mqtt_server = "broker.honeychain.io";
const int mqtt_port = 1883;
const char* mqtt_user = "honeychain_device";
const char* mqtt_pass = "secure_password";

const char* device_id = "HC-ESP32-A1B2C3D4";
const char* hive_id = "HC-HIVE-98765432";
const char* telemetry_topic = "honeychain/hive/telemetry";

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

void setup() {
  Serial.begin(115200);
  dht.begin();
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale(2280.f); 
  scale.tare();

  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  float t = dht.readTemperature();
  float h = dht.readHumidity();
  float w = scale.get_units(10);
  
  if (isnan(t) || isnan(h)) {
    Serial.println("Failed to read from DHT sensor!");
    t = 34.5;
    h = 55.0;
  }

  StaticJsonDocument<256> doc;
  doc["deviceId"] = device_id;
  doc["hiveId"] = hive_id;
  doc["temperature"] = t;
  doc["humidity"] = h;
  doc["weightKg"] = w;
  doc["batteryLevel"] = 4.12;
  doc["signalStrength"] = WiFi.RSSI();
  doc["timestamp"] = 0; // Filled by backend

  char buffer[256];
  serializeJson(doc, buffer);
  
  Serial.print("Publishing message: ");
  Serial.println(buffer);
  client.publish(telemetry_topic, buffer);
  
  delay(600000); // 10 minutes
}
