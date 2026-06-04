#!/usr/bin/env python3
"""F2 — Phase 0 reality-check sub-step.

For a feature whose state.json carries a tasks list, this script checks each
pending task against recent (≤30d) evidence of completion in the codebase:

  1. Recent merged PRs whose title contains the task description keywords
  2. Recent (≤30d) git log commits whose subject contains the keywords
  3. Recent Tier 2.2 log events (.claude/logs/<feature>.log.json) whose
     summary mentions the task ID or description keywords

Emits structured advisory findings to stdout AND writes to
`.claude/shared/phase-0-reality-check.json` for downstream Phase 0
consumers (e.g., /pm-workflow can read the cache).

Motivation: 5 confirmed instances of post-squash-merge state-drift
documented in a single week (2026-05-30 → 2026-06-04). F2 is the
mechanical defense — surface "this task may already be done" advisories
BEFORE scheduling new work on top of stale state.

Spec: docs/master-plan/infra-master-plan-2026-05-12.md §3.1 Theme A F2 (RICE 42.7).
Linear: FIT-90.

Usage:
    scripts/phase-0-reality-check.py --feature <feature-name>
    scripts/phase-0-reality-check.py --feature <name> --quiet
    scripts/phase-0-reality-check.py --feature <name> --window-days 60

Exit codes:
    0  reality-check completed (advisories printed; never blocking)
    1  feature state.json missing or unreadable
    2  usage error
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


# `REPO_ROOT_OVERRIDE` env var support (Q6 fix from F16 — see PR #611).
_REPO_ROOT_OVERRIDE = os.environ.get("REPO_ROOT_OVERRIDE")
if _REPO_ROOT_OVERRIDE:
    REPO_ROOT = Path(_REPO_ROOT_OVERRIDE).resolve()
else:
    REPO_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_WINDOW_DAYS = 30
DEFAULT_OUTPUT = REPO_ROOT / ".claude" / "shared" / "phase-0-reality-check.json"


# Task description tokens that are too generic to match against (would
# false-positive on every commit). Tunable via the script's __test__ hook.
NOISE_TOKENS = {
    "the", "a", "an", "of", "and", "or", "to", "in", "on", "for", "with",
    "from", "by", "at", "as", "is", "be", "was", "were", "are", "do", "does",
    "did", "have", "has", "had", "will", "would", "should", "must", "can",
    "may", "test", "tests", "testing", "add", "update", "make", "ensure",
    "use", "run", "write", "build", "create", "set", "get", "check",
    "feature", "task", "phase", "ship", "shipped", "implement", "ts", "py",
    "md", "json", "yaml", "yml", "above", "below", "etc", "incl", "via",
    "before", "after", "until", "while", "during", "case", "case-study",
    "scripts", "tests", "framework", "v7", "v8",
}


def _extract_keywords(text: str, min_len: int = 4) -> list[str]:
    """Return distinct alphanumeric tokens of length >= min_len from `text`,
    minus the noise list.

    Used to build the search corpus for git log + PR-title matching. Order
    is stable (insertion order); duplicates removed.
    """
    if not isinstance(text, str):
        return []
    tokens = re.findall(r"[A-Za-z][A-Za-z0-9_-]{%d,}" % (min_len - 1), text)
    seen: set[str] = set()
    out: list[str] = []
    for tok in tokens:
        low = tok.lower()
        if low in NOISE_TOKENS:
            continue
        if low in seen:
            continue
        seen.add(low)
        out.append(tok)
    return out


def _recent_git_subjects(window_days: int) -> list[tuple[str, str]]:
    """Return [(commit_sha, subject)] for commits in the last `window_days`.

    Falls back to empty list on git failure.
    """
    try:
        out = subprocess.check_output(
            [
                "git",
                "log",
                f"--since={window_days} days ago",
                "--pretty=format:%H\t%s",
            ],
            cwd=REPO_ROOT,
            text=True,
            timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return []
    rows: list[tuple[str, str]] = []
    for line in out.splitlines():
        if "\t" not in line:
            continue
        sha, subj = line.split("\t", 1)
        rows.append((sha.strip(), subj.strip()))
    return rows


def _recent_merged_prs(window_days: int) -> list[dict]:
    """Return merged PR records from .cache/gh-pr-cache.json within the window.

    Reads the v7.8.3 D-3 unified PR cache. Falls back to empty list if the
    cache is absent or malformed.
    """
    cache_path = REPO_ROOT / ".cache" / "gh-pr-cache.json"
    if not cache_path.exists():
        return []
    try:
        cache = json.loads(cache_path.read_text())
    except json.JSONDecodeError:
        return []
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)
    out: list[dict] = []
    for repo, by_state in (cache.get("repos") or {}).items():
        for state in ("merged", "closed", "open"):
            for pr in (by_state.get(state) or []):
                # The cache stores number/title/state; merge timestamps are
                # not cached. We accept all merged PRs as in-window since
                # the cache itself is freshness-controlled by ensure-pr-cache-fresh.py.
                if not isinstance(pr, dict):
                    continue
                out.append({"repo": repo, **pr})
    return out


def _recent_log_events(feature_slug: str, window_days: int) -> list[dict]:
    """Return Tier 2.2 log events (≤window_days old) for the feature."""
    log_path = REPO_ROOT / ".claude" / "logs" / f"{feature_slug}.log.json"
    if not log_path.exists():
        return []
    try:
        data = json.loads(log_path.read_text())
    except json.JSONDecodeError:
        return []
    events = data.get("events") or []
    cutoff = datetime.now(timezone.utc) - timedelta(days=window_days)
    out: list[dict] = []
    for ev in events:
        if not isinstance(ev, dict):
            continue
        ts = ev.get("timestamp")
        if not isinstance(ts, str):
            continue
        try:
            ts_dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts_dt < cutoff:
            continue
        out.append(ev)
    return out


def check_task(
    task: dict,
    git_subjects: list[tuple[str, str]],
    merged_prs: list[dict],
    log_events: list[dict],
) -> dict:
    """Return a finding dict for one task.

    Result shape:
      {
        "id": "T3",
        "status": "pending",
        "description": "...",
        "evidence": {
          "git_commits": [{"sha": "...", "subject": "..."}],
          "merged_prs": [{"repo": "...", "number": N, "title": "..."}],
          "log_events": [{"event_type": "...", "summary": "...", "timestamp": "..."}],
        },
        "match_score": int,  # rough sum: total matched commits + PRs + events
        "advisory": "this task may already be done" | None,
      }
    """
    desc = task.get("description") or ""
    task_id = task.get("id") or "?"
    keywords = _extract_keywords(desc)

    matched_commits: list[dict] = []
    matched_prs: list[dict] = []
    matched_events: list[dict] = []

    # Git log subject matching — at least 2 distinct keywords must hit.
    if keywords:
        for sha, subj in git_subjects:
            subj_low = subj.lower()
            hits = sum(1 for kw in keywords if kw.lower() in subj_low)
            if hits >= 2:
                matched_commits.append({"sha": sha[:8], "subject": subj})

    # PR title matching — at least 2 distinct keywords.
    if keywords:
        for pr in merged_prs:
            title = (pr.get("title") or "").lower()
            hits = sum(1 for kw in keywords if kw.lower() in title)
            if hits >= 2:
                matched_prs.append(
                    {
                        "repo": pr.get("repo"),
                        "number": pr.get("number"),
                        "title": pr.get("title"),
                    }
                )

    # Tier 2.2 log event matching — task ID OR keywords.
    for ev in log_events:
        summary = (ev.get("summary") or "").lower()
        if task_id.lower() in summary:
            matched_events.append(
                {
                    "event_type": ev.get("event_type"),
                    "summary": ev.get("summary"),
                    "timestamp": ev.get("timestamp"),
                }
            )
            continue
        if keywords:
            hits = sum(1 for kw in keywords if kw.lower() in summary)
            if hits >= 2:
                matched_events.append(
                    {
                        "event_type": ev.get("event_type"),
                        "summary": ev.get("summary"),
                        "timestamp": ev.get("timestamp"),
                    }
                )

    score = len(matched_commits) + len(matched_prs) + len(matched_events)
    advisory = None
    if (
        task.get("status") in {"pending", "open", "in_progress"}
        and score >= 2
    ):
        advisory = "this task may already be done"

    return {
        "id": task_id,
        "status": task.get("status"),
        "description": desc,
        "evidence": {
            "git_commits": matched_commits,
            "merged_prs": matched_prs,
            "log_events": matched_events,
        },
        "match_score": score,
        "advisory": advisory,
    }


def reality_check(
    feature_slug: str, window_days: int = DEFAULT_WINDOW_DAYS
) -> dict:
    """Run the reality-check for one feature and return the full report.

    Raises:
        FileNotFoundError: if the feature's state.json does not exist.
    """
    state_path = (
        REPO_ROOT / ".claude" / "features" / feature_slug / "state.json"
    )
    if not state_path.exists():
        raise FileNotFoundError(f"state.json not found: {state_path}")
    state = json.loads(state_path.read_text())
    tasks = state.get("tasks") or []
    if not isinstance(tasks, list):
        tasks = []

    git_subjects = _recent_git_subjects(window_days)
    merged_prs = _recent_merged_prs(window_days)
    log_events = _recent_log_events(feature_slug, window_days)

    findings = [
        check_task(t, git_subjects, merged_prs, log_events)
        for t in tasks
        if isinstance(t, dict)
    ]
    flagged = [f for f in findings if f["advisory"]]

    return {
        "schema_version": 1,
        "checked_at": datetime.now(timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z"),
        "feature": feature_slug,
        "window_days": window_days,
        "task_count": len(findings),
        "flagged_count": len(flagged),
        "findings": findings,
    }


def print_report(report: dict, quiet: bool = False) -> None:
    """Pretty-print the report to stdout."""
    if quiet:
        return
    feature = report["feature"]
    flagged = report["flagged_count"]
    total = report["task_count"]
    if flagged == 0:
        print(
            f"phase-0-reality-check: {feature} — {total} tasks, "
            f"0 advisories (no drift detected)."
        )
        return
    print(
        f"phase-0-reality-check: {feature} — {total} tasks, "
        f"{flagged} advisory finding(s):"
    )
    for f in report["findings"]:
        if not f["advisory"]:
            continue
        evidence = f["evidence"]
        print(f"  [{f['id']}] {f['description'][:100]}")
        print(f"      status={f['status']} — {f['advisory']}")
        if evidence["git_commits"]:
            for c in evidence["git_commits"][:3]:
                print(f"      git: {c['sha']} — {c['subject'][:80]}")
        if evidence["merged_prs"]:
            for p in evidence["merged_prs"][:3]:
                print(
                    f"      PR : {p['repo']}#{p['number']} — "
                    f"{(p.get('title') or '')[:80]}"
                )
        if evidence["log_events"]:
            for ev in evidence["log_events"][:2]:
                print(
                    f"      log: {ev.get('event_type')} @ "
                    f"{ev.get('timestamp')} — "
                    f"{(ev.get('summary') or '')[:80]}"
                )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--feature", required=True, help="Feature slug (e.g., f17-last-fired-at-index)"
    )
    parser.add_argument(
        "--window-days",
        type=int,
        default=DEFAULT_WINDOW_DAYS,
        help=f"How far back to scan git log + Tier 2.2 events (default: {DEFAULT_WINDOW_DAYS})",
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help="Path to write the report JSON (default: .claude/shared/phase-0-reality-check.json)",
    )
    parser.add_argument(
        "--quiet", action="store_true", help="Suppress stdout report"
    )
    args = parser.parse_args()

    try:
        report = reality_check(args.feature, window_days=args.window_days)
    except FileNotFoundError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
        f.write("\n")

    print_report(report, quiet=args.quiet)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
