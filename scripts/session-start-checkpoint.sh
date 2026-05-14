#!/usr/bin/env bash
# Session-start wrapper for daily-integrity-checkpoint.py.
#
# Fired by the SessionStart hook in .claude/settings.json. Two responsibilities:
#   1. If today's checkpoint hasn't run yet, kick off the snapshot in the background.
#      The script handles its own idempotency (--idempotent flag) so re-firing is safe.
#   2. Print a one-line status from the latest ledger row so the operator sees the
#      current integrity posture every session.
#
# Cross-repo guard: silently no-ops when invoked outside the FitTracker2 repo
# (e.g. from a fitme-story session or a worktree without the script). Matches the
# pattern used by observe-cache-hit.py and check-branch-drift.py.
#
# Disable with: CLAUDE_DISABLE_DAILY_CHECKPOINT=1

set -u

if [ "${CLAUDE_DISABLE_DAILY_CHECKPOINT:-}" = "1" ]; then
    exit 0
fi

# Cross-repo / worktree guard
if [ ! -f scripts/daily-integrity-checkpoint.py ]; then
    exit 0
fi

# Fire snapshot in background. The --idempotent flag means re-fires are no-ops.
# nohup + & + redirect detaches cleanly so session start is not blocked.
nohup python3 scripts/daily-integrity-checkpoint.py --idempotent --quiet \
    >/dev/null 2>&1 </dev/null &
disown 2>/dev/null || true

# Print latest ledger status (always — even if today's checkpoint already ran)
LEDGER=.claude/shared/integrity-checkpoint-ledger.jsonl
if [ -f "$LEDGER" ]; then
    tail -1 "$LEDGER" 2>/dev/null | python3 -c '
import json, sys
try:
    line = sys.stdin.read().strip()
    if not line:
        sys.exit(0)
    d = json.loads(line)
    m = d.get("metrics", {})
    regr = "REGRESSION" if d.get("regression") else "stable"
    ssd = "ssd=OK" if d.get("snapshot_ssd_ok") else "ssd=N/A"
    print(f"## Daily Integrity Checkpoint")
    print(f"last={d.get(\"date\",\"?\")} | findings={m.get(\"integrity_findings\",\"?\")} | advisory={m.get(\"integrity_advisory\",\"?\")} | debt={m.get(\"doc_debt_open\",\"?\")} | adopt={m.get(\"adoption_pct_post_v6\",\"?\")}% | {regr} | {ssd}")
except Exception:
    pass
' 2>/dev/null
fi

# Surface any active regression flag loudly
if [ -f .claude/shared/integrity-checkpoint-regression.flag ]; then
    echo ""
    echo "⚠ INTEGRITY REGRESSION FLAG ACTIVE"
    cat .claude/shared/integrity-checkpoint-regression.flag
    echo "(see .claude/shared/integrity-checkpoint-ledger.md for the diff; clear by running \`make daily-checkpoint\`)"
fi

exit 0
