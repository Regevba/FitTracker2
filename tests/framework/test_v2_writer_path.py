"""V2 — Mechanism C writer-path enforced (CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT).

Promotes the cache_hits[] writer-path gate from advisory (v7.8) to
enforced (v7.8.3) per spec §3.5.2 Phase 0 calibration target."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check-state-schema.py"


def run_check(state_path: Path) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(state_path)],
        capture_output=True, text=True,
    )
    return result.returncode, result.stderr + result.stdout


def test_v2_post_v6_with_empty_cache_hits_and_session_reads_fails(write_state, test_repo):
    """When state.json is post-v6 (framework_version >= v6.0) AND post-Mechanism-C
    (created_at >= 2026-05-02) AND has corresponding session Read events
    BUT cache_hits[] is empty, V2 enforcement MUST reject."""
    state_path = write_state("test-feature", {
        "name": "test-feature",
        "framework_version": "v7.8.3",
        "created_at": "2026-05-12T00:00:00Z",
        "current_phase": "complete",
        "case_study_type": "no_case_study_required",
        "case_study_exempt_reason": "test fixture",
        "cache_hits": [],
    })
    # Simulate session events showing Read activity
    session_log = test_repo / ".claude" / "logs" / "_session-test.events.jsonl"
    session_log.write_text(json.dumps({"feature": "test-feature", "tool": "Read", "ts": "2026-05-12T01:00:00Z"}) + "\n")
    code, output = run_check(state_path)
    assert code != 0, f"expected V2 to fail; got code=0\n{output}"
    assert "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT" in output


def test_v2_pre_v6_with_empty_cache_hits_passes(write_state):
    """Pre-v6 features are exempt from V2 (per CLAUDE.md gate doc)."""
    state_path = write_state("legacy-feature", {
        "name": "legacy-feature",
        "framework_version": "v5.1",
        "created_at": "2026-04-01T00:00:00Z",
        "current_phase": "complete",
        "case_study_type": "no_case_study_required",
        "case_study_exempt_reason": "pre-v6 exempt",
        "cache_hits": [],
    })
    code, output = run_check(state_path)
    assert code == 0, f"expected pre-v6 exempt; got code != 0\n{output}"


def test_v2_with_populated_cache_hits_passes(write_state):
    """When cache_hits[] is non-empty, V2 passes regardless of Read events."""
    state_path = write_state("ok-feature", {
        "name": "ok-feature",
        "framework_version": "v7.8.3",
        "created_at": "2026-05-12T00:00:00Z",
        "current_phase": "complete",
        "case_study_type": "no_case_study_required",
        "case_study_exempt_reason": "test fixture",
        "cache_hits": [{"file": "x.py", "ts": "2026-05-12T01:00:00Z"}],
    })
    code, output = run_check(state_path)
    assert code == 0, f"populated cache_hits; expected pass\n{output}"
