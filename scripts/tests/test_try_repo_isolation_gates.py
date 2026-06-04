"""F16 try-repo harness — T4d isolation gate tests.

Per-gate integration tests for the 3 isolation gates:
- ISOLATION_OPT_OUT_REASON_MISSING (state.json::isolation_opt_out=true + empty reason)
- BRANCH_ISOLATION_VIOLATION Mode B (infra commit on non-feature branch — needs
  throwaway repo initialized on `main`)
- BRANCH_ISOLATION_VIOLATION Mode C (state.json::branch field mismatches actual
  git branch on the throwaway repo)
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


# Gates where the throwaway repo runs on the default feature/_test-fixture
# branch. ISOLATION_OPT_OUT_REASON_MISSING and Mode C both exercise via
# state.json overrides only.
ISOLATION_GATES_DEFAULT_BRANCH = [
    "ISOLATION_OPT_OUT_REASON_MISSING",
    "BRANCH_ISOLATION_VIOLATION_MODE_C",
]


def _run_fixture(
    fixture_dir: Path,
    tmp_path: Path,
    *,
    initial_branch: str = "feature/_test-fixture",
) -> tuple[int, str, str]:
    repo = make_throwaway_repo(tmp_path, initial_branch=initial_branch)
    stage_fixture(fixture_dir, repo)
    env_overrides = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    result = run_precommit(repo, env_overrides=env_overrides)
    return result.returncode, result.stdout, result.stderr


# ────────────────────────────────────────────────────────────────────────────
# Gates that work on the default throwaway branch
# ────────────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("gate", ISOLATION_GATES_DEFAULT_BRANCH)
def test_isolation_gate_fires_on_positive_fixture(gate: str, tmp_path: Path):
    fixture = FIXTURE_ROOT / gate / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc != 0, (
        f"{gate} positive fixture: pre-commit returned 0 but should reject.\n"
        f"  stdout={stdout!r}\n  stderr={stderr!r}"
    )
    combined = (stdout + stderr).lower()
    signals_per_gate = {
        "ISOLATION_OPT_OUT_REASON_MISSING": [
            "isolation_opt_out_reason_missing",
            "isolation_opt_out_reason",
            "isolation_opt_out=true requires",
        ],
        "BRANCH_ISOLATION_VIOLATION_MODE_C": [
            "branch_isolation_violation",
            "mutate state.json::current_phase only from the feature's declared branch",
        ],
    }[gate]
    assert any(s in combined for s in signals_per_gate), (
        f"{gate} positive: rejected, but no expected signal in output. "
        f"Looked for one of: {signals_per_gate}\n  combined={combined!r}"
    )


@pytest.mark.parametrize("gate", ISOLATION_GATES_DEFAULT_BRANCH)
def test_isolation_gate_passes_on_negative_fixture(gate: str, tmp_path: Path):
    fixture = FIXTURE_ROOT / gate / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc == 0, (
        f"{gate} negative fixture: pre-commit returned {rc} but should accept.\n"
        f"  stdout={stdout!r}\n  stderr={stderr!r}"
    )


# ────────────────────────────────────────────────────────────────────────────
# BRANCH_ISOLATION_VIOLATION Mode B — needs throwaway on `main` branch
# ────────────────────────────────────────────────────────────────────────────


def test_branch_isolation_mode_b_fires_on_positive_fixture(tmp_path: Path):
    """Mode B (commit-level): work_subtype=framework_feature on a non-feature/*
    branch fires the gate. The throwaway is initialized on `main`.
    """
    fixture = FIXTURE_ROOT / "BRANCH_ISOLATION_VIOLATION_MODE_B" / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path, initial_branch="main")
    assert rc != 0, (
        "Mode B positive fixture: pre-commit returned 0 but should reject.\n"
        f"  stdout={stdout!r}\n  stderr={stderr!r}"
    )
    combined = (stdout + stderr).lower()
    assert (
        "branch_isolation_violation" in combined
        or "expected branch=feature" in combined
        or "feature/<name> or chore/<name> branch" in combined
    ), f"Expected Mode B signal in output. combined={combined!r}"


def test_branch_isolation_mode_b_passes_on_negative_fixture(tmp_path: Path):
    """Mode B negative: feature/* branch + baseline. Gate skips."""
    fixture = FIXTURE_ROOT / "BRANCH_ISOLATION_VIOLATION_MODE_B" / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)  # default feature branch
    assert rc == 0, (
        f"Mode B negative fixture: pre-commit returned {rc} but should accept.\n"
        f"  stdout={stdout!r}\n  stderr={stderr!r}"
    )
