"""Daily-checkpoint telemetry honesty (added 2026-07-30).

Two defects made the daily ledger's own health columns unreadable:

1. `parse_integrity_findings` used a `split("+")` parse that raised on the
   no-advisory emission form `"Findings: 0 ()"`, so EVERY clean day recorded
   `integrity_findings: -1` — a healthy run indistinguishable from a run whose
   output could not be parsed at all. Observed on every ledger row from at
   least 2026-07-24 through 2026-07-30.

2. `run_integrity_sweep` kept only `{layer: status}` and dropped each layer's
   `detail`, so a cron-only `Framework integrity: FAIL` (2026-07-25 / -27 /
   -30 — none of which reproduced interactively) left no finding count and no
   code behind to diagnose from.

Both are the reader/format-mismatch class of observed-patterns #24.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "daily-integrity-checkpoint.py"
_spec = importlib.util.spec_from_file_location("daily_integrity_checkpoint", _MOD)
dic = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dic)


# ── 1. findings parse ─────────────────────────────────────────────────────────

def test_parses_no_advisory_form():
    """The regression: 'Findings: 0 ()' is what a clean run actually emits."""
    assert dic.parse_integrity_findings("Findings: 0 ()") == (0, 0)


def test_parses_advisory_form():
    # NB: no real gate ID in this file — `gate-catalog.py` derives per-gate test
    # coverage by grepping gate names out of test sources, so naming one here
    # would falsely credit that gate with coverage it does not have.
    assert dic.parse_integrity_findings("Findings: 3 + 2 advisory (SOME_CODE)") == (3, 2)


def test_parses_nonzero_no_advisory_form():
    assert dic.parse_integrity_findings("Findings: 7 ()") == (7, 0)


def test_finds_line_amid_surrounding_output():
    text = "Features scanned: 132\nCase studies: 120\nFindings: 0 ()\n\n✅ No findings.\n"
    assert dic.parse_integrity_findings(text) == (0, 0)


def test_returns_sentinel_when_line_absent():
    """-1 must still mean 'genuinely unparseable', not 'healthy'."""
    assert dic.parse_integrity_findings("make: *** No rule to make target") == (-1, -1)


# ── 2. sweep layer details ───────────────────────────────────────────────────

def _fake_sweep(monkeypatch, payload: dict):
    class _P:
        stdout = json.dumps(payload)
        stderr = ""
        returncode = 0

    monkeypatch.setattr(dic.subprocess, "run", lambda *a, **k: _P())
    monkeypatch.setattr(Path, "exists", lambda self: True)


def test_records_detail_for_failing_layer(monkeypatch):
    _fake_sweep(monkeypatch, {
        "overall": "FAIL",
        "layers": [
            {"layer": "Framework integrity", "status": "FAIL", "detail": "12 findings + 1 advisory"},
            {"layer": "Documentation debt", "status": "PASS", "detail": "1 open item(s)"},
        ],
    })
    out = dic.run_integrity_sweep()
    assert out["overall"] == "FAIL"
    assert out["layers"]["Framework integrity"] == "FAIL"
    # The number is what makes the next cron FAIL diagnosable.
    assert out["layer_details"] == {"Framework integrity": "12 findings + 1 advisory"}


def test_records_detail_for_warn_layer(monkeypatch):
    _fake_sweep(monkeypatch, {
        "overall": "WARN",
        "layers": [{"layer": "Cross-repo sync", "status": "WARN", "detail": "mirror 4321m old"}],
    })
    assert dic.run_integrity_sweep()["layer_details"] == {"Cross-repo sync": "mirror 4321m old"}


def test_omits_details_key_on_all_green(monkeypatch):
    """Append-only ledger must not bloat on the common healthy day."""
    _fake_sweep(monkeypatch, {
        "overall": "PASS",
        "layers": [
            {"layer": "Framework integrity", "status": "PASS", "detail": "0 findings + 0 advisory"},
            {"layer": "Analytics / GA4", "status": "INFO", "detail": "requires GA4 MCP"},
        ],
    })
    out = dic.run_integrity_sweep()
    assert out["overall"] == "PASS"
    assert "layer_details" not in out


def test_never_crashes_the_checkpoint_on_bad_sweep_output(monkeypatch):
    class _P:
        stdout = "not json"
        stderr = ""
        returncode = 1

    monkeypatch.setattr(dic.subprocess, "run", lambda *a, **k: _P())
    monkeypatch.setattr(Path, "exists", lambda self: True)
    assert dic.run_integrity_sweep()["overall"] == "SKIPPED"
