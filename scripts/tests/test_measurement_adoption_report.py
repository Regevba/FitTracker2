"""Tests for scripts/measurement-adoption-report.py adoption-dimension detectors.

Focus: the `has_cu_v2` field-mismatch fix. The adoption metric must count CU v2
data in BOTH representations that coexist in the corpus — the v7.7+ canonical
top-level `cu_v2` object AND the legacy `complexity.cu_version == 2` marker —
or it systematically undercounts (the `created`/`created_at` bug class).
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


def _load_module():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "measurement-adoption-report.py"
    spec = importlib.util.spec_from_file_location("measurement_adoption_report", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["measurement_adoption_report"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load_module()


# --- has_cu_v2: both representations + negatives ---------------------------

def test_cu_v2_canonical_toplevel_object(mod):
    """v7.7+ canonical shape: top-level cu_v2 object with a total."""
    d = {"cu_v2": {"factors": {"complexity": 0.4}, "total": 1.6, "tier_class": "B_medium"}}
    assert mod.has_cu_v2(d) is True


def test_cu_v2_legacy_complexity_marker(mod):
    """v6.0-era legacy marker still counts (back-compat)."""
    assert mod.has_cu_v2({"complexity": {"cu_version": 2}}) is True
    assert mod.has_cu_v2({"complexity": {"cu_version": "v2"}}) is True


def test_cu_v2_either_representation_alone_is_enough(mod):
    """The two field shapes are nearly disjoint in the corpus; either suffices."""
    only_toplevel = {"cu_v2": {"total": 2.0}}
    only_legacy = {"complexity": {"cu_version": 2}}
    assert mod.has_cu_v2(only_toplevel) is True
    assert mod.has_cu_v2(only_legacy) is True


def test_cu_v2_absent(mod):
    assert mod.has_cu_v2({}) is False
    assert mod.has_cu_v2({"complexity": {"cu_version": 1}}) is False
    assert mod.has_cu_v2({"complexity": {}}) is False


def test_cu_v2_toplevel_object_without_total_does_not_count(mod):
    """An empty/partial cu_v2 stub without a total is not adoption."""
    assert mod.has_cu_v2({"cu_v2": {}}) is False
    assert mod.has_cu_v2({"cu_v2": {"factors": {"complexity": 0.4}}}) is False


def test_cu_v2_malformed_types_are_safe(mod):
    assert mod.has_cu_v2({"cu_v2": "not-an-object"}) is False
    assert mod.has_cu_v2({"complexity": "not-an-object"}) is False


# --- regression guards on the other detectors ------------------------------

def test_timing_wall_time_requires_positive_minutes(mod):
    assert mod.has_timing_wall_time({"timing": {"total_wall_time_minutes": 12}}) is True
    assert mod.has_timing_wall_time({"timing": {"total_wall_time_minutes": 0}}) is False
    assert mod.has_timing_wall_time({"timing": {}}) is False


def test_cache_hits_populated_list(mod):
    assert mod.has_cache_hits({"cache_hits": [{"path": "x"}]}) is True
    assert mod.has_cache_hits({"cache_hits": []}) is False
    assert mod.has_cache_hits({}) is False


# --- provenance split: instrumented vs derived (FT2-FH-004) ----------------

def test_wall_time_is_derived_detects_backfill_provenance(mod):
    d = {"timing": {"total_wall_time_minutes": 60,
                    "total_wall_time_minutes_provenance": "backfill-derived-from-phase-durations-2026-06-10"}}
    assert mod.wall_time_is_derived(d) is True


def test_wall_time_instrumented_when_no_provenance(mod):
    assert mod.wall_time_is_derived({"timing": {"total_wall_time_minutes": 60}}) is False
    assert mod.wall_time_is_derived({"timing": {}}) is False


def test_provenance_vector_labels_each_dimension(mod):
    d = {"timing": {"total_wall_time_minutes": 60,
                    "total_wall_time_minutes_provenance": "backfill-derived-x"}}
    adoption = {"timing_wall_time": True, "per_phase_timing": True,
                "cache_hits": False, "cu_v2": False}
    pv = mod.provenance_vector(d, adoption)
    assert pv["timing_wall_time"] == "derived"
    assert pv["per_phase_timing"] == "instrumented"   # no derived predicate → instrumented
    assert pv["cache_hits"] is None                    # not adopted
