#!/usr/bin/env python3
"""T20 (framework-v7-8-branch-isolation): create-isolated-worktree.py

Implements the contract from integration-spec.md §2.1 — creates a feature
worktree with smart-directory naming + state.json + agent-leases.json
updates. Idempotent on already-exists.

This is the local CLI equivalent of `superpowers:using-git-worktrees
--feature X --create-if-missing`. The skill is for agent contexts; this
script is for shell/pre-commit-hook contexts. They implement the same
contract.

Usage:
    scripts/create-isolated-worktree.py --feature {slug} --create-if-missing
    scripts/create-isolated-worktree.py --feature {slug} --worktree-name-override custom

Exit codes per integration-spec §2.1:
    0  worktree created OR already_exists (idempotent success)
    2  feature-not-found
    3  feature-has-no-branch
    4  worktree-mismatch
    5  git-error / disk-full
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
SHARED_DIR = REPO_ROOT / ".claude" / "shared"
AGENT_LEASES_PATH = SHARED_DIR / "agent-leases.json"


def _shorten(slug: str) -> str:
    """Shorten a feature slug to ~3 words for path naming.

    Examples:
        framework-v7-8-branch-isolation → branch-isolation
        push-notifications-v2 → push-notifications-v2 (already short)
        unified-control-center → unified-control-center (3 words OK)
    """
    parts = slug.split("-")
    if len(parts) <= 3:
        return slug
    # Drop leading framework-vX-Y prefix common to infra features
    if parts[0] == "framework" and re.match(r"^v\d+$", parts[1] if len(parts) > 1 else ""):
        return "-".join(parts[3:]) or slug  # drop "framework-vX-Y"
    return "-".join(parts[-3:])


def _is_infra_feature(state: dict) -> bool:
    return (
        state.get("work_subtype") == "framework_feature"
        or state.get("work_type") == "chore"
    )


def _expected_worktree_path(slug: str, state: dict, override: str | None) -> Path:
    if override:
        return REPO_ROOT.parent / override
    if _is_infra_feature(state):
        return REPO_ROOT.parent / f"FitTracker2-infra-{_shorten(slug)}"
    return REPO_ROOT.parent / f"FitTracker2-{slug}"


def _utc_now() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _update_state_worktree_path(state_path: Path, worktree_path: str) -> None:
    """Atomic update of state.json::worktree_path via tmp+rename."""
    state = json.loads(state_path.read_text())
    state["worktree_path"] = worktree_path
    state["updated"] = _utc_now()
    tmp = state_path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.rename(state_path)


def _register_lease(slug: str, worktree_path: str) -> None:
    """Append/update an entry in agent-leases.json."""
    SHARED_DIR.mkdir(parents=True, exist_ok=True)
    if AGENT_LEASES_PATH.exists():
        try:
            data = json.loads(AGENT_LEASES_PATH.read_text())
        except json.JSONDecodeError:
            data = {"version": "1.0", "leases": []}
    else:
        data = {"version": "1.0", "leases": []}
    leases = data.setdefault("leases", [])
    # Update existing or append new
    for lease in leases:
        if lease.get("feature") == slug:
            lease["worktree_path"] = worktree_path
            lease["last_heartbeat"] = _utc_now()
            break
    else:
        leases.append({
            "feature": slug,
            "worktree_path": worktree_path,
            "leased_paths": [],
            "started_at": _utc_now(),
            "last_heartbeat": _utc_now(),
            "status": "active",
        })
    AGENT_LEASES_PATH.write_text(json.dumps(data, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--feature", required=True,
                        help="Feature slug (must match .claude/features/<slug>/)")
    parser.add_argument("--create-if-missing", action="store_true",
                        help="Create the worktree if it doesn't exist")
    parser.add_argument("--worktree-name-override", default=None,
                        help="Custom worktree directory name (relative to FitTracker2 parent)")
    args = parser.parse_args()

    slug = args.feature
    state_path = FEATURES_DIR / slug / "state.json"
    if not state_path.exists():
        print(f"feature-not-found: {slug}", file=sys.stderr)
        return 2

    try:
        state = json.loads(state_path.read_text())
    except json.JSONDecodeError as e:
        print(f"feature-state-invalid: {e}", file=sys.stderr)
        return 2

    expected_branch = state.get("branch")
    if not expected_branch or expected_branch == "main":
        print(f"feature-has-no-branch: {slug} (state.json::branch is '{expected_branch}')",
              file=sys.stderr)
        return 3

    expected_path = _expected_worktree_path(slug, state, args.worktree_name_override)

    # Idempotent: if already populated and exists, return success
    declared_path = state.get("worktree_path")
    if declared_path and Path(declared_path).exists():
        if declared_path != str(expected_path):
            print(f"worktree-mismatch: expected={expected_path} found={declared_path}",
                  file=sys.stderr)
            return 4
        # Already exists — refresh lease, exit 0
        _register_lease(slug, declared_path)
        print(f"already_exists: {declared_path}")
        return 0

    # If expected_path exists on disk but state.json doesn't know about it,
    # ADOPT it: link it back into state.json + register lease. This handles
    # the case where the worktree was created manually before state.json
    # learned the location (e.g. during the bootstrap of THIS feature).
    if expected_path.exists():
        # Verify it's actually a git worktree on the expected branch
        try:
            br = subprocess.check_output(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                cwd=expected_path, text=True,
            ).strip()
        except Exception as e:
            print(f"worktree-mismatch: {expected_path} exists but is not a "
                  f"valid git worktree ({e})", file=sys.stderr)
            return 4
        if br != expected_branch:
            print(f"worktree-mismatch: {expected_path} is on branch '{br}' "
                  f"but expected '{expected_branch}'", file=sys.stderr)
            return 4
        # Adopt: link state.json + register lease
        _update_state_worktree_path(state_path, str(expected_path))
        _register_lease(slug, str(expected_path))
        print(f"adopted: {expected_path}")
        return 0

    if not args.create_if_missing:
        print(f"worktree-not-found: state.json::worktree_path is null and "
              f"--create-if-missing not set. Pass --create-if-missing to "
              f"create at {expected_path}.", file=sys.stderr)
        return 4

    try:
        subprocess.run(
            ["git", "worktree", "add", str(expected_path), "-b", expected_branch],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except subprocess.CalledProcessError as e:
        print(f"git-error: {e.stderr}", file=sys.stderr)
        return 5
    except subprocess.TimeoutExpired:
        print("git-error: worktree creation timed out (30s)", file=sys.stderr)
        return 5

    # Update state.json + register lease
    _update_state_worktree_path(state_path, str(expected_path))
    _register_lease(slug, str(expected_path))

    print(str(expected_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
