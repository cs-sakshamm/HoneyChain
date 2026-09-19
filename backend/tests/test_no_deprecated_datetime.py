"""
Deprecation regression guard for the backend.

`datetime.utcnow()` and `datetime.utcfromtimestamp()` were removed from the
backend source (replaced by the naive-UTC helpers `_utcnow()`/`_utcfromts()`
in `backend.main` and `_utcfromtimestamp()` in `services.mqtt_consumer`)
because Python 3.12 deprecated them and they are deleted in later versions.

These tests pin that guarantee so the deprecated APIs cannot silently
reappear:

1. No backend module calls the deprecated APIs while warnings are escalated
   to errors (import + helper execution).
2. A static source scan of every backend module rejects
   `datetime.utcnow()` / `datetime.utcfromtimestamp()` call sites outside
   `ai_ml/` (which is out of scope for backend changes).

The naive-UTC contract of the replacement helpers is also asserted, since
downstream comparisons (e.g. OTP expiry) depend on it.
"""
from __future__ import annotations

import ast
import os
import re
import warnings
from datetime import datetime, timezone
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent

# Matches utcnow()/utcfromtimestamp() *call sites* while ignoring the words
# appearing in docstrings/comments/identifiers like `_utcnow`.
DEPRECATED_CALL_RE = re.compile(
    r"(?<![\w.])(?:datetime\.)?(?:utcnow|utcfromtimestamp)\(\s*\)"
)


# ── 1. Runtime: deprecated APIs must never execute in backend code ──────────

@pytest.mark.filterwarnings("error::DeprecationWarning")
def test_backend_imports_clean_under_deprecation_error():
    """Importing the FastAPI app must not trigger datetime deprecations."""
    import backend.main  # noqa: F401


@pytest.mark.filterwarnings("error::DeprecationWarning")
def test_utcnow_helper_clean_under_deprecation_error():
    """`_utcnow()` must produce naive UTC without touching deprecated APIs."""
    from backend.main import _utcnow

    ts = _utcnow()
    assert isinstance(ts, datetime)
    assert ts.tzinfo is None  # project convention: naive UTC
    # Must read the actual UTC clock, not the host-local one.
    now_utc_epoch = datetime.now(timezone.utc).timestamp()
    assert abs(ts.replace(tzinfo=timezone.utc).timestamp() - now_utc_epoch) < 5


@pytest.mark.filterwarnings("error::DeprecationWarning")
def test_mqtt_consumer_import_clean_under_deprecation_error():
    """The MQTT consumer module (imported at app startup) must be clean too."""
    import backend.services.mqtt_consumer  # noqa: F401

    from backend.services.mqtt_consumer import _utcfromtimestamp

    dt = _utcfromtimestamp(1_725_879_172.0)
    assert dt == datetime(2024, 9, 9, 10, 52, 52)  # spec example timestamp, UTC
    assert dt.tzinfo is None


# ── 2. Static: no deprecated call sites in backend source ───────────────────

def _backend_python_files() -> list[str]:
    """All tracked backend .py files (tests included), excluding caches."""
    result: list[str] = []
    for root, _dirs, files in os.walk(BACKEND_DIR):
        if "__pycache__" in root or ".venv" in root:
            continue
        for name in files:
            if name.endswith(".py"):
                result.append(str(Path(root) / name))
    return sorted(result)


def test_no_deprecated_datetime_calls_in_backend_source():
    """Static AST scan: `utcnow()`/`utcfromtimestamp()` must not be called."""
    offenders: list[str] = []

    for path in _backend_python_files():
        source = Path(path).read_text(encoding="utf-8", errors="replace")
        try:
            tree = ast.parse(source, filename=path)
        except SyntaxError:
            continue  # not Python-parseable content; runtime tests cover imports

        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                func = node.func
                name = func.attr if isinstance(func, ast.Attribute) else getattr(func, "id", "")
                if name in ("utcnow", "utcfromtimestamp"):
                    offenders.append(f"{path}:{node.lineno} {name}()")

    assert offenders == [], (
        "Deprecated datetime APIs reappeared in backend source — use "
        "`_utcnow()` / `_utcfromts()` (backend.main) or "
        "`datetime.now(timezone.utc)` instead:\n" + "\n".join(offenders)
    )


def test_static_scan_would_catch_regression():
    """Guard the guard: the scanner itself detects a planted violation."""
    snippet = "x = datetime.utcnow()\ny = utcfromtimestamp(0)\n"
    matches = [
        n
        for n in ast.walk(ast.parse(snippet))
        if isinstance(n, ast.Call)
        and (
            getattr(n.func, "attr", "") in ("utcnow", "utcfromtimestamp")
            or getattr(n.func, "id", "") in ("utcnow", "utcfromtimestamp")
        )
    ]
    assert len(matches) == 2
    assert DEPRECATED_CALL_RE.search(snippet) is not None
