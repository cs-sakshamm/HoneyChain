"""Reload bounded telemetry history into the AI feature cache at startup."""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from sqlalchemy import create_engine, text

from .feature_builder import HISTORY_REQUIRED

if TYPE_CHECKING:
    from .feature_builder import FeatureBuilder

logger = logging.getLogger("HoneyChainAIHistory")

_SENSOR_FIELDS = (
    "temperature_c",
    "humidity_pct",
    "weight_kg",
    "acoustics_hz",
)


def _bounded_limit(limit: int) -> int:
    try:
        parsed = int(limit)
    except (TypeError, ValueError):
        return HISTORY_REQUIRED
    return max(1, min(parsed, HISTORY_REQUIRED))


def reload_history(feature_builder: "FeatureBuilder", database_url: str, limit: int = HISTORY_REQUIRED) -> int:
    """Load the newest bounded history for every known device.

    The window-function query is read-only and works with PostgreSQL and the
    SQLite development database. An unavailable database is non-fatal: the
    long-running processor continues collecting fresh MQTT readings.
    """
    if not database_url:
        logger.info("No DATABASE_URL configured; AI history starts empty.")
        return 0

    bound = _bounded_limit(limit)
    engine = None
    try:
        engine_kwargs = {"pool_pre_ping": True}
        if database_url.startswith("postgres"):
            engine_kwargs["pool_size"] = 1
            engine_kwargs["max_overflow"] = 0
            engine_kwargs["connect_args"] = {"connect_timeout": 5}
        engine = create_engine(database_url, **engine_kwargs)
        statement = text("""
            SELECT device_id, timestamp, temperature_c, humidity_pct, weight_kg, acoustics_hz
            FROM (
                SELECT device_id, timestamp, temperature_c, humidity_pct, weight_kg, acoustics_hz,
                       ROW_NUMBER() OVER (PARTITION BY device_id ORDER BY timestamp DESC) AS history_rank
                FROM hive_telemetry
                WHERE device_id IS NOT NULL AND timestamp IS NOT NULL
            ) recent
            WHERE history_rank <= :limit
            ORDER BY device_id, timestamp
        """)
        loaded = 0
        skipped = 0
        with engine.connect() as connection:
            rows = connection.execute(statement, {"limit": bound}).mappings()
            for row in rows:
                try:
                    sensors = {field: row[field] for field in _SENSOR_FIELDS}
                    if any(value is None for value in sensors.values()):
                        raise ValueError("sensor field is null")
                    feature_builder.add_reading(
                        device_id=str(row["device_id"]),
                        timestamp=int(row["timestamp"]),
                        sensors=sensors,
                    )
                    loaded += 1
                except (TypeError, ValueError, KeyError) as exc:
                    skipped += 1
                    logger.warning("Skipping malformed telemetry history row: %s", exc)
        logger.info("Reloaded %s telemetry readings into AI history.", loaded)
        if skipped:
            logger.warning("Skipped %s malformed telemetry history rows.", skipped)
        return loaded
    except Exception as exc:
        logger.warning("Could not reload AI history from the database: %s", exc)
        return 0
    finally:
        if engine is not None:
            engine.dispose()
