"""N5 — daily-checkpoint item-registry freshness advisory (added 2026-07-23).

The FIT-200 crosswalk index has no scheduled producer; it drifted to 118
items against a 132-feature corpus before anything noticed. N5 makes that
drift visible daily. These tests pin the contract that matters operationally:
the advisory reports honestly, and a broken checker never blocks the
checkpoint.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "daily-integrity-checkpoint.py"
_spec = importlib.util.spec_from_file_location("daily_integrity_checkpoint", _MOD)
dic = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dic)


def test_reports_stale_verdict(monkeypatch):
    monkeypatch.setattr(dic, "run", lambda *a, **k: (
        3, '{"stale": true, "reason": "fingerprint_mismatch", '
           '"registry_items": 118, "live_items": 132, "fingerprint_match": false}'))
    v = dic.item_registry_freshness()
    assert v["stale"] is True
    assert (v["registry_items"], v["live_items"]) == (118, 132)


def test_reports_fresh_verdict(monkeypatch):
    monkeypatch.setattr(dic, "run", lambda *a, **k: (
        0, '{"stale": false, "reason": "fresh", "registry_items": 132, '
           '"live_items": 132, "fingerprint_match": true}'))
    assert dic.item_registry_freshness()["stale"] is False


def test_tolerates_trailing_noise_on_stdout(monkeypatch):
    """Only the last line is the verdict; warnings above it must not break parsing."""
    monkeypatch.setattr(dic, "run", lambda *a, **k: (
        0, 'some unrelated warning\n{"stale": false, "reason": "fresh", '
           '"registry_items": 1, "live_items": 1, "fingerprint_match": true}'))
    assert dic.item_registry_freshness()["reason"] == "fresh"


def test_tooling_failure_is_silent_not_a_false_alarm(monkeypatch):
    """rc=2 (features dir missing) / rc=1 (crash) must yield {} — never a stale claim."""
    for rc in (1, 2, 127):
        monkeypatch.setattr(dic, "run", lambda *a, _rc=rc, **k: (_rc, "boom"))
        assert dic.item_registry_freshness() == {}


def test_malformed_json_is_silent(monkeypatch):
    monkeypatch.setattr(dic, "run", lambda *a, **k: (3, "not json at all"))
    assert dic.item_registry_freshness() == {}


def test_empty_output_is_silent(monkeypatch):
    monkeypatch.setattr(dic, "run", lambda *a, **k: (3, ""))
    assert dic.item_registry_freshness() == {}
