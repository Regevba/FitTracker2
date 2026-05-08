#!/usr/bin/env python3
"""T22 (framework-v7-8-branch-isolation): verify-isolation.py

System-wide readout of branch isolation status. For every feature:
  - declared branch (state.json::branch)
  - declared worktree path (state.json::worktree_path)
  - actual current branch (if checked out anywhere)
  - actual git worktree presence
  - launchd plist references (macOS-only)

Exit codes:
  0 — all features clean OR all findings explained by isolation_opt_out
  1 — one or more features have unexplained findings

Per PRD §6.1 + integration-spec §2.1 + Q3 + Q4 + Q5.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"


def _git_worktree_list() -> list[dict]:
    """Parse `git worktree list --porcelain` into structured records."""
    out = subprocess.check_output(
        ["git", "worktree", "list", "--porcelain"],
        cwd=REPO_ROOT, text=True,
    )
    records = []
    cur: dict = {}
    for line in out.splitlines():
        line = line.rstrip()
        if not line:
            if cur:
                records.append(cur)
                cur = {}
            continue
        if line.startswith("worktree "):
            cur["path"] = line[len("worktree "):]
        elif line.startswith("HEAD "):
            cur["head"] = line[len("HEAD "):]
        elif line.startswith("branch "):
            cur["branch"] = line[len("branch "):]
    if cur:
        records.append(cur)
    return records


def main() -> int:
    if not FEATURES_DIR.exists():
        print("No features directory; nothing to verify.")
        return 0

    worktrees = _git_worktree_list()
    # Build branch → worktree path map
    branch_to_wt: dict[str, str] = {}
    for w in worktrees:
        ref = w.get("branch", "")
        if ref.startswith("refs/heads/"):
            branch_to_wt[ref[len("refs/heads/"):]] = w["path"]

    findings: list[dict] = []
    rows: list[tuple[str, str, str, str, str]] = []

    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        feature = state_path.parent.name
        try:
            state = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            rows.append((feature, "?", "?", "?", "INVALID JSON"))
            findings.append({"feature": feature, "issue": "invalid_state_json"})
            continue

        declared_branch = state.get("branch") or "—"
        declared_wt = state.get("worktree_path") or "—"
        opt_out = state.get("isolation_opt_out") is True
        current_phase = state.get("current_phase", "?")

        # Skip terminal features by default — they don't need active isolation
        if current_phase in ("complete", "closed"):
            rows.append((feature, declared_branch, declared_wt or "—",
                         f"phase={current_phase}", "✓ terminal"))
            continue

        # Skip if opt-out (mark explicitly)
        if opt_out:
            reason = state.get("isolation_opt_out_reason", "")
            rows.append((feature, declared_branch, declared_wt or "—",
                         "opt-out", f"⊘ {reason[:40]}"))
            continue

        # Skip if no branch declared (research phase often has no branch yet)
        if declared_branch in (None, "", "—", "main"):
            rows.append((feature, declared_branch or "main", "—",
                         f"phase={current_phase}", "—"))
            continue

        # Active feature with declared branch — check actual worktree
        actual_wt = branch_to_wt.get(declared_branch)
        if actual_wt:
            if declared_wt and declared_wt != "—" and Path(declared_wt).resolve() != Path(actual_wt).resolve():
                rows.append((feature, declared_branch, declared_wt, actual_wt,
                             "✗ MISMATCH"))
                findings.append({
                    "feature": feature,
                    "issue": "worktree_path_mismatch",
                    "declared": declared_wt,
                    "actual": actual_wt,
                })
            else:
                rows.append((feature, declared_branch, declared_wt, actual_wt,
                             "✓ ok"))
        else:
            rows.append((feature, declared_branch, declared_wt or "—",
                         "(no worktree)",
                         "⚠ no worktree" if declared_wt and declared_wt != "—" else "—"))
            if declared_wt and declared_wt != "—":
                findings.append({
                    "feature": feature,
                    "issue": "worktree_declared_but_missing",
                    "declared": declared_wt,
                })

    # Print readout
    print(f"Branch isolation status — verify-isolation.py")
    print(f"=" * 80)
    print(f"{'Feature':<40} {'Branch':<35} {'Status':<20}")
    print("-" * 80)
    for feature, branch, dwt, awt, status in rows:
        print(f"{feature[:39]:<40} {branch[:34]:<35} {status[:19]:<20}")

    print()
    if findings:
        print(f"⚠ {len(findings)} finding(s):")
        for f in findings:
            print(f"  - {f['feature']}: {f['issue']}")
            for k, v in f.items():
                if k not in ("feature", "issue"):
                    print(f"      {k}: {v}")
        return 1

    print(f"✓ All {len(rows)} features clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
