#!/usr/bin/env python3
"""
Validate `.claude/features/*/state.json` files against the canonical schema.

Canonical schema rules (enforced at write time via the pre-commit hook):

1. **SCHEMA_DRIFT** — use `current_phase`, not the legacy `phase` key.
   Surfaced by the 2026-04-21 structural meta-analysis (2 of 40 files used
   the legacy key); both since migrated.
2. **PR_NUMBER_UNRESOLVED** — if `phases.merge.pr_number` is set, verify the
   PR resolves via `gh pr view`. Closes Gemini audit Tier 1.2's
   "integrate with sources of truth" recommendation at write-time rather
   than only post-hoc on the 72h integrity cycle. Skipped gracefully if
   `gh` is unavailable (CI without GH_TOKEN, offline dev, etc.).

Usage:
    scripts/check-state-schema.py                    # scan all state.json files
    scripts/check-state-schema.py <path> [<path>...] # validate specific files
    scripts/check-state-schema.py --staged           # validate git-staged files

Exit codes:
    0  all validated files pass all checks
    1  one or more files violate a check (message on stderr)
    2  usage error or missing file
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"


# Module-level PR cache. Populated lazily on first PR-resolving check so we
# only call `gh pr list` once per script invocation, not once per file.
# None = "not yet loaded"; set() = "loaded but empty or unavailable".
_PR_CACHE: set[int] | None = None
_PR_CACHE_LOADED: bool = False


def _load_pr_cache() -> set[int] | None:
    """Load all PR numbers via `gh pr list --state all`.

    Returns None if `gh` is unavailable or unauthenticated — the caller skips
    the PR-resolution check rather than failing the hook. We never want a
    missing GH_TOKEN or an offline dev environment to block a legitimate
    commit; the 72h integrity cycle catches PR drift anyway.
    """
    global _PR_CACHE, _PR_CACHE_LOADED
    if _PR_CACHE_LOADED:
        return _PR_CACHE
    _PR_CACHE_LOADED = True
    try:
        out = subprocess.check_output(
            ["gh", "pr", "list", "--state", "all", "--limit", "500",
             "--json", "number"],
            text=True, stderr=subprocess.DEVNULL,
        )
        _PR_CACHE = {p["number"] for p in json.loads(out)}
    except (subprocess.CalledProcessError, FileNotFoundError,
            json.JSONDecodeError):
        _PR_CACHE = None
    return _PR_CACHE


def validate_file(path: Path) -> list[str]:
    """Return a list of human-readable violation messages for one file."""
    errors: list[str] = []
    if not path.exists():
        errors.append(f"{path}: does not exist")
        return errors
    try:
        d = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"{path}: invalid JSON ({e})")
        return errors

    # Check 1: SCHEMA_DRIFT — legacy `phase` key
    if "phase" in d and "current_phase" not in d:
        errors.append(
            f"{path}: uses legacy `phase` key; canonical is `current_phase`. "
            f"Rename the key (value stays the same)."
        )

    # Check 2: PR_NUMBER_UNRESOLVED — phases.merge.pr_number must resolve
    merge_obj = (d.get("phases") or {}).get("merge")
    if isinstance(merge_obj, dict):
        pr_number = merge_obj.get("pr_number")
        if isinstance(pr_number, int):
            pr_cache = _load_pr_cache()
            if pr_cache is not None and pr_number not in pr_cache:
                errors.append(
                    f"{path}: phases.merge.pr_number = {pr_number} does not "
                    f"resolve on GitHub. Fix the number or remove the field "
                    f"before advancing to the merge phase."
                )
    return errors


def collect_staged_state_files() -> list[Path]:
    """Return list of staged state.json paths under .claude/features/."""
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    paths = []
    for line in out.splitlines():
        if not line:
            continue
        if line.startswith(".claude/features/") and line.endswith("/state.json"):
            p = REPO_ROOT / line
            if p.exists():
                paths.append(p)
    return paths


def collect_all_state_files() -> list[Path]:
    if not FEATURES_DIR.exists():
        return []
    return sorted(FEATURES_DIR.glob("*/state.json"))


def main() -> int:
    args = sys.argv[1:]
    if args == ["--staged"]:
        files = collect_staged_state_files()
        mode = "staged"
    elif not args:
        files = collect_all_state_files()
        mode = "all"
    else:
        files = [Path(a).resolve() for a in args]
        mode = "explicit"

    if not files:
        print(f"No state.json files to validate (mode={mode}).")
        return 0

    all_errors: list[str] = []
    for p in files:
        all_errors.extend(validate_file(p))

    if all_errors:
        print(f"✗ STATE_SCHEMA: {len(all_errors)} violation(s) "
              f"(mode={mode}, files scanned={len(files)})",
              file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    pr_cache = _PR_CACHE if _PR_CACHE_LOADED else None
    pr_note = ""
    if pr_cache is not None:
        pr_note = f" (PR-resolution: {len(pr_cache)} known PRs)"
    elif _PR_CACHE_LOADED:
        pr_note = " (PR-resolution skipped — gh unavailable)"
    print(f"✓ All {len(files)} state.json files pass all checks "
          f"(mode={mode}){pr_note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
