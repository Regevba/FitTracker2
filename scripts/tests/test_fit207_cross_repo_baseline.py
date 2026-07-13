"""FIT-207 — fitme-story cross-repo shared-state baseline in the daily checkpoint.

The daily integrity checkpoint captures FT2's forensic state plus fitme-story's
git head; FIT-207 adds the sibling repo's *shared state*: the sync-freshness
marker and a gate-coverage mirror-vs-source drift summary. These tests cover:

  1. Behavioral — summarize_fitme_story_cross_repo_state() reports freshness
     presence, mirror/source row counts, an in-sync verdict, and inventory.
  2. Drift verdict — fresh mirror → in_sync True; stalled mirror → False;
     missing inputs → None (never raises).
  3. Failure-safety — an absent fitme-story checkout degrades to a typed marker.
  4. Structural — the summarizer is invoked inside write_snapshot so a refactor
     can't silently drop the step-5b capture.
"""
from __future__ import annotations

import ast
import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
SCRIPT_PATH = SCRIPTS_DIR / "daily-integrity-checkpoint.py"

sys.path.insert(0, str(SCRIPTS_DIR))
_spec = importlib.util.spec_from_file_location("daily_integrity_checkpoint", SCRIPT_PATH)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]


def _make_fs_repo(tmp_path: Path, *, mirror_rows: int | None, freshness: bool) -> Path:
    """Build a minimal fake fitme-story checkout under tmp_path."""
    fs = tmp_path / "fitme-story"
    data = fs / "src" / "data"
    (data / "integrity").mkdir(parents=True)
    if freshness:
        (data / "freshness.json").write_text("{}")
    if mirror_rows is not None:
        (data / "integrity" / "gate-coverage-ft2.jsonl").write_text(
            "\n".join('{"gate":"G"}' for _ in range(mirror_rows))
        )
    (data / "features").mkdir()
    (data / "features" / "a.json").write_text("{}")
    (data / "features" / "b.json").write_text("{}")
    (data / "logs").mkdir()
    (data / "logs" / "a.log.json").write_text("{}")
    return fs


def _make_ft2_source(tmp_path: Path, rows: int) -> Path:
    src = tmp_path / "gate-coverage.jsonl"
    src.write_text("\n".join('{"gate":"G"}' for _ in range(rows)))
    return src


# ---------------------------------------------------------------- behavioral

def test_absent_fitme_story_repo_degrades_gracefully(tmp_path):
    summary = _mod.summarize_fitme_story_cross_repo_state(
        tmp_path / "does-not-exist", tmp_path / "gc.jsonl"
    )
    assert summary["present"] is False
    assert summary["reason"] == "fitme_story_repo_absent"
    # No raise, no gate_coverage_mirror key required when absent.


def test_fresh_mirror_is_in_sync(tmp_path):
    fs = _make_fs_repo(tmp_path, mirror_rows=1000, freshness=True)
    src = _make_ft2_source(tmp_path, rows=1000)
    summary = _mod.summarize_fitme_story_cross_repo_state(fs, src)

    assert summary["present"] is True
    assert summary["freshness_present"] is True
    gc = summary["gate_coverage_mirror"]
    assert gc["mirror_rows"] == 1000
    assert gc["ft2_source_rows"] == 1000
    assert gc["delta_source_minus_mirror"] == 0
    assert gc["mirror_in_sync"] is True
    assert summary["synced_inventory"]["features"] == 2
    assert summary["synced_inventory"]["logs"] == 1


def test_slightly_behind_mirror_within_tolerance_is_in_sync(tmp_path):
    # Mirror 20 rows behind a 1000-row source → within max(50, 1000//20)=50.
    fs = _make_fs_repo(tmp_path, mirror_rows=980, freshness=True)
    src = _make_ft2_source(tmp_path, rows=1000)
    gc = _mod.summarize_fitme_story_cross_repo_state(fs, src)["gate_coverage_mirror"]
    assert gc["delta_source_minus_mirror"] == 20
    assert gc["mirror_in_sync"] is True


def test_stalled_mirror_far_behind_is_out_of_sync(tmp_path):
    # Mirror 500 rows behind a 1000-row source → far beyond tolerance.
    fs = _make_fs_repo(tmp_path, mirror_rows=500, freshness=True)
    src = _make_ft2_source(tmp_path, rows=1000)
    gc = _mod.summarize_fitme_story_cross_repo_state(fs, src)["gate_coverage_mirror"]
    assert gc["delta_source_minus_mirror"] == 500
    assert gc["mirror_in_sync"] is False


def test_mirror_ahead_of_source_is_out_of_sync(tmp_path):
    # Negative delta (mirror ahead) is anomalous → not in sync.
    fs = _make_fs_repo(tmp_path, mirror_rows=1100, freshness=True)
    src = _make_ft2_source(tmp_path, rows=1000)
    gc = _mod.summarize_fitme_story_cross_repo_state(fs, src)["gate_coverage_mirror"]
    assert gc["delta_source_minus_mirror"] == -100
    assert gc["mirror_in_sync"] is False


def test_missing_inputs_yield_none_verdict(tmp_path):
    fs = _make_fs_repo(tmp_path, mirror_rows=None, freshness=False)  # no mirror file
    src = tmp_path / "no-source.jsonl"  # missing source
    summary = _mod.summarize_fitme_story_cross_repo_state(fs, src)
    assert summary["freshness_present"] is False
    gc = summary["gate_coverage_mirror"]
    assert gc["mirror_rows"] is None
    assert gc["ft2_source_rows"] is None
    assert gc["mirror_in_sync"] is None


# ---------------------------------------------------------------- structural

def test_summarizer_invoked_inside_write_snapshot():
    tree = ast.parse(SCRIPT_PATH.read_text())
    write_snapshot = next(
        n for n in ast.walk(tree)
        if isinstance(n, ast.FunctionDef) and n.name == "write_snapshot"
    )
    calls = {
        node.func.id
        for node in ast.walk(write_snapshot)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
    }
    assert "summarize_fitme_story_cross_repo_state" in calls, (
        "FIT-207 step 5b must call summarize_fitme_story_cross_repo_state "
        "inside write_snapshot so the capture can't be silently dropped"
    )
