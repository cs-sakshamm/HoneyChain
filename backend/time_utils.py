"""Naive-UTC time helpers for the HoneyChain backend.

The project stores all timestamps as *naive* UTC datetimes (a long-standing
convention the database schema and comparisons rely on). Historically the
codebase used ``datetime.utcnow`` — deprecated since Python 3.12 and removed
in later versions — both as direct calls and as SQLAlchemy column defaults.

These helpers produce values identical to ``datetime.utcnow`` /
``datetime.utcfromtimestamp`` while never touching the deprecated APIs:

* the clock is read in UTC explicitly (host-timezone independent);
* ``tzinfo`` is stripped to preserve the naive-UTC storage convention, so
  existing comparisons (e.g. OTP expiry) keep working unchanged.
"""
from __future__ import annotations

from datetime import datetime, timezone


def utcnow_naive() -> datetime:
    """Naive UTC timestamp — drop-in replacement for ``datetime.utcnow()``."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def utcfromtimestamp_naive(ts: float) -> datetime:
    """Naive UTC datetime from an epoch — replacement for the deprecated
    ``datetime.utcfromtimestamp()``."""
    return datetime.fromtimestamp(ts, tz=timezone.utc).replace(tzinfo=None)
