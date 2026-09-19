// Copy this file to secrets.h before compiling the ESP32 firmware.
// Do not commit secrets.h.

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Use a LAN-reachable broker address for physical hardware, NOT localhost.
// localhost on the ESP32 means the ESP32 itself.
const char* mqtt_server = "192.168.1.100";
const int mqtt_port = 1883;
const char* mqtt_user = "";
const char* mqtt_pass = "";

// Optional: unique per-unit device identifier (SIH_HIVE_01, SIH_HIVE_02, ...).
// Uncomment and set per physical unit; every hive/device must be unique.
// #define DEVICE_ID "SIH_HIVE_01"
