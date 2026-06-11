"""Tests for scripts/integrity-data-lake.py reconciliation logic — the unified
telemetry data-layer's cross-source consistency checks (data-integrity sub-plan §2.7).

Focus: the R1 weekly-vs-F17 anomaly detector (the empirically-observed
weekly distinct_gate_count=0 while the F17 index has gates) must fire HIGH.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


def _load():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "integrity-data-lake.py"
    spec = importlib.util.spec_from_file_location("integrity_data_lake", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["integrity_data_lake"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load()


def _base_tables(mod):
    """Minimal tables dict that reconcile() accepts without raising."""
    return {
        "features": [],
        "gate_coverage": [{"gate": "G1", "candidates": 5, "checked": 5, "skipped": 0, "rows": 5, "last_ts": "2026-06-10"}],
        "f17_index": [{"gate": "G1", "total_firings": 5, "total_candidates": 5}],
        "weekly_gate_trend": [{"date": "2026-06-08", "distinct_gate_count": 1}],
        "daily_checkpoints": [],
        "adoption_history": [],
        "anchors": [{"label": "2026-05-14-platform", "canonical": True, "n_features": 70, "path": "~/x"}],
        "snapshots": {"local": [], "ssd": [], "ssd_mounted": False},
    }


def test_r1_fires_on_weekly_zero_with_index_present(mod):
    t = _base_tables(mod)
    t["weekly_gate_trend"] = [{"date": "2026-06-08", "distinct_gate_count": 0}]
    findings = mod.reconcile(t)
    r1 = [x for x in findings if x["id"] == "R1-weekly-zero-vs-index"]
    assert r1 and r1[0]["severity"] == "HIGH"


def test_r1_silent_when_weekly_healthy(mod):
    findings = mod.reconcile(_base_tables(mod))
    assert not [x for x in findings if x["id"] == "R1-weekly-zero-vs-index"]


def test_r5_flags_zero_candidate_gate(mod):
    t = _base_tables(mod)
    t["f17_index"].append({"gate": "DEAD", "total_firings": 0, "total_candidates": 0})
    findings = mod.reconcile(t)
    r5 = [x for x in findings if x["id"] == "R5-zero-candidate-gates"]
    assert r5 and "DEAD" in r5[0]["message"]


def test_to_columnar_unions_keys(mod):
    rows = [{"a": 1}, {"a": 2, "b": 3}]
    col = mod._to_columnar(rows)
    assert col["a"] == [1, 2]
    assert col["b"] == [None, 3]


def test_loaders_run_against_live_repo_without_error(mod):
    # smoke: the real loaders must not raise on the live tree (read-only).
    assert isinstance(mod.load_features(), list)
    assert isinstance(mod.load_gate_coverage(), list)
    assert isinstance(mod.load_snapshots(), dict)
