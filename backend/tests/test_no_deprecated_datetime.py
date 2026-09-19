"""
Deprecation regression guard for the backend.

`datetime.utcnow` / `datetime.utcfromtimestamp` were removed from the
backend source (replaced by the shared naive-UTC helpers in
`backend.time_utils`) because Python 3.12 deprecated them and they are
deleted in later versions.

These tests pin that guarantee so the deprecated APIs cannot silently
reappear, in EITHER form:

* direct calls — ``datetime.utcnow()`` or a bare ``utcnow()`` name call;
* **callable references** — ``Column(DateTime, default=datetime.utcnow)``
  (no parentheses), which execute the deprecated API on every row insert
  and are invisible to a call-only scan.

1. Runtime: importing the backend under ``DeprecationWarning -> error``
   must stay clean, and the replacement helpers must keep their
   naive-UTC contract (downstream comparisons, e.g. OTP expiry, rely on
   it).
2. Static: an AST scan of every backend source file rejects both forms.
   A meta-test proves the scanner catches planted violations so it
   cannot rot into a no-op.

`ai_ml/` is intentionally out of scope (read-only by project rule).
"""
from __future__ import annotations

import ast
import os
import re
from datetime import datetime, timezone
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent

DEPRECATED_NAMES = ("utcnow", "utcfromtimestamp")

# Regex companion for quick greps of actual call sites.
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


# ── 2. Static: no deprecated calls OR references in backend source ─────────

def _deprecated_datetime_nodes(tree: ast.AST) -> list[tuple[int, str]]:
    """Find deprecated datetime usage in both dangerous forms.

    Returns (lineno, label) pairs where label is ``datetime.utcnow``-style
    for attribute access (calls AND bare references) or the bare function
    name for ``from datetime import utcnow`` name calls.
    """
    offenders: list[tuple[int, str]] = []
    for node in ast.walk(tree):
        # Form 1: attribute access on something datetime-ish — catches
        # `datetime.utcnow()` calls and `default=datetime.utcnow` references.
        if isinstance(node, ast.Attribute) and node.attr in DEPRECATED_NAMES:
            base = node.value
            base_name = getattr(base, "id", None) or getattr(base, "attr", None)
            if base_name is None or "datetime" in base_name or base_name.endswith("dt"):
                offenders.append((node.lineno, f"datetime.{node.attr}"))
        # Form 2: bare name call — `utcnow()` after `from datetime import utcnow`.
        elif (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id in DEPRECATED_NAMES
        ):
            offenders.append((node.lineno, node.func.id))
    return sorted(offenders)


def _backend_python_files() -> list[str]:
    """All backend .py files (tests included), excluding caches/venvs."""
    result: list[str] = []
    for root, _dirs, files in os.walk(BACKEND_DIR):
        if "__pycache__" in root or ".venv" in root:
            continue
        for name in files:
            if name.endswith(".py"):
                result.append(str(Path(root) / name))
    return sorted(result)


def test_no_deprecated_datetime_calls_in_backend_source():
    """Static AST scan: no deprecated datetime calls or references."""
    offenders: list[str] = []

    for path in _backend_python_files():
        source = Path(path).read_text(encoding="utf-8", errors="replace")
        try:
            tree = ast.parse(source, filename=path)
        except SyntaxError:
            continue  # not Python-parseable content; runtime tests cover imports

        for lineno, label in _deprecated_datetime_nodes(tree):
            offenders.append(f"{path}:{lineno} {label}")

    assert offenders == [], (
        "Deprecated datetime APIs reappeared in backend source — use "
        "`utcnow_naive()` / `utcfromtimestamp_naive()` from "
        "backend.time_utils (or `_utcnow()` in backend.main) instead:\n"
        + "\n".join(offenders)
    )


def test_static_scan_would_catch_regression():
    """Guard the guard: the scanner detects planted violations of both kinds."""
    call_tree = ast.parse(
        "x = datetime.utcnow()\n"
        "y = utcfromtimestamp(0)\n"
    )
    ref_tree = ast.parse(
        "col = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)\n"
    )
    clean_tree = ast.parse(
        "col = Column(DateTime, default=utcnow_naive)\n"
        "t = utcnow_naive()\n"
    )
    assert _deprecated_datetime_nodes(call_tree) == [
        (1, "datetime.utcnow"),
        (2, "utcfromtimestamp"),
    ]
    assert _deprecated_datetime_nodes(ref_tree) == [
        (1, "datetime.utcnow"),
        (1, "datetime.utcnow"),
    ]
    assert _deprecated_datetime_nodes(clean_tree) == []
    assert DEPRECATED_CALL_RE.search("datetime.utcnow()") is not None
    assert DEPRECATED_CALL_RE.search("_utcnow()") is None
    assert DEPRECATED_CALL_RE.search("default=utcnow_naive") is None
