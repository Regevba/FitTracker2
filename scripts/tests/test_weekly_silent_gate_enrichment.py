"""
Unit tests for the A5 silent-gate enrichment in scripts/weekly-trend-scan.py
(FIT-185 / dev-env R19). Pure — feeds a synthetic F17 index, no filesystem.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "weekly-trend-scan.py"


def _load():
    spec = importlib.util.spec_from_file_location("weekly_trend_scan", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


wts = _load()


def _idx(gates: dict) -> dict:
    return {"gates": gates}


def test_flags_candidates_with_zero_firings():
    idx = _idx({
        "SILENT_A": {"total_candidates": 100, "total_firings": 0, "total_skips": 100},
        "HEALTHY": {"total_candidates": 500, "total_firings": 12, "total_skips": 488},
    })
    out = wts.compute_silent_gate_candidates(idx, top_n=3)
    names = [r["gate"] for r in out]
    assert names == ["SILENT_A"]  # HEALTHY has firings>0, excluded
    assert out[0]["candidates"] == 100
    assert out[0]["skips"] == 100


def test_excludes_zero_candidate_gates():
    """A gate with no candidates at all is NOT a silent-gate candidate (it's the
    separate 0-candidate mis-wire class handled by GATE_COVERAGE_ZERO)."""
    idx = _idx({"NEVER_REACHED": {"total_candidates": 0, "total_firings": 0, "total_skips": 0}})
    assert wts.compute_silent_gate_candidates(idx) == []


def test_ranked_by_candidate_volume_and_truncated():
    idx = _idx({
        "LOUD": {"total_candidates": 900, "total_firings": 0, "total_skips": 900},
        "MID": {"total_candidates": 50, "total_firings": 0, "total_skips": 50},
        "QUIET": {"total_candidates": 5, "total_firings": 0, "total_skips": 5},
        "EXTRA": {"total_candidates": 1, "total_firings": 0, "total_skips": 1},
    })
    out = wts.compute_silent_gate_candidates(idx, top_n=3)
    assert [r["gate"] for r in out] == ["LOUD", "MID", "QUIET"]  # top_n=3, sorted desc


def test_empty_or_malformed_index():
    assert wts.compute_silent_gate_candidates({}, 3) == []
    assert wts.compute_silent_gate_candidates({"gates": "not-a-dict"}, 3) == []
    # a non-dict gate entry is skipped, not crashed on
    assert wts.compute_silent_gate_candidates({"gates": {"X": None}}, 3) == []


def test_top_n_zero_returns_empty():
    idx = _idx({"S": {"total_candidates": 10, "total_firings": 0, "total_skips": 10}})
    assert wts.compute_silent_gate_candidates(idx, top_n=0) == []
