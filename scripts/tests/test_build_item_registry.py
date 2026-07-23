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


def test_unified_status_wont_do_marker_wins_over_paused():
    # A parked-permanently feature is also paused; Won't-Do must win.
    assert bir.unified_status({"current_phase": "tasks_phase", "paused": True, "wont_do": True}) == "Won't-Do"


def test_unified_status_linear_canceled_is_wont_do():
    assert bir.unified_status({"current_phase": "prd", "linear_status": "Canceled"}) == "Won't-Do"


def test_unified_status_paused_without_wont_do_still_blocked():
    # Regression guard: a normal pause (no wont_do / cancel) stays Blocked.
    assert bir.unified_status({"current_phase": "tasks_phase", "paused": True}) == "Blocked"


def test_unified_status_completed_wins_over_wont_do():
    assert bir.unified_status({"current_phase": "complete", "wont_do": True}) == "Done"


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


# ─────────────────────────────────────────────────────────────
# Freshness guard (added 2026-07-23) — the derived index must be able to
# prove it still describes the corpus. Regression-proof for the drift that
# let item-registry.json sit at 118 items against a 132-feature corpus.
# ─────────────────────────────────────────────────────────────


def _corpus(tmp_path, specs: dict) -> Path:
    import json
    feats = tmp_path / ".claude" / "features"
    for slug, state in specs.items():
        (feats / slug).mkdir(parents=True)
        (feats / slug / "state.json").write_text(json.dumps(state))
    return feats


def _wire(monkeypatch, feats: Path, registry: Path):
    monkeypatch.setattr(bir, "FEATURES_DIR", feats)
    monkeypatch.setattr(bir, "REGISTRY", registry)


def test_fingerprint_is_deterministic_across_calls():
    items = [{"slug": "a", "linear_id": "FIT-1"}, {"slug": "b", "linear_id": None}]
    assert bir.fingerprint(items) == bir.fingerprint(list(items))


def test_fingerprint_changes_when_a_join_relevant_field_changes():
    before = bir.fingerprint([{"slug": "a", "linear_id": None}])
    after = bir.fingerprint([{"slug": "a", "linear_id": "FIT-1"}])
    assert before != after


def test_build_embeds_matching_fingerprint(tmp_path, monkeypatch):
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    monkeypatch.setattr(bir, "FEATURES_DIR", feats)
    reg = bir.build()
    assert reg["source_fingerprint"] == bir.fingerprint(reg["items"])


def test_freshness_fresh_after_write(tmp_path, monkeypatch):
    import json
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    registry.write_text(json.dumps(bir.build()))
    v = bir.freshness()
    assert v["stale"] is False and v["reason"] == "fresh"
    assert v["registry_items"] == v["live_items"] == 1


def test_freshness_detects_a_new_feature_the_index_never_saw(tmp_path, monkeypatch):
    """The exact 2026-07-23 drift: corpus grew, index didn't."""
    import json
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    registry.write_text(json.dumps(bir.build()))          # index captured at 1 feature
    (feats / "t4-snapshot").mkdir()
    (feats / "t4-snapshot" / "state.json").write_text(json.dumps({"current_phase": "implement"}))
    v = bir.freshness()
    assert v["stale"] is True and v["reason"] == "fingerprint_mismatch"
    assert v["registry_items"] == 1 and v["live_items"] == 2


def test_freshness_detects_a_phase_advance_with_no_count_change(tmp_path, monkeypatch):
    """Count-only checks miss this; the fingerprint doesn't."""
    import json
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "implementation"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    registry.write_text(json.dumps(bir.build()))
    (feats / "alpha" / "state.json").write_text(json.dumps({"current_phase": "complete"}))
    v = bir.freshness()
    assert v["stale"] is True
    assert v["registry_items"] == v["live_items"] == 1     # same count, still stale


def test_freshness_missing_registry_is_stale(tmp_path, monkeypatch):
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    _wire(monkeypatch, feats, tmp_path / "absent.json")
    assert bir.freshness() == {
        "stale": True, "reason": "registry_missing", "registry_items": None,
        "live_items": 1, "fingerprint_match": False,
    }


def test_freshness_unreadable_registry_is_stale(tmp_path, monkeypatch):
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    registry.write_text("{not json")
    _wire(monkeypatch, feats, registry)
    assert bir.freshness()["reason"] == "registry_unreadable"


def test_freshness_pre_fingerprint_registry_is_stale(tmp_path, monkeypatch):
    """A legacy registry cannot prove freshness — that is what hid the drift."""
    import json
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    legacy = bir.build()
    legacy.pop("source_fingerprint")
    registry.write_text(json.dumps(legacy))
    _wire(monkeypatch, feats, registry)
    v = bir.freshness()
    assert v["stale"] is True and v["reason"] == "no_fingerprint_pre_2026_07_23_format"


def test_check_exit_code_3_when_stale(tmp_path, monkeypatch, capsys):
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    _wire(monkeypatch, feats, tmp_path / "absent.json")
    assert bir.main(["--check"]) == 3
    assert "STALE" in capsys.readouterr().out


def test_check_exit_code_0_and_json_when_fresh(tmp_path, monkeypatch, capsys):
    import json
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    registry.write_text(json.dumps(bir.build()))
    assert bir.main(["--check", "--json"]) == 0
    assert json.loads(capsys.readouterr().out.strip())["stale"] is False


def test_check_never_writes_the_registry(tmp_path, monkeypatch):
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    bir.main(["--check", "--quiet"])
    assert not registry.exists()


def test_write_is_idempotent_byte_for_byte(tmp_path, monkeypatch):
    """No clock in the payload → re-running produces zero diff (no churn)."""
    feats = _corpus(tmp_path, {"alpha": {"current_phase": "complete"}})
    registry = tmp_path / "item-registry.json"
    _wire(monkeypatch, feats, registry)
    bir.main(["--quiet"])
    first = registry.read_bytes()
    bir.main(["--quiet"])
    assert registry.read_bytes() == first
