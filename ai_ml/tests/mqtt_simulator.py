"""Fast, configurable ESP32 telemetry simulator for local and LAN demos."""
from __future__ import annotations

import argparse
import json
import time

import paho.mqtt.client as mqtt


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--topic", default="honeychain/hive/telemetry")
    parser.add_argument("--device-id", default="SIH_HIVE_MVP_01")
    parser.add_argument("--count", type=int, default=145)
    parser.add_argument("--interval", type=float, default=0.05)
    parser.add_argument("--scenario", choices=("normal", "attention", "alert", "ml"), default="normal")
    return parser.parse_args()


def readings(args: argparse.Namespace):
    start = int(time.time()) - max(args.count - 1, 0) * 600
    for index in range(args.count):
        temperature, humidity, weight, acoustics = 34.2, 61.5, 3.25 + index * 0.001, 245.0
        if args.scenario == "attention" and index == args.count - 1:
            temperature = 37.0
        elif args.scenario == "alert" and index == args.count - 1:
            temperature, humidity, weight = 38.0, 75.0, 2.80
        elif args.scenario == "ml" and index == args.count - 1:
            temperature, humidity, weight, acoustics = 12.0, 18.0, 0.40, 40.0
        yield {
            "device_id": args.device_id,
            "timestamp": start + index * 600,
            "sensors": {
                "weight_kg": round(weight, 3),
                "temperature_c": temperature,
                "humidity_pct": humidity,
                "acoustics_hz": acoustics,
            },
            "diagnostics": {"battery_v": 4.12, "wifi_rssi_dbm": -68},
        }


def main() -> None:
    args = parse_args()
    if args.count < 1:
        raise SystemExit("--count must be positive")
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.connect(args.host, args.port, 60)
    client.loop_start()
    try:
        for number, payload in enumerate(readings(args), start=1):
            client.publish(args.topic, json.dumps(payload), qos=1).wait_for_publish()
            print(f"[{number}/{args.count}] {payload['device_id']} t={payload['timestamp']} {args.scenario}")
            if args.interval:
                time.sleep(args.interval)
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
