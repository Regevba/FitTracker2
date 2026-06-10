"""Unit tests for check_gate_coverage_zero() in scripts/integrity-check.py.

The live corpus produces 0 findings (healthy — every active gate is current),
so the detection logic is proven by construction here with a synthetic
gate-last-fired.json index: a historically-active gate that went silent while
the corpus stayed active MUST flag; healthy + low-volume gates MUST NOT.
"""
import importlib.util
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "integrity_check",
    Path(__file__).resolve().parent.parent / "integrity-check.py",
)
ic = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(ic)


def _write_index(tmp_path, gates):
    d = tmp_path / ".claude" / "shared"
    d.mkdir(parents=True)
    (d / "gate-last-fired.json").write_text(json.dumps({"schema_version": 1, "gates": gates}))


def _iso(dt):
    return dt.isoformat()


def _run(tmp_path, gates, monkeypatch):
    _write_index(tmp_path, gates)
    monkeypatch.setattr(ic, "REPO_ROOT", tmp_path)
    return ic.check_gate_coverage_zero()


def test_silent_historically_active_gate_flagged(tmp_path, monkeypatch):
    now = datetime.now(timezone.utc)
    gates = {
        "ACTIVE_GATE": {"total_candidates": 200, "last_checked_at": _iso(now),
                        "last_skipped_at": _iso(now)},
        "SILENT_GATE": {"total_candidates": 150,  # historically active...
                        "last_checked_at": _iso(now - timedelta(days=40)),
                        "last_skipped_at": _iso(now - timedelta(days=40))},  # ...went silent
    }
    findings = _run(tmp_path, gates, monkeypatch)
    flagged = {f["message"].split("`")[1] for f in findings}
    assert "SILENT_GATE" in flagged
    assert "ACTIVE_GATE" not in flagged
    assert all(f["code"] == "GATE_COVERAGE_ZERO" and f["severity"] == "ADVISORY" for f in findings)


def test_low_volume_gate_not_flagged(tmp_path, monkeypatch):
    # < MIN_CANDIDATES (20) historical candidates → ignored even if stale.
    now = datetime.now(timezone.utc)
    gates = {
        "ACTIVE_GATE": {"total_candidates": 200, "last_checked_at": _iso(now),
                        "last_skipped_at": _iso(now)},
        "RARE_GATE": {"total_candidates": 5,
                      "last_checked_at": _iso(now - timedelta(days=40)),
                      "last_skipped_at": _iso(now - timedelta(days=40))},
    }
    findings = _run(tmp_path, gates, monkeypatch)
    assert findings == []


def test_all_recent_no_findings(tmp_path, monkeypatch):
    now = datetime.now(timezone.utc)
    gates = {
        "G1": {"total_candidates": 200, "last_checked_at": _iso(now), "last_skipped_at": _iso(now)},
        "G2": {"total_candidates": 100, "last_checked_at": _iso(now - timedelta(days=3)),
               "last_skipped_at": _iso(now - timedelta(days=1))},
    }
    assert _run(tmp_path, gates, monkeypatch) == []


def test_missing_index_safe(tmp_path, monkeypatch):
    monkeypatch.setattr(ic, "REPO_ROOT", tmp_path)  # no index file
    assert ic.check_gate_coverage_zero() == []


# --- v7.10 mis-wire (0-candidate) detection -------------------------------

def test_miswire_zero_candidate_gate_flagged(tmp_path, monkeypatch):
    """A gate registered in the index but with ALL counters zero = mis-wired."""
    now = datetime.now(timezone.utc)
    gates = {
        "ACTIVE_GATE": {"total_candidates": 200, "last_checked_at": _iso(now),
                        "last_skipped_at": _iso(now)},
        "MISWIRED_GATE": {"total_candidates": 0, "total_checked": 0, "total_skips": 0,
                          "total_firings": 0},
    }
    findings = _run(tmp_path, gates, monkeypatch)
    msgs = " ".join(f["message"] for f in findings)
    assert "MISWIRED_GATE" in msgs
    assert "every counter is zero" in msgs
    assert all(f["code"] == "GATE_COVERAGE_ZERO" for f in findings)


def test_healthy_zero_firing_gate_not_flagged(tmp_path, monkeypatch):
    """STATE_OWNER_MISSING shape: thousands of candidates, 0 firings — HEALTHY.

    The gate runs on every commit and never finds a violation; it must NOT be
    flagged as mis-wired (it has non-zero candidates) nor as stale (its activity
    is current).
    """
    now = datetime.now(timezone.utc)
    gates = {
        "ACTIVE_GATE": {"total_candidates": 200, "last_checked_at": _iso(now),
                        "last_skipped_at": _iso(now)},
        "STATE_OWNER_MISSING": {"total_candidates": 1936, "total_firings": 0,
                                "total_skips": 1936,
                                "last_checked_at": _iso(now),
                                "last_skipped_at": _iso(now)},
    }
    findings = _run(tmp_path, gates, monkeypatch)
    flagged = {f["message"].split("`")[1] for f in findings if "`" in f["message"]}
    assert "STATE_OWNER_MISSING" not in flagged


def test_miswire_does_not_double_flag_as_stale(tmp_path, monkeypatch):
    """A 0-candidate gate produces exactly one finding (mis-wire), not also stale."""
    now = datetime.now(timezone.utc)
    gates = {
        "ACTIVE_GATE": {"total_candidates": 200, "last_checked_at": _iso(now),
                        "last_skipped_at": _iso(now)},
        "MISWIRED_GATE": {"total_candidates": 0, "total_checked": 0, "total_skips": 0},
    }
    findings = _run(tmp_path, gates, monkeypatch)
    miswire = [f for f in findings if "MISWIRED_GATE" in f["message"]]
    assert len(miswire) == 1
