#!/bin/bash
# Pre-flight smoke-fire (T2-D): 1 call/endpoint shake-out under same wrapper.
# Aborts on any error response. Catches: API key has no quota, model id rejected,
# endpoint URL changed, streaming protocol changed.
#
# Usage: scripts/hadf-phase2bis-smoke-fire.sh <subexp-id>
# Output: SMOKE_FIRE_OK or SMOKE_FIRE_FAIL with details

set -uo pipefail

SUBEXP="${1:-}"
if [ -z "$SUBEXP" ]; then
    echo "ERROR: subexp-id required (subexp1, subexp2, or subexp3)" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE_DIR="$REPO_ROOT/.claude/shared/hadf/phase2bis-deploy-verification"
mkdir -p "$SMOKE_DIR"
SMOKE_LOG="$SMOKE_DIR/smoke-fire-$SUBEXP-$(date -u +%Y-%m-%dT%H-%M-%SZ).log"

echo "Running smoke-fire for $SUBEXP..." | tee "$SMOKE_LOG"

# Use wrapper in dry-run mode first to validate preflight passes
"$REPO_ROOT/scripts/hadf-phase2bis-collect.sh" --subexp "$SUBEXP" --dry-run 2>&1 | tee -a "$SMOKE_LOG"
if [ "${PIPESTATUS[0]}" != "0" ]; then
    echo "SMOKE_FIRE_FAIL: preflight failed for $SUBEXP" | tee -a "$SMOKE_LOG"
    exit 1
fi

# Then 1-call/endpoint actual fire (needs real API hits — operator-driven)
# For now, scaffold marks success on preflight pass; full smoke implementation
# fills in after first real provider call code lands (post-A5 iteration).
echo "SMOKE_FIRE_OK: preflight passed (full 1-call/endpoint TBD when provider call code implemented)" | tee -a "$SMOKE_LOG"
