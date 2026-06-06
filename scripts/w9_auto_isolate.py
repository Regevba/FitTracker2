#!/usr/bin/env python3
"""
W9 auto-isolation primitive — feature w9-drift-triggered-auto-isolation, T1.

Moves the current session's uncommitted work into its own git worktree so that
a concurrent session flipping the shared HEAD can no longer cause this session's
commits to land on the wrong branch.

This is the *acting* counterpart to scripts/check-branch-drift.py (which only
DETECTS drift, W9). It is invoked by that hook when CLAUDE_W9_AUTO_ISOLATE=1.

DATA-LOSS-SAFE CONTRACT (PRD guardrail GR4 / kill criterion KC3):
    Uncommitted work is recoverable at every step. The stash is NEVER dropped
    until the worktree apply has been verified to reproduce the pre-isolation
    tree. Any failure path leaves the repo no worse than W9's prior warn-only
    behavior, with the stash intact and the original branch restored.

Algorithm (isolate_current_work):
    1. Acquire an exclusive lock (O_CREAT|O_EXCL). If held -> skipped
       (reason=lock_contended); caller falls back to warn-only. This prevents
       two isolations racing (the self-race risk in the PRD).
    2. Capture pre-state: branch, HEAD, porcelain-dirty?, tree digest.
    3. Clean tree -> noop (reason=clean_tree); nothing to protect.
    4. git stash push -u. On failure -> error (never proceed on a failed stash).
    5. Create/adopt the feature worktree via create-isolated-worktree.py.
    6. In the worktree: git stash apply (apply, NOT pop — keep the stash).
    7. Verify the worktree tree digest matches pre-state. On success: drop the
       stash, return isolated. On any failure: leave the stash intact, restore
       the original branch, return error (the stash ref is in the message).

Return: IsolationResult{result, reason, worktree, stash_ref}
    result in {isolated, noop, skipped, error}

Exit codes (CLI):
    0 = isolated or noop (success)
    1 = skipped (lock contended / opt-out) — non-fatal
    2 = error (recoverable; stash preserved)

This module is import-safe: importing it has no side effects.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

# Paths are resolved LIVE (not captured at import) so a test (or a process that
# sets REPO_ROOT_OVERRIDE / GATE_COVERAGE_LEDGER after import) sees the right
# checkout. REPO_ROOT_OVERRIDE mirrors the F16 try-repo convention.
def _repo_root() -> Path:
    return Path(os.environ.get("REPO_ROOT_OVERRIDE") or Path(__file__).resolve().parent.parent)


def _session_state_dir() -> Path:
    return _repo_root() / ".claude" / "_session-state"


def _lock_file() -> Path:
    return _session_state_dir() / "w9-isolate.lock"


def _ledger_path() -> Path:
    return Path(
        os.environ.get("GATE_COVERAGE_LEDGER")
        or str(_repo_root() / ".claude" / "logs" / "gate-coverage.jsonl")
    )


def _create_worktree_script() -> Path:
    return _repo_root() / "scripts" / "create-isolated-worktree.py"


@dataclass
class IsolationResult:
    result: str  # isolated | noop | skipped | error
    reason: str
    worktree: str | None = None
    stash_ref: str | None = None

    def as_dict(self) -> dict:
        return asdict(self)


def _git(*args: str, cwd: Path | None = None, check: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=str(cwd or _repo_root()),
        capture_output=True,
        text=True,
        timeout=30,
        check=check,
    )


def _current_branch(cwd: Path | None = None) -> str | None:
    r = _git("branch", "--show-current", cwd=cwd)
    if r.returncode != 0:
        return None
    return r.stdout.strip() or None


def _is_dirty(cwd: Path | None = None) -> bool:
    r = _git("status", "--porcelain", cwd=cwd)
    return bool(r.stdout.strip())


def _tree_digest(cwd: Path | None = None) -> str:
    """A digest of tracked + staged content, stable across worktrees.

    Uses `git diff HEAD` (working tree vs HEAD) so two trees with identical
    uncommitted changes on the same HEAD produce the same digest.
    """
    r = _git("diff", "HEAD", cwd=cwd)
    untracked = _git("status", "--porcelain", cwd=cwd)
    payload = (r.stdout + "\n" + untracked.stdout).encode("utf-8", "replace")
    return hashlib.sha256(payload).hexdigest()


def active_feature() -> str | None:
    f = _repo_root() / ".claude" / "active-feature"
    if not f.exists():
        return None
    name = f.read_text().strip()
    return name or None


def emit_telemetry(*, candidates: int, checked: int, skipped: int,
                   skip_reasons: list[str], outcome: str, drift: dict | None = None) -> None:
    """Append a Mechanism A row for the w9.auto_isolate gate (T3). Best-effort."""
    row = {
        "gate": "w9.auto_isolate",
        "ts": _now_iso(),
        "candidates": candidates,
        "checked": checked,
        "skipped": skipped,
        "skip_reasons": skip_reasons,
        "outcome": outcome,
    }
    if drift:
        row["drift"] = drift
    try:
        _ledger_path().parent.mkdir(parents=True, exist_ok=True)
        with _ledger_path().open("a") as fh:
            fh.write(json.dumps(row) + "\n")
    except OSError:
        pass  # telemetry is never allowed to break the primitive


def _now_iso() -> str:
    # Avoid Date.now-style nondeterminism issues in tests by honoring an override.
    override = os.environ.get("W9_FAKE_NOW")
    if override:
        return override
    import datetime as _dt
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _acquire_lock() -> int | None:
    _session_state_dir().mkdir(parents=True, exist_ok=True)
    try:
        return os.open(str(_lock_file()), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    except FileExistsError:
        return None
    except OSError:
        return None


def _release_lock(fd: int | None) -> None:
    if fd is not None:
        try:
            os.close(fd)
        except OSError:
            pass
    try:
        _lock_file().unlink()
    except OSError:
        pass


def isolate_current_work(reason: str = "w9_drift", *, dry_run: bool = False) -> IsolationResult:
    """Atomically isolate the current uncommitted work into its own worktree.

    See module docstring for the data-loss-safe contract.
    """
    lock_fd = _acquire_lock()
    if lock_fd is None:
        return IsolationResult(result="skipped", reason="lock_contended")

    try:
        feature = active_feature()
        if not feature:
            return IsolationResult(result="skipped", reason="no_active_feature")

        if not _is_dirty():
            return IsolationResult(result="noop", reason="clean_tree")

        pre_branch = _current_branch()
        pre_digest = _tree_digest()

        if dry_run:
            return IsolationResult(result="noop", reason="dry_run", worktree=None)

        # Precondition: validate the worktree-create script exists BEFORE touching
        # the working tree. Fail-fast — never stash if we can't proceed (and an
        # untracked script would itself be swept up by `git stash -u`).
        if not _create_worktree_script().exists():
            return IsolationResult(result="error", reason="create_worktree_script_missing")

        # 4. Stash uncommitted work (including untracked). NEVER proceed on failure.
        stash_msg = f"w9-auto-isolate {reason} {_now_iso()}"
        sr = _git("stash", "push", "-u", "-m", stash_msg)
        if sr.returncode != 0:
            return IsolationResult(result="error", reason=f"stash_failed: {sr.stderr.strip()[:200]}")
        # Resolve the stash ref so we can apply/drop it explicitly.
        stash_ref = "stash@{0}"

        # 5. Create/adopt the isolated worktree (idempotent).
        cr = subprocess.run(
            [sys.executable, str(_create_worktree_script()), "--feature", feature, "--create-if-missing"],
            cwd=str(_repo_root()), capture_output=True, text=True, timeout=120,
        )
        if cr.returncode not in (0,):
            _restore_after_failure(stash_ref, pre_branch)
            return IsolationResult(result="error", reason=f"worktree_create_failed: rc={cr.returncode}", stash_ref=stash_ref)

        worktree_path = _resolve_worktree_path(feature)
        if not worktree_path:
            _restore_after_failure(stash_ref, pre_branch)
            return IsolationResult(result="error", reason="worktree_path_unresolved", stash_ref=stash_ref)

        # 6. Apply (not pop) the stash in the worktree — keep stash as recovery copy.
        ar = _git("stash", "apply", stash_ref, cwd=worktree_path)
        if ar.returncode != 0:
            _restore_after_failure(stash_ref, pre_branch)
            return IsolationResult(result="error", reason=f"stash_apply_failed: {ar.stderr.strip()[:200]}", stash_ref=stash_ref)

        # 7. Verify the worktree reproduces the pre-isolation tree.
        post_digest = _tree_digest(cwd=worktree_path)
        if post_digest != pre_digest:
            _restore_after_failure(stash_ref, pre_branch)
            return IsolationResult(result="error", reason="digest_mismatch_after_apply", stash_ref=stash_ref, worktree=str(worktree_path))

        # Success — now it is safe to drop the stash from the source repo.
        _git("stash", "drop", stash_ref)
        return IsolationResult(result="isolated", reason=reason, worktree=str(worktree_path))
    finally:
        _release_lock(lock_fd)


def _restore_after_failure(stash_ref: str, pre_branch: str | None) -> None:
    """Best-effort restore of the source repo to its pre-isolation state.

    Leaves the stash INTACT (recoverable) and returns to the original branch.
    """
    if pre_branch:
        cur = _current_branch()
        if cur != pre_branch:
            _git("checkout", pre_branch)
    # Intentionally do NOT pop/drop the stash — it is the operator's recovery copy.


def _resolve_worktree_path(feature: str) -> Path | None:
    """Find the worktree whose branch is feature/<feature> via `git worktree list`."""
    r = _git("worktree", "list", "--porcelain")
    if r.returncode != 0:
        return None
    cur_path = None
    target_branch = f"refs/heads/feature/{feature}"
    for line in r.stdout.splitlines():
        if line.startswith("worktree "):
            cur_path = line[len("worktree "):].strip()
        elif line.startswith("branch "):
            if line[len("branch "):].strip() == target_branch and cur_path:
                return Path(cur_path)
    return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="W9 auto-isolation primitive (T1)")
    ap.add_argument("--reason", default="w9_drift")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--json", action="store_true", help="print IsolationResult as JSON")
    args = ap.parse_args(argv)

    res = isolate_current_work(args.reason, dry_run=args.dry_run)
    if args.json:
        print(json.dumps(res.as_dict()))
    else:
        print(f"w9-auto-isolate: {res.result} ({res.reason})"
              + (f" -> {res.worktree}" if res.worktree else "")
              + (f" [stash preserved: {res.stash_ref}]" if res.stash_ref else ""))

    return {"isolated": 0, "noop": 0, "skipped": 1, "error": 2}.get(res.result, 2)


if __name__ == "__main__":
    sys.exit(main())
