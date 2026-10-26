#!/usr/bin/env python3
"""Refresh the unified cross-repo PR cite cache.

v7.8.3 D-3. Writes .cache/gh-pr-cache.json with PRs from both
Regevba/FitTracker2 and Regevba/fitme-story.

Schema:
  {
    "schema_version": 1,
    "last_refreshed_at": "<ISO timestamp>",
    "repos": {
      "Regevba/FitTracker2": {"open": [...], "merged": [...], "closed": [...]},
      "Regevba/fitme-story": {"open": [...], "merged": [...], "closed": [...]},
    }
  }

Skips gracefully when `gh` is unavailable or auth missing (matches existing
BROKEN_PR_CITATION skip-on-missing-gh pattern).

Partial failure (2026-10-26): if one repo's fetch fails (e.g. a gh timeout on
the ~1.2k-PR FT2 list), that repo's entry is carried forward from the previous
cache instead of being dropped, and the script exits 1 so
ensure-pr-cache-fresh.py raises its refresh-failed flag. Dropping the repo made
every FT2 cite look broken (521 phantom findings in the 10-26 checkpoint).
"""
from __future__ import annotations
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPOS = ["Regevba/FitTracker2", "Regevba/fitme-story"]
CACHE_FILE = Path(".cache") / "gh-pr-cache.json"


def fetch_repo_prs(repo: str) -> dict | None:
    """Fetch PRs for one repo across all states. Return None on gh failure."""
    repo_data = {}
    for state in ["open", "merged", "closed"]:
        try:
            result = subprocess.check_output(
                ["gh", "pr", "list", "--repo", repo, "--state", state,
                 "--json", "number,title,state", "--limit", "2000"],
                stderr=subprocess.PIPE,
                timeout=120,
            )
            repo_data[state] = json.loads(result)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"WARN: failed to fetch {repo} {state} PRs: {e}", file=sys.stderr)
            return None
    return repo_data


def load_previous_cache() -> dict:
    """The existing cache file's contents, or {} if it is missing/unreadable."""
    try:
        return json.loads(CACHE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def main() -> int:
    previous_cache = load_previous_cache()
    previous = previous_cache.get("repos", {})
    failed = []
    cache = {
        "schema_version": 1,
        "last_refreshed_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "repos": {},
    }
    for repo in REPOS:
        repo_data = fetch_repo_prs(repo)
        if repo_data is None:
            failed.append(repo)
            if repo in previous:
                print(f"WARN: {repo} fetch failed; carrying forward its previous cache entry", file=sys.stderr)
                cache["repos"][repo] = previous[repo]
            else:
                print(f"WARN: skipping {repo} (gh unavailable or auth failed)", file=sys.stderr)
            continue
        cache["repos"][repo] = repo_data

    if failed and previous_cache.get("last_refreshed_at"):
        # Carried-forward data is as old as the previous refresh; keep its
        # timestamp so the freshness gate retries instead of trusting it for 24h.
        cache["last_refreshed_at"] = previous_cache["last_refreshed_at"]

    if not cache["repos"]:
        print("ERROR: no repos cached; gh likely unavailable", file=sys.stderr)
        return 1

    CACHE_FILE.parent.mkdir(exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, indent=2) + "\n")
    pr_count = sum(len(r.get(s, [])) for r in cache['repos'].values() for s in ['open','merged','closed'])
    print(f"Wrote {CACHE_FILE} ({pr_count} PRs across {len(cache['repos'])} repos)")
    if failed:
        print(f"ERROR: partial refresh — failed: {', '.join(failed)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
