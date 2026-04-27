#!/usr/bin/env python3
"""Tests for scripts/log-cache-hit.py — the auto-discovering cache-hit wrapper.

T2 / PR-1 of framework v7.7 Validity Closure.

Verifies:
  1. Active-feature auto-discovery appends to BOTH state.json.cache_hits[] AND
     the events log (dual-write requirement).
  2. Fail-soft when no active feature exists (exit 0, no crash).
  3. mtime ordering: picks the most-recently-modified non-paused feature.
  4. Paused-but-recently-modified features are skipped in favour of
     unpaused ones.
  5. Fail-soft when append-feature-log.py itself errors: still exits 0 and
     still writes state.json.cache_hits[] (state-write side-steps the error).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

# Resolve the scripts/ directory relative to this test file so we can locate
# both log-cache-hit.py and append-feature-log.py regardless of cwd.
SCRIPTS_DIR = Path(__file__).resolve().parents[1]
WRAPPER = SCRIPTS_DIR / "log-cache-hit.py"
APPEND_SCRIPT = SCRIPTS_DIR / "append-feature-log.py"


def _run_wrapper(repo_root: Path, extra_args: list[str]) -> subprocess.CompletedProcess:
    """Run log-cache-hit.py with REPO_ROOT env override so the wrapper finds
    the synthetic temp-repo rather than the real repo."""
    env = {**os.environ, "LOG_CACHE_HIT_REPO_ROOT": str(repo_root)}
    return subprocess.run(
        [sys.executable, str(WRAPPER)] + extra_args,
        capture_output=True,
        text=True,
        env=env,
    )


def _make_feature(
    repo_root: Path,
    slug: str,
    *,
    paused: bool = False,
    cache_hits: list | None = None,
) -> Path:
    """Create a minimal feature directory with a state.json."""
    state_dir = repo_root / ".claude" / "features" / slug
    state_dir.mkdir(parents=True, exist_ok=True)
    state: dict = {
        "feature_name": slug,
        "current_phase": "implementation",
        "cache_hits": cache_hits if cache_hits is not None else [],
    }
    if paused:
        state["paused"] = {"at": "2026-04-27T14:00:00Z", "reason": "test pause"}
    (state_dir / "state.json").write_text(json.dumps(state, indent=2) + "\n")
    return state_dir / "state.json"


# ---------------------------------------------------------------------------
# T1: active-feature append — dual-write (state.json + events log)
# ---------------------------------------------------------------------------

def test_appends_entry_to_active_feature(tmp_path):
    """Wrapper appends one entry to state.json.cache_hits[] AND to the events log."""
    _make_feature(tmp_path, "test-feature")

    result = _run_wrapper(tmp_path, ["--key", "skill:pm-workflow", "--layer", "L1"])

    assert result.returncode == 0, f"Expected exit 0, got {result.returncode}.\nstderr: {result.stderr}"

    # --- state.json side ---
    state_path = tmp_path / ".claude" / "features" / "test-feature" / "state.json"
    state = json.loads(state_path.read_text())
    hits = state.get("cache_hits", [])
    assert len(hits) == 1, f"Expected 1 cache_hits entry, got {hits}"
    hit = hits[0]
    assert hit["key"] == "skill:pm-workflow"
    assert hit["layer"] == "L1"
    assert hit["ts"].endswith("Z"), f"Timestamp must end in Z, got: {hit['ts']}"

    # --- events log side ---
    log_path = tmp_path / ".claude" / "logs" / "test-feature.log.json"
    assert log_path.exists(), "Events log was not created"
    log = json.loads(log_path.read_text())
    events = log.get("events", [])
    assert len(events) >= 1, f"Expected at least 1 event, got {events}"
    # Find the cache_hit event
    cache_events = [e for e in events if e.get("cache_hit") or e.get("event_type") == "cache_hit_logged"]
    assert len(cache_events) >= 1, f"No cache_hit event found in log events: {events}"


# ---------------------------------------------------------------------------
# T2: fail-soft when no active feature
# ---------------------------------------------------------------------------

def test_fails_soft_when_no_active_feature(tmp_path):
    """No .claude/features/*/state.json exists — wrapper exits 0 silently."""
    # Don't create any feature dirs
    result = _run_wrapper(tmp_path, ["--key", "skill:pm-workflow", "--layer", "L2"])

    assert result.returncode == 0, (
        f"Expected exit 0 (fail-soft), got {result.returncode}.\n"
        f"stderr: {result.stderr}"
    )


# ---------------------------------------------------------------------------
# T3: mtime ordering — picks the most-recently-modified non-paused feature
# ---------------------------------------------------------------------------

def test_picks_most_recently_modified_feature(tmp_path):
    """Two unpaused features exist; wrapper writes to the newer one only."""
    older_state = _make_feature(tmp_path, "older-feature")
    time.sleep(0.05)  # ensure distinct mtime
    newer_state = _make_feature(tmp_path, "newer-feature")

    result = _run_wrapper(tmp_path, ["--key", "skill:ux", "--layer", "L2"])

    assert result.returncode == 0, f"stderr: {result.stderr}"

    newer_data = json.loads(newer_state.read_text())
    older_data = json.loads(older_state.read_text())

    assert len(newer_data.get("cache_hits", [])) == 1, (
        "Expected newer-feature to receive the cache hit"
    )
    assert len(older_data.get("cache_hits", [])) == 0, (
        "Expected older-feature to be untouched"
    )


# ---------------------------------------------------------------------------
# T4: paused-but-recently-modified feature is skipped
# ---------------------------------------------------------------------------

def test_skips_paused_feature_in_favour_of_unpaused(tmp_path):
    """A paused feature modified more recently is skipped; unpaused older feature wins."""
    unpaused_state = _make_feature(tmp_path, "active-feature", paused=False)
    time.sleep(0.05)
    paused_state = _make_feature(tmp_path, "paused-feature", paused=True)
    # Now paused-feature has the most-recent mtime — but it must be skipped.

    result = _run_wrapper(tmp_path, ["--key", "skill:dev", "--layer", "L1"])

    assert result.returncode == 0, f"stderr: {result.stderr}"

    active_data = json.loads(unpaused_state.read_text())
    paused_data = json.loads(paused_state.read_text())

    assert len(active_data.get("cache_hits", [])) == 1, (
        "Expected active-feature to receive the cache hit (paused skipped)"
    )
    assert len(paused_data.get("cache_hits", [])) == 0, (
        "Paused feature must not receive cache hits"
    )


# ---------------------------------------------------------------------------
# T5: fail-soft when append-feature-log.py errors
# ---------------------------------------------------------------------------

def test_fails_soft_on_append_feature_log_error(tmp_path, monkeypatch):
    """append-feature-log.py errors but wrapper still exits 0 and still writes
    state.json.cache_hits[].

    Strategy: monkeypatch the APPEND_SCRIPT path env var to point at a script
    that always exits 1 — the wrapper must not propagate the error.
    """
    _make_feature(tmp_path, "test-feature")

    # Write a broken stub that exits non-zero
    broken_script = tmp_path / "broken-append.py"
    broken_script.write_text("import sys; sys.exit(1)\n")
    broken_script.chmod(0o755)

    env = {
        **os.environ,
        "LOG_CACHE_HIT_REPO_ROOT": str(tmp_path),
        "LOG_CACHE_HIT_APPEND_SCRIPT": str(broken_script),
    }
    result = subprocess.run(
        [sys.executable, str(WRAPPER), "--key", "skill:qa", "--layer", "L3"],
        capture_output=True,
        text=True,
        env=env,
    )

    assert result.returncode == 0, (
        f"Wrapper must exit 0 even when append-feature-log.py fails.\n"
        f"stderr: {result.stderr}"
    )

    # state.json.cache_hits[] must still be written (the state write happens in
    # the wrapper itself, independently of the subprocess call).
    state_path = tmp_path / ".claude" / "features" / "test-feature" / "state.json"
    state = json.loads(state_path.read_text())
    hits = state.get("cache_hits", [])
    assert len(hits) == 1, (
        f"state.json.cache_hits[] must be written even when events-log subprocess fails. "
        f"Got: {hits}"
    )
