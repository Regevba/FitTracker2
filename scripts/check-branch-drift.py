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


def _working_tree_dirty() -> bool:
    """True if there is uncommitted (tracked or untracked) work to protect."""
    try:
        r = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(REPO_ROOT), capture_output=True, text=True, timeout=5,
        )
        return bool(r.stdout.strip())
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return False


def _active_feature() -> str | None:
    f = REPO_ROOT / ".claude" / "active-feature"
    try:
        name = f.read_text().strip()
        return name or None
    except OSError:
        return None


def _isolation_opt_out(feature: str | None) -> bool:
    """Read state.json::isolation_opt_out for the active feature (honored, warn-only)."""
    if not feature:
        return False
    state = REPO_ROOT / ".claude" / "features" / feature / "state.json"
    try:
        import json
        return bool(json.loads(state.read_text()).get("isolation_opt_out"))
    except (OSError, ValueError):
        return False


def _escalate_on_drift(expected: str, branch: str) -> None:
    """W9 drift-triggered auto-isolation escalation (feature T2).

    Fail-safe: any error here degrades to W9's prior warn-only behavior. Never
    raises; the caller already printed the drift warning + recovery playbook.
    """
    if not _working_tree_dirty():
        return  # nothing uncommitted to protect — warning alone suffices

    feature = _active_feature()
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import w9_auto_isolate as wai
    except Exception:
        return  # primitive unavailable — warn-only

    drift = {"from_branch": expected, "to_branch": branch}

    if _isolation_opt_out(feature):
        wai.emit_telemetry(candidates=1, checked=0, skipped=1,
                           skip_reasons=["opt_out"], outcome="opt_out", drift=drift)
        return

    if os.environ.get("CLAUDE_W9_AUTO_ISOLATE") == "1":
        # Advisory->enforced: act only on explicit opt-in until the T+7d promotion.
        try:
            res = wai.isolate_current_work(reason="w9_drift")
        except Exception:
            wai.emit_telemetry(candidates=1, checked=1, skipped=0,
                               skip_reasons=[], outcome="error", drift=drift)
            return
        wai.emit_telemetry(candidates=1, checked=1, skipped=0,
                           skip_reasons=[], outcome=res.result, drift=drift)
        print("", file=sys.stderr)
        if res.result == "isolated":
            print(f"   ✅ W9 auto-isolated your uncommitted work into: {res.worktree}", file=sys.stderr)
            print(f"      cd {res.worktree}  — your changes are there, on the correct branch.", file=sys.stderr)
        else:
            print(f"   ⚠️  W9 auto-isolation did not complete: {res.result} ({res.reason}).", file=sys.stderr)
            if res.stash_ref:
                print(f"      Your work is preserved in {res.stash_ref} — recover with: git stash apply {res.stash_ref}", file=sys.stderr)
        print("", file=sys.stderr)
        return

    # Default advisory: OFFER (don't act). Print the exact pre-filled command.
    wai.emit_telemetry(candidates=1, checked=0, skipped=1,
                       skip_reasons=["offer_not_acted"], outcome="offer", drift=drift)
    feat = feature or "<active-feature>"
    print("", file=sys.stderr)
    print("   💡 W9 can auto-isolate this work into its own worktree so the drift", file=sys.stderr)
    print("      can't reach it. Run either:", file=sys.stderr)
    print(f"        CLAUDE_W9_AUTO_ISOLATE=1  (then re-run any command — auto-isolates)", file=sys.stderr)
    print(f"        python3 scripts/create-isolated-worktree.py --feature {feat} --create-if-missing", file=sys.stderr)
    print("", file=sys.stderr)


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

    # W9 drift-triggered auto-isolation (feature w9-drift-triggered-auto-isolation, T2).
    # Fail-safe: never raises; degrades to warn-only on any error.
    try:
        _escalate_on_drift(expected, branch)
    except Exception:
        pass

    # Update the state to current to avoid spamming on subsequent calls
    STATE_FILE.write_text(branch + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
