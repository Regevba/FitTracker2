"""Shared fixtures for framework gate tests."""
from __future__ import annotations
import json
import shutil
import subprocess
from pathlib import Path
import pytest


@pytest.fixture
def test_repo(tmp_path: Path) -> Path:
    """Create a minimal git repo with .claude/features/ structure."""
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=tmp_path, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=tmp_path, check=True)
    (tmp_path / ".claude" / "features").mkdir(parents=True)
    (tmp_path / ".claude" / "logs").mkdir(parents=True)
    (tmp_path / ".claude" / "shared").mkdir(parents=True)
    return tmp_path


@pytest.fixture
def write_state(test_repo: Path):
    """Helper: write a state.json under .claude/features/<name>/."""
    def _write(name: str, content: dict) -> Path:
        feat_dir = test_repo / ".claude" / "features" / name
        feat_dir.mkdir(parents=True, exist_ok=True)
        path = feat_dir / "state.json"
        path.write_text(json.dumps(content, indent=2) + "\n")
        return path
    return _write
