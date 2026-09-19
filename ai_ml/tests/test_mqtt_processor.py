from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import Mock

from ai_ml.mqtt import mqtt_processor
from ai_ml.src.feature_builder import FeatureBuilder


def _sensors(weight: float = 3.25) -> dict[str, float]:
    return {
        "temperature_c": 34.2,
        "humidity_pct": 61.5,
        "weight_kg": weight,
        "acoustics_hz": 245.0,
    }


def test_feature_history_ignores_qos_redelivery() -> None:
    builder = FeatureBuilder()
    builder.add_reading("device-1", 1_700_000_000, _sensors())
    builder.add_reading("device-1", 1_700_000_000, _sensors(weight=3.5))

    assert builder.get_history_size("device-1") == 1
    assert builder.histories["device-1"].data[0]["weight_kg"] == 3.5


def test_malformed_or_incomplete_mqtt_payload_does_not_escape_callback(monkeypatch) -> None:
    add_reading = Mock()
    monkeypatch.setattr(mqtt_processor.feature_builder, "add_reading", add_reading)

    mqtt_processor.on_message(None, None, SimpleNamespace(payload=b"not-json"))
    mqtt_processor.on_message(
        None,
        None,
        SimpleNamespace(payload=b'{"device_id":"device-1","timestamp":1,"sensors":{"temperature_c":34}}'),
    )

    add_reading.assert_not_called()


def test_mqtt_client_has_callbacks_and_reconnect_enabled() -> None:
    client = Mock()
    mqtt_processor.run_client_once(client)

    client.connect.assert_called_once_with(mqtt_processor.MQTT_BROKER, mqtt_processor.MQTT_PORT, 60)
    client.loop_forever.assert_called_once_with(retry_first_connection=True)

    configured = mqtt_processor.build_client()
    assert configured.on_connect is mqtt_processor.on_connect
    assert configured.on_disconnect is mqtt_processor.on_disconnect
    assert configured.on_message is mqtt_processor.on_message


def test_connect_callback_subscribes_to_telemetry_topic() -> None:
    client = Mock()
    mqtt_processor.on_connect(client, None, None, 0)

    client.subscribe.assert_called_once_with(mqtt_processor.MQTT_INPUT_TOPIC)


def test_simulator_canonical_payload_and_scenarios() -> None:
    from argparse import Namespace

    from ai_ml.tests.mqtt_simulator import readings

    args = Namespace(count=2, device_id="SIH_HIVE_MVP_01", scenario="ml")
    packets = list(readings(args))
    assert packets[0]["device_id"] == "SIH_HIVE_MVP_01"
    assert set(packets[0]["sensors"]) == {"weight_kg", "temperature_c", "humidity_pct", "acoustics_hz"}
    assert packets[-1]["sensors"]["temperature_c"] == 12.0
