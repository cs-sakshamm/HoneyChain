"""Safe defaults for HoneyChain's Python test suite.

Tests must never require a developer's production PostgreSQL instance.  A
developer may still explicitly provide DATABASE_URL to exercise Postgres; in
its absence this selects the ignored local SQLite test database before backend
modules are imported.
"""
from __future__ import annotations

import os
from pathlib import Path


_TEST_DATABASE = Path(__file__).resolve().parent / "backend" / "honeychain-test.db"

os.environ.setdefault("ENV", "test")
os.environ.setdefault("DEV_OFFLINE_SQLITE", "true")
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_TEST_DATABASE.as_posix()}")
