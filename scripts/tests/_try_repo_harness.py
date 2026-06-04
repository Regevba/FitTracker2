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

import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

# Import sibling helper (sys.path injection for test-time use).
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))
from _try_repo_fixtures import make_state_json  # noqa: E402


REPO_ROOT = Path(__file__).resolve().parents[2]
PRE_COMMIT_HOOK_PATH = REPO_ROOT / ".githooks" / "pre-commit"
PRE_COMMIT_TIMEOUT_S = 30

THROWAWAY_REPO_INIT_FILES: dict[str, str] = {
    # Intentionally do NOT gitignore .claude/logs/* — fixtures need to
    # `git add` the canonical log file to satisfy PHASE_TRANSITION_NO_LOG.
    ".gitignore": "*.pyc\n__pycache__/\n",
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

    # Initial branch matches the baseline state.json::branch field so
    # BRANCH_ISOLATION_VIOLATION Mode B + Mode C gates can be exercised
    # in either positive (mismatch) or negative (match) fixtures.
    _run_git(repo, "init", "--initial-branch=feature/_test-fixture")
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


def stage_fixture(
    fixture_dir: Path,
    repo: Path,
    target_path: str = ".claude/features/_test-fixture/state.json",
) -> Path:
    """Materialize a per-gate fixture into `repo` and `git add` the result.

    Reads `fixture_dir / "state.overrides.json"` as a JSON dict of overrides
    to merge onto the baseline (via `make_state_json`). Writes the merged
    state.json at `repo / target_path` and stages it.

    Companion files (resolved in order — per-gate fixture wins over baseline):

    1. `tests/fixtures/_baseline/feature.log.json` → `.claude/logs/_test-fixture.log.json`
       (canonical log to satisfy PHASE_TRANSITION_NO_LOG gate)
    2. `tests/fixtures/_baseline/case-study.md` (if present) → `docs/case-studies/_test-fixture-case-study.md`
    3. `fixture_dir / "feature.log.json"` (if present) — OVERRIDES the baseline log
    4. `fixture_dir / "case-study.md"` (if present) — OVERRIDES the baseline case study

    `_comment` keys at any depth in the overrides JSON are stripped before
    merging — they're for fixture-readers, not for the gate dispatchers.

    Args:
        fixture_dir: path under tests/fixtures/<gate-id>/{positive,negative}/
        repo: throwaway repo root (output of `make_throwaway_repo`)
        target_path: where in the throwaway repo to write the state.json.
            Default matches the canonical feature-directory pattern.

    Returns:
        Absolute path to the staged state.json file.

    Raises:
        FileNotFoundError: if `fixture_dir/state.overrides.json` does not exist
        json.JSONDecodeError: if the overrides file is not valid JSON
    """
    overrides_path = fixture_dir / "state.overrides.json"
    with overrides_path.open("r", encoding="utf-8") as f:
        overrides = json.load(f)
    overrides = _strip_comments(overrides)

    dest = repo / target_path
    make_state_json(overrides, dest)
    _run_git(repo, "add", target_path)

    # Companion files — baseline first, per-fixture overrides last.
    baseline_dir = (
        Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "_baseline"
    )

    def _maybe_copy(src: Path, rel_dest: str) -> None:
        if not src.exists():
            return
        dest_path = repo / rel_dest
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest_path)
        _run_git(repo, "add", rel_dest)

    # 1. Generate a baseline log with a fresh-timestamp phase_started event.
    # PHASE_TRANSITION_NO_LOG requires the matching event to be ≤15 min old.
    # Static log files in fixtures cannot satisfy this; we generate at
    # stage time using the current process clock. This is a TEST-ONLY
    # construction — production logs are written by append-feature-log.py.
    _write_fresh_baseline_log(repo, ".claude/logs/_test-fixture.log.json")
    _run_git(repo, "add", ".claude/logs/_test-fixture.log.json")
    # 2. Baseline case study (only if a baseline copy exists)
    _maybe_copy(
        baseline_dir / "case-study.md",
        "docs/case-studies/_test-fixture-case-study.md",
    )
    # 3. Per-fixture log override
    _maybe_copy(
        fixture_dir / "feature.log.json", ".claude/logs/_test-fixture.log.json"
    )
    # 4. Per-fixture case study override
    _maybe_copy(
        fixture_dir / "case-study.md",
        "docs/case-studies/_test-fixture-case-study.md",
    )

    return dest


def _write_fresh_baseline_log(repo: Path, rel_path: str) -> None:
    """Write a baseline feature.log.json with a current-time phase_started event.

    PHASE_TRANSITION_NO_LOG (scripts/check-state-schema.py) requires the
    matching event to be ≤PHASE_EVENT_FRESHNESS_MIN (15 min) old. Static
    fixtures cannot satisfy this in long-lived test infra, so we generate
    at stage time using the current process clock.

    Mirrors append-feature-log.py's event shape. The implementation phase
    matches the baseline state.json's current_phase.
    """
    from datetime import datetime, timezone

    now_iso = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    log = {
        "feature": "_test-fixture",
        "events": [
            {
                "event_type": "phase_started",
                "phase": "implementation",
                "timestamp": now_iso,
                "summary": "F16 try-repo fixture — fresh phase_started event "
                "to satisfy PHASE_TRANSITION_NO_LOG freshness window.",
            }
        ],
    }
    dest = repo / rel_path
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)
        f.write("\n")


def _strip_comments(obj: Any) -> Any:
    """Recursively remove keys starting with `_comment` from a dict tree.

    Fixtures use `_comment` keys to document themselves; the gate dispatchers
    never see them.
    """
    if isinstance(obj, dict):
        return {
            k: _strip_comments(v)
            for k, v in obj.items()
            if not (isinstance(k, str) and k.startswith("_comment"))
        }
    if isinstance(obj, list):
        return [_strip_comments(item) for item in obj]
    return obj


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
    "stage_fixture",
]
