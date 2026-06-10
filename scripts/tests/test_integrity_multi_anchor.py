"""Tests for scripts/integrity-multi-anchor.py classify_delta() — the dilution-aware
regression classifier that single-sources the regression *definition* for
integrity-diff + the data-lake (data-integrity sub-plan §2.6).

The core invariant: a raw percentage drop caused purely by corpus growth (new
features entering the denominator with empty metrics) must classify as `dilution`,
NOT `REAL_REGRESSION`. A drop on the shared cohort, or an absolute-numerator
decrease, must classify as `REAL_REGRESSION`.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


def _load():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "integrity-multi-anchor.py"
    spec = importlib.util.spec_from_file_location("integrity_multi_anchor", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["integrity_multi_anchor"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load()


def _adopt(*flags):
    """Build {feature: {dim: bool}} for the single dimension 'd' from flags."""
    return {f"f{i}": {"d": bool(v)} for i, v in enumerate(flags)}


def test_pure_dilution_is_not_regression(mod):
    # anchor: 2/2 adopted (100%). latest: same 2 still adopted + 2 new empty → 50% raw.
    anchor = _adopt(1, 1)
    latest = {**_adopt(1, 1), "new1": {"d": False}, "new2": {"d": False}}
    c = mod.classify_delta(anchor, latest, "d")
    assert c["raw_delta"] < 0           # raw % fell
    assert c["cohort_delta"] == 0.0     # shared cohort unchanged
    assert c["numerator_delta"] == 0    # absolute count unchanged
    assert c["verdict"] == "dilution"


def test_cohort_drop_is_real_regression(mod):
    # a feature present in both LOST the metric → cohort drop.
    anchor = _adopt(1, 1)
    latest = {"f0": {"d": True}, "f1": {"d": False}}
    c = mod.classify_delta(anchor, latest, "d")
    assert c["cohort_delta"] < 0
    assert c["verdict"] == "REAL_REGRESSION"


def test_numerator_drop_is_real_regression(mod):
    anchor = _adopt(1, 1, 1)      # numerator 3
    latest = _adopt(1, 1)         # numerator 2 (a feature removed)
    c = mod.classify_delta(anchor, latest, "d")
    assert c["numerator_delta"] < 0
    assert c["verdict"] == "REAL_REGRESSION"


def test_genuine_improvement(mod):
    anchor = _adopt(1, 0)
    latest = _adopt(1, 1)
    c = mod.classify_delta(anchor, latest, "d")
    assert c["verdict"] == "improved"
    assert c["numerator_delta"] == 1


def test_flat(mod):
    anchor = _adopt(1, 1)
    latest = _adopt(1, 1)
    c = mod.classify_delta(anchor, latest, "d")
    assert c["verdict"] == "flat"


def test_instrumented_only_drops_derived(mod, tmp_path):
    # measurement-adoption.json with one derived + one instrumented timing value.
    p = tmp_path / "ma.json"
    p.write_text('{"features":['
                 '{"feature":"a","adoption":{"timing_wall_time":true},"provenance":{"timing_wall_time":"derived"}},'
                 '{"feature":"b","adoption":{"timing_wall_time":true},"provenance":{"timing_wall_time":"instrumented"}}'
                 ']}')
    full = mod.load_adoption_features(p)
    strict = mod.load_adoption_features(p, instrumented_only=True)
    assert full["a"]["timing_wall_time"] is True
    assert strict["a"]["timing_wall_time"] is False   # derived dropped
    assert strict["b"]["timing_wall_time"] is True    # instrumented kept
