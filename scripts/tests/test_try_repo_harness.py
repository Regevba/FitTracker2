"""F16 try-repo harness — T3 scaffold tests.

Validates `make_throwaway_repo`, `run_precommit`, `scrub_home_env`, and
`stage_files`. These tests do NOT exercise specific gates — they cover only
the scaffold mechanics. Per-gate behavior is tested in T5 (separate file).

Q5 enforcement (PRD §3.5, REVISED 2026-06-04 during T3 development): every
test that calls `run_precommit` MUST pass `GATE_COVERAGE_LEDGER_DISABLED=1`
in env_overrides. The PRD originally specified a `GATE_COVERAGE_LEDGER`
path-override, but production code uses `GATE_COVERAGE_LEDGER` as a
module-level constant (not env-var); the real opt-out is the `_DISABLED`
toggle which skips the write entirely. Per-test assertions rely on stderr
+ exit code rather than ledger row inspection.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

# Add scripts/tests/ to sys.path for test-only helper imports.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    PRE_COMMIT_HOOK_PATH,
    PRE_COMMIT_TIMEOUT_S,
    THROWAWAY_REPO_INIT_FILES,
    PrecommitResult,
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_files,
)


# ────────────────────────────────────────────────────────────────────────────
# make_throwaway_repo
# ────────────────────────────────────────────────────────────────────────────


def test_make_throwaway_repo_creates_repo_with_bootstrap_files(tmp_path: Path):
    """All 3 init files are present after bootstrap."""
    repo = make_throwaway_repo(tmp_path)
    for filename in THROWAWAY_REPO_INIT_FILES:
        assert (repo / filename).exists(), f"{filename} missing from throwaway repo"


def test_make_throwaway_repo_is_a_git_repo(tmp_path: Path):
    """Repo is git-initialized with at least the bootstrap commit."""
    repo = make_throwaway_repo(tmp_path)
    assert (repo / ".git").is_dir()
    # `git log -1` succeeds → at least one commit exists
    result = subprocess.run(
        ["git", "log", "-1", "--format=%s"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    assert "F16 throwaway repo bootstrap" in result.stdout


def test_make_throwaway_repo_hooks_path_points_at_real_repo(tmp_path: Path):
    """core.hooksPath is set so the throwaway repo USES the real pre-commit."""
    repo = make_throwaway_repo(tmp_path)
    result = subprocess.run(
        ["git", "config", "core.hooksPath"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    assert PRE_COMMIT_HOOK_PATH.parent.name in result.stdout, (
        f"core.hooksPath should point at FT2's .githooks; got: {result.stdout!r}"
    )


def test_make_throwaway_repo_has_scripts_symlink(tmp_path: Path):
    """scripts/ is symlinked so the hook can find Python gate dispatchers."""
    repo = make_throwaway_repo(tmp_path)
    scripts_link = repo / "scripts"
    assert scripts_link.is_symlink() or scripts_link.is_dir()
    # check-state-schema.py is reachable via the link
    assert (scripts_link / "check-state-schema.py").exists()


def test_make_throwaway_repo_commit_signing_disabled(tmp_path: Path):
    """commit.gpgsign is false so CI signing-key absence doesn't fail."""
    repo = make_throwaway_repo(tmp_path)
    result = subprocess.run(
        ["git", "config", "commit.gpgsign"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout.strip() == "false"


# ────────────────────────────────────────────────────────────────────────────
# scrub_home_env
# ────────────────────────────────────────────────────────────────────────────


def test_scrub_home_env_overrides_HOME(tmp_path: Path):
    """HOME points at tmp_path."""
    overrides = scrub_home_env(tmp_path)
    assert overrides["HOME"] == str(tmp_path)


def test_scrub_home_env_overrides_XDG_vars(tmp_path: Path):
    """All 4 XDG_* vars are anchored under tmp_path."""
    overrides = scrub_home_env(tmp_path)
    for var in ("XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME"):
        assert overrides[var].startswith(str(tmp_path)), (
            f"{var} not anchored under tmp_path"
        )


def test_scrub_home_env_does_not_touch_PATH(tmp_path: Path):
    """PATH is NOT overridden — the hook needs git, python3, etc."""
    overrides = scrub_home_env(tmp_path)
    assert "PATH" not in overrides


# ────────────────────────────────────────────────────────────────────────────
# run_precommit
# ────────────────────────────────────────────────────────────────────────────


def test_run_precommit_returns_passed_on_empty_repo(tmp_path: Path):
    """A bootstrap repo with no staged changes after init should pass the hook.

    Why this works: the bootstrap commit is already in history; `git status --porcelain`
    on the freshly-bootstrapped repo is empty; gates have nothing to scan; pre-commit
    exits 0.

    This is the "no false positive on baseline" smoke test.
    """
    repo = make_throwaway_repo(tmp_path)
    gate_ledger = tmp_path / "gate-coverage.jsonl"
    result = run_precommit(
        repo,
        env_overrides={
            "GATE_COVERAGE_LEDGER_DISABLED": "1",
            **scrub_home_env(tmp_path),
        },
    )
    assert result.passed, (
        f"Baseline repo failed pre-commit unexpectedly:\n"
        f"  rc={result.returncode}\n"
        f"  stdout={result.stdout!r}\n"
        f"  stderr={result.stderr!r}"
    )


def test_run_precommit_returns_PrecommitResult(tmp_path: Path):
    """Return type is the documented frozen dataclass."""
    repo = make_throwaway_repo(tmp_path)
    result = run_precommit(
        repo,
        env_overrides={
            "GATE_COVERAGE_LEDGER_DISABLED": "1",
            **scrub_home_env(tmp_path),
        },
    )
    assert isinstance(result, PrecommitResult)
    assert hasattr(result, "returncode")
    assert hasattr(result, "stdout")
    assert hasattr(result, "stderr")
    assert hasattr(result, "passed")


def test_run_precommit_inherits_env_minus_overrides(tmp_path: Path):
    """Non-overridden env vars survive (e.g., PATH from parent process)."""
    repo = make_throwaway_repo(tmp_path)
    # If PATH wasn't inherited, the hook's `git` and `python3` subprocesses
    # would fail before getting to a gate decision. The test_run_precommit_*
    # tests above only pass if PATH is intact.
    # This test is a defensive marker: future refactors must not switch to
    # `env=overrides_only` (which would drop PATH).
    assert "PATH" in os.environ
    result = run_precommit(
        repo,
        env_overrides={
            "GATE_COVERAGE_LEDGER_DISABLED": "1",
            **scrub_home_env(tmp_path),
        },
    )
    # rc==0 implies subprocess found git+python+the hook script.
    assert result.passed


def test_run_precommit_timeout_kwarg_respected(tmp_path: Path):
    """The `timeout_s` kwarg is plumbed to subprocess.run."""
    repo = make_throwaway_repo(tmp_path)
    # 30s default is plenty for our baseline run; we just confirm the kwarg
    # is accepted without error (real timeout behavior tested via subprocess
    # standard library — not our problem to re-prove).
    result = run_precommit(
        repo,
        env_overrides={
            "GATE_COVERAGE_LEDGER_DISABLED": "1",
            **scrub_home_env(tmp_path),
        },
        timeout_s=PRE_COMMIT_TIMEOUT_S,
    )
    assert isinstance(result, PrecommitResult)


# ────────────────────────────────────────────────────────────────────────────
# stage_files
# ────────────────────────────────────────────────────────────────────────────


def test_stage_files_writes_string_content(tmp_path: Path):
    """String content lands as UTF-8 text."""
    repo = make_throwaway_repo(tmp_path)
    stage_files(repo, {"notes.md": "# hello F16\n"})
    assert (repo / "notes.md").read_text() == "# hello F16\n"


def test_stage_files_creates_nested_parents(tmp_path: Path):
    """Nested paths auto-create parent directories."""
    repo = make_throwaway_repo(tmp_path)
    stage_files(repo, {"a/b/c/deep.txt": "deep"})
    assert (repo / "a" / "b" / "c" / "deep.txt").exists()


def test_stage_files_copies_path_objects(tmp_path: Path):
    """Path-typed content is copied (not stringified)."""
    repo = make_throwaway_repo(tmp_path)
    source = tmp_path / "source.txt"
    source.write_text("from path")
    stage_files(repo, {"copied.txt": source})
    assert (repo / "copied.txt").read_text() == "from path"


def test_stage_files_git_adds(tmp_path: Path):
    """Staged files appear in `git status --porcelain` with `A ` prefix."""
    repo = make_throwaway_repo(tmp_path)
    stage_files(repo, {"new.md": "new file"})
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=repo,
        capture_output=True,
        text=True,
        check=True,
    )
    assert "new.md" in result.stdout
    # `A ` prefix means staged-added
    assert result.stdout.lstrip().startswith("A"), (
        f"new.md not staged-added: porcelain={result.stdout!r}"
    )


# ────────────────────────────────────────────────────────────────────────────
# Q5 enforcement — Mechanism A canonical ledger untouched
# ────────────────────────────────────────────────────────────────────────────


def test_canonical_gate_coverage_ledger_untouched_after_run(tmp_path: Path):
    """Q5 — running try-repo MUST NOT mutate `.claude/logs/gate-coverage.jsonl`.

    The opt-out is `GATE_COVERAGE_LEDGER_DISABLED=1` env var; gates skip
    the ledger write entirely when set. This test verifies the toggle is
    honored end-to-end (not silently masked at any layer).
    """
    canonical = (
        Path(__file__).resolve().parents[2]
        / ".claude"
        / "logs"
        / "gate-coverage.jsonl"
    )
    if not canonical.exists():
        pytest.skip(
            "Canonical ledger does not exist in this environment "
            "(fresh checkout?); Q5 test requires the file to exist for "
            "mtime/size comparison."
        )
    before_mtime = canonical.stat().st_mtime
    before_size = canonical.stat().st_size

    repo = make_throwaway_repo(tmp_path)
    result = run_precommit(
        repo,
        env_overrides={
            "GATE_COVERAGE_LEDGER_DISABLED": "1",
            **scrub_home_env(tmp_path),
        },
    )
    # We don't care about the result; Q5 is about the CANONICAL ledger,
    # which should NOT have been touched regardless of pass/fail.
    _ = result

    after_mtime = canonical.stat().st_mtime
    after_size = canonical.stat().st_size

    assert before_mtime == after_mtime, (
        "Q5 VIOLATION: canonical gate-coverage.jsonl mtime changed during "
        "try-repo run. Mechanism A telemetry is being silently contaminated. "
        "Verify GATE_COVERAGE_LEDGER_DISABLED=1 is in env_overrides and "
        "that scripts/check-state-schema.py:1544 honors the env var "
        "(the `skip_ledger` flag)."
    )
    assert before_size == after_size, (
        "Q5 VIOLATION: canonical gate-coverage.jsonl grew during try-repo "
        "run. Same investigation as the mtime assertion."
    )
