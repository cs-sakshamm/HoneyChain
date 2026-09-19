"""
Database configuration for HoneyChain backend using SQLAlchemy.

PostgreSQL (Supabase) is the authoritative database. The connection URL is
taken exclusively from the environment:

    DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DB

Security rules enforced here:
- No hardcoded credentials, hosts or fallback URLs.
- Explicit localhost/127.0.0.1 guard: Supabase is the configured authority and
  a localhost URL in configuration is treated as a configuration error (this
  is what previously caused "password authentication failed for user
  postgres" against a local Postgres).
- No silent SQLite fallback: if PostgreSQL is configured and unreachable, a
  clear error is raised so the real problem gets fixed. SQLite is used ONLY
  when explicitly requested (DEV_OFFLINE_SQLITE=true, or a sqlite:// URL, or
  ENV=test), which keeps unit tests hermetic without ever hijacking a
  production run.
- Credentials never appear in logs or error messages (URLs are sanitized
  before logging; DB driver errors are masked).
"""
from __future__ import annotations

import logging
import os
import re
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

try:
    from .db_base import Base
except ImportError:  # direct-module import (backend/ itself on sys.path)
    from db_base import Base

# Load backend/.env BEFORE any database configuration is evaluated.
load_dotenv(Path(__file__).resolve().parent / ".env")

logger = logging.getLogger("HoneyChainDB")


def _sanitize_db_url(url: str) -> str:
    """Return a log-safe representation of a database URL (no password)."""
    try:
        from urllib.parse import urlsplit, urlunsplit

        parts = urlsplit(url)
        if parts.password is None:
            return url
        host_part = parts.hostname or ""
        if parts.port:
            host_part = f"{host_part}:{parts.port}"
        creds = parts.username or ""
        if creds:
            creds += ":***REDACTED***"
        return urlunsplit((parts.scheme, f"{creds}@{host_part}", parts.path, "", ""))
    except Exception:
        return "<unparseable-database-url>"


def _mask_driver_error(err: Exception) -> str:
    """Strip any credential-looking substrings from a driver error message."""
    text = str(err)
    # Redact URL-style credentials (user:pass@host) wherever they appear.
    text = re.sub(r"://[^@/\s]+:[^@/\s]+@", "://***:***REDACTED***@", text)
    # Redact obvious password assignments (e.g. password=...).
    text = re.sub(r"(password[=:]\s*)\S+", r"\1***REDACTED***", text, flags=re.IGNORECASE)
    return text


DATABASE_URL = (os.getenv("DATABASE_URL") or "").strip()
clean_db_url = DATABASE_URL
if "?schema=" in clean_db_url:
    clean_db_url = clean_db_url.split("?schema=")[0]

is_postgres = False
engine = None

# Connection pool settings (kept from the previous configuration).
DB_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
DB_MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))
DB_POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))

# SQLite is valid ONLY when explicitly requested (tests / offline dev).
_sqlite_requested = (
    os.getenv("DEV_OFFLINE_SQLITE", "false").lower() in ("true", "1", "yes")
    or os.getenv("ENV", "").lower() == "test"
    or clean_db_url.startswith("sqlite")
)

if _sqlite_requested:
    sqlite_path = Path(__file__).resolve().parent / "honeychain.db"
    sqlite_url = f"sqlite:///{sqlite_path.as_posix()}"
    engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
    is_postgres = False
    logger.info("SQLite mode (explicitly requested): %s", sqlite_url)
elif not DATABASE_URL:
    # No silent fallback: make the missing configuration impossible to miss.
    raise RuntimeError(
        "DATABASE_URL is not configured. HoneyChain uses Supabase PostgreSQL as "
        "its authoritative database. Set DATABASE_URL in backend/.env, e.g. "
        "DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DB (do not commit the "
        "password; see backend/.env.example)."
    )
elif clean_db_url.startswith("postgres"):
    # Explicit guard: Supabase is authoritative, so a localhost database URL is
    # a configuration mistake (this is what previously caused the localhost
    # "password authentication failed" error).
    from urllib.parse import urlsplit

    _host = (urlsplit(clean_db_url).hostname or "").lower()
    if _host in ("localhost", "127.0.0.1", "::1"):
        raise RuntimeError(
            "DATABASE_URL points to a localhost PostgreSQL server, but HoneyChain "
            "is configured for Supabase PostgreSQL. Update DATABASE_URL in "
            "backend/.env to the Supabase host (db.<project-ref>.supabase.co). "
            "If you need a temporary offline database for tests, run with "
            "ENV=test or DEV_OFFLINE_SQLITE=true instead."
        )

    try:
        engine = create_engine(
            clean_db_url,
            pool_size=DB_POOL_SIZE,
            max_overflow=DB_MAX_OVERFLOW,
            pool_timeout=DB_POOL_TIMEOUT,
            pool_pre_ping=True,
            pool_recycle=1800,
            connect_args={"connect_timeout": 10},
        )
        with engine.connect() as conn:
            pass
        is_postgres = True
        # Log only a sanitized URL — never credentials.
        logger.info(
            "Connected to PostgreSQL database at %s",
            _sanitize_db_url(clean_db_url),
        )
    except Exception as e:  # noqa: BLE001 - surface a sanitized, actionable error
        logger.critical("FATAL: Could not connect to the configured PostgreSQL database.")
        logger.critical("  Target : %s", _sanitize_db_url(clean_db_url))
        logger.critical("  Cause  : %s", _mask_driver_error(e))
        raise RuntimeError(
            "Could not connect to the configured PostgreSQL database "
            f"({_sanitize_db_url(clean_db_url)}). SQLite fallback is disabled; fix "
            "the PostgreSQL connection (verify DATABASE_URL in backend/.env, the "
            "database password, SSL requirements and network access to the "
            "Supabase host) and restart. Driver detail: "
            f"{_mask_driver_error(e)}"
        ) from e
else:
    raise RuntimeError(
        "Unsupported DATABASE_URL scheme. HoneyChain expects a postgresql:// URL "
        "(Supabase PostgreSQL), or an explicit sqlite:// URL only for tests."
    )


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
# Base is defined once in backend/db_base.py and shared with alembic, so there
# is exactly one declarative registry and one database configuration.


def check_database_health() -> dict:
    """Return database health status, engine type, and latency (no secrets)."""
    try:
        with engine.connect() as conn:
            from sqlalchemy import text
            import time

            start = time.time()
            conn.execute(text("SELECT 1"))
            latency_ms = round((time.time() - start) * 1000, 2)
            return {
                "status": "HEALTHY",
                "engine": "postgresql" if is_postgres else "sqlite",
                "databaseUrlConfigured": bool(DATABASE_URL),
                "isCloudPostgres": is_postgres,
                "latencyMs": latency_ms,
            }
    except Exception as err:
        return {
            "status": "UNHEALTHY",
            "engine": "postgresql" if is_postgres else "sqlite",
            "error": _mask_driver_error(err),
        }


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    try:
        from . import models  # noqa
    except ImportError:
        try:
            import backend.models  # noqa
        except ImportError:
            import models  # noqa
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables initialized successfully.")
