"""
Database configuration for HoneyChain backend using SQLAlchemy.
PostgreSQL is the authoritative production database (e.g. Supabase).
Connection pooling and health monitoring configured per production standards.
"""
from __future__ import annotations

import os
import logging
from pathlib import Path
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

load_dotenv(Path(__file__).resolve().parent / ".env")
logger = logging.getLogger("HoneyChainDB")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/honeychain")
clean_db_url = DATABASE_URL
if "?schema=" in clean_db_url:
    clean_db_url = clean_db_url.split("?schema=")[0]

# Connection pool settings
DB_POOL_SIZE = int(os.getenv("DB_POOL_SIZE", "10"))
DB_MAX_OVERFLOW = int(os.getenv("DB_MAX_OVERFLOW", "20"))
DB_POOL_TIMEOUT = int(os.getenv("DB_POOL_TIMEOUT", "30"))

allow_sqlite = (
    os.getenv("DEV_OFFLINE_SQLITE", "false").lower() in ("true", "1")
    or clean_db_url.startswith("sqlite")
    or os.getenv("ENV") == "test"
)

engine = None
is_postgres = False

try:
    if allow_sqlite:
        sqlite_path = Path(__file__).resolve().parent / "honeychain.db"
        sqlite_url = f"sqlite:///{sqlite_path.as_posix()}"
        engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
        logger.info(f"Connected to local SQLite database: {sqlite_url}")
    elif clean_db_url.startswith("postgres") or clean_db_url.startswith("postgresql"):
        test_engine = create_engine(
            clean_db_url,
            pool_size=DB_POOL_SIZE,
            max_overflow=DB_MAX_OVERFLOW,
            pool_timeout=DB_POOL_TIMEOUT,
            pool_pre_ping=True,
            pool_recycle=1800,
            connect_args={"connect_timeout": 10},
        )
        with test_engine.connect() as conn:
            pass
        engine = test_engine
        is_postgres = True
        logger.info(f"Connected to PostgreSQL database: {clean_db_url.split('@')[-1]}")
    else:
        raise ValueError(f"Unsupported database scheme: {clean_db_url}")
except Exception as e:
    sqlite_path = Path(__file__).resolve().parent / "honeychain.db"
    if sqlite_path.exists() and os.getenv("ENVIRONMENT", "development") != "production":
        logger.warning(f"PostgreSQL connection failed ({e}). Falling back to local SQLite: {sqlite_path}")
        sqlite_url = f"sqlite:///{sqlite_path.as_posix()}"
        engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
        is_postgres = False
    else:
        logger.critical(f"FATAL: Production database connection failed: {e}")
        raise RuntimeError(f"Failed to connect to authoritative PostgreSQL database: {e}") from e

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def check_database_health() -> dict:
    """Return database health status, engine type, and latency."""
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
            "error": str(err),
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
