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

# w9_session centralizes the real session-id source (hook stdin JSON, not the
# never-set CLAUDE_SESSION_ID env var) + intentional-checkout detection. See
# scripts/w9_session.py for the bug this fixes (feature fix/w9-session-id-keying).
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import w9_session as w9s
except Exception:  # pragma: no cover - degrade to legacy behavior if absent
    w9s = None


REPO_ROOT = Path(__file__).resolve().parent.parent


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


def evaluate_drift(expected: str, current: str, command: str | None) -> str:
    """Classify a branch state into 'ok' | 'intentional' | 'drift'.

    - 'ok'          — branch unchanged.
    - 'intentional' — branch changed AND the command that just ran was itself a
                      branch switch (`git checkout`/`switch`/`worktree add`).
                      This suppresses the false positives that dominated the
                      pre-fix telemetry (every deliberate checkout looked like a
                      concurrent-session collision).
    - 'drift'       — branch changed with no command that explains it → the real
                      W9 pattern (another session flipped HEAD).
    """
    if expected == current:
        return "ok"
    if w9s is not None and w9s.command_indicates_branch_switch(command):
        return "intentional"
    return "drift"


def _session_state_dir() -> Path:
    return REPO_ROOT / ".claude" / "_session-state"


def main(payload: dict | None = None) -> int:
    if os.environ.get("CLAUDE_W9_DISABLE_DRIFT_CHECK") == "1":
        return 0

    # Read the hook payload once: it carries both the real session id and the
    # command that just ran (for intentional-switch suppression).
    if payload is None:
        payload = w9s.hook_payload() if w9s is not None else {}
    sid = w9s.session_id(payload=payload) if w9s is not None else "default"
    command = w9s.command_from_payload(payload) if w9s is not None else None

    branch = current_branch()
    if not branch:
        # Detached HEAD or not in a repo — nothing useful to compare
        return 0

    # Fix #1 (heartbeat): keep THIS session's lease fresh on every Bash call so
    # `another_session_live()` sees it for as long as the session is actually
    # working — instead of the lease decaying 1h after worktree creation
    # (nothing else refreshed it). Best-effort; never affects drift detection.
    if sid and sid != "default":
        try:
            import w9_auto_isolate as _wai
            _wai.touch_own_lease(
                session_id=sid,
                feature=_active_feature(),
                worktree_path=str(REPO_ROOT),
            )
        except Exception:
            pass

    state_dir = _session_state_dir()
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / f"{sid}-branch.txt"

    if not state_file.exists():
        state_file.write_text(branch + "\n")
        return 0

    expected = state_file.read_text().strip()
    verdict = evaluate_drift(expected, branch, command)
    if verdict == "ok":
        return 0
    if verdict == "intentional":
        # This session deliberately switched branches — rebase the baseline
        # silently; no alert, no escalation, no telemetry.
        state_file.write_text(branch + "\n")
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
    state_file.write_text(branch + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
