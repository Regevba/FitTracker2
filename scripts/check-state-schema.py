#!/usr/bin/env python3
"""
Validate `.claude/features/*/state.json` files against the canonical schema.

Canonical schema rule: use `current_phase`, not `phase`. The two-key drift was
surfaced by the 2026-04-21 structural meta-analysis (2 of 40 files used the
legacy key). This script enforces the rule on write.

Usage:
    scripts/check-state-schema.py                    # scan all state.json files
    scripts/check-state-schema.py <path> [<path>...] # validate specific files
    scripts/check-state-schema.py --staged           # validate git-staged files

Exit codes:
    0  all validated files use the canonical schema
    1  one or more files violate the schema (message on stderr)
    2  usage error or missing file
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"


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
    if "phase" in d and "current_phase" not in d:
        errors.append(
            f"{path}: uses legacy `phase` key; canonical is `current_phase`. "
            f"Rename the key (value stays the same)."
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
        print(f"✗ SCHEMA_DRIFT: {len(all_errors)} violation(s) "
              f"(mode={mode}, files scanned={len(files)})",
              file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(f"✓ All {len(files)} state.json files use canonical schema "
          f"(mode={mode}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
