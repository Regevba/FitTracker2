"""Tests for scripts/gate_coverage.py.

Covers Mechanism A (v7.8 §4.1) — the per-gate coverage tracker that
detects silent-pass failures (a gate that runs every commit but never
exercises real data).

Verifies:
  1. candidate / skip / checked counters balance (every candidate
     ends up in exactly one of skipped or checked).
  2. JSONL writer produces well-formed events matching the bridge
     design's example shape.
  3. The optional `coverage` parameter on `check_cache_hits_empty_post_v6`
     populates the tracker correctly across each early-return branch
     (no_created_at, pre_v6, pre_mechanism_c, not_complete) AND the
     "checked" path that reaches the predicate.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

import importlib.util

_spec = importlib.util.spec_from_file_location(
    "check_state_schema",
    SCRIPTS_DIR / "check-state-schema.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

check_cache_hits_empty_post_v6 = _mod.check_cache_hits_empty_post_v6
check_state_no_case_study_link = _mod.check_state_no_case_study_link
check_cu_v2_schema = _mod.check_cu_v2_schema

from gate_coverage import GateCoverage  # noqa: E402


# ---------------------------------------------------------------------------
# T1 — counter balance: every candidate ends up in checked OR skipped
# ---------------------------------------------------------------------------

def test_counters_balance_after_one_candidate():
    """One candidate + one skip → totals balance."""
    cov = GateCoverage()
    cov.candidate("X")
    cov.skip("X", "reason_a")
    stats = cov.gates["X"]
    assert stats["candidates"] == 1
    assert stats["skipped"] == 1
    assert stats["checked"] == 0
    assert stats["skip_reasons"] == {"reason_a": 1}


def test_counters_balance_mixed_paths():
    """5 candidates across 3 reasons + 2 checked → totals balance."""
    cov = GateCoverage()
    for _ in range(2):
        cov.candidate("Y")
        cov.skip("Y", "absent")
    cov.candidate("Y")
    cov.skip("Y", "ineligible")
    for _ in range(2):
        cov.candidate("Y")
        cov.checked("Y")
    stats = cov.gates["Y"]
    assert stats["candidates"] == 5
    assert stats["checked"] == 2
    assert stats["skipped"] == 3
    assert stats["skip_reasons"] == {"absent": 2, "ineligible": 1}
    # Invariant: checked + skipped == candidates
    assert stats["checked"] + stats["skipped"] == stats["candidates"]


# ---------------------------------------------------------------------------
# T2 — JSONL writer produces correct event shape
# ---------------------------------------------------------------------------

def test_to_events_matches_bridge_design_shape():
    """Event dict has all keys the bridge design example has."""
    cov = GateCoverage(mode="all")
    cov.candidate("CACHE_HITS_EMPTY_POST_V6")
    cov.skip("CACHE_HITS_EMPTY_POST_V6", "pre_v6")
    events = cov.to_events()
    assert len(events) == 1
    ev = events[0]
    # Required keys per bridge design §4.1 example
    assert set(ev.keys()) >= {
        "timestamp", "gate", "candidates", "checked", "skipped", "skip_reasons"
    }
    assert ev["gate"] == "CACHE_HITS_EMPTY_POST_V6"
    assert ev["candidates"] == 1
    assert ev["checked"] == 0
    assert ev["skipped"] == 1
    assert ev["skip_reasons"] == {"pre_v6": 1}
    assert ev["mode"] == "all"
    # ISO 8601 timestamp
    assert "T" in ev["timestamp"] and ev["timestamp"].endswith("+00:00")


def test_write_jsonl_appends_one_event_per_gate(tmp_path):
    """write_jsonl produces one line per gate, valid JSON each line."""
    cov = GateCoverage(mode="staged")
    cov.candidate("GATE_A")
    cov.checked("GATE_A")
    cov.candidate("GATE_B")
    cov.skip("GATE_B", "reason")
    ledger = tmp_path / "gate-coverage.jsonl"
    n = cov.write_jsonl(ledger)
    assert n == 2
    lines = ledger.read_text().strip().split("\n")
    assert len(lines) == 2
    parsed = [json.loads(line) for line in lines]
    gates = {ev["gate"] for ev in parsed}
    assert gates == {"GATE_A", "GATE_B"}


def test_write_jsonl_appends_not_overwrites(tmp_path):
    """Two runs against the same ledger accumulate, not replace."""
    ledger = tmp_path / "gate-coverage.jsonl"
    cov1 = GateCoverage()
    cov1.candidate("X")
    cov1.checked("X")
    cov1.write_jsonl(ledger)
    cov2 = GateCoverage()
    cov2.candidate("Y")
    cov2.checked("Y")
    cov2.write_jsonl(ledger)
    lines = ledger.read_text().strip().split("\n")
    assert len(lines) == 2  # one event per run × one gate per run


def test_write_jsonl_creates_parent_dir(tmp_path):
    """write_jsonl mkdir-p's the parent so the caller doesn't have to."""
    nested = tmp_path / "deep" / "nested" / "dir" / "ledger.jsonl"
    cov = GateCoverage()
    cov.candidate("X")
    cov.checked("X")
    cov.write_jsonl(nested)
    assert nested.exists()


def test_write_jsonl_with_no_gates_returns_zero(tmp_path):
    """Empty tracker → write_jsonl returns 0 and creates no file."""
    ledger = tmp_path / "ledger.jsonl"
    cov = GateCoverage()
    n = cov.write_jsonl(ledger)
    assert n == 0
    assert not ledger.exists()


# ---------------------------------------------------------------------------
# T3 — gate functions populate coverage on each early-return path
# ---------------------------------------------------------------------------

# NOTE: the gate function `check_cache_hits_empty_post_v6` retains its legacy
# Python name (it pre-dates the v7.8.3 rename from CACHE_HITS_EMPTY_POST_V6 →
# CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT), but its Mechanism A emission key is
# the canonical NEW name. Tests below assert against the canonical emission key
# — v7.8.5 fix (2026-05-12) to close the keying-drift suspicion flagged in
# PR #318 §"Pre-promotion remediation". Production telemetry has been clean
# since v7.8.3; only the test fixtures referenced the obsolete key.

CACHE_HITS_GATE_KEY = "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT"


def test_cache_hits_gate_emits_canonical_key():
    """REGRESSION (v7.8.5): the gate function MUST emit to gate-coverage under
    the canonical CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT key — never the legacy
    CACHE_HITS_EMPTY_POST_V6 key — regardless of which call path triggers it.

    Catches future rename drift between function-name and emission-key (the
    class of bug suspected by PR #318 §Pre-promotion remediation, ruled out
    in v7.8.5 diagnostic).
    """
    cov = GateCoverage()
    state = {
        "feature_name": "regression",
        "current_phase": "complete",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C, hits main predicate
        "cache_hits": [{"key": "x"}],
    }
    check_cache_hits_empty_post_v6(state, coverage=cov)
    assert CACHE_HITS_GATE_KEY in cov.gates, (
        f"Gate must emit under canonical key {CACHE_HITS_GATE_KEY!r}; "
        f"got keys: {list(cov.gates.keys())}"
    )
    assert "CACHE_HITS_EMPTY_POST_V6" not in cov.gates, (
        "Legacy key CACHE_HITS_EMPTY_POST_V6 must NOT appear — was renamed in v7.8.3"
    )


def test_cache_hits_gate_records_pre_v6_skip():
    """Pre-v6 feature: skip reason 'pre_v6'."""
    cov = GateCoverage()
    state = {
        "feature_name": "old",
        "current_phase": "complete",
        "created_at": "2026-04-15T00:00:00Z",  # pre-v6
        "cache_hits": [],
    }
    check_cache_hits_empty_post_v6(state, coverage=cov)
    stats = cov.gates[CACHE_HITS_GATE_KEY]
    assert stats["candidates"] == 1
    assert stats["checked"] == 0
    assert stats["skipped"] == 1
    assert stats["skip_reasons"] == {"pre_v6": 1}


def test_cache_hits_gate_records_pre_mechanism_c_skip():
    """Post-v6, pre-Mechanism-C feature: skip reason 'pre_mechanism_c'."""
    cov = GateCoverage()
    state = {
        "feature_name": "mid",
        "current_phase": "complete",
        "created_at": "2026-04-20T00:00:00Z",  # post-v6, pre-Mechanism-C
        "cache_hits": [],
    }
    check_cache_hits_empty_post_v6(state, coverage=cov)
    stats = cov.gates[CACHE_HITS_GATE_KEY]
    assert stats["skipped"] == 1
    assert stats["skip_reasons"] == {"pre_mechanism_c": 1}


def test_cache_hits_gate_records_not_complete_skip():
    """Post-Mechanism-C but in-progress: skip reason 'not_complete'."""
    cov = GateCoverage()
    state = {
        "feature_name": "wip",
        "current_phase": "implementation",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C
        "cache_hits": [],
    }
    check_cache_hits_empty_post_v6(state, coverage=cov)
    stats = cov.gates[CACHE_HITS_GATE_KEY]
    assert stats["skipped"] == 1
    assert stats["skip_reasons"] == {"not_complete": 1}


def test_cache_hits_gate_records_checked_when_predicate_runs():
    """Post-Mechanism-C complete feature reaches the main predicate."""
    cov = GateCoverage()
    state = {
        "feature_name": "ok",
        "current_phase": "complete",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C
        "cache_hits": [{"key": "x"}],
    }
    check_cache_hits_empty_post_v6(state, coverage=cov)
    stats = cov.gates[CACHE_HITS_GATE_KEY]
    assert stats["checked"] == 1
    assert stats["skipped"] == 0


def test_cu_v2_gate_records_field_absent_skip():
    """No cu_v2 key → skip reason 'field_absent'."""
    cov = GateCoverage()
    check_cu_v2_schema({"feature_name": "x"}, coverage=cov)
    stats = cov.gates["CU_V2_INVALID"]
    assert stats["skipped"] == 1
    assert stats["skip_reasons"] == {"field_absent": 1}


def test_state_no_case_study_link_records_not_complete_skip():
    """In-progress feature: skip reason 'not_complete'."""
    cov = GateCoverage()
    check_state_no_case_study_link(
        {"feature_name": "x", "current_phase": "implementation"},
        coverage=cov,
    )
    stats = cov.gates["STATE_NO_CASE_STUDY_LINK"]
    assert stats["skipped"] == 1
    assert stats["skip_reasons"] == {"not_complete": 1}


def test_gate_function_without_coverage_works_unchanged():
    """Backward compat: gate functions still work with no coverage kwarg."""
    state = {
        "feature_name": "old",
        "current_phase": "complete",
        "created_at": "2026-04-15T00:00:00Z",
        "cache_hits": [],
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == []  # pre-v6 exempt → no finding, no error
