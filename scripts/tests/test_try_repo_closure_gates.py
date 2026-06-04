"""F16 try-repo harness — T4b closure gate tests.

Per-gate integration tests for 4 closure gates:
- STATE_OWNER_LOCATION_MISMATCH (SKIPPED — structurally untestable via harness)
- FEATURE_CLOSURE_COMPLETENESS (current_phase=complete transition validation)
- STATE_NO_CASE_STUDY_LINK (complete without case_study link)
- CASE_STUDY_MISSING_FIELDS (staged .md missing required frontmatter)

Same pattern as test_try_repo_schema_gates.py: positive = gate fires +
pre-commit rc != 0; negative = gate passes + pre-commit rc == 0.
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


# 3 of the 4 closure gates are exercised end-to-end. STATE_OWNER_LOCATION_MISMATCH
# is structurally untestable in the harness (see fixture _comment); it would
# require the throwaway repo to live under /FitTracker2[-/] or /fitme-story/
# rather than /private/tmp/.
CLOSURE_GATES = [
    "FEATURE_CLOSURE_COMPLETENESS",
    "STATE_NO_CASE_STUDY_LINK",
    "CASE_STUDY_MISSING_FIELDS",
]


def _run_fixture(fixture_dir: Path, tmp_path: Path) -> tuple[int, str, str]:
    """Bootstrap a throwaway repo, stage the fixture, run pre-commit.

    Sets `REPO_ROOT_OVERRIDE=<throwaway_repo>` (PR #611 fix) and
    `GATE_COVERAGE_LEDGER_DISABLED=1` (PRD Q5).
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


@pytest.mark.parametrize("gate", CLOSURE_GATES)
def test_closure_gate_fires_on_positive_fixture(gate: str, tmp_path: Path):
    """Each closure gate's positive fixture must cause pre-commit to reject."""
    fixture = FIXTURE_ROOT / gate / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc != 0, (
        f"{gate} positive fixture: pre-commit returned 0 (accepted) but "
        f"should have rejected.\n"
        f"  stdout={stdout!r}\n"
        f"  stderr={stderr!r}"
    )
    combined = (stdout + stderr).lower()
    signals_per_gate = {
        "FEATURE_CLOSURE_COMPLETENESS": [
            "feature_closure_completeness",
            "missing required",
            "case study",
        ],
        "STATE_NO_CASE_STUDY_LINK": [
            "state_no_case_study_link",
            "case_study",
            "no case study link",
            "missing required field 'case_study'",
        ],
        "CASE_STUDY_MISSING_FIELDS": [
            "case_study_missing_fields",
            "missing required field",
            "frontmatter",
        ],
    }[gate]
    assert any(s in combined for s in signals_per_gate), (
        f"{gate} positive: rejected, but no expected signal in output. "
        f"Looked for one of: {signals_per_gate}\n  combined={combined!r}"
    )


# ────────────────────────────────────────────────────────────────────────────
# Negative fixtures — gate must NOT fire
# ────────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("gate", CLOSURE_GATES)
def test_closure_gate_passes_on_negative_fixture(gate: str, tmp_path: Path):
    """Each closure gate's negative fixture must let pre-commit accept."""
    fixture = FIXTURE_ROOT / gate / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc == 0, (
        f"{gate} negative fixture: pre-commit returned {rc} (rejected) but "
        f"should have accepted.\n"
        f"  stdout={stdout!r}\n"
        f"  stderr={stderr!r}"
    )


# ────────────────────────────────────────────────────────────────────────────
# STATE_OWNER_LOCATION_MISMATCH — documented structural skip
# ────────────────────────────────────────────────────────────────────────────


@pytest.mark.skip(
    reason=(
        "STATE_OWNER_LOCATION_MISMATCH gate skips with `path_neutral` when "
        "the file path is not under /FitTracker2[-/] or /fitme-story/. The "
        "throwaway repo lives at /private/tmp/pytest-of-* which matches "
        "neither. Testing this gate via the try-repo harness would require "
        "bind-mount or symlink hacks. Deferred to F16.1 follow-up. See "
        "tests/fixtures/STATE_OWNER_LOCATION_MISMATCH/*/state.overrides.json."
    )
)
def test_state_owner_location_mismatch_placeholder():
    """Placeholder for the structurally-skipped gate. See decorator reason."""
    pass
