"""Shared SQLAlchemy declarative base for HoneyChain.

Lives in its own tiny module so that importing the ORM models (e.g. from
alembic/env.py) never triggers backend.database's engine/connection setup.
There is still exactly one Base registry and one database configuration.
"""
from __future__ import annotations

from sqlalchemy.orm import declarative_base

Base = declarative_base()
