"""F16 try-repo harness — F4 FRAMEWORK_VERSION_STALE advisory gate.

FRAMEWORK_VERSION_STALE ships ADVISORY (FRAMEWORK_VERSION_STALE_ADVISORY_MODE),
so it never makes pre-commit exit non-zero during its calibration window. The
advisory-gate analog of the rc!=0 assertion (per the PLATFORMS_TESTED precedent)
is therefore an assertion on the `[ADVISORY] FRAMEWORK_VERSION_STALE` text in
stderr: present for the positive fixture, absent for the negative — both rc==0.

Canonical version is injected via FRAMEWORK_VERSION_CANONICAL_OVERRIDE so the
test does not depend on the throwaway repo carrying docs/FRAMEWORK-FACTS.md.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Add scripts/tests/ to sys.path for test-only helper imports.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_fixture,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = REPO_ROOT / "tests" / "fixtures" / "FRAMEWORK_VERSION_STALE"
ADVISORY_MARKER = "[ADVISORY] FRAMEWORK_VERSION_STALE"


def _run_fixture(fixture_dir: Path, tmp_path: Path) -> tuple[int, str, str]:
    repo = make_throwaway_repo(tmp_path)
    stage_fixture(fixture_dir, repo)
    env_overrides = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        "FRAMEWORK_VERSION_CANONICAL_OVERRIDE": "v7.10",
        **scrub_home_env(tmp_path),
    }
    result = run_precommit(repo, env_overrides=env_overrides)
    return result.returncode, result.stdout, result.stderr


def test_framework_version_stale_fires_on_positive_fixture(tmp_path: Path):
    """Stale framework_version (v7.5 < canonical v7.10) on a transition →
    advisory in stderr. rc stays 0 (advisory mode does not block)."""
    rc, out, err = _run_fixture(FIXTURE_ROOT / "positive", tmp_path)
    combined = out + err
    assert ADVISORY_MARKER in combined, (
        f"expected advisory marker in output; rc={rc}\nSTDOUT:\n{out}\nSTDERR:\n{err}"
    )
    assert rc == 0, f"advisory gate must not block the commit; rc={rc}\n{err}"


def test_framework_version_stale_silent_on_negative_fixture(tmp_path: Path):
    """Current framework_version (v7.10 == canonical) → no advisory, rc 0."""
    rc, out, err = _run_fixture(FIXTURE_ROOT / "negative", tmp_path)
    combined = out + err
    assert ADVISORY_MARKER not in combined, (
        f"gate must NOT fire on a current version; rc={rc}\nSTDOUT:\n{out}\nSTDERR:\n{err}"
    )
    assert rc == 0, f"clean commit must pass; rc={rc}\n{err}"
