"""F16 try-repo harness — make_throwaway_repo + run_precommit helpers.

This is the runtime side of the F16 test infrastructure. Per-gate test cases
import these helpers, build a fixture-staged throwaway repo, run the real
`.githooks/pre-commit` shell script via subprocess, and assert exit code +
stderr content.

Constants frozen by PRD §4:
- `THROWAWAY_REPO_INIT_FILES` — 3 minimal files committed to bootstrap the repo
- `PRE_COMMIT_TIMEOUT_S` = 30
- `PRE_COMMIT_HOOK_PATH` = relative path to the real pre-commit script

Q5 enforcement (PRD §3.5, REVISED 2026-06-04): callers MUST pass
`GATE_COVERAGE_LEDGER_DISABLED=1` in `env_overrides` to prevent canonical
Mechanism A telemetry contamination. The PRD originally specified a
`GATE_COVERAGE_LEDGER` path-override, but Phase 4 T3 testing surfaced that
the gates use `GATE_COVERAGE_LEDGER` as a module-level constant (not an
env var) — the production opt-out is `GATE_COVERAGE_LEDGER_DISABLED=1`
which skips the write entirely. Per-test assertions rely on stderr + exit
code rather than ledger row inspection, which is strictly stronger
evidence anyway (rc != 0 proves the gate fired; ledger row only proves a
row was emitted).

The harness does NOT default-set the DISABLED toggle — explicit is better
than implicit, and an oversight should fail loudly in the Q5-enforcement
test (`test_canonical_gate_coverage_ledger_untouched_after_run`) rather
than be silently masked here.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
PRE_COMMIT_HOOK_PATH = REPO_ROOT / ".githooks" / "pre-commit"
PRE_COMMIT_TIMEOUT_S = 30

THROWAWAY_REPO_INIT_FILES: dict[str, str] = {
    ".gitignore": ".claude/logs/*\n*.pyc\n__pycache__/\n",
    "CLAUDE.md": (
        "# F16 try-repo test fixture\n\n"
        "This is a throwaway repo created by the F16 try-repo harness.\n"
        "Real CLAUDE.md content is not required — the pre-commit script\n"
        "only checks for the file's existence in some gates.\n"
    ),
    "Makefile": ".PHONY: dummy\ndummy:\n\t@echo F16 test fixture\n",
}


@dataclass(frozen=True)
class PrecommitResult:
    """Output of `run_precommit`. Frozen for safe sharing across assertions."""

    returncode: int
    stdout: str
    stderr: str

    @property
    def passed(self) -> bool:
        """True iff the pre-commit hook accepted the commit (exit 0)."""
        return self.returncode == 0


def scrub_home_env(tmp_home: Path) -> dict[str, str]:
    """Return env overrides that scrub HOME pollution.

    Why this matters: gates that read `~/.gitconfig` or `~/.fittracker/`
    inherit operator-machine state if HOME isn't overridden, causing
    pass-locally-fail-CI bugs. The throwaway repo gets its own HOME
    pointing at `tmp_path`, isolated from the operator's real environment.

    Caller is responsible for ensuring `tmp_home` exists.
    """
    return {
        "HOME": str(tmp_home),
        "XDG_CONFIG_HOME": str(tmp_home / ".config"),
        "XDG_CACHE_HOME": str(tmp_home / ".cache"),
        "XDG_DATA_HOME": str(tmp_home / ".local" / "share"),
    }


def make_throwaway_repo(tmp_path: Path) -> Path:
    """Initialize a throwaway git repo at `tmp_path` with bootstrap commit.

    Steps:
    1. Write the 3 THROWAWAY_REPO_INIT_FILES to the repo root
    2. `git init` (suppress branch-name hint)
    3. Set local git user.email + user.name (so commits don't fail on
       missing identity in CI)
    4. Set core.hooksPath to `.githooks` so the throwaway repo USES the
       real FT2 pre-commit hook (the whole point of the harness)
    5. Symlink `.githooks` from the real repo so the hook script can be
       executed by the throwaway repo's pre-commit driver
    6. Symlink `scripts/` so the hook can find the Python gate dispatchers
    7. Initial commit (NOT via the hook — bypass to seed history)

    Returns:
        Path to the throwaway repo root.

    Raises:
        OSError: on any file or subprocess failure.
    """
    repo = tmp_path / "throwaway_repo"
    repo.mkdir(parents=True, exist_ok=True)

    for filename, content in THROWAWAY_REPO_INIT_FILES.items():
        (repo / filename).write_text(content, encoding="utf-8")

    _run_git(repo, "init", "--initial-branch=main")
    _run_git(repo, "config", "user.email", "f16-test@example.com")
    _run_git(repo, "config", "user.name", "F16 Test")
    _run_git(repo, "config", "commit.gpgsign", "false")  # CI signing-key absent
    _run_git(repo, "config", "core.hooksPath", str(REPO_ROOT / ".githooks"))

    # Symlink scripts/ so the hook can find Python gate dispatchers without
    # the throwaway repo needing its own copy.
    (repo / "scripts").symlink_to(REPO_ROOT / "scripts")

    # Seed history WITHOUT the hook (bypass).
    _run_git(repo, "add", "-A")
    _run_git(
        repo,
        "-c",
        "core.hooksPath=/dev/null",
        "commit",
        "-m",
        "seed: F16 throwaway repo bootstrap",
        "--no-verify",
    )

    return repo


def run_precommit(
    repo: Path,
    env_overrides: Mapping[str, str] | None = None,
    timeout_s: int = PRE_COMMIT_TIMEOUT_S,
) -> PrecommitResult:
    """Run the real `.githooks/pre-commit` script in `repo`.

    Args:
        repo: throwaway repo root (output of `make_throwaway_repo`)
        env_overrides: dict merged onto current process env. Callers SHOULD
            pass at least `GATE_COVERAGE_LEDGER` (PRD §3.5 Q5) to redirect
            Mechanism A telemetry away from the canonical ledger.
        timeout_s: subprocess wall-clock cap. Default 30s per PRD §4.

    Returns:
        PrecommitResult with (returncode, stdout, stderr).

    Notes:
        - `cwd=repo` ensures the hook resolves staged-files via the throwaway
          repo's `git status --porcelain`, not the real FT2 repo.
        - The hook script itself is at REPO_ROOT/.githooks/pre-commit, which
          is what `core.hooksPath` was set to in `make_throwaway_repo`.
        - Subprocess inherits parent env minus `env_overrides`. Callers
          control HOME scrub via `scrub_home_env()`.
    """
    env = os.environ.copy()
    if env_overrides:
        env.update(env_overrides)

    result = subprocess.run(
        [str(PRE_COMMIT_HOOK_PATH)],
        cwd=str(repo),
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout_s,
        check=False,
    )
    return PrecommitResult(
        returncode=result.returncode,
        stdout=result.stdout,
        stderr=result.stderr,
    )


def stage_files(repo: Path, files: Mapping[str, str | bytes | Path]) -> None:
    """Write `files` into `repo` and `git add` them.

    `files` is a mapping of relative path inside the repo to either:
    - `str` content (written as UTF-8 text)
    - `bytes` content (written as binary)
    - `Path` to a source file (copied)

    Parent dirs are auto-created.

    Does NOT commit. The pre-commit hook is invoked separately via
    `run_precommit`.
    """
    for rel_path, content in files.items():
        dest = repo / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, Path):
            shutil.copy2(content, dest)
        elif isinstance(content, bytes):
            dest.write_bytes(content)
        else:
            dest.write_text(content, encoding="utf-8")
        _run_git(repo, "add", rel_path)


def _run_git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    """Run `git <args>` in `repo` with hook bypass for harness setup ops.

    Internal — callers should use the public helpers above.
    """
    return subprocess.run(
        ["git", *args],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=True,
    )


__all__ = [
    "PRE_COMMIT_HOOK_PATH",
    "PRE_COMMIT_TIMEOUT_S",
    "THROWAWAY_REPO_INIT_FILES",
    "PrecommitResult",
    "make_throwaway_repo",
    "run_precommit",
    "scrub_home_env",
    "stage_files",
]
