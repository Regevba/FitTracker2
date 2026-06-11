"""Unit tests for current_distinct_gates() in scripts/weekly-trend-scan.py.

Regression guard for the 2026-06-11 data-lake R1 finding: the weekly
Mechanism A gate-coverage zero-drift observer was structurally blind in CI.
Its source — `.claude/logs/gate-coverage.jsonl` — is gitignored and absent on
the GitHub Actions runner, so `current_distinct_gates()` returned the empty
set and the observer persisted `distinct_gate_count: 0` every week, unable to
ever fire its own "a gate stopped emitting" alert.

Fix: source distinct gates from the committed F17 index
(`.claude/shared/gate-last-fired.json`), which IS tracked and CI-durable,
falling back to the raw ledger only when the index is absent.
"""
import importlib.util
import json
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "weekly_trend_scan",
    Path(__file__).resolve().parent.parent / "weekly-trend-scan.py",
)
wts = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(wts)


def _write_index(tmp_path, gate_names):
    p = tmp_path / "gate-last-fired.json"
    p.write_text(json.dumps({
        "schema_version": 1,
        "gates": {g: {"total_candidates": 1} for g in gate_names},
    }))
    return p


def _write_ledger(tmp_path, gate_names):
    p = tmp_path / "gate-coverage.jsonl"
    p.write_text("".join(
        json.dumps({"timestamp": "2026-06-11T00:00:00Z", "gate": g,
                    "candidates": 1, "checked": 1, "skipped": 0}) + "\n"
        for g in gate_names
    ))
    return p


def test_index_is_source_when_ledger_absent(tmp_path):
    """CI case: ledger missing → must still see the committed index's gates."""
    index = _write_index(tmp_path, ["GATE_A", "GATE_B", "GATE_C"])
    missing_ledger = tmp_path / "does-not-exist.jsonl"
    gates = wts.current_distinct_gates(index_path=index, ledger_path=missing_ledger)
    assert gates == {"GATE_A", "GATE_B", "GATE_C"}


def test_index_preferred_over_ledger_for_consistency(tmp_path):
    """Index is the consistent superset source; both present → index wins
    so the source doesn't flap between environments (local ledger vs CI index)."""
    index = _write_index(tmp_path, ["GATE_A", "GATE_B", "GATE_C", "GATE_D"])
    ledger = _write_ledger(tmp_path, ["GATE_A", "GATE_B"])
    gates = wts.current_distinct_gates(index_path=index, ledger_path=ledger)
    assert gates == {"GATE_A", "GATE_B", "GATE_C", "GATE_D"}


def test_ledger_fallback_when_index_absent(tmp_path):
    """Pre-F17 / index-missing environments still work via the raw ledger."""
    missing_index = tmp_path / "no-index.json"
    ledger = _write_ledger(tmp_path, ["GATE_X", "GATE_Y"])
    gates = wts.current_distinct_gates(index_path=missing_index, ledger_path=ledger)
    assert gates == {"GATE_X", "GATE_Y"}


def test_empty_index_falls_back_to_ledger(tmp_path):
    """An index that exists but lists zero gates must not shadow a live ledger."""
    empty_index = tmp_path / "empty-index.json"
    empty_index.write_text(json.dumps({"schema_version": 1, "gates": {}}))
    ledger = _write_ledger(tmp_path, ["GATE_Z"])
    gates = wts.current_distinct_gates(index_path=empty_index, ledger_path=ledger)
    assert gates == {"GATE_Z"}


def test_both_absent_returns_empty(tmp_path):
    """No index, no ledger → empty set (no crash)."""
    gates = wts.current_distinct_gates(
        index_path=tmp_path / "nope.json",
        ledger_path=tmp_path / "nope.jsonl",
    )
    assert gates == set()


def test_malformed_index_falls_back_to_ledger(tmp_path):
    """A corrupt index JSON must not break the scan — fall back to the ledger."""
    bad_index = tmp_path / "bad-index.json"
    bad_index.write_text("{not valid json")
    ledger = _write_ledger(tmp_path, ["GATE_Q"])
    gates = wts.current_distinct_gates(index_path=bad_index, ledger_path=ledger)
    assert gates == {"GATE_Q"}
