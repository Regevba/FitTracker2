#!/usr/bin/env python3
"""W31 (v7.9.1+ durable fix): detect workflow delivery anomalies on a PR.

Compares the set of *always-expected* check-runs (workflows that run on every
PR regardless of touched files) against the set of actual check-runs attached
to the PR's HEAD SHA. Surfaces any always-expected workflows that should have
run but didn't — the silent-pass class documented in observed-patterns.md W31.

Usage:
    python3 scripts/check-pr-workflow-coverage.py <PR_NUMBER>

Exit codes:
    0 — coverage looks fine (all always-expected workflows present)
    1 — missing workflows detected; operator-actionable (try rebase +
        force-push per W31 silence path 1)
    2 — usage error or gh CLI unavailable

Design notes:
- The W31 entry in observed-patterns.md documents the workaround as rebase +
  force-push (forces a `synchronize` event with clean lineage). This script
  detects the condition that would prompt that workaround — it does NOT
  auto-trigger it.
- Does NOT block PRs. This is an operator-side diagnostic tool; framework
  position is that gh-API workflow-delivery quirks are bounded by the rebase
  workaround, so the value is detection + nudge, not enforcement.
- The always-expected list is curated (not derived from `.github/workflows/`
  filesystem scan) because many workflows are intentionally path-filtered or
  schedule-triggered — including them in "expected" produces false positives.
  When CI changes, update ALWAYS_EXPECTED_PATTERNS below.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Curated list of check-run name substrings that should appear on EVERY PR
# regardless of touched files. Each entry is matched case-insensitively as a
# substring of actual check-run names. Path-filtered workflows (coverage.yml,
# pip-audit.yml, shellcheck.yml, …) are intentionally excluded.
ALWAYS_EXPECTED_PATTERNS: list[str] = [
    "build and test",          # ci.yml main job
    "analyze (actions)",       # CodeQL actions
    "analyze (javascript",     # CodeQL js/ts
    "analyze (python)",        # CodeQL py
    "codeql",                  # CodeQL umbrella
    "gitguardian",             # external secret-scan
    "gitleaks",                # secret-scan workflow
    "integrity",               # integrity-check workflow
    "lint commits",            # commitlint
    "lint-ios",                # SwiftLint
    "lint-md",                 # markdownlint
    "lint-py",                 # ruff
    "pm-framework/pr-integrity",  # pr-integrity-check.yml sticky-comment bot
    "try-repo-harness",        # F16 harness — runs on every PR
]


def _pr_head_sha(pr_number: int) -> str | None:
    try:
        result = subprocess.run(
            ["gh", "pr", "view", str(pr_number), "--json", "headRefOid", "-q", ".headRefOid"],
            capture_output=True, text=True, check=True, timeout=15,
        )
        return result.stdout.strip() or None
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return None


def _actual_check_run_names(sha: str) -> list[str] | None:
    """Combines both /check-runs (Actions) + /status (commit-status) endpoints.

    `pm-framework/pr-integrity` and similar commit-status entries surface
    under /status, not /check-runs, so a check-runs-only query under-counts
    delivered work. The `gh pr checks` UI merges both views.
    """
    names: set[str] = set()
    try:
        result = subprocess.run(
            ["gh", "api", f"repos/:owner/:repo/commits/{sha}/check-runs",
             "--jq", ".check_runs[].name"],
            capture_output=True, text=True, check=True, timeout=15,
        )
        names.update(line.strip() for line in result.stdout.splitlines() if line.strip())
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return None
    try:
        result = subprocess.run(
            ["gh", "api", f"repos/:owner/:repo/commits/{sha}/status",
             "--jq", ".statuses[].context"],
            capture_output=True, text=True, check=True, timeout=15,
        )
        names.update(line.strip() for line in result.stdout.splitlines() if line.strip())
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        # status endpoint failure shouldn't abort — check-runs alone is partial
        # but useful diagnostic.
        pass
    return sorted(names)


def check_coverage(pr_number: int) -> int:
    sha = _pr_head_sha(pr_number)
    if not sha:
        print(f"W31: could not resolve PR #{pr_number} head SHA (gh CLI unavailable?)", file=sys.stderr)
        return 2

    actual = _actual_check_run_names(sha)
    if actual is None:
        print(f"W31: could not fetch check-runs for SHA {sha[:8]} (gh CLI unavailable?)", file=sys.stderr)
        return 2

    actual_lower = [a.lower() for a in actual]
    missing_patterns: list[str] = []
    for pattern in ALWAYS_EXPECTED_PATTERNS:
        if not any(pattern.lower() in a for a in actual_lower):
            missing_patterns.append(pattern)

    present_count = len(ALWAYS_EXPECTED_PATTERNS) - len(missing_patterns)
    print(f"PR #{pr_number} (SHA {sha[:8]}): {len(actual)} check-runs delivered")
    print(f"  Always-expected workflows: {present_count}/{len(ALWAYS_EXPECTED_PATTERNS)} present")

    if missing_patterns:
        print(f"\n⚠ W31 — {len(missing_patterns)} always-expected check-run(s) appear to be MISSING:")
        for p in missing_patterns:
            print(f"    - {p}")
        print(
            "\n  Likely cause: GitHub Actions webhook delivery anomaly. "
            "Documented remediation per observed-patterns.md W31:"
        )
        print("    1. git rebase + git push --force-with-lease  (forces `synchronize` event)")
        print("    2. Verify with `gh pr checks <PR>` that the missing checks now appear")
        return 1

    print("\n✓ Coverage looks fine — all always-expected workflows present.")
    return 0


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <PR_NUMBER>", file=sys.stderr)
        return 2
    try:
        pr = int(sys.argv[1])
    except ValueError:
        print(f"usage: {Path(sys.argv[0]).name} <PR_NUMBER>", file=sys.stderr)
        return 2
    return check_coverage(pr)


if __name__ == "__main__":
    sys.exit(main())
