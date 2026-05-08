"""Tests for scripts/membrane-status.py (v7.8 Mechanism F advisory)."""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest


def _load_module():
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "membrane-status.py"
    spec = importlib.util.spec_from_file_location("membrane_status", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["membrane_status"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load_module()


def test_load_leases_returns_default_when_file_missing(mod, tmp_path, monkeypatch):
    monkeypatch.setattr(mod, "LEASES_FILE", tmp_path / "missing.json")
    data = mod._load_leases()
    assert data == {"version": "1.0", "epoch": 0, "leases": []}


def test_load_leases_handles_invalid_json(mod, tmp_path, monkeypatch):
    bad = tmp_path / "agent-leases.json"
    bad.write_text("not json {[")
    monkeypatch.setattr(mod, "LEASES_FILE", bad)
    data = mod._load_leases()
    assert data == {"version": "1.0", "epoch": 0, "leases": []}


def test_load_features_skips_invalid_json(mod, tmp_path, monkeypatch):
    fdir = tmp_path / "features"
    (fdir / "good").mkdir(parents=True)
    (fdir / "good" / "state.json").write_text(json.dumps({
        "current_phase": "complete", "framework_version": "v7.8",
        "branch": "feature/good"
    }))
    (fdir / "bad").mkdir()
    (fdir / "bad" / "state.json").write_text("{not json")
    monkeypatch.setattr(mod, "FEATURES_DIR", fdir)
    out = mod._load_features()
    assert len(out) == 1
    assert out[0]["slug"] == "good"
    assert out[0]["current_phase"] == "complete"
    assert out[0]["framework_version"] == "v7.8"


def test_render_status_sorts_by_mtime_desc(mod, tmp_path, monkeypatch):
    fdir = tmp_path / "features"
    older = fdir / "older"
    newer = fdir / "newer"
    older.mkdir(parents=True)
    newer.mkdir()
    (older / "state.json").write_text(json.dumps({"current_phase": "complete"}))
    (newer / "state.json").write_text(json.dumps({"current_phase": "tasks"}))
    # Force older mtime on the older entry.
    import os, time
    older_t = time.time() - 3600
    os.utime(older / "state.json", (older_t, older_t))
    monkeypatch.setattr(mod, "FEATURES_DIR", fdir)
    monkeypatch.setattr(mod, "LEASES_FILE", tmp_path / "missing.json")
    monkeypatch.setattr(mod, "_open_branches", lambda: {})
    status = mod.render_status()
    slugs = [f["slug"] for f in status["features"]]
    assert slugs == ["newer", "older"]


def test_render_status_emits_advisory_note(mod, monkeypatch, tmp_path):
    monkeypatch.setattr(mod, "FEATURES_DIR", tmp_path / "missing")
    monkeypatch.setattr(mod, "LEASES_FILE", tmp_path / "missing.json")
    monkeypatch.setattr(mod, "_open_branches", lambda: {})
    status = mod.render_status()
    assert "v7.8 Mechanism F is advisory" in status["_advisory_note"]
    assert status["feature_count"] == 0


def test_render_ascii_truncates_to_30_features(mod, tmp_path, monkeypatch):
    fdir = tmp_path / "features"
    fdir.mkdir()
    for i in range(35):
        d = fdir / f"feature-{i:02d}"
        d.mkdir()
        (d / "state.json").write_text(json.dumps({"current_phase": "complete"}))
    monkeypatch.setattr(mod, "FEATURES_DIR", fdir)
    monkeypatch.setattr(mod, "LEASES_FILE", tmp_path / "missing.json")
    monkeypatch.setattr(mod, "_open_branches", lambda: {})
    status = mod.render_status()
    text = mod.render_ascii(status)
    assert "+5 more" in text


def test_render_status_runs_against_real_repo(mod):
    """Smoke test: real repo should produce at least one feature without raising."""
    status = mod.render_status()
    assert status["feature_count"] >= 1
    assert "generated_at" in status
