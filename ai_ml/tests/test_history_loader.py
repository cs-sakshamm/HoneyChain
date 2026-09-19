from __future__ import annotations

from sqlalchemy import create_engine, text

from ai_ml.src.feature_builder import FeatureBuilder, HISTORY_REQUIRED
from ai_ml.src.history_loader import reload_history


def _create_table(engine) -> None:
    with engine.begin() as connection:
        connection.execute(text("""
            CREATE TABLE hive_telemetry (
                device_id TEXT,
                timestamp INTEGER,
                temperature_c REAL,
                humidity_pct REAL,
                weight_kg REAL,
                acoustics_hz REAL
            )
        """))


def _insert(engine, rows: list[dict]) -> None:
    with engine.begin() as connection:
        connection.execute(
            text("""INSERT INTO hive_telemetry
                (device_id, timestamp, temperature_c, humidity_pct, weight_kg, acoustics_hz)
                VALUES (:device_id, :timestamp, :temperature_c, :humidity_pct, :weight_kg, :acoustics_hz)"""),
            rows,
        )


def _row(device_id: str, timestamp: int, weight: float = 3.25, temperature: float = 34.2) -> dict:
    return {
        "device_id": device_id,
        "timestamp": timestamp,
        "temperature_c": temperature,
        "humidity_pct": 61.5,
        "weight_kg": weight,
        "acoustics_hz": 245.0,
    }


def test_history_reload_restores_complete_temporal_context(tmp_path) -> None:
    database_url = f"sqlite:///{(tmp_path / 'history.db').as_posix()}"
    engine = create_engine(database_url)
    _create_table(engine)
    _insert(
        engine,
        [
            _row("restart-test", 1_700_000_000 + index * 600, weight=3.25 + index * 0.001)
            for index in range(HISTORY_REQUIRED)
        ],
    )

    builder = FeatureBuilder()
    assert reload_history(builder, database_url) == HISTORY_REQUIRED
    assert builder.get_history_size("restart-test") == HISTORY_REQUIRED
    assert builder.build_latest_features("restart-test") is not None


def test_history_reload_is_bounded_per_device_and_read_only(tmp_path) -> None:
    database_url = f"sqlite:///{(tmp_path / 'bounded.db').as_posix()}"
    engine = create_engine(database_url)
    _create_table(engine)
    extra = 12
    rows = [
        _row("device-a", 1_700_000_000 + index * 600, weight=3.0 + index * 0.001)
        for index in range(HISTORY_REQUIRED + extra)
    ]
    rows.extend(_row("device-b", 1_800_000_000 + index * 600) for index in range(5))
    _insert(engine, rows)

    builder = FeatureBuilder()
    loaded = reload_history(builder, database_url)
    assert loaded == HISTORY_REQUIRED + 5
    assert builder.get_history_size("device-a") == HISTORY_REQUIRED
    assert builder.get_history_size("device-b") == 5
    assert builder.build_latest_features("device-a") is not None
    assert builder.build_latest_features("device-b") is None

    with engine.connect() as connection:
        stored = connection.execute(text("SELECT COUNT(*) FROM hive_telemetry")).scalar_one()
    assert stored == HISTORY_REQUIRED + extra + 5


def test_history_reload_skips_malformed_rows(tmp_path) -> None:
    database_url = f"sqlite:///{(tmp_path / 'malformed.db').as_posix()}"
    engine = create_engine(database_url)
    _create_table(engine)
    _insert(
        engine,
        [
            _row("device-ok", 1_700_000_000),
            {
                "device_id": "device-ok",
                "timestamp": 1_700_000_600,
                "temperature_c": None,
                "humidity_pct": 61.5,
                "weight_kg": 3.25,
                "acoustics_hz": 245.0,
            },
        ],
    )

    builder = FeatureBuilder()
    assert reload_history(builder, database_url) == 1
    assert builder.get_history_size("device-ok") == 1


def test_history_reload_fails_open_without_database() -> None:
    builder = FeatureBuilder()
    assert reload_history(builder, "") == 0
    assert reload_history(builder, "postgresql://honeychain:honeychain@127.0.0.1:1/missing") == 0
    assert builder.histories == {}


def test_restart_then_live_reading_keeps_temporal_features(tmp_path) -> None:
    database_url = f"sqlite:///{(tmp_path / 'restart.db').as_posix()}"
    engine = create_engine(database_url)
    _create_table(engine)
    start = 1_700_000_000
    _insert(
        engine,
        [_row("SIH_HIVE_MVP_01", start + index * 600, weight=3.25 + index * 0.001) for index in range(HISTORY_REQUIRED)],
    )

    restarted = FeatureBuilder()
    reload_history(restarted, database_url)
    restarted.add_reading(
        "SIH_HIVE_MVP_01",
        start + HISTORY_REQUIRED * 600,
        {
            "temperature_c": 34.2,
            "humidity_pct": 61.5,
            "weight_kg": 3.25 + HISTORY_REQUIRED * 0.001,
            "acoustics_hz": 245.0,
        },
    )
    features = restarted.build_latest_features("SIH_HIVE_MVP_01")
    assert features is not None
    assert features["weight_delta_24h"] != 0.0
