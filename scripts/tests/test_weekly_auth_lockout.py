"""Unit tests for auth_lockout_activity() in scripts/weekly-trend-scan.py (E-3).

Surfaces UCC auth-lockout events (auth_lockout_triggered + auth_lockout_blocked_attempt)
from the synced audit log into the Monday framework-status weekly digest. The
`detected` flag drives the workflow's issue-open condition, so a lockout spike
becomes visible weekly instead of only in raw Blob-store logs.
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "weekly_trend_scan",
    Path(__file__).resolve().parent.parent / "weekly-trend-scan.py",
)
wts = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(wts)

REF = "2026-07-08T00:00:00Z"  # fixed reference date so tests never call now()


def _log(tmp_path, events):
    p = tmp_path / "ucc-auth-events.jsonl"
    p.write_text("".join(json.dumps(e) + "\n" for e in events))
    return p


def _ev(event_type, ts, outcome="blocked"):
    return {"event_type": event_type, "outcome": outcome, "timestamp": ts}


def test_absent_log_is_clean_not_error(tmp_path):
    r = wts.auth_lockout_activity(log_path=tmp_path / "missing.jsonl", ref_date=REF)
    assert r["log_present"] is False
    assert r["detected"] is False
    assert r["triggered"] == 0 and r["blocked"] == 0


def test_no_lockouts_in_window_is_clean(tmp_path):
    # Only benign auth events present → not detected.
    p = _log(tmp_path, [
        _ev("auth_passkey_authenticate_succeeded", "2026-07-07T10:00:00Z", "success"),
        _ev("auth_session_minted", "2026-07-06T10:00:00Z", "success"),
    ])
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["log_present"] is True
    assert r["detected"] is False
    assert r["triggered"] == 0 and r["blocked"] == 0


def test_triggered_within_window_is_detected(tmp_path):
    p = _log(tmp_path, [
        _ev("auth_lockout_triggered", "2026-07-05T12:00:00Z"),
        _ev("auth_lockout_blocked_attempt", "2026-07-05T12:00:05Z"),
        _ev("auth_lockout_blocked_attempt", "2026-07-06T09:00:00Z"),
    ])
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["detected"] is True
    assert r["triggered"] == 1
    assert r["blocked"] == 2


def test_events_outside_window_excluded(tmp_path):
    # 8 days before REF → outside the 7-day window.
    p = _log(tmp_path, [
        _ev("auth_lockout_triggered", "2026-06-30T12:00:00Z"),
        _ev("auth_lockout_blocked_attempt", "2026-06-29T12:00:00Z"),
    ])
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["detected"] is False
    assert r["triggered"] == 0 and r["blocked"] == 0


def test_cleared_is_informational_not_detected(tmp_path):
    # auth_lockout_cleared alone (lockout expired) must NOT open an issue.
    p = _log(tmp_path, [_ev("auth_lockout_cleared", "2026-07-05T12:00:00Z", "success")])
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["detected"] is False
    assert r["cleared"] == 1


def test_malformed_lines_skipped(tmp_path):
    p = tmp_path / "ucc-auth-events.jsonl"
    p.write_text(
        json.dumps(_ev("auth_lockout_triggered", "2026-07-05T12:00:00Z")) + "\n"
        + "{not json\n"
        + "\n"
        + json.dumps(_ev("auth_lockout_blocked_attempt", "2026-07-06T12:00:00Z")) + "\n"
    )
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["triggered"] == 1 and r["blocked"] == 1
    assert r["detected"] is True


def test_missing_or_bad_timestamp_excluded(tmp_path):
    p = _log(tmp_path, [
        {"event_type": "auth_lockout_triggered"},                       # no ts
        _ev("auth_lockout_blocked_attempt", "not-a-date"),              # bad ts
        _ev("auth_lockout_triggered", "2026-07-05T12:00:00Z"),         # valid
    ])
    r = wts.auth_lockout_activity(log_path=p, ref_date=REF)
    assert r["triggered"] == 1 and r["blocked"] == 0
