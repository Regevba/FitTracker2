"""Tests for scripts/backfill-timing-wall-time.py classify() — the honesty boundary
that decides which features get a derived total_wall_time_minutes and which are
transparently excluded (data-integrity sub-plan §2.6 / honesty ledger FT2-FH-004).

Only clean, same-session, monotonic phase timing may be derived. Multi-day spans
and dirty (out-of-order / negative) timestamps must NOT be fabricated — they are
tagged excluded instead.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


def _load():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "backfill-timing-wall-time.py"
    spec = importlib.util.spec_from_file_location("backfill_timing_wall_time", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["backfill_timing_wall_time"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load()


def _phases(*spans):
    """spans = list of (start_iso, end_iso)."""
    return {"timing": {"phases": {f"p{i}": {"started_at": s, "ended_at": e}
                                  for i, (s, e) in enumerate(spans)}}}


def test_already_set_is_untouched(mod):
    d = {"timing": {"total_wall_time_minutes": 120, "phases": {}}}
    status, minutes = mod.classify(d)
    assert status == "already_set"


def test_no_per_phase(mod):
    status, minutes = mod.classify({"timing": {"phases": {}}})
    assert status == "no_per_phase"


def test_clean_same_session_derivable(mod):
    # two contiguous 30-min phases on the same day → 60 min
    d = _phases(("2026-06-10T10:00:00Z", "2026-06-10T10:30:00Z"),
                ("2026-06-10T10:30:00Z", "2026-06-10T11:00:00Z"))
    status, minutes = mod.classify(d)
    assert status == "derivable"
    assert minutes == 60.0


def test_overlap_capped_by_span(mod):
    # phases overlap → summed (60) > span (45) → use span
    d = _phases(("2026-06-10T10:00:00Z", "2026-06-10T10:30:00Z"),
                ("2026-06-10T10:15:00Z", "2026-06-10T10:45:00Z"))
    status, minutes = mod.classify(d)
    assert status == "derivable"
    assert minutes == 45.0


def test_multiday_excluded(mod):
    d = _phases(("2026-06-01T10:00:00Z", "2026-06-05T10:00:00Z"))  # 4-day span
    status, minutes = mod.classify(d)
    assert status == "multiday"
    assert minutes is None


def test_dirty_negative_excluded(mod):
    d = _phases(("2026-06-10T11:00:00Z", "2026-06-10T10:00:00Z"))  # end < start
    status, minutes = mod.classify(d)
    assert status == "dirty"
    assert minutes is None
