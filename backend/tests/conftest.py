"""Effective safety net for the backend test suite.

The repo-root conftest.py holds the same defaults, but pytest selects
``backend/pytest.ini`` as the ini/rootdir when running ``pytest backend/tests``
(as documented in backend/README.md), so the repo-root conftest sits above
confcutdir and NEVER loads. Without this file the suite silently connects to
the DATABASE_URL from backend/.env — i.e. the real Supabase PostgreSQL —
instead of the isolated SQLite database the documentation promises. That leak
is how test rows ended up in the production database and why the broken
Firebase token verifier (google.auth.jwt.decode(certs_url=...)) was never
caught: failures surfaced against real data instead of the hermetic suite.

A developer can still exercise PostgreSQL explicitly by exporting DATABASE_URL
(and clearing DEV_OFFLINE_SQLITE) before running pytest — this file only
applies *defaults* with setdefault.
"""
from __future__ import annotations

import os
from pathlib import Path


_TEST_DATABASE = Path(__file__).resolve().parents[2] / "backend" / "honeychain-test.db"

os.environ.setdefault("ENV", "test")
os.environ.setdefault("DEV_OFFLINE_SQLITE", "true")
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_TEST_DATABASE.as_posix()}")
