"""Tests for scripts/flock_writer.py.

Covers v7.8 Mechanism I scaffolding (bridge design §4.7.3):
  - flocked() context manager acquires + releases without error on local FS
  - sidecar lockfile is created adjacent to the target
  - NFS-path heuristic refuses to operate
  - write_json_locked convenience wraps it correctly
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

from flock_writer import flocked, write_json_locked, _refuse_nfs  # noqa: E402


def test_flocked_yields_then_releases(tmp_path):
    target = tmp_path / "data.json"
    with flocked(target):
        target.write_text('{"x": 1}')
    assert target.read_text() == '{"x": 1}'
    # Sidecar lockfile should exist after the block
    assert (tmp_path / "data.json.lock").exists()


def test_flocked_sequential_acquires_succeed(tmp_path):
    target = tmp_path / "data.json"
    for i in range(3):
        with flocked(target):
            target.write_text(f'{{"x": {i}}}')
    assert '"x": 2' in target.read_text()


def test_write_json_locked_writes_content(tmp_path):
    target = tmp_path / "data.json"
    write_json_locked(target, '{"key": "value"}\n')
    assert target.read_text() == '{"key": "value"}\n'


def test_refuse_nfs_blocks_known_signatures():
    """Apparent NFS paths raise OSError."""
    with pytest.raises(OSError, match="NFS"):
        _refuse_nfs(Path("/private/var/automount/some/path"))
    with pytest.raises(OSError, match="NFS"):
        _refuse_nfs(Path("/net/server/share"))
    with pytest.raises(OSError, match="NFS"):
        _refuse_nfs(Path("/Network/Servers/foo/bar"))


def test_refuse_nfs_passes_local_paths(tmp_path):
    """Local + external SSD paths pass through cleanly."""
    _refuse_nfs(tmp_path / "local.json")  # tmp_path is local
    _refuse_nfs(Path("/Volumes/DevSSD/FitTracker2/some.json"))  # external SSD


def test_flocked_creates_parent_dir(tmp_path):
    """If the target's parent doesn't exist, flocked() creates it."""
    target = tmp_path / "deep" / "nested" / "data.json"
    with flocked(target):
        target.write_text('{}')
    assert target.exists()
    assert (tmp_path / "deep" / "nested" / "data.json.lock").exists()


def test_flocked_lockfile_sidecar_pattern(tmp_path):
    """Lock is on `<path>.lock`, not on the target itself."""
    target = tmp_path / "data.json"
    target.write_text('{"original": true}')
    with flocked(target):
        # Inside the block, target content is intact (not truncated)
        assert '"original"' in target.read_text()
    assert target.read_text() == '{"original": true}'
