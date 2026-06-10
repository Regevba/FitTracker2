"""F17 — Tests for refresh-gate-last-fired.py.

Covers:
- Empty ledger
- Single-gate single-row
- Single-gate multi-row aggregation
- Multi-gate aggregation
- Malformed JSON row resilience
- Missing required fields (gate, timestamp)
- last_fired_at vs last_checked_at vs last_skipped_at semantics
- Idempotent re-runs (same input → same output)
- Schema_version + source_rows_* metadata
- File-system contract (dest dir auto-created, trailing newline)
"""

from __future__ import annotations

import json
import sys
import importlib.util
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "refresh-gate-last-fired.py"


# Load the script as a module (hyphen prevents direct import).
_spec = importlib.util.spec_from_file_location(
    "refresh_gate_last_fired", SCRIPT_PATH
)
assert _spec is not None and _spec.loader is not None
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


def _write_ledger(path: Path, rows: list[dict]) -> Path:
    """Write a JSONL file from a list of dicts."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row) + "\n")
    return path


# ────────────────────────────────────────────────────────────────────────────
# Empty + missing input
# ────────────────────────────────────────────────────────────────────────────


def test_empty_ledger_produces_empty_gates(tmp_path: Path):
    ledger = _write_ledger(tmp_path / "empty.jsonl", [])
    idx = _mod.refresh_index(ledger)
    assert idx["gates"] == {}
    assert idx["source_rows_read"] == 0
    assert idx["source_rows_malformed"] == 0
    assert idx["schema_version"] == _mod.SCHEMA_VERSION


def test_missing_ledger_raises(tmp_path: Path):
    with pytest.raises(FileNotFoundError):
        _mod.refresh_index(tmp_path / "does-not-exist.jsonl")


# ────────────────────────────────────────────────────────────────────────────
# Single-gate single-row
# ────────────────────────────────────────────────────────────────────────────


def test_single_row_single_gate(tmp_path: Path):
    ledger = _write_ledger(
        tmp_path / "single.jsonl",
        [
            {
                "timestamp": "2026-06-04T10:00:00Z",
                "gate": "TEST_GATE",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            }
        ],
    )
    idx = _mod.refresh_index(ledger)
    assert set(idx["gates"].keys()) == {"TEST_GATE"}
    entry = idx["gates"]["TEST_GATE"]
    assert entry["last_fired_at"] == "2026-06-04T10:00:00Z"
    assert entry["last_checked_at"] == "2026-06-04T10:00:00Z"
    assert entry["last_skipped_at"] is None  # never skipped
    assert entry["first_seen_at"] == "2026-06-04T10:00:00Z"
    assert entry["total_candidates"] == 1
    assert entry["total_firings"] == 1
    assert entry["total_skips"] == 0


# ────────────────────────────────────────────────────────────────────────────
# Aggregation across rows
# ────────────────────────────────────────────────────────────────────────────


def test_multi_row_aggregation_picks_latest_per_field(tmp_path: Path):
    ledger = _write_ledger(
        tmp_path / "multi.jsonl",
        [
            # Earlier fire — should win first_seen_at
            {
                "timestamp": "2026-06-01T00:00:00Z",
                "gate": "G",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            },
            # Later skip — should set last_skipped_at + advance last_checked_at
            {
                "timestamp": "2026-06-02T00:00:00Z",
                "gate": "G",
                "candidates": 1,
                "checked": 0,
                "skipped": 1,
            },
            # Latest fire — should advance last_fired_at + last_checked_at
            {
                "timestamp": "2026-06-03T00:00:00Z",
                "gate": "G",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            },
        ],
    )
    idx = _mod.refresh_index(ledger)
    entry = idx["gates"]["G"]
    assert entry["first_seen_at"] == "2026-06-01T00:00:00Z"
    assert entry["last_fired_at"] == "2026-06-03T00:00:00Z"
    assert entry["last_checked_at"] == "2026-06-03T00:00:00Z"
    assert entry["last_skipped_at"] == "2026-06-02T00:00:00Z"
    assert entry["total_firings"] == 2
    assert entry["total_skips"] == 1
    assert entry["total_candidates"] == 3


def test_multi_gate_isolation(tmp_path: Path):
    """Each gate's aggregates are independent."""
    ledger = _write_ledger(
        tmp_path / "multi-gate.jsonl",
        [
            {
                "timestamp": "2026-06-01T00:00:00Z",
                "gate": "A",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            },
            {
                "timestamp": "2026-06-02T00:00:00Z",
                "gate": "B",
                "candidates": 1,
                "checked": 0,
                "skipped": 1,
            },
        ],
    )
    idx = _mod.refresh_index(ledger)
    assert set(idx["gates"].keys()) == {"A", "B"}
    assert idx["gates"]["A"]["last_fired_at"] == "2026-06-01T00:00:00Z"
    assert idx["gates"]["A"]["last_skipped_at"] is None
    assert idx["gates"]["B"]["last_fired_at"] is None
    assert idx["gates"]["B"]["last_skipped_at"] == "2026-06-02T00:00:00Z"


# ────────────────────────────────────────────────────────────────────────────
# Resilience
# ────────────────────────────────────────────────────────────────────────────


def test_malformed_json_row_is_counted_not_crashed(tmp_path: Path):
    ledger = tmp_path / "with-bad.jsonl"
    with ledger.open("w") as f:
        f.write(
            '{"timestamp":"2026-06-01T00:00:00Z","gate":"GOOD","candidates":1,"checked":1,"skipped":0}\n'
        )
        f.write("not valid json at all\n")
        f.write(
            '{"timestamp":"2026-06-02T00:00:00Z","gate":"GOOD","candidates":1,"checked":1,"skipped":0}\n'
        )
    idx = _mod.refresh_index(ledger)
    assert idx["source_rows_read"] == 3
    assert idx["source_rows_malformed"] == 1
    assert idx["gates"]["GOOD"]["total_firings"] == 2


def test_missing_required_field_is_malformed(tmp_path: Path):
    """A row without `gate` or without `timestamp` counts as malformed."""
    ledger = _write_ledger(
        tmp_path / "missing-fields.jsonl",
        [
            {"timestamp": "2026-06-01T00:00:00Z", "candidates": 1},  # no gate
            {"gate": "X", "candidates": 1},  # no timestamp
            {
                "timestamp": "2026-06-02T00:00:00Z",
                "gate": "X",
                "candidates": 1,
                "checked": 1,
            },
        ],
    )
    idx = _mod.refresh_index(ledger)
    assert idx["source_rows_read"] == 3
    assert idx["source_rows_malformed"] == 2
    assert "X" in idx["gates"]
    assert idx["gates"]["X"]["total_firings"] == 1


def test_blank_lines_skipped_not_counted_as_malformed(tmp_path: Path):
    ledger = tmp_path / "blanks.jsonl"
    with ledger.open("w") as f:
        f.write('{"timestamp":"2026-06-01T00:00:00Z","gate":"G","checked":1}\n')
        f.write("\n")  # blank
        f.write("   \n")  # whitespace
        f.write('{"timestamp":"2026-06-02T00:00:00Z","gate":"G","checked":1}\n')
    idx = _mod.refresh_index(ledger)
    assert idx["source_rows_read"] == 2
    assert idx["source_rows_malformed"] == 0
    assert idx["gates"]["G"]["total_firings"] == 2


# ────────────────────────────────────────────────────────────────────────────
# last_fired_at semantics — strict "checked >= 1"
# ────────────────────────────────────────────────────────────────────────────


def test_last_fired_at_only_advances_on_checked(tmp_path: Path):
    """A row with `checked == 0` does NOT update last_fired_at even if newer."""
    ledger = _write_ledger(
        tmp_path / "fired-semantics.jsonl",
        [
            {
                "timestamp": "2026-06-01T00:00:00Z",
                "gate": "G",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            },
            # Later all-skipped row — should NOT advance last_fired_at
            {
                "timestamp": "2026-06-02T00:00:00Z",
                "gate": "G",
                "candidates": 5,
                "checked": 0,
                "skipped": 5,
            },
        ],
    )
    idx = _mod.refresh_index(ledger)
    entry = idx["gates"]["G"]
    assert entry["last_fired_at"] == "2026-06-01T00:00:00Z"
    assert entry["last_checked_at"] == "2026-06-02T00:00:00Z"  # advanced
    assert entry["last_skipped_at"] == "2026-06-02T00:00:00Z"


# ────────────────────────────────────────────────────────────────────────────
# Idempotent
# ────────────────────────────────────────────────────────────────────────────


def test_idempotent_re_runs(tmp_path: Path):
    ledger = _write_ledger(
        tmp_path / "idempotent.jsonl",
        [
            {
                "timestamp": "2026-06-01T00:00:00Z",
                "gate": "G",
                "candidates": 1,
                "checked": 1,
                "skipped": 0,
            }
        ],
    )
    idx1 = _mod.refresh_index(ledger, now_iso="2026-06-04T12:00:00Z")
    idx2 = _mod.refresh_index(ledger, now_iso="2026-06-04T12:00:00Z")
    assert idx1 == idx2


# ────────────────────────────────────────────────────────────────────────────
# Metadata + schema
# ────────────────────────────────────────────────────────────────────────────


def test_metadata_fields_present(tmp_path: Path):
    ledger = _write_ledger(
        tmp_path / "meta.jsonl",
        [{"timestamp": "2026-06-01T00:00:00Z", "gate": "G", "checked": 1}],
    )
    idx = _mod.refresh_index(ledger, now_iso="2026-06-04T13:00:00Z")
    assert idx["schema_version"] == _mod.SCHEMA_VERSION
    assert idx["refreshed_at"] == "2026-06-04T13:00:00Z"
    assert idx["source_rows_read"] == 1


# ────────────────────────────────────────────────────────────────────────────
# File-system contract
# ────────────────────────────────────────────────────────────────────────────


def test_write_index_creates_parent_dirs(tmp_path: Path):
    idx = {"schema_version": 1, "gates": {}}
    dest = tmp_path / "deeply" / "nested" / "index.json"
    _mod.write_index(idx, dest)
    assert dest.exists()
    assert json.loads(dest.read_text()) == idx


def test_write_index_trailing_newline(tmp_path: Path):
    idx = {"schema_version": 1, "gates": {}}
    dest = tmp_path / "newline.json"
    _mod.write_index(idx, dest)
    assert dest.read_bytes().endswith(b"\n")


# ────────────────────────────────────────────────────────────────────────────
# Int coercion (defensive)
# ────────────────────────────────────────────────────────────────────────────


def test_non_int_count_fields_default_to_zero(tmp_path: Path):
    """Defensive: float counts coerce to int; string counts default to 0."""
    ledger = _write_ledger(
        tmp_path / "weird.jsonl",
        [
            {
                "timestamp": "2026-06-01T00:00:00Z",
                "gate": "G",
                "candidates": 1.5,  # float → 1
                "checked": "not_a_number",  # → 0
                "skipped": 2,
            }
        ],
    )
    idx = _mod.refresh_index(ledger)
    entry = idx["gates"]["G"]
    assert entry["total_candidates"] == 1
    assert entry["total_firings"] == 0
    assert entry["total_skips"] == 2


# ── T13: failure-history merge from integrity snapshots ───────────────────

def _write_snapshot(snap_dir, ts, findings):
    import json as _json
    snap_dir.mkdir(parents=True, exist_ok=True)
    (snap_dir / f"{ts.replace(':', '-')}.json").write_text(
        _json.dumps({"timestamp": ts, "findings": findings}))


def test_merge_failure_history_sets_last_failed_at(tmp_path):
    gates = {}
    snap = tmp_path / "snaps"
    _write_snapshot(snap, "2026-06-01T00:00:00Z", [{"code": "FOO", "severity": "WARN"}])
    _write_snapshot(snap, "2026-06-05T00:00:00Z", [{"code": "FOO", "severity": "INCONSISTENT"}])
    scanned = _mod.merge_failure_history(gates, snap)
    assert scanned == 2
    assert gates["FOO"]["last_failed_at"] == "2026-06-05T00:00:00Z"  # most recent
    assert gates["FOO"]["last_failure_severity"] == "INCONSISTENT"
    assert gates["FOO"]["total_failure_snapshots"] == 2


def test_merge_failure_history_dedups_codes_within_a_snapshot(tmp_path):
    gates = {}
    snap = tmp_path / "snaps"
    # same code twice in one snapshot → counts as ONE failing snapshot
    _write_snapshot(snap, "2026-06-01T00:00:00Z",
                    [{"code": "BAR", "severity": "WARN"}, {"code": "BAR", "severity": "WARN"}])
    _mod.merge_failure_history(gates, snap)
    assert gates["BAR"]["total_failure_snapshots"] == 1


def test_merge_failure_history_creates_entry_for_failure_only_code(tmp_path):
    # a cycle-time code with no coverage row still appears in the index
    gates = {}
    snap = tmp_path / "snaps"
    _write_snapshot(snap, "2026-06-01T00:00:00Z", [{"code": "CYCLE_ONLY", "severity": "ADVISORY"}])
    _mod.merge_failure_history(gates, snap)
    assert "CYCLE_ONLY" in gates
    assert gates["CYCLE_ONLY"]["last_fired_at"] is None  # never emitted coverage
    assert gates["CYCLE_ONLY"]["last_failed_at"] == "2026-06-01T00:00:00Z"


def test_merge_failure_history_missing_dir_is_noop(tmp_path):
    gates = {}
    assert _mod.merge_failure_history(gates, tmp_path / "does-not-exist") == 0
    assert gates == {}


def test_merge_failure_history_malformed_snapshot_skipped(tmp_path):
    gates = {}
    snap = tmp_path / "snaps"; snap.mkdir()
    (snap / "bad.json").write_text("{not json")
    _write_snapshot(snap, "2026-06-01T00:00:00Z", [{"code": "OK", "severity": "WARN"}])
    scanned = _mod.merge_failure_history(gates, snap)
    assert scanned == 1 and "OK" in gates  # bad one skipped, good one counted
