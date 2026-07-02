"""
Unit tests for scripts/profile-precommit-hooks.py (FIT-181 / dev-env R15).

Tests the pure analysis layer (percentile / summarize / build_report / budget
evaluation) with synthetic durations — never shells out, so it's fast + stable
in CI.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "profile-precommit-hooks.py"


def _load():
    spec = importlib.util.spec_from_file_location("profile_precommit_hooks", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


pp = _load()


def test_percentile_interpolates():
    vals = [1.0, 2.0, 3.0, 4.0, 5.0]
    assert pp.percentile(vals, 0.0) == 1.0
    assert pp.percentile(vals, 1.0) == 5.0
    assert pp.percentile(vals, 0.5) == 3.0
    # p95 of 1..5 interpolates between the 4th and 5th value
    assert 4.7 < pp.percentile(vals, 0.95) <= 5.0


def test_percentile_edge_cases():
    assert pp.percentile([], 0.95) == 0.0
    assert pp.percentile([2.5], 0.95) == 2.5


def test_summarize_shape():
    s = pp.summarize([0.3, 0.1, 0.2])
    assert s["samples"] == 3
    assert s["p50"] == 0.2
    assert s["max"] == 0.3
    assert abs(s["mean"] - 0.2) < 1e-9


def test_build_report_within_budget():
    durs = {
        "check-a": [0.5, 0.6, 0.55],
        "check-b": [0.4, 0.45, 0.42],
    }
    budgets = {"per_check_p95": 3.0, "total_p95": 8.0}
    r = pp.build_report(durs, budgets)
    assert r["within_budget"] is True
    assert r["over_budget"]["per_check"] == []
    assert r["over_budget"]["total"] is False
    assert set(r["checks"]) == {"check-a", "check-b"}
    assert r["total_p95"] == round(r["checks"]["check-a"]["p95"] + r["checks"]["check-b"]["p95"], 4)


def test_build_report_per_check_over_budget():
    durs = {"slow": [5.0, 5.1, 5.2], "fast": [0.1, 0.1, 0.1]}
    budgets = {"per_check_p95": 3.0, "total_p95": 100.0}  # total generous, per-check tight
    r = pp.build_report(durs, budgets)
    assert r["over_budget"]["per_check"] == ["slow"]
    assert r["within_budget"] is False


def test_build_report_total_over_budget():
    durs = {"a": [3.0, 3.0, 3.0], "b": [3.0, 3.0, 3.0]}
    budgets = {"per_check_p95": 10.0, "total_p95": 5.0}  # per-check generous, total tight
    r = pp.build_report(durs, budgets)
    assert r["over_budget"]["per_check"] == []
    assert r["over_budget"]["total"] is True
    assert r["within_budget"] is False


def test_checks_registry_matches_hook():
    """The profiled checks must be the ones the real pre-commit hook invokes."""
    names = {c["name"] for c in pp.CHECKS}
    assert names == {"check-state-schema", "check-case-study-preflight", "check-prereg-lock"}
