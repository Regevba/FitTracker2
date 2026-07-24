#!/usr/bin/env python3
"""
W9 per-session lease registration — feature w9-drift-triggered-auto-isolation,
Phase 2 calibration-organics fix #2.

Wired as a SessionStart hook (see .claude/settings.json). Registers a
lightweight lease for THIS session in agent-leases.json keyed by the real
session id (hook-stdin payload), so a session working on the shared checkout
ADVERTISES its liveness even when it has NOT created an isolated worktree.

Why this exists
---------------
Before this fix, the ONLY writer of agent-leases.json was
`create-isolated-worktree.py` — so a session that never isolated left no lease,
and could therefore never be the "other session" that trips a concurrent
session's `another_session_live()` check. The Phase-2 `w9.concurrency`
`concurrency_offer` telemetry could only fire in the rare window where BOTH
sessions had run the worktree-create script within the 1h heartbeat TTL. That
is why n=1 offer accumulated in ~6 weeks (see calibration.md 2026-07-21).

Registering a per-session lease at SessionStart (and refreshing its heartbeat on
every Bash via check-branch-drift.py, fix #1) makes ordinary shared-checkout
concurrency detectable — the signal the advisory→enforced calibration needs.

Posture: ADVISORY telemetry substrate. It does NOT act, block, or isolate. It
only writes a lease row. Exit 0 always.

Disable: CLAUDE_W9_DISABLE_SESSION_LEASE=1 (also honors the concurrency-check
and drift-check disables so one env var can silence the whole W9 layer).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

REPO_ROOT = Path(os.environ.get("REPO_ROOT_OVERRIDE") or Path(__file__).resolve().parent.parent)


def _disabled() -> bool:
    return (
        os.environ.get("CLAUDE_W9_DISABLE_SESSION_LEASE") == "1"
        or os.environ.get("CLAUDE_W9_DISABLE_CONCURRENCY_CHECK") == "1"
    )


def _active_feature() -> str | None:
    f = REPO_ROOT / ".claude" / "active-feature"
    try:
        name = f.read_text().strip()
        return name or None
    except OSError:
        return None


def main() -> int:
    if _disabled():
        return 0

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    # Resolve the real session id from the hook stdin payload.
    try:
        import w9_session as w9s
        sid = w9s.session_id()
    except Exception:
        sid = os.environ.get("CLAUDE_SESSION_ID", "")
    if not sid or sid == "default":
        # No resolvable per-session identity — a shared "default" lease would be
        # worse than none (it would self-collide across sessions). Skip.
        return 0

    try:
        import w9_auto_isolate as wai
    except Exception:
        return 0  # primitive unavailable — no-op

    try:
        wai.touch_own_lease(
            session_id=sid,
            feature=_active_feature(),
            worktree_path=str(REPO_ROOT),
        )
    except Exception:
        pass  # advisory substrate — never break session start
    return 0


if __name__ == "__main__":
    sys.exit(main())
