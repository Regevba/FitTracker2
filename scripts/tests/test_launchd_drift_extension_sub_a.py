"""Unit tests for v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (a).

Covers the extended `check_branch_isolation_launchd_drift()` path-resolution
checks in scripts/integrity-check.py:

  (i)   WorkingDirectory exists as a directory
  (ii)  ProgramArguments[0] (script) resolves as a file
  (iii) StandardOutPath / StandardErrorPath parent dir is writable

Tests use monkeypatch to redirect Path.home() so the launchagents scan reads
a controlled tmp dir; plists are constructed with `plistlib.dump()` so the
production code path (`plistlib.load()`) is exercised verbatim.
"""
from __future__ import annotations

import importlib.util
import plistlib
import sys
from pathlib import Path
from unittest.mock import patch

import pytest


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))


def _load(filename: str, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, SCRIPTS_DIR / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def ic():
    return _load("integrity-check.py", "integrity_check_for_sub_a")


@pytest.fixture
def fake_home(tmp_path, monkeypatch):
    """Redirect Path.home() to a tmp dir with a Library/LaunchAgents/ subdir."""
    home = tmp_path / "fake-home"
    launchagents = home / "Library" / "LaunchAgents"
    launchagents.mkdir(parents=True)
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


def _write_plist(launchagents: Path, name: str, plist: dict) -> Path:
    """Write a plist with the given dict to launchagents/<name>.plist."""
    path = launchagents / name
    with open(path, "wb") as f:
        plistlib.dump(plist, f)
    return path


def _force_darwin(monkeypatch):
    monkeypatch.setattr(sys, "platform", "darwin")


# ---------------------------------------------------------------------------
# Skip-on-Linux guard (the gate is macOS-only)
# ---------------------------------------------------------------------------

def test_returns_empty_on_non_darwin(ic, monkeypatch):
    """check_branch_isolation_launchd_drift() returns [] on Linux/Windows."""
    monkeypatch.setattr(sys, "platform", "linux")
    assert ic.check_branch_isolation_launchd_drift() == []


# ---------------------------------------------------------------------------
# Heuristic: _plist_references_ft2
# ---------------------------------------------------------------------------

def test_plist_referenced_by_filename(ic):
    assert ic._plist_references_ft2(Path("com.fittracker.daily.plist"), [], None) is True


def test_plist_referenced_by_program_args(ic):
    assert ic._plist_references_ft2(
        Path("com.example.cron.plist"),
        ["/bin/bash", "/Volumes/DevSSD/FitTracker2/scripts/daily.sh"],
        None,
    ) is True


def test_plist_referenced_by_workingdirectory(ic):
    assert ic._plist_references_ft2(
        Path("com.example.cron.plist"),
        ["/usr/bin/python3", "/tmp/something.py"],
        "/Volumes/DevSSD/FitTracker2",
    ) is True


def test_plist_not_referenced_when_unrelated(ic):
    """Unrelated plist (Spotlight, etc.) is NOT misidentified as FT2."""
    assert ic._plist_references_ft2(
        Path("com.apple.Spotlight.plist"),
        ["/System/Library/Spotlight/SpotlightHelper"],
        "/Users/anonymous",
    ) is False


# ---------------------------------------------------------------------------
# Sub-check (i): WorkingDirectory exists
# ---------------------------------------------------------------------------

def test_working_directory_missing_fires_advisory(ic, fake_home, monkeypatch, tmp_path):
    """WorkingDirectory pointing at a nonexistent path → advisory fires."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    # Script exists; only WorkingDirectory is broken.
    script = tmp_path / "script.sh"
    script.write_text("#!/bin/sh\necho hi\n")
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": "/Volumes/DevSSD 1/nonexistent-after-ssd-migration",
        "ProgramArguments": ["/bin/bash", str(script)],
    })
    findings = ic.check_branch_isolation_launchd_drift()
    msgs = [f["message"] for f in findings]
    assert any("WorkingDirectory" in m and "extant directory" in m for m in msgs)


def test_working_directory_present_no_advisory(ic, fake_home, monkeypatch, tmp_path):
    """WorkingDirectory pointing at an existing dir → no advisory."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    script = tmp_path / "script.sh"
    script.write_text("#!/bin/sh\n")
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["/bin/bash", str(script)],
    })
    findings = ic.check_branch_isolation_launchd_drift()
    wd_msgs = [f for f in findings if "WorkingDirectory" in f["message"] and "extant" in f["message"]]
    assert wd_msgs == []


# ---------------------------------------------------------------------------
# Sub-check (ii): ProgramArguments[0] script exists
# ---------------------------------------------------------------------------

def test_program_args_missing_script_fires_advisory(ic, fake_home, monkeypatch, tmp_path):
    """Script in ProgramArguments doesn't exist on disk → advisory fires."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["/bin/bash", "/Volumes/DevSSD/FitTracker2/scripts/deleted.sh"],
    })
    findings = ic.check_branch_isolation_launchd_drift()
    msgs = [f["message"] for f in findings]
    assert any("ProgramArguments" in m and "extant file" in m for m in msgs)


def test_program_args_present_no_advisory(ic, fake_home, monkeypatch, tmp_path):
    """Script in ProgramArguments exists → no script-resolution advisory."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    script = tmp_path / "script.sh"
    script.write_text("#!/bin/sh\n")
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["/bin/bash", str(script)],
    })
    findings = ic.check_branch_isolation_launchd_drift()
    sm = [f for f in findings if "ProgramArguments" in f["message"] and "extant file" in f["message"]]
    assert sm == []


def test_program_args_relative_path_skipped(ic, fake_home, monkeypatch, tmp_path):
    """Relative paths (rely on PATH) are out of scope — no advisory."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["python3", "scripts/some-script.py"],  # both relative
    })
    findings = ic.check_branch_isolation_launchd_drift()
    sm = [f for f in findings if "ProgramArguments" in f["message"] and "extant file" in f["message"]]
    assert sm == []


# ---------------------------------------------------------------------------
# Sub-check (iii): StandardOutPath / StandardErrorPath parent writable
# ---------------------------------------------------------------------------

def test_standard_out_parent_missing_fires_advisory(ic, fake_home, monkeypatch, tmp_path):
    """StandardOutPath parent dir doesn't exist → advisory fires."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    script = tmp_path / "script.sh"
    script.write_text("#!/bin/sh\n")
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["/bin/bash", str(script)],
        "StandardOutPath": "/Volumes/DevSSD 1/logs/daily.log",
    })
    findings = ic.check_branch_isolation_launchd_drift()
    msgs = [f["message"] for f in findings]
    assert any("StandardOutPath" in m and "parent directory does not exist" in m for m in msgs)


def test_standard_out_parent_writable_no_advisory(ic, fake_home, monkeypatch, tmp_path):
    """StandardOutPath parent dir exists + is writable → no advisory."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    work_dir = tmp_path / "workdir"
    work_dir.mkdir()
    log_dir = tmp_path / "logs"
    log_dir.mkdir()
    script = tmp_path / "script.sh"
    script.write_text("#!/bin/sh\n")
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": str(work_dir),
        "ProgramArguments": ["/bin/bash", str(script)],
        "StandardOutPath": str(log_dir / "out.log"),
        "StandardErrorPath": str(log_dir / "err.log"),
    })
    findings = ic.check_branch_isolation_launchd_drift()
    sp_msgs = [f for f in findings if "StandardOut" in f["message"] or "StandardError" in f["message"]]
    assert sp_msgs == []


# ---------------------------------------------------------------------------
# Compound: a plist with multiple distinct problems emits one advisory per problem
# ---------------------------------------------------------------------------

def test_compound_plist_emits_multiple_advisories(ic, fake_home, monkeypatch):
    """One plist with broken WorkingDirectory + broken script + broken log path → 3 advisories."""
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    _write_plist(launchagents, "com.fittracker.daily.plist", {
        "Label": "com.fittracker.daily",
        "WorkingDirectory": "/Volumes/DevSSD 1/missing",
        "ProgramArguments": ["/bin/bash", "/Volumes/DevSSD 1/scripts/gone.sh"],
        "StandardOutPath": "/Volumes/DevSSD 1/logs/out.log",
    })
    findings = ic.check_branch_isolation_launchd_drift()
    msgs = [f["message"] for f in findings]
    assert any("WorkingDirectory" in m and "extant directory" in m for m in msgs)
    assert any("ProgramArguments" in m and "extant file" in m for m in msgs)
    assert any("StandardOutPath" in m for m in msgs)


# ---------------------------------------------------------------------------
# Negative: unrelated plist is ignored entirely (no false positives)
# ---------------------------------------------------------------------------

def test_unrelated_plist_with_broken_paths_ignored(ic, fake_home, monkeypatch):
    """An unrelated plist (e.g., Spotlight) with broken paths → no findings.

    The point: sub-fix (a) only scans FT2-related plists, so a system plist
    with a stale path doesn't flood the operator with irrelevant noise.
    """
    _force_darwin(monkeypatch)
    launchagents = fake_home / "Library" / "LaunchAgents"
    _write_plist(launchagents, "com.apple.unrelated.plist", {
        "Label": "com.apple.unrelated",
        "WorkingDirectory": "/path/that/does/not/exist",
        "ProgramArguments": ["/usr/bin/no-such-binary"],
    })
    findings = ic.check_branch_isolation_launchd_drift()
    assert findings == []
