from __future__ import annotations


def build_app_json(
    device_id: str,
    timestamp: int,
    sensors: dict,
    diagnostics: dict,
    ml_result: dict,
    risk_result: dict,
) -> dict:

    return {
        "device_id": device_id,
        "timestamp": timestamp,

        "hive_status": {
            "risk_level": risk_result["risk_level"],
            "status": risk_result["status"],
            "anomaly_detected": ml_result["anomaly_detected"],
            "anomaly_score": ml_result["anomaly_score"],
        },

        "sensors": {
            "temperature_c": sensors["temperature_c"],
            "humidity_pct": sensors["humidity_pct"],
            "weight_kg": sensors["weight_kg"],
            "acoustics_hz": sensors["acoustics_hz"],
        },

        "analysis": {
            "temperature": {
                "status": risk_result["temperature_status"],
                "value": sensors["temperature_c"],
                "reference_range": {
                    "min": 30.0,
                    "max": 36.0,
                },
            },

            "humidity": {
                "status": risk_result["humidity_status"],
                "value": sensors["humidity_pct"],
                "reference_range": {
                    "min": 50.0,
                    "max": 70.0,
                },
            },

            "weight": {
                "status": risk_result["weight_status"],
                "trend": risk_result["weight_trend"],
                "value_kg": sensors["weight_kg"],
            },

            "acoustics": {
                "status": risk_result["acoustics_status"],
                "value_hz": sensors["acoustics_hz"],
            },
        },

        "alerts": risk_result["alerts"],

        "analysis_summary": {
            "reasons": risk_result["reasons"],
        },

        "diagnostics": {
            "battery_v": diagnostics.get("battery_v"),
            "wifi_rssi_dbm": diagnostics.get("wifi_rssi_dbm"),
        },
    }