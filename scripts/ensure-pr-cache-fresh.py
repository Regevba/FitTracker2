#!/usr/bin/env python3
"""PR-cache freshness gate — v7.8.4.

Checks `.cache/gh-pr-cache.json` for staleness (>24h since last_refreshed_at,
or missing/empty cache). If stale, invokes `scripts/refresh-pr-cache.py`
inline so downstream consumers (integrity-check, pre-commit BROKEN_PR_CITATION,
PR_NUMBER_UNRESOLVED) see a fresh cache.

This closes the v7.8.3-era silent-pass mode where an empty/stale cache turned
all `BROKEN_PR_CITATION` lookups into false positives (33 spurious findings
observed 2026-05-12 before this gate shipped). See CLAUDE.md "v7.8.4" section.

Exit codes:
    0 — cache is fresh OR was just refreshed successfully
    1 — refresh attempt failed (gh CLI unavailable, network error, etc.)
        Downstream consumers should still proceed but treat
        BROKEN_PR_CITATION findings with skepticism in this run.

Usage:
    python3 scripts/ensure-pr-cache-fresh.py [--max-age-hours 24] [--quiet]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_PATH = REPO_ROOT / ".cache" / "gh-pr-cache.json"
REFRESH_SCRIPT = REPO_ROOT / "scripts" / "refresh-pr-cache.py"

# Keep in sync with REPOS in scripts/refresh-pr-cache.py (v7.8.3 D-3 unified cache).
# If refresh-pr-cache.py ever adds a third repo, append it here too — otherwise
# the per-repo completeness check below will perpetually request a refresh.
EXPECTED_REPOS = ("Regevba/FitTracker2", "Regevba/fitme-story")


def cache_age_seconds() -> float | None:
    """Return cache age in seconds, or None if cache is missing/unreadable."""
    if not CACHE_PATH.exists():
        return None
    try:
        data = json.loads(CACHE_PATH.read_text())
    except (json.JSONDecodeError, OSError):
        return None
    ts = data.get("last_refreshed_at")
    if not ts:
        return None
    try:
        # Parse ISO-8601 timestamp with Z suffix
        from datetime import datetime, timezone
        if ts.endswith("Z"):
            ts = ts[:-1] + "+00:00"
        dt = datetime.fromisoformat(ts)
        return time.time() - dt.timestamp()
    except (ValueError, AttributeError):
        return None


def cache_is_empty() -> bool:
    """A cache file exists but reports zero PRs in both repos. Treat as stale."""
    if not CACHE_PATH.exists():
        return True
    try:
        data = json.loads(CACHE_PATH.read_text())
    except (json.JSONDecodeError, OSError):
        return True
    repos = data.get("repos", {})
    if not repos:
        return True
    for _, info in repos.items():
        if not isinstance(info, dict):
            continue
        for bucket in ("open", "merged", "closed"):
            if info.get(bucket):
                return False  # found at least one PR somewhere
    return True


def cache_missing_expected_repos() -> tuple[bool, list[str]]:
    """Detect the W11 pattern: cache exists + non-empty but one of the expected
    cross-repo entries is absent or has zero PRs in all buckets. A partial-write
    or refresh interruption can leave the cache in this state, causing every
    cross-repo BROKEN_PR_CITATION lookup to false-positive.

    Returns (is_incomplete, missing_repos). Sibling check to cache_is_empty —
    we run both so a fully-empty cache surfaces its own clearer reason string.
    """
    if not CACHE_PATH.exists():
        return False, []  # cache_age_seconds() already covers this case
    try:
        data = json.loads(CACHE_PATH.read_text())
    except (json.JSONDecodeError, OSError):
        return False, []
    repos = data.get("repos", {})
    missing: list[str] = []
    for expected in EXPECTED_REPOS:
        info = repos.get(expected)
        if not isinstance(info, dict):
            missing.append(expected)
            continue
        has_any = any(info.get(b) for b in ("open", "merged", "closed"))
        if not has_any:
            missing.append(expected)
    return (len(missing) > 0), missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max-age-hours", type=float, default=24.0,
        help="Refresh if cache is older than this (default: 24)",
    )
    parser.add_argument(
        "--quiet", action="store_true",
        help="Suppress stdout when cache is fresh (errors still go to stderr)",
    )
    args = parser.parse_args()

    age = cache_age_seconds()
    max_age_seconds = args.max_age_hours * 3600

    needs_refresh = False
    reason = ""

    if age is None:
        needs_refresh = True
        reason = "cache missing or unparseable"
    elif cache_is_empty():
        needs_refresh = True
        reason = "cache reports 0 PRs in all repos (likely never populated)"
    else:
        # W11 — incomplete cache (one of two expected repos absent or empty).
        # See .claude/integrity/observed-patterns.md §W11 for the full story.
        incomplete, missing = cache_missing_expected_repos()
        if incomplete:
            needs_refresh = True
            reason = f"cache missing expected repo(s): {', '.join(missing)} (W11 incomplete-cache pattern)"
        elif age > max_age_seconds:
            needs_refresh = True
            reason = f"cache age {age/3600:.1f}h > threshold {args.max_age_hours}h"

    if not needs_refresh:
        if not args.quiet:
            print(f"PR cache fresh ({age/3600:.1f}h old).")
        return 0

    print(f"PR_CACHE_STALE: {reason}. Refreshing…", file=sys.stderr)
    try:
        result = subprocess.run(
            ["python3", str(REFRESH_SCRIPT)],
            cwd=str(REPO_ROOT),
            check=True,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.stdout:
            print(result.stdout.rstrip(), file=sys.stderr)
        return 0
    except subprocess.CalledProcessError as exc:
        print(
            f"PR_CACHE_STALE: refresh failed ({exc}). "
            f"Downstream PR-citation gates may produce false positives.",
            file=sys.stderr,
        )
        if exc.stderr:
            print(exc.stderr.rstrip(), file=sys.stderr)
        return 1
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(
            f"PR_CACHE_STALE: refresh unavailable ({exc}). "
            f"Downstream PR-citation gates may produce false positives.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
