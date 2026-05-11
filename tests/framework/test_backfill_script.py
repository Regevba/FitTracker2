"""Phase 2 — backfill-state-owner.py.

One-shot mechanical script that adds state_owner: 'ft2' to all existing
state.json files. Tests idempotency + correctness."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "backfill-state-owner.py"


def test_backfill_adds_state_owner_to_missing(test_repo: Path, monkeypatch):
    """Features without state_owner get state_owner: 'ft2'."""
    feat_a = test_repo / ".claude" / "features" / "feat-a"
    feat_a.mkdir(parents=True)
    (feat_a / "state.json").write_text(json.dumps({"name": "feat-a", "current_phase": "research"}, indent=2) + "\n")
    feat_b = test_repo / ".claude" / "features" / "feat-b"
    feat_b.mkdir()
    (feat_b / "state.json").write_text(json.dumps({"name": "feat-b", "current_phase": "complete"}, indent=2) + "\n")
    feat_c = test_repo / ".claude" / "features" / "feat-c"
    feat_c.mkdir()
    (feat_c / "state.json").write_text(json.dumps({"name": "feat-c", "state_owner": "ft2", "current_phase": "complete"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    result = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr

    assert json.loads((feat_a / "state.json").read_text())["state_owner"] == "ft2"
    assert json.loads((feat_b / "state.json").read_text())["state_owner"] == "ft2"
    assert json.loads((feat_c / "state.json").read_text())["state_owner"] == "ft2"


def test_backfill_idempotent(test_repo: Path, monkeypatch):
    """Running twice doesn't change anything."""
    feat = test_repo / ".claude" / "features" / "feat-x"
    feat.mkdir(parents=True)
    state_path = feat / "state.json"
    state_path.write_text(json.dumps({"name": "feat-x", "current_phase": "research"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    after_first = state_path.read_text()
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    after_second = state_path.read_text()
    assert after_first == after_second


def test_backfill_inserts_after_name_field(test_repo: Path, monkeypatch):
    """state_owner is inserted as second key (after 'name')."""
    feat = test_repo / ".claude" / "features" / "feat-y"
    feat.mkdir(parents=True)
    (feat / "state.json").write_text(json.dumps({"name": "feat-y", "current_phase": "research", "framework_version": "v7.8.3"}, indent=2) + "\n")

    monkeypatch.chdir(test_repo)
    subprocess.run([sys.executable, str(SCRIPT)], check=True, capture_output=True)
    state = json.loads((feat / "state.json").read_text())
    keys = list(state.keys())
    assert keys[0] == "name"
    assert keys[1] == "state_owner"
