"""
Database configuration for HoneyChain backend using SQLAlchemy.
Connects to PostgreSQL as primary source of truth, with seamless fallback for offline/local environments.
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

# Try PostgreSQL first; if it fails to connect, fallback to SQLite
engine = None
try:
    if clean_db_url.startswith("postgres"):
        test_engine = create_engine(clean_db_url, pool_pre_ping=True)
        with test_engine.connect() as conn:
            pass
        engine = test_engine
        logger.info(f"Connected to PostgreSQL database: {clean_db_url.split('@')[-1]}")
    else:
        engine = create_engine(clean_db_url)
except Exception as e:
    sqlite_path = Path(__file__).resolve().parent / "honeychain.db"
    sqlite_url = f"sqlite:///{sqlite_path.as_posix()}"
    logger.warning(f"PostgreSQL connection failed ({e}). Falling back to local SQLite: {sqlite_url}")
    engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    import backend.models  # noqa
    Base.metadata.create_all(bind=engine)

    # Automatically add any missing columns for backwards compatibility
    with engine.connect() as conn:
        from sqlalchemy import inspect, text
        inspector = inspect(engine)
        for table_name in Base.metadata.tables.keys():
            if inspector.has_table(table_name):
                existing_cols = {c["name"] for c in inspector.get_columns(table_name)}
                table_obj = Base.metadata.tables[table_name]
                for col in table_obj.columns:
                    if col.name not in existing_cols:
                        col_type = col.type.compile(engine.dialect)
                        try:
                            conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {col.name} {col_type}"))
                            conn.commit()
                            logger.info(f"Added missing column '{col.name}' ({col_type}) to table '{table_name}'.")
                        except Exception as err:
                            logger.warning(f"Could not add column {col.name} to {table_name}: {err}")

    logger.info("Database tables initialized successfully.")
