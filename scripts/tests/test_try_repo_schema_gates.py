"""F16 try-repo harness — T4a + T5 schema gate tests (5 gates × 2 fixtures = 10 cases).

Per-gate integration tests for the 5 schema gates:
- SCHEMA_DRIFT_LEGACY_PHASE
- SCHEMA_DRIFT_LEGACY_CREATED
- FRAMEWORK_VERSION_FORMAT
- STATE_OWNER_MISSING
- STATE_OWNER_INVALID

Pattern:
- positive fixture (gate should fire) → assert `not result.passed` AND
  the gate's name appears in stderr
- negative fixture (gate should pass) → assert `result.passed`

Per PRD Q5 (revised): every run passes `GATE_COVERAGE_LEDGER_DISABLED=1`
to prevent canonical Mechanism A telemetry contamination.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Add scripts/tests/ to sys.path for test-only helper imports.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_fixture,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = REPO_ROOT / "tests" / "fixtures"


SCHEMA_GATES = [
    "SCHEMA_DRIFT_LEGACY_PHASE",
    "SCHEMA_DRIFT_LEGACY_CREATED",
    "FRAMEWORK_VERSION_FORMAT",
    "STATE_OWNER_MISSING",
    "STATE_OWNER_INVALID",
]

# PRD §3.5 Q6 finding (RESOLVED 2026-06-04 via PR #611): the fix-tier PR
# added `REPO_ROOT_OVERRIDE` env var support to scripts/check-state-schema.py
# + scripts/check-case-study-preflight.py. The harness now passes
# `REPO_ROOT_OVERRIDE=<throwaway_repo>` in env_overrides so the gates look
# up staged state.json files under the throwaway path instead of canonical
# FT2. See `_run_fixture` below.


def _run_fixture(
    fixture_dir: Path, tmp_path: Path
) -> tuple[int, str, str]:
    """Bootstrap a throwaway repo, stage the fixture, run pre-commit.

    Sets `REPO_ROOT_OVERRIDE=<throwaway_repo>` so the gate dispatchers'
    `REPO_ROOT` module constant resolves to the throwaway path (Q6 fix,
    PR #611). Without this, `collect_staged_state_files()` would look up
    files under canonical FT2 root and silently drop them.

    Returns (returncode, stdout, stderr).
    """
    repo = make_throwaway_repo(tmp_path)
    stage_fixture(fixture_dir, repo)
    env_overrides = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    result = run_precommit(repo, env_overrides=env_overrides)
    return result.returncode, result.stdout, result.stderr


# ────────────────────────────────────────────────────────────────────────────
# Positive fixtures — gate must fire
# ────────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("gate", SCHEMA_GATES)
def test_schema_gate_fires_on_positive_fixture(gate: str, tmp_path: Path):
    """Each schema gate's positive fixture must cause pre-commit to reject."""
    fixture = FIXTURE_ROOT / gate / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)

    assert rc != 0, (
        f"{gate} positive fixture: pre-commit returned 0 (accepted) but "
        f"should have rejected.\n"
        f"  stdout={stdout!r}\n"
        f"  stderr={stderr!r}"
    )
    # The gate's name (or its remediation text) should appear in the hook's
    # output. Different gates surface differently — some print the code name,
    # others print a remediation string. We accept either.
    combined = (stdout + stderr).lower()
    gate_lower = gate.lower()
    # For schema-drift gates the visible message is "uses legacy ..." not
    # the gate code; allow lookup on either signal.
    signals = {
        "SCHEMA_DRIFT_LEGACY_PHASE": [gate_lower, "legacy `phase` key", "legacy phase"],
        "SCHEMA_DRIFT_LEGACY_CREATED": [gate_lower, "legacy `created` key", "legacy created"],
        "FRAMEWORK_VERSION_FORMAT": [gate_lower, "framework_version", "canonical `vx.y`", "not in canonical"],
        "STATE_OWNER_MISSING": [gate_lower, "state_owner_missing", "missing required field"],
        "STATE_OWNER_INVALID": [gate_lower, "state_owner_invalid", "state_owner = "],
    }[gate]
    assert any(signal in combined for signal in signals), (
        f"{gate} positive fixture rejected, but no expected signal in "
        f"output. Looked for one of: {signals}\n"
        f"  combined output (lowered)={combined!r}"
    )


# ────────────────────────────────────────────────────────────────────────────
# Negative fixtures — gate must NOT fire
# ────────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("gate", SCHEMA_GATES)
def test_schema_gate_passes_on_negative_fixture(gate: str, tmp_path: Path):
    """Each schema gate's negative fixture must let pre-commit accept."""
    fixture = FIXTURE_ROOT / gate / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)

    assert rc == 0, (
        f"{gate} negative fixture: pre-commit returned {rc} (rejected) but "
        f"should have accepted (baseline + no override is by construction "
        f"all-gates-passing).\n"
        f"  stdout={stdout!r}\n"
        f"  stderr={stderr!r}"
    )
