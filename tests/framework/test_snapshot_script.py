"""Per-phase snapshot script — spec §10.

Verifies snapshot-phase-completion.sh creates correct directory structure +
copies expected files + generates manifest + sha256 checksums."""
from __future__ import annotations
import os
import shutil
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "snapshot-phase-completion.sh"


def test_snapshot_creates_dir_with_manifest_and_checksums(tmp_path: Path, monkeypatch):
    """Snapshot script creates ~/Documents/FitTracker2-backups/<date>-<feature>-<phase>/
    with MANIFEST.md + CHECKSUMS.sha256 + state.json copies."""
    # Set up mock home dir to avoid polluting real backups
    fake_home = tmp_path / "fake_home"
    fake_home.mkdir()
    monkeypatch.setenv("HOME", str(fake_home))

    # Set up fake repo with .claude/features/test-feature/state.json
    repo = tmp_path / "repo"
    (repo / ".claude" / "features" / "test-feature").mkdir(parents=True)
    (repo / ".claude" / "features" / "test-feature" / "state.json").write_text('{"name":"test-feature"}\n')
    (repo / ".claude" / "logs").mkdir()
    (repo / ".claude" / "logs" / "test-feature.log.json").write_text('{"events":[]}\n')

    # Init as git repo (script reads commit SHA + branch)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@e.com"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=repo, check=True)
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-qm", "initial"], cwd=repo, check=True)

    # Run snapshot script
    result = subprocess.run(
        ["bash", str(SCRIPT), "phase-0-complete", "test-feature"],
        cwd=repo, capture_output=True, text=True,
    )
    assert result.returncode == 0, f"script failed: {result.stderr}"

    # Find the snapshot dir under fake_home
    backup_root = fake_home / "Documents" / "FitTracker2-backups"
    assert backup_root.exists()
    snapshots = list(backup_root.iterdir())
    assert len(snapshots) == 1
    snapshot_dir = snapshots[0]
    assert "test-feature-phase-0-complete" in snapshot_dir.name

    # Verify expected files
    assert (snapshot_dir / "state.json").exists()
    assert (snapshot_dir / "test-feature.log.json").exists()
    assert (snapshot_dir / "MANIFEST.md").exists()
    assert (snapshot_dir / "CHECKSUMS.sha256").exists()

    # Verify checksums valid
    verify = subprocess.run(["shasum", "-a", "256", "-c", "CHECKSUMS.sha256"],
                            cwd=snapshot_dir, capture_output=True, text=True)
    assert verify.returncode == 0, f"checksum mismatch: {verify.stdout}"
