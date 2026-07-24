#!/usr/bin/env python3
"""
W9 concurrency-proactive first-edit trigger — feature w9-drift-triggered-auto-
isolation, T8 (Phase 2, ADVISORY).

Wired as a PostToolUse hook on Edit|Write (see .claude/settings.json). On the
FIRST such event in a session, it checks whether another session holds a fresh
lease on this shared checkout (T6) and, if so, surfaces a concurrency advisory +
emits a `w9.concurrency` Mechanism A row (T7). It runs at most once per session
(a session-state marker prevents re-firing on every edit).

NOTE (fix/w9-session-id-keying): if this hook is ever promoted to ACT (auto-
isolate) rather than advise, it must move to PreToolUse so isolation happens
BEFORE the edit lands on the wrong branch. While advisory (telemetry-only),
PostToolUse is correct.

The session id is resolved via w9_session (the hook-stdin `session_id` payload),
NOT the never-set CLAUDE_SESSION_ID env var — the prior code keyed every session
on the constant "default", so the once-per-session marker permanently suppressed
this check across all sessions (the Phase-2 calibration gathered ZERO data).

Posture: ADVISORY. It NEVER blocks the edit and NEVER acts unless BOTH
CLAUDE_W9_AUTO_ISOLATE=1 and CLAUDE_W9_CONCURRENCY_ENFORCE=1 are set. Exit 0
always. This is the proactive companion to the drift-reactive Phase 1 hook;
acting unprompted is gated on the T+14d advisory->enforced calibration.

Disable: CLAUDE_W9_DISABLE_CONCURRENCY_CHECK=1.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(os.environ.get("REPO_ROOT_OVERRIDE") or Path(__file__).resolve().parent.parent)

# Resolve the real session id (hook-stdin payload), not the never-set env var.
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import w9_session as w9s
    SESSION_ID = w9s.session_id()
except Exception:  # pragma: no cover - degrade gracefully if helper absent
    w9s = None
    SESSION_ID = os.environ.get("CLAUDE_SESSION_ID", "default")
MARKER = REPO_ROOT / ".claude" / "_session-state" / f"{SESSION_ID}-w9-concurrency.done"

# Fix #3: re-arm the once-per-session marker as a COOLDOWN instead of a
# permanent latch. The check samples one instant per session; concurrency that
# arises LATER in a long session was never observed. A cooldown re-samples every
# COOLDOWN_SECONDS, multiplying observation opportunities while bounding noise.
COOLDOWN_SECONDS = 2700  # 45 min default


def _cooldown_seconds() -> int:
    override = os.environ.get("CLAUDE_W9_CONCURRENCY_COOLDOWN_SECONDS")
    if override:
        try:
            return max(0, int(override))
        except ValueError:
            pass
    return COOLDOWN_SECONDS


def _now_epoch() -> float:
    override = os.environ.get("W9_FAKE_NOW_EPOCH")
    if override:
        try:
            return float(override)
        except ValueError:
            pass
    import datetime as _dt
    return _dt.datetime.now(_dt.timezone.utc).timestamp()


def _already_fired() -> bool:
    """True iff the marker exists AND its timestamp is within the cooldown.

    A stale marker (older than the cooldown) is treated as absent, so the check
    re-fires. The pre-cooldown latch wrote "1\\n"; that parses as epoch 1.0
    (ancient) → stale → re-fires exactly once on upgrade, then `_mark_fired`
    rewrites it with a real timestamp. Genuinely non-numeric content is honored
    as "fired" (fail-safe: don't spuriously re-sample on a corrupt marker).
    """
    try:
        raw = MARKER.read_text().strip()
    except OSError:
        return False
    try:
        fired_at = float(raw)
    except ValueError:
        # Non-numeric/corrupt content — honor as "fired" for this window.
        return True
    return (_now_epoch() - fired_at) < _cooldown_seconds()


def _mark_fired() -> None:
    try:
        MARKER.parent.mkdir(parents=True, exist_ok=True)
        MARKER.write_text(f"{_now_epoch()}\n")
    except OSError:
        pass


def main() -> int:
    if os.environ.get("CLAUDE_W9_DISABLE_CONCURRENCY_CHECK") == "1":
        return 0
    if _already_fired():
        return 0  # once-per-session

    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import w9_auto_isolate as wai
    except Exception:
        return 0  # primitive unavailable — no-op

    try:
        # Pass the real session id so the decision self-excludes THIS session's
        # own lease (fix #2 now registers one) while still detecting siblings.
        res = wai.concurrency_isolation_decision(session_id=SESSION_ID)
    except Exception:
        return 0  # fail-safe: never break an edit

    _mark_fired()

    # Only surface a notice when concurrency was actually detected.
    if res.reason in ("advisory_concurrency",) or res.result == "isolated":
        feature = wai.active_feature() or "<active-feature>"
        print("", file=sys.stderr)
        print("   ⚠️  W9 concurrency advisory: another session holds a fresh lease on this", file=sys.stderr)
        print("      shared checkout. Your non-infra work is exposed to branch drift.", file=sys.stderr)
        if res.result == "isolated":
            print(f"      ✅ Auto-isolated into: {res.worktree}", file=sys.stderr)
        else:
            print(f"      Isolate proactively: python3 scripts/create-isolated-worktree.py --feature {feature} --create-if-missing", file=sys.stderr)
            print("      (or set CLAUDE_W9_AUTO_ISOLATE=1 CLAUDE_W9_CONCURRENCY_ENFORCE=1 to auto-isolate)", file=sys.stderr)
        print("", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
