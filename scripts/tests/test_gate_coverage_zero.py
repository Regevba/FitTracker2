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
