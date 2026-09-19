from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
# This line sets up loggers basically.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

try:
    from backend.models import Base
except ImportError:
    from models import Base

target_metadata = Base.metadata

db_url = (os.getenv("DATABASE_URL") or "").strip()
if "?schema=" in db_url:
    db_url = db_url.split("?schema=")[0]

if not db_url:
    # Same contract as backend/database.py: Supabase PostgreSQL is the
    # authoritative database and there is no silent fallback.
    raise RuntimeError(
        "DATABASE_URL is not configured. Alembic uses the same DATABASE_URL as "
        "FastAPI (backend/.env). Set it to the Supabase PostgreSQL URL, e.g. "
        "DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DB."
    )

# Guard: Alembic must target Supabase, never a localhost Postgres.
from urllib.parse import urlsplit

_host = (urlsplit(db_url).hostname or "").lower()
if db_url.startswith("postgres") and _host in ("localhost", "127.0.0.1", "::1"):
    raise RuntimeError(
        "DATABASE_URL points to a localhost PostgreSQL server, but HoneyChain is "
        "configured for Supabase PostgreSQL. Update DATABASE_URL in backend/.env "
        "to the Supabase host (db.<project-ref>.supabase.co)."
    )

config.set_main_option("sqlalchemy.url", db_url)


def include_object(object, name, type_, reflected, compare_to):
    if type_ == "table" and reflected and name not in target_metadata.tables:
        return False
    return True


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        connect_args={"connect_timeout": 10},
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_object=include_object,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
