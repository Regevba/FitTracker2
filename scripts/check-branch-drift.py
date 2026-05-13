#!/usr/bin/env python3
"""
Branch-drift detector — W9 pattern from `.claude/integrity/observed-patterns.md`.

Runs as a PostToolUse:Bash hook. Detects when the current git branch has
changed unexpectedly between tool invocations within a single Claude session.

Root cause this catches:
    Another concurrent Claude session sharing the same git working directory
    runs `git checkout`, flipping THIS session's HEAD. The current session's
    next `git commit` lands on the wrong branch.

How it works:
    1. On first invocation, record current branch to a session-state file.
    2. On subsequent invocations, compare current branch to the recorded one.
    3. If they differ:
       - emit a LOUD warning to stderr (which the harness surfaces back to
         the assistant via tool output), so the assistant can flag to the
         user IN REAL TIME
       - update the recorded baseline to the NEW branch, so subsequent
         intentional operations on the new branch don't keep re-firing
    4. Exit 0 always — this is informational, never blocks the tool call.

Output format (stderr):
    ⚠️ BRANCH DRIFT DETECTED ⚠️
    Expected: <prev>
    Current:  <new>
    Recovery: see W9 in .claude/integrity/observed-patterns.md

Resolution recipe (printed at every fire):
    1. STOP — do NOT commit on the new branch unless you intended to be there.
    2. SAVE your work-in-progress:
         git stash push -u -m "wip-recovery-<date>"
       OR commit on the current (wrong) branch and cherry-pick out later.
    3. Switch back to the expected branch:
         git checkout <expected>
    4. If you committed already, cherry-pick from the wrong branch:
         git cherry-pick <wrong-branch-tip-SHA>
       then reset the wrong branch:
         git checkout <wrong-branch> && git reset --hard <pre-collision-SHA>

Prevention recipe:
    Each concurrent session should use its own git worktree:
      git worktree add ../FitTracker2-w9-test feature/my-work
    See .claude/integrity/observed-patterns.md W9 for full prevention rules.

Configuration:
    - Disabled when CLAUDE_W9_DISABLE_DRIFT_CHECK=1 in env
    - Session state stored at .claude/_session-state/<sessionid>-branch.txt
      (gitignored; pruned per session)

Exit codes:
    0 = always (do not block tool calls; this is observational telemetry)
"""

import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SESSION_STATE_DIR = REPO_ROOT / ".claude" / "_session-state"
SESSION_ID = os.environ.get("CLAUDE_SESSION_ID", "default")
STATE_FILE = SESSION_STATE_DIR / f"{SESSION_ID}-branch.txt"


def current_branch() -> str | None:
    """Return current branch name, or None if not in a git repo / detached."""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return None
        branch = result.stdout.strip()
        return branch if branch else None
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return None


def main() -> int:
    if os.environ.get("CLAUDE_W9_DISABLE_DRIFT_CHECK") == "1":
        return 0

    branch = current_branch()
    if not branch:
        # Detached HEAD or not in a repo — nothing useful to compare
        return 0

    SESSION_STATE_DIR.mkdir(parents=True, exist_ok=True)

    if not STATE_FILE.exists():
        STATE_FILE.write_text(branch + "\n")
        return 0

    expected = STATE_FILE.read_text().strip()
    if expected == branch:
        return 0

    # DRIFT DETECTED — emit loud warning to stderr.
    # The harness surfaces stderr to the assistant via tool result output.
    print("", file=sys.stderr)
    print("⚠️  BRANCH DRIFT DETECTED (W9 pattern)  ⚠️", file=sys.stderr)
    print(f"   Expected branch: {expected}", file=sys.stderr)
    print(f"   Current branch:  {branch}", file=sys.stderr)
    print("", file=sys.stderr)
    print("   Cause: another concurrent Claude session likely ran `git checkout`", file=sys.stderr)
    print("   in this same working directory, flipping HEAD.", file=sys.stderr)
    print("", file=sys.stderr)
    print("   Resolution:", file=sys.stderr)
    print("   1. STOP — do not commit unless you intended this branch.", file=sys.stderr)
    print(f"   2. To recover: git checkout {expected}", file=sys.stderr)
    print(f"      If you have uncommitted work: git stash push -u first", file=sys.stderr)
    print(f"      If you have committed on the wrong branch: cherry-pick to {expected}", file=sys.stderr)
    print("", file=sys.stderr)
    print("   Full playbook: .claude/integrity/observed-patterns.md (W9)", file=sys.stderr)
    print("", file=sys.stderr)

    # Update the state to current to avoid spamming on subsequent calls
    STATE_FILE.write_text(branch + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
