"""Tests for scripts/close-feature.py phase normalization.

Regression for the PHASE_LIE drift surfaced by garmin-health-connection closure
(FT2 #709): close-feature.py wrote a `docs` phase block but left a pre-existing
canonical `documentation` sub-phase at status=pending, so the integrity
PHASE_LIE check flagged "top-level complete but documentation=pending".

Run: python3 -m pytest scripts/tests/test_close_feature.py -q
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1]

# Mirror integrity-check.py COMPLETE_PHASE_STATUSES.
_COMPLETE = {"approved", "complete", "completed", "done", "skipped", "closed"}


def _load_cf():
    spec = importlib.util.spec_from_file_location("close_feature_mod", SCRIPTS / "close-feature.py")
    mod = importlib.util.module_from_spec(spec)
    import sys
    sys.modules["close_feature_mod"] = mod
    spec.loader.exec_module(mod)
    return mod


def _merged_meta(*_a, **_k):
    return {
        "state": "MERGED",
        "mergedAt": "2026-06-14T00:00:00Z",
        "mergeCommit": {"oid": "abc123def4567890"},
        "headRefName": "feature/demo",
        "mergedBy": {"login": "operator"},
        "title": "demo",
    }


@pytest.fixture
def feature_repo(tmp_path, monkeypatch):
    cf = _load_cf()
    monkeypatch.setattr(cf, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(cf, "fetch_pr_metadata", _merged_meta)
    monkeypatch.setattr(cf, "run", lambda *a, **k: None)  # no append-log subprocess
    fdir = tmp_path / ".claude" / "features" / "demo"
    fdir.mkdir(parents=True)
    return cf, fdir


def _write_state(fdir, phases):
    (fdir / "state.json").write_text(json.dumps({
        "feature": "demo", "current_phase": "testing", "phases": phases,
    }))


def test_close_normalizes_pending_documentation_subphase(feature_repo):
    cf, fdir = feature_repo
    _write_state(fdir, {
        "testing": {"status": "complete"},
        "documentation": {"status": "pending"},
    })
    rc = cf.close_feature(feature="demo", pr_number=1,
                          closure_branch="chore/demo-closure",
                          do_strike_backlog=False, dry_run=False)
    assert rc == 0
    s = json.loads((fdir / "state.json").read_text())
    assert s["current_phase"] == "complete"
    # The pre-existing documentation sub-phase must NOT be left pending.
    assert s["phases"]["documentation"]["status"] in _COMPLETE


def test_close_preserves_pending_na_subphase(feature_repo):
    """Phases intentionally marked pending_na are exempt — must NOT be flipped."""
    cf, fdir = feature_repo
    _write_state(fdir, {
        "testing": {"status": "complete"},
        "metrics": {"status": "pending_na"},
    })
    cf.close_feature(feature="demo", pr_number=1, closure_branch="chore/demo-closure",
                     do_strike_backlog=False, dry_run=False)
    s = json.loads((fdir / "state.json").read_text())
    assert s["phases"]["metrics"]["status"] == "pending_na"


def test_close_leaves_no_nonterminal_status(feature_repo):
    """After closure, NO existing phase status is left non-terminal (the PHASE_LIE
    invariant): every status is in the complete set OR pending_na."""
    cf, fdir = feature_repo
    _write_state(fdir, {
        "research": {"status": "complete"},
        "implementation": {"status": "in_progress"},
        "documentation": {"status": "pending"},
        "metrics": {"status": "pending_na"},
    })
    cf.close_feature(feature="demo", pr_number=1, closure_branch="chore/demo-closure",
                     do_strike_backlog=False, dry_run=False)
    s = json.loads((fdir / "state.json").read_text())
    for pname, pobj in s["phases"].items():
        status = pobj.get("status") if isinstance(pobj, dict) else None
        if status is None:
            continue
        assert status in _COMPLETE or status == "pending_na", f"{pname}={status} left non-terminal"
