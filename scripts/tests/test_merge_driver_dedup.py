"""Tests for scripts/merge-driver-dedup.py (v7.8 Mechanism E).

Covers union-dedup merge of append-only ledgers:
  - .claude/shared/measurement-adoption-history.json (snapshots[], dedup by date)
  - .claude/shared/documentation-debt.json (debt_items[], dedup by id)
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "merge_driver_dedup",
    SCRIPTS_DIR / "merge-driver-dedup.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

merge = _mod.merge
_config_for = _mod._config_for
LEDGER_CONFIG = _mod.LEDGER_CONFIG


# ---------------------------------------------------------------------------
# T1 — config lookup by path suffix
# ---------------------------------------------------------------------------

def test_config_for_adoption_history():
    cfg = _config_for(".claude/shared/measurement-adoption-history.json")
    assert cfg == {"array": "snapshots", "key": "date"}


def test_config_for_documentation_debt():
    cfg = _config_for(".claude/shared/documentation-debt.json")
    assert cfg == {"array": "debt_items", "key": "id"}


def test_config_for_absolute_path_works():
    cfg = _config_for(
        "/Volumes/DevSSD/FitTracker2/.claude/shared/measurement-adoption-history.json"
    )
    assert cfg is not None
    assert cfg["array"] == "snapshots"


def test_config_for_unregistered_returns_none():
    assert _config_for("docs/something.md") is None
    assert _config_for(".claude/shared/random.json") is None


# ---------------------------------------------------------------------------
# T2 — union-dedup merge correctness
# ---------------------------------------------------------------------------

def _write(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def _make_files(tmp_path: Path, ours: dict, theirs: dict, real_path: str):
    """Create the four temp files git would pass in. Returns argv tuple."""
    p_o = tmp_path / "ancestor.json"
    p_a = tmp_path / "ours.json"  # also the OUTPUT path
    p_b = tmp_path / "theirs.json"
    _write(p_o, {})  # ancestor unused — driver ignores %O
    _write(p_a, ours)
    _write(p_b, theirs)
    return str(p_o), str(p_a), str(p_b), real_path


def test_disjoint_snapshots_merge_to_union(tmp_path):
    """No overlapping dates → result is union of both, sorted."""
    ours = {
        "version": "1.0",
        "snapshots": [
            {"date": "2026-04-25", "summary": {"total": 42}},
        ],
    }
    theirs = {
        "version": "1.0",
        "snapshots": [
            {"date": "2026-04-27", "summary": {"total": 43}},
        ],
    }
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    rc = merge(*args)
    assert rc == 0
    result = json.loads(Path(args[1]).read_text())
    dates = [s["date"] for s in result["snapshots"]]
    assert dates == ["2026-04-25", "2026-04-27"]


def test_overlapping_dates_dedup_theirs_wins(tmp_path):
    """Same date in both → theirs wins (later writer convention)."""
    ours = {
        "snapshots": [
            {"date": "2026-04-25", "summary": {"source": "ours"}},
        ],
    }
    theirs = {
        "snapshots": [
            {"date": "2026-04-25", "summary": {"source": "theirs"}},
            {"date": "2026-04-27", "summary": {"source": "theirs"}},
        ],
    }
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    assert merge(*args) == 0
    result = json.loads(Path(args[1]).read_text())
    by_date = {s["date"]: s for s in result["snapshots"]}
    assert by_date["2026-04-25"]["summary"]["source"] == "theirs"
    assert len(result["snapshots"]) == 2


def test_top_level_fields_preserved_from_ours(tmp_path):
    """version / description / updated come from `ours` structurally."""
    ours = {
        "version": "1.0",
        "description": "Append-only daily snapshots",
        "snapshots": [{"date": "2026-04-25"}],
    }
    theirs = {
        "version": "0.9",  # would be wrong — should NOT win
        "snapshots": [{"date": "2026-04-27"}],
    }
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    assert merge(*args) == 0
    result = json.loads(Path(args[1]).read_text())
    assert result["version"] == "1.0"  # ours' top-level wins
    assert result["description"] == "Append-only daily snapshots"
    assert len(result["snapshots"]) == 2


def test_documentation_debt_dedup_by_id(tmp_path):
    """debt_items merge by `id`, theirs wins on collision."""
    ours = {
        "debt_items": [
            {"id": "date_written", "count": 6},
            {"id": "old_only", "count": 1},
        ],
    }
    theirs = {
        "debt_items": [
            {"id": "date_written", "count": 5},  # newer count
            {"id": "new_only", "count": 2},
        ],
    }
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/documentation-debt.json",
    )
    assert merge(*args) == 0
    result = json.loads(Path(args[1]).read_text())
    by_id = {x["id"]: x for x in result["debt_items"]}
    assert by_id["date_written"]["count"] == 5  # theirs won
    assert "old_only" in by_id
    assert "new_only" in by_id
    assert len(result["debt_items"]) == 3


def test_missing_array_treated_as_empty(tmp_path):
    """One side without the array → other side's entries pass through."""
    ours = {"version": "1.0"}
    theirs = {"snapshots": [{"date": "2026-04-25"}]}
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    assert merge(*args) == 0
    result = json.loads(Path(args[1]).read_text())
    assert len(result["snapshots"]) == 1


def test_items_missing_dedup_key_dropped(tmp_path):
    """Malformed item (no `date`) is silently dropped."""
    ours = {"snapshots": [{"date": "2026-04-25"}, {"summary": "no date"}]}
    theirs = {"snapshots": []}
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    assert merge(*args) == 0
    result = json.loads(Path(args[1]).read_text())
    assert len(result["snapshots"]) == 1
    assert result["snapshots"][0]["date"] == "2026-04-25"


# ---------------------------------------------------------------------------
# T3 — error handling
# ---------------------------------------------------------------------------

def test_unregistered_path_returns_1_for_git_fallback(tmp_path):
    args = _make_files(tmp_path, {}, {}, "docs/random.json")
    assert merge(*args) == 1


def test_invalid_json_returns_1(tmp_path):
    p_o = tmp_path / "o.json"
    p_a = tmp_path / "a.json"
    p_b = tmp_path / "b.json"
    p_o.write_text("{}")
    p_a.write_text("{not valid json")
    p_b.write_text("{}")
    rc = merge(
        str(p_o), str(p_a), str(p_b),
        ".claude/shared/documentation-debt.json",
    )
    assert rc == 1


def test_array_not_list_returns_1(tmp_path):
    ours = {"snapshots": "not-a-list"}
    theirs = {"snapshots": []}
    args = _make_files(
        tmp_path, ours, theirs,
        ".claude/shared/measurement-adoption-history.json",
    )
    assert merge(*args) == 1
