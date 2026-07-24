"""F16 try-repo integration test for T14 PLATFORMS_TESTED (ENFORCED 2026-06-21, cadence B15).

PLATFORMS_TESTED was promoted advisory→enforced on 2026-06-21 (all 4 §2.2
criteria met). The real pre-commit hook BLOCKS (exits non-zero) when a feature
transitions current_phase=complete while platforms_tested names no platform.
This exercises the full integration surface the unit + function tests can't:
hook composition, REPO_ROOT_OVERRIDE resolution, real `git status --porcelain`,
committed-state diff (`_load_committed_state`), HOME scrub.

Positive: complete transition, work_subtype removed (un-exempt), no platform
named → PLATFORMS_TESTED blocks the commit (rc != 0) + names the gate.
Negative: same complete transition but ios=true → gate runs its non-empty
check and passes; commit accepted (rc == 0).

Note on the fixture design: the baseline state.json carries
`work_subtype: framework_feature`, which Q2-exempts PLATFORMS_TESTED. Both
fixtures delete that key (null delete-sentinel in state.overrides.json) so the
gate is genuinely exercised rather than skipped as exempt. Both ship a
fully-populated companion case-study.md so the sibling closure/tier gates stay
quiet and PLATFORMS_TESTED is the only gate under test.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_fixture,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = REPO_ROOT / "tests" / "fixtures"


def _run_fixture(fixture_dir: Path, tmp_path: Path) -> tuple[int, str, str]:
    """Bootstrap a throwaway repo, stage the fixture, run the real pre-commit."""
    repo = make_throwaway_repo(tmp_path)
    stage_fixture(fixture_dir, repo)
    env_overrides = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    result = run_precommit(repo, env_overrides=env_overrides)
    return result.returncode, result.stdout, result.stderr


def test_platforms_tested_fires_on_positive_fixture(tmp_path: Path):
    """Complete transition naming no platform → pre-commit must reject."""
    fixture = FIXTURE_ROOT / "PLATFORMS_TESTED" / "positive"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc != 0, (
        "PLATFORMS_TESTED positive fixture: pre-commit returned 0 (accepted) "
        f"but should have rejected.\n  stdout={stdout!r}\n  stderr={stderr!r}"
    )
    combined = (stdout + stderr).lower()
    assert "platforms_tested" in combined, (
        "PLATFORMS_TESTED positive: rejected, but the gate name is not in the "
        f"hook output.\n  combined={combined!r}"
    )


def test_platforms_tested_passes_on_negative_fixture(tmp_path: Path):
    """Complete transition naming ios=true → pre-commit must accept."""
    fixture = FIXTURE_ROOT / "PLATFORMS_TESTED" / "negative"
    rc, stdout, stderr = _run_fixture(fixture, tmp_path)
    assert rc == 0, (
        f"PLATFORMS_TESTED negative fixture: pre-commit returned {rc} "
        f"(rejected) but should have accepted.\n"
        f"  stdout={stdout!r}\n  stderr={stderr!r}"
    )
    assert "platforms_tested" not in (stdout + stderr).lower(), (
        "PLATFORMS_TESTED negative: a platform is named, so the gate must not "
        f"fire.\n  stdout={stdout!r}\n  stderr={stderr!r}"
    )
