"""V9 — Mechanism E custom git merge driver covers .claude/logs/<feature>.log.json.

Per spec §10 / Phase 0. Extends existing union-dedup-by-key driver
(measurement-adoption-history.json + documentation-debt.json) to handle
Tier 2.2 contemporaneous feature logs."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

DRIVER = Path(__file__).resolve().parents[2] / "scripts" / "merge-driver-dedup.py"


def run_driver(ours_path: Path, theirs_path: Path, ancestor_path: Path, real_path: str) -> int:
    """Invoke the driver with git's merge-driver argument convention (%O %A %B %P)."""
    result = subprocess.run(
        [sys.executable, str(DRIVER), str(ancestor_path), str(ours_path), str(theirs_path), real_path],
        capture_output=True, text=True,
    )
    return result.returncode


def test_v9_feature_log_union_dedup(tmp_path: Path):
    """Two diverging feature log files merge via union-dedup-by-key on event timestamps."""
    ours = tmp_path / "ours.json"
    theirs = tmp_path / "theirs.json"
    ancestor = tmp_path / "ancestor.json"

    ancestor.write_text(json.dumps({
        "feature": "test-feature",
        "events": [{"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"}],
    }))
    ours.write_text(json.dumps({
        "feature": "test-feature",
        "events": [
            {"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"},
            {"ts": "2026-05-12T01:00:00Z", "event_type": "phase_approved", "phase": "research"},
        ],
    }))
    theirs.write_text(json.dumps({
        "feature": "test-feature",
        "events": [
            {"ts": "2026-05-12T00:00:00Z", "event_type": "phase_started", "phase": "research"},
            {"ts": "2026-05-12T02:00:00Z", "event_type": "phase_started", "phase": "prd"},
        ],
    }))

    code = run_driver(ours, theirs, ancestor, ".claude/logs/test-feature.log.json")
    assert code == 0, "driver should return 0 on successful merge"

    merged = json.loads(ours.read_text())
    timestamps = sorted(e["ts"] for e in merged["events"])
    assert timestamps == [
        "2026-05-12T00:00:00Z",
        "2026-05-12T01:00:00Z",
        "2026-05-12T02:00:00Z",
    ], f"expected union-dedup; got {timestamps}"


def test_v9_feature_log_idempotent_when_no_conflict(tmp_path: Path):
    """If ours == theirs, merge result is identical."""
    ours = tmp_path / "ours.json"
    theirs = tmp_path / "theirs.json"
    ancestor = tmp_path / "ancestor.json"

    content = {"feature": "x", "events": [{"ts": "2026-05-12T00:00:00Z", "event_type": "x", "phase": "x"}]}
    ancestor.write_text(json.dumps(content))
    ours.write_text(json.dumps(content))
    theirs.write_text(json.dumps(content))

    code = run_driver(ours, theirs, ancestor, ".claude/logs/x.log.json")
    assert code == 0
    merged = json.loads(ours.read_text())
    assert merged == content
