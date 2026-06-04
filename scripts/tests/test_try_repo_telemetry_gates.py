"""F16 try-repo harness — T4c telemetry gate tests.

Per-gate integration tests for the 4 telemetry gates:
- PHASE_TRANSITION_NO_LOG
- PHASE_TRANSITION_NO_TIMING
- CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT
- CU_V2_INVALID

Same pattern as T4a + T4b: positive = gate fires; negative = gate passes.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_fixture,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = REPO_ROOT / "tests" / "fixtures"


TELEMETRY_GATES = [
    "PHASE_TRANSITION_NO_LOG",
    "PHASE_TRANSITION_NO_TIMING",
    "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT",
    "CU_V2_INVALID",
]


def _run_fixture(fixture_dir: Path, tmp_path: Path) -> tuple[int, str, str]:
    repo = make_throwaway_repo(tmp_path)
    stage_fixture(fixture_dir, repo)
    env_overrides = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    result = run_precommit(repo, env_overrides=env_overrides)
    return result.returncode, result.stdout, result.stderr


@pytest.mark.parametrize("gate", TELEMETRY_GATES)
def test_telemetry_gate_fires_on_positive_fixture(gate: str, tmp_path: Path):
    """Each telemetry gate's positive fixture must cause pre-commit to reject."""
    fixture = FIXTURE_ROOT / gate / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc != 0, (
        f"{gate} positive fixture: pre-commit returned 0 (accepted) but "
        f"should have rejected.\n  stdout={stdout!r}\n  stderr={stderr!r}"
    )
    combined = (stdout + stderr).lower()
    signals_per_gate = {
        "PHASE_TRANSITION_NO_LOG": [
            "phase_transition_no_log",
            "no recent",
            "matching event",
        ],
        "PHASE_TRANSITION_NO_TIMING": [
            "phase_transition_no_timing",
            "timing.phases",
            "started_at",
        ],
        "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT": [
            "cache_hits_auto_instrumentation_drift",
            "cache_hits",
        ],
        "CU_V2_INVALID": [
            "cu_v2_invalid",
            "factors",
        ],
    }[gate]
    assert any(s in combined for s in signals_per_gate), (
        f"{gate} positive: rejected, but no expected signal in output. "
        f"Looked for one of: {signals_per_gate}\n  combined={combined!r}"
    )


@pytest.mark.parametrize("gate", TELEMETRY_GATES)
def test_telemetry_gate_passes_on_negative_fixture(gate: str, tmp_path: Path):
    """Each telemetry gate's negative fixture must let pre-commit accept."""
    fixture = FIXTURE_ROOT / gate / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc == 0, (
        f"{gate} negative fixture: pre-commit returned {rc} (rejected) but "
        f"should have accepted.\n  stdout={stdout!r}\n  stderr={stderr!r}"
    )
