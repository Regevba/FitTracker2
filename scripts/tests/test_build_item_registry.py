"""Tests for scripts/build-item-registry.py (FIT-200 crosswalk generator)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "build-item-registry.py"
_spec = importlib.util.spec_from_file_location("build_item_registry", _MOD)
bir = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bir)


def test_unified_status_complete_is_done():
    assert bir.unified_status({"current_phase": "complete"}) == "Done"


def test_unified_status_inflight_is_in_progress():
    assert bir.unified_status({"current_phase": "implementation"}) == "In Progress"


def test_unified_status_planning():
    assert bir.unified_status({"current_phase": "prd"}) == "Planned"


def test_unified_status_blocked_signal():
    assert bir.unified_status({"current_phase": "implementation", "blocked_on": "x"}) == "Blocked"


def test_unified_status_no_phase_is_backlog():
    assert bir.unified_status({}) == "Backlog"


def test_collect_prs_merges_all_sources_deduped_sorted():
    state = {
        "related_prs": [10, "12", 10],
        "phases": {"merge": {"pr_number": 11}},
        "tasks": [{"pr_number": 12}, {"pr_number": 13}, {"status": "done"}],
    }
    assert bir.collect_prs(state) == [10, 11, 12, 13]


def test_collect_prs_empty():
    assert bir.collect_prs({}) == []


def test_build_shape_and_coverage(tmp_path, monkeypatch):
    import json
    feats = tmp_path / ".claude" / "features"
    (feats / "alpha").mkdir(parents=True)
    (feats / "beta").mkdir(parents=True)
    (feats / "alpha" / "state.json").write_text(json.dumps({
        "current_phase": "complete", "linear_id": "FIT-1",
        "thematic_codes": ["FW-F4"], "related_prs": [5],
    }))
    (feats / "beta" / "state.json").write_text(json.dumps({
        "current_phase": "implementation",  # no linear_id → missing join
    }))
    monkeypatch.setattr(bir, "FEATURES_DIR", feats)
    reg = bir.build()
    assert reg["coverage"]["total"] == 2
    assert reg["coverage"]["with_linear_id"] == 1
    assert reg["coverage"]["missing_linear_id"] == 1
    by = {it["slug"]: it for it in reg["items"]}
    assert by["alpha"]["status"] == "Done"
    assert by["alpha"]["linear_id"] == "FIT-1"
    assert by["alpha"]["prs"] == [5]
    assert by["beta"]["status"] == "In Progress"
    assert by["beta"]["linear_id"] is None
