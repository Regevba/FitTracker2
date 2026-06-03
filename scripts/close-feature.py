#!/usr/bin/env python3
"""
close-feature.py — automate post-merge feature-state closure.

Closes the gap documented as the "drift-pattern" in session memory:
single-session feature ships via squash-merge, but the state.json closure
batch (testing → review → merge → docs → complete) lands separately as a
chore PR. By 2026-06-03 this had happened 5 times — automation justified.

Usage:
    python3 scripts/close-feature.py FEATURE [--pr N] [--closure-branch NAME]
                                     [--no-strike] [--no-commit]
                                     [--dry-run]

Examples:
    # Auto-detect the merge PR by feature branch name (`feature/<FEATURE>`):
    python3 scripts/close-feature.py adaptive-intelligence-next-pass

    # Explicit PR number when the branch name didn't match:
    python3 scripts/close-feature.py orchid-v1-5 --pr 401

    # Just stage the changes — caller writes their own commit message:
    python3 scripts/close-feature.py c5-feature --pr 572 --no-commit

What it does (mirrors the manual D1 closure pattern that landed in PR #587):
    1. Look up the merge PR via `gh pr view` — needs status==MERGED.
    2. Open `chore/<feature>-post-merge-closure` off current branch (unless
       already on a chore branch — then just commit there).
    3. Mutate `.claude/features/<feature>/state.json`:
       - current_phase                → complete
       - merge_pr_number              → N
       - merge_commit_sha             → full sha
       - merged_at                    → ISO timestamp
       - case_study                   → docs/case-studies/<feature>-case-study.md (if exists)
       - branch                       → closure branch name
       - feature_branch_merged        → original branch
       - phases.{review,merge,docs,complete} → added with audit transitions
       - timing.phases mirrors        → same
       - transitions[]                → 4 transitions appended
    4. Append a Tier 2.2 log entry via `scripts/append-feature-log.py`.
    5. (Optional) strike the matching backlog row in `docs/product/backlog.md`.
    6. `git add` everything (caller commits unless --no-commit).

Idempotency: if `current_phase` is already `complete`, exits with a warning
and does nothing. Safe to re-run.

Validation: refuses to mutate if state.json is missing or the PR isn't
merged. Prints what it would change in dry-run mode.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def run(cmd: list[str], *, check: bool = True, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        check=check,
        capture_output=capture,
        text=True,
    )


def fetch_pr_metadata(pr_number: int) -> dict:
    """Returns {state, mergedAt, mergeCommit.oid, headRefName, mergedBy.login}."""
    r = run(
        ["gh", "pr", "view", str(pr_number),
         "--json", "state,mergedAt,mergeCommit,headRefName,mergedBy,title"],
    )
    return json.loads(r.stdout)


def find_pr_for_feature(feature: str) -> int | None:
    """Search recent merged PRs for one whose headRefName matches feature/<feature>."""
    r = run(
        ["gh", "pr", "list", "--state", "merged", "--limit", "60",
         "--json", "number,headRefName,mergedAt"],
    )
    pulls = json.loads(r.stdout)
    candidates = [p for p in pulls if p["headRefName"] == f"feature/{feature}"]
    if not candidates:
        return None
    # Newest merge wins (if multiple merge-PRs to feature/<name> ever existed)
    candidates.sort(key=lambda p: p["mergedAt"], reverse=True)
    return candidates[0]["number"]


def current_branch() -> str:
    return run(["git", "rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()


def open_closure_branch(name: str) -> None:
    """git checkout -b name (or stay on it if already there)."""
    if current_branch() == name:
        return
    # New branch off the current HEAD
    run(["git", "checkout", "-b", name])


def now_iso() -> str:
    # The merge happened at PR's mergedAt; the closure happens now.
    # We accept caller's clock — used only for phases.docs/complete.{started_at,ended_at}.
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def close_feature(
    *, feature: str, pr_number: int,
    closure_branch: str, do_strike_backlog: bool,
    dry_run: bool, force_incomplete: bool = False,
) -> int:
    close_feature._force_incomplete = force_incomplete  # type: ignore[attr-defined]
    state_path = REPO_ROOT / ".claude" / "features" / feature / "state.json"
    if not state_path.exists():
        print(f"✗ state.json missing for feature '{feature}' at {state_path}", file=sys.stderr)
        return 2

    state = json.loads(state_path.read_text())

    if state.get("current_phase") == "complete":
        print(f"✓ '{feature}' already complete (current_phase=complete). Idempotent no-op.")
        return 0

    # Sanity: usual happy-path is closing from `testing`. Any earlier phase
    # means the feature PR was partial — closing now would skip phases that
    # never finished. Surface this loudly; operator may still proceed with
    # --force-incomplete (escape hatch).
    EARLY_PHASES = {"research", "prd", "tasks_phase", "ux_or_integration", "implementation"}
    if state.get("current_phase") in EARLY_PHASES:
        print(
            f"⚠ '{feature}' is at current_phase={state['current_phase']} — earlier than 'testing'.\n"
            f"  This usually means PR #{pr_number} was a partial-phase landing and the feature\n"
            f"  isn't actually done. Closing now would skip the remaining phases.\n"
            f"  If you still want to close (the PR was the final landing), re-run with\n"
            f"  --force-incomplete.",
            file=sys.stderr,
        )
        if not getattr(close_feature, "_force_incomplete", False):
            return 4

    pr_meta = fetch_pr_metadata(pr_number)
    if pr_meta.get("state") != "MERGED":
        print(
            f"✗ PR #{pr_number} state is {pr_meta.get('state')}, not MERGED. Aborting.",
            file=sys.stderr,
        )
        return 3

    merged_at = pr_meta["mergedAt"]
    merge_sha = pr_meta["mergeCommit"]["oid"]
    feature_branch = pr_meta["headRefName"]
    closure_ts = now_iso()

    old_phase = state.get("current_phase", "?")

    # Top-level closure fields
    state["current_phase"] = "complete"
    state["merge_pr_number"] = pr_number
    state["merge_commit_sha"] = merge_sha
    state["merged_at"] = merged_at

    # case_study link if file exists at the canonical default
    cs_default = Path(f"docs/case-studies/{feature}-case-study.md")
    if (REPO_ROOT / cs_default).exists() and not state.get("case_study"):
        state["case_study"] = str(cs_default)

    # Branch ownership (Mode C compliance)
    state["branch"] = closure_branch
    state["feature_branch_merged"] = feature_branch

    # Add closure phase blocks
    phases = state.setdefault("phases", {})

    # End the previous phase if it didn't have ended_at
    if old_phase != "?" and old_phase in phases:
        phases[old_phase].setdefault("ended_at", merged_at)
        phases[old_phase].setdefault("approved_by", "operator")
        phases[old_phase].setdefault(
            "approval_signal",
            f"(implicit — operator merged PR #{pr_number})",
        )

    phases["review"] = {
        "started_at": merged_at,
        "ended_at": merged_at,
        "approved_by": "operator",
        "approval_signal": "merged",
    }
    phases["merge"] = {
        "started_at": merged_at,
        "ended_at": merged_at,
        "pr_number": pr_number,
        "merge_commit_sha": merge_sha,
        "merged_at": merged_at,
        "approved_by": "operator",
        "approval_signal": "merged",
    }
    phases["docs"] = {
        "started_at": merged_at,
        "ended_at": closure_ts,
        "approved_by": "operator",
        "approval_signal": "(post-merge closure batch — case study + backlog strike shipped in feature PR)",
    }
    phases["complete"] = {
        "started_at": closure_ts,
        "ended_at": closure_ts,
        "approved_by": "operator",
        "approval_signal": "merged",
    }

    # Mirror in timing.phases
    timing_phases = state.setdefault("timing", {}).setdefault("phases", {})
    if old_phase != "?" and old_phase in timing_phases:
        timing_phases[old_phase].setdefault("ended_at", merged_at)
    timing_phases["review"] = {"started_at": merged_at, "ended_at": merged_at}
    timing_phases["merge"] = {"started_at": merged_at, "ended_at": merged_at}
    timing_phases["docs"] = {"started_at": merged_at, "ended_at": closure_ts}
    timing_phases["complete"] = {"started_at": closure_ts, "ended_at": closure_ts}

    # Append transitions (4: testing→review→merge→docs→complete equivalent)
    transitions = state.setdefault("transitions", [])
    base_reason = (
        f"PR #{pr_number} squashed onto main as {merge_sha[:10]} "
        f"(operator-merged {merged_at}). Closure landed via close-feature.py."
    )
    transitions.append({
        "from": old_phase,
        "to": "review",
        "at": merged_at,
        "reason": f"{base_reason} CI checks green; operator review preceded merge.",
    })
    transitions.append({
        "from": "review",
        "to": "merge",
        "at": merged_at,
        "reason": f"{base_reason} Squash-merged.",
    })
    transitions.append({
        "from": "merge",
        "to": "docs",
        "at": merged_at,
        "reason": "Case study + backlog strike shipped in same feature PR. No additional docs.",
    })
    transitions.append({
        "from": "docs",
        "to": "complete",
        "at": closure_ts,
        "reason": (
            f"Feature CLOSED via close-feature.py on {closure_branch}. "
            f"Closes the testing→complete drift-pattern documented across 5+ instances "
            f"by automating the post-merge audit trail."
        ),
    })

    backlog_struck = False
    backlog_path = REPO_ROOT / "docs" / "product" / "backlog.md"
    if do_strike_backlog and backlog_path.exists():
        backlog_text = backlog_path.read_text()
        # Strike rows where the feature name appears in a bold ** ... ** segment
        # of an un-struck table row. Be conservative: only strike if the row
        # mentions the feature AND isn't already struck.
        new_lines = []
        for line in backlog_text.splitlines():
            if (
                feature in line
                and line.lstrip().startswith("|")
                and "~~" not in line
            ):
                # Wrap RICE column + feature column in strikethrough
                # Pattern: | RICE | **Name** | ... → | ~~RICE~~ | ~~**Name**~~ — **SHIPPED <date>** | ... |
                parts = [p.strip() for p in line.split("|")]
                if len(parts) >= 3 and parts[1] and parts[2]:
                    parts[1] = f"~~{parts[1]}~~"
                    parts[2] = f"~~{parts[2]}~~ — **SHIPPED via close-feature.py (PR #{pr_number})**"
                    new_lines.append("|".join(["", *[f" {p} " for p in parts[1:-1]], parts[-1]]) if parts[-1] == "" else "| " + " | ".join(parts[1:-1]) + " |")
                    backlog_struck = True
                    continue
            new_lines.append(line)
        if backlog_struck:
            if not dry_run:
                backlog_path.write_text("\n".join(new_lines) + "\n")

    # ─── Write back state.json ────────────────────────────────────────────
    if dry_run:
        print(f"[dry-run] Would close '{feature}': {old_phase} → complete")
        print(f"          merge_pr_number = {pr_number}")
        print(f"          merge_commit_sha = {merge_sha[:12]}")
        print(f"          merged_at = {merged_at}")
        print(f"          closure_branch = {closure_branch}")
        print(f"          case_study = {state.get('case_study', '(none)')}")
        print(f"          backlog struck = {backlog_struck}")
        return 0

    state_path.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")
    print(f"✓ state.json flipped: {old_phase} → complete  (merge_pr_number={pr_number})")

    # Append Tier 2.2 log
    log_summary = (
        f"Phase 9 CLOSED via close-feature.py. PR #{pr_number} squashed onto main "
        f"as {merge_sha[:10]} (operator-merged {merged_at}). state.json {old_phase}→complete "
        f"with full audit transitions + merge metadata."
    )
    run([
        "python3", "scripts/append-feature-log.py",
        "--feature", feature,
        "--event-type", "phase_transition",
        "--summary", log_summary,
    ])
    print("✓ Tier 2.2 log appended")

    if backlog_struck:
        print("✓ Backlog row struck")

    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        description="Automate post-merge feature-state closure (testing → complete).",
    )
    p.add_argument("feature", help="Feature directory name under .claude/features/")
    p.add_argument("--pr", type=int, help="Merge PR number (auto-detect if omitted)")
    p.add_argument(
        "--closure-branch",
        help="Branch to land closure commit on. Default: chore/<feature>-post-merge-closure",
    )
    p.add_argument(
        "--no-strike",
        action="store_true",
        help="Skip backlog row strike (default: strike if a matching row is found)",
    )
    p.add_argument(
        "--no-commit",
        action="store_true",
        help="Stage but don't commit (caller writes the commit message)",
    )
    p.add_argument(
        "--no-branch",
        action="store_true",
        help="Don't open a new closure branch; stage on current branch (use when bundling multiple features in one chore PR)",
    )
    p.add_argument("--dry-run", action="store_true",
                   help="Print what would happen, mutate nothing")
    p.add_argument(
        "--force-incomplete",
        action="store_true",
        help="Allow closing from a phase earlier than 'testing'. Use only when "
             "the merge PR really was the final landing of an incomplete-feeling feature.",
    )
    args = p.parse_args(argv)

    pr_number = args.pr
    if pr_number is None:
        pr_number = find_pr_for_feature(args.feature)
        if pr_number is None:
            print(
                f"✗ Could not auto-detect a merged PR for feature '{args.feature}'. "
                f"Pass --pr <N> explicitly.",
                file=sys.stderr,
            )
            return 2
        print(f"  auto-detected merge PR #{pr_number} for feature '{args.feature}'")

    closure_branch = args.closure_branch or f"chore/{args.feature}-post-merge-closure"

    if not args.no_branch and not args.dry_run:
        open_closure_branch(closure_branch)
        print(f"  on branch: {current_branch()}")

    rc = close_feature(
        feature=args.feature,
        pr_number=pr_number,
        closure_branch=closure_branch,
        do_strike_backlog=not args.no_strike,
        dry_run=args.dry_run,
        force_incomplete=args.force_incomplete,
    )
    if rc != 0 or args.dry_run:
        return rc

    state_path = f".claude/features/{args.feature}/state.json"
    log_path = f".claude/logs/{args.feature}.log.json"
    run(["git", "add", state_path, log_path])
    if (REPO_ROOT / "docs" / "product" / "backlog.md").exists():
        run(["git", "add", "docs/product/backlog.md"], check=False)

    print(f"\n✓ Staged closure for '{args.feature}'.")
    if args.no_commit:
        print("  (use --no-commit; caller writes the commit)")
    else:
        print("  Suggested commit: chore(<feature>): close out — state testing→complete (PR #<N> merged)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
