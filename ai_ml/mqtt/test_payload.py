import json


payload = {
    "device_id": "SIH_HIVE_MVP_01",
    "timestamp": 1725879172,
    "sensors": {
        "weight_kg": 3.25,
        "temperature_c": 34.2,
        "humidity_pct": 61.5,
        "acoustics_hz": 245,
        "co2_ppm": 850
    },
    "diagnostics": {
        "battery_v": 4.12,
        "wifi_rssi_dbm": -68
    }
}


def extract_features(data):

    sensors = data["sensors"]
    diagnostics = data["diagnostics"]

    result = {
        "device_id": data["device_id"],
        "timestamp": data["timestamp"],

        "temperature_c": sensors["temperature_c"],
        "humidity_pct": sensors["humidity_pct"],
        "weight_kg": sensors["weight_kg"],
        "acoustics_hz": sensors["acoustics_hz"],
        "co2_ppm": sensors["co2_ppm"],

        "battery_v": diagnostics["battery_v"],
        "wifi_rssi_dbm": diagnostics["wifi_rssi_dbm"],
    }

    return result


json_string = json.dumps(payload)

received_data = json.loads(json_string)

features = extract_features(received_data)

print("Extracted data:")
print(features)