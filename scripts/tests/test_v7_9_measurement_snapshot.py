"""Tests for scripts/v7-9-measurement-snapshot.py."""
from __future__ import annotations

import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest


def _load_module():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "v7-9-measurement-snapshot.py"
    spec = importlib.util.spec_from_file_location("v7_9_measurement_snapshot", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["v7_9_measurement_snapshot"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load_module()


def test_parse_window_start_default(mod):
    assert mod._parse_window_start(None) == mod.DEFAULT_WINDOW_START


def test_parse_window_start_valid(mod):
    assert mod._parse_window_start("2026-05-11") == "2026-05-11"


def test_parse_window_start_invalid(mod):
    with pytest.raises(SystemExit):
        mod._parse_window_start("not-a-date")


def test_decision_points_pre_first(mod):
    d = mod._decision_points(0)
    assert d["phase"] == "pre_first_snapshot"
    assert "first measurement-window snapshot" in d["next_action"]


def test_decision_points_first_window(mod):
    d = mod._decision_points(7)
    assert d["phase"] == "first_window_open"


def test_decision_points_design_lock(mod):
    d = mod._decision_points(21)
    assert d["phase"] == "design_lock_window"


def test_decision_points_v7_9_ship(mod):
    d = mod._decision_points(28)
    assert d["phase"] == "v7_9_ship_window"


def test_load_gate_coverage_empty_when_file_missing(mod, tmp_path, monkeypatch):
    monkeypatch.setattr(mod, "LOGS_DIR", tmp_path / "missing")
    result = mod.load_gate_coverage("2026-05-04")
    assert result == {}


def test_load_gate_coverage_rolls_up_runs(mod, tmp_path, monkeypatch):
    logs = tmp_path / "logs"
    logs.mkdir()
    f = logs / "gate-coverage.jsonl"
    f.write_text(
        json.dumps({
            "timestamp": "2026-05-05T00:00:00Z",
            "gate": "CACHE_HITS_EMPTY_POST_V6",
            "candidates": 48,
            "checked": 0,
            "skipped": 48,
            "skip_reasons": {"pre_v6": 34, "pre_mechanism_c": 14},
        }) + "\n" +
        json.dumps({
            "timestamp": "2026-05-06T00:00:00Z",
            "gate": "CACHE_HITS_EMPTY_POST_V6",
            "candidates": 48,
            "checked": 1,
            "skipped": 47,
            "skip_reasons": {"pre_v6": 34, "pre_mechanism_c": 13},
        }) + "\n" +
        json.dumps({
            "timestamp": "2026-05-05T00:00:00Z",
            "gate": "FRAMEWORK_VERSION_FORMAT",
            "candidates": 48,
            "checked": 48,
            "skipped": 0,
            "skip_reasons": {},
        }) + "\n"
    )
    monkeypatch.setattr(mod, "LOGS_DIR", logs)
    result = mod.load_gate_coverage("2026-05-04")
    assert "CACHE_HITS_EMPTY_POST_V6" in result
    assert "FRAMEWORK_VERSION_FORMAT" in result
    cache = result["CACHE_HITS_EMPTY_POST_V6"]
    assert cache.runs == 2
    assert cache.total_candidates == 96
    assert cache.total_checked == 1
    assert cache.silent_pass_risk == "low_coverage"  # 1/96 < 5%
    fv = result["FRAMEWORK_VERSION_FORMAT"]
    assert fv.silent_pass_risk == "ok"  # 100%


def test_load_gate_coverage_skips_pre_window_entries(mod, tmp_path, monkeypatch):
    logs = tmp_path / "logs"
    logs.mkdir()
    f = logs / "gate-coverage.jsonl"
    f.write_text(
        json.dumps({
            "timestamp": "2026-05-01T00:00:00Z",
            "gate": "OLD_GATE",
            "candidates": 1,
            "checked": 1,
            "skipped": 0,
        }) + "\n" +
        json.dumps({
            "timestamp": "2026-05-05T00:00:00Z",
            "gate": "NEW_GATE",
            "candidates": 1,
            "checked": 1,
            "skipped": 0,
        }) + "\n"
    )
    monkeypatch.setattr(mod, "LOGS_DIR", logs)
    result = mod.load_gate_coverage("2026-05-04")
    assert "OLD_GATE" not in result
    assert "NEW_GATE" in result


def test_load_gate_coverage_handles_invalid_json_lines(mod, tmp_path, monkeypatch):
    logs = tmp_path / "logs"
    logs.mkdir()
    f = logs / "gate-coverage.jsonl"
    f.write_text(
        "not valid json\n" +
        json.dumps({"timestamp": "2026-05-05T00:00:00Z", "gate": "G", "candidates": 1, "checked": 0, "skipped": 1}) + "\n"
    )
    monkeypatch.setattr(mod, "LOGS_DIR", logs)
    result = mod.load_gate_coverage("2026-05-04")
    assert "G" in result
    assert result["G"].runs == 1


def test_load_session_attribution_aggregates_events(mod, tmp_path, monkeypatch):
    logs = tmp_path / "logs"
    logs.mkdir()
    s1 = logs / "_session-aaa.events.jsonl"
    s1.write_text(
        json.dumps({"timestamp": "2026-05-05T00:00:00Z", "kind": "tool_read", "active_feature": "feat-x"}) + "\n" +
        json.dumps({"timestamp": "2026-05-05T00:00:00Z", "kind": "tool_read", "active_feature": ""}) + "\n" +
        json.dumps({"timestamp": "2026-05-05T00:00:00Z", "kind": "other_event"}) + "\n"
    )
    s2 = logs / "_session-bbb.events.jsonl"
    s2.write_text(
        json.dumps({"timestamp": "2026-05-05T00:00:00Z", "kind": "tool_read", "active_feature": "feat-x"}) + "\n"
    )
    monkeypatch.setattr(mod, "LOGS_DIR", logs)
    result = mod.load_session_attribution("2026-05-04")
    assert result["sessions"] == 2
    assert result["total_read_events"] == 3  # only tool_read counted
    assert result["attributed_events"] == 2
    assert result["unattributed_events"] == 1
    assert result["attribution_rate"] == pytest.approx(2 / 3)
    assert result["events_per_feature"] == {"feat-x": 2}


def test_load_reducer_misses_missing_file(mod, tmp_path, monkeypatch):
    monkeypatch.setattr(mod, "LOGS_DIR", tmp_path / "missing")
    result = mod.load_reducer_misses()
    assert result["misses"] == []
    assert "no merge conflicts" in result["note"]


def test_render_snapshot_complete_shape(mod, tmp_path, monkeypatch):
    logs = tmp_path / "logs"
    logs.mkdir()
    monkeypatch.setattr(mod, "LOGS_DIR", logs)
    snapshot = mod.render_snapshot("2026-05-04")
    assert snapshot["window_start"] == "2026-05-04"
    assert "gate_coverage_summary" in snapshot
    assert "session_attribution" in snapshot
    assert "reducer_misses" in snapshot
    assert "decision_points" in snapshot
    assert snapshot["decision_points"]["phase"] in {
        "pre_first_snapshot",
        "first_window_open",
        "second_window_open",
        "design_lock_window",
        "v7_9_ship_window",
    }


def test_render_markdown_runs_against_real_repo(mod):
    """Smoke: real repo state must render without raising."""
    snapshot = mod.render_snapshot(mod.DEFAULT_WINDOW_START)
    md = mod.render_markdown(snapshot)
    assert "v7.9 Measurement Snapshot" in md
    assert "Mechanism A" in md
    assert "Mechanism C" in md
