#!/usr/bin/env python3
"""Bot-PR health check — Option B soak-window monitor (2026-07-13).

Detects the deadlock class Option B fixes: automated snapshot PRs
(integrity-cycle / framework-status / digest) that were opened but whose
required checks never ran ("expected" forever) because a GITHUB_TOKEN-authored
PR does not trigger workflows.

A PR is DEADLOCKED when ALL of:
  - it is open,
  - it carries an `automated` / `integrity-cycle` / `framework-status` label
    OR is authored by `app/github-actions`,
  - it is older than --max-age-hours (default 6),
  - at least one of the 3 required checks (integrity, Build and Test,
    try-repo-harness) is MISSING or in a non-terminal state (EXPECTED / PENDING /
    QUEUED) on its head.

Exit code: 0 = healthy (no deadlocked bot PRs), 1 = one or more deadlocked.
Degrades gracefully (exit 0 + notice) when `gh` is unavailable or unauthenticated,
matching the other cron-safe scripts. Meant for ad-hoc runs, the soak window, and
optional wiring into scripts/daily-integrity-checkpoint.py.

Usage:
  python3 scripts/check-bot-pr-health.py [--repo OWNER/REPO] [--max-age-hours N] [--json]
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone

REQUIRED_CHECKS = {"integrity", "Build and Test", "try-repo-harness"}
BOT_LABELS = {"automated", "integrity-cycle", "framework-status"}
TERMINAL_OK = {"SUCCESS", "NEUTRAL", "SKIPPED"}
DEFAULT_REPO = "Regevba/FitTracker2"


def _gh(args: list[str]) -> tuple[int, str]:
    try:
        p = subprocess.run(
            ["gh", *args], capture_output=True, text=True, timeout=60, check=False
        )
        return p.returncode, p.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return 127, ""


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _age_hours(iso: str) -> float:
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        return (_now() - dt).total_seconds() / 3600.0
    except ValueError:
        return 0.0


def analyze(prs: list[dict], max_age_hours: float) -> list[dict]:
    """Return the list of deadlocked PRs (pure — unit-testable)."""
    deadlocked = []
    for pr in prs:
        labels = {lbl.get("name", "") for lbl in pr.get("labels", [])}
        author = pr.get("author", {}).get("login", "")
        is_bot = bool(labels & BOT_LABELS) or author in {
            "app/github-actions",
            "github-actions[bot]",
            "github-actions",
        }
        if not is_bot:
            continue
        if _age_hours(pr.get("createdAt", "")) < max_age_hours:
            continue
        rollup = pr.get("statusCheckRollup") or []
        states = {}
        for c in rollup:
            name = c.get("name") or c.get("context") or ""
            states[name] = c.get("state") or c.get("conclusion") or "EXPECTED"
        missing = [
            c for c in REQUIRED_CHECKS
            if states.get(c) is None or states.get(c) not in TERMINAL_OK
        ]
        if missing:
            deadlocked.append({
                "number": pr.get("number"),
                "title": pr.get("title", ""),
                "author": author,
                "age_hours": round(_age_hours(pr.get("createdAt", "")), 1),
                "missing_or_pending": sorted(missing),
            })
    return deadlocked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument("--max-age-hours", type=float, default=6.0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    rc, out = _gh([
        "pr", "list", "--repo", args.repo, "--state", "open", "--limit", "50",
        "--json", "number,title,author,labels,createdAt,statusCheckRollup",
    ])
    if rc == 127:
        print("notice: gh unavailable — bot-PR health check skipped (exit 0).")
        return 0
    if rc != 0:
        print("notice: gh pr list failed (auth?) — bot-PR health check skipped (exit 0).")
        return 0
    try:
        prs = json.loads(out or "[]")
    except json.JSONDecodeError:
        print("notice: could not parse gh output — skipped (exit 0).")
        return 0

    deadlocked = analyze(prs, args.max_age_hours)
    if args.json:
        print(json.dumps({"deadlocked": deadlocked, "count": len(deadlocked)}, indent=2))
    elif not deadlocked:
        print(f"✓ bot-PR health OK — no deadlocked automated PRs (repo {args.repo}).")
    else:
        print(f"⚠ {len(deadlocked)} DEADLOCKED bot PR(s) — Option B not working "
              f"(WORKFLOW_PR_TOKEN unset, or the PAT-PR path failed):")
        for d in deadlocked:
            print(f"  #{d['number']} [{d['age_hours']}h] {d['title']}")
            print(f"       missing/pending required checks: {', '.join(d['missing_or_pending'])}")
        print("  → See docs/setup/bot-pr-ci-trigger-setup.md. If persistent through the "
              "soak window, Option B failed — reconsider Option A.")
    return 1 if deadlocked else 0


if __name__ == "__main__":
    sys.exit(main())
