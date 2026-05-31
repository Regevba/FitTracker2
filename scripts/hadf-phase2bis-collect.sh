#!/bin/bash
# HADF Phase 2-bis collection wrapper
# Fixes: #1 worktree-local venv (real dir, not symlink) - relies on operator setup
#        #2 .env.local copied (not symlink) - validated by preflight check
#        #3 wrapper preflight self-check - this script
#        #4 raw-data preservation - .claude/shared/hadf/phase2bis-raw-<subexp>-<run>.jsonl

set -uo pipefail  # NOT set -e: we handle errors explicitly per check

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUBEXP=""
DRY_RUN=false
RUN_ID=""
HEARTBEAT_LEDGER="$REPO_ROOT/.claude/shared/hadf/phase2bis-fire-heartbeat.jsonl"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --subexp) SUBEXP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$SUBEXP" ]; then
    echo "ERROR: --subexp required" >&2
    exit 2
fi

[ -z "$RUN_ID" ] && RUN_ID="$SUBEXP-$(date -u +%Y-%m-%dT%H-%M-%SZ)"

PREFLIGHT_LOG="$REPO_ROOT/.claude/shared/hadf/phase2bis-deploy-verification/preflight-$RUN_ID.log"
mkdir -p "$(dirname "$PREFLIGHT_LOG")"

log_preflight() { echo "$(date -u +%FT%TZ) [$RUN_ID] $*" | tee -a "$PREFLIGHT_LOG" >&2; }

# Heartbeat: fire_started
emit_heartbeat() {
    local event="$1"
    local extra="${2:-}"
    local ts=$(date -u +%FT%TZ)
    mkdir -p "$(dirname "$HEARTBEAT_LEDGER")"
    echo "{\"timestamp\":\"$ts\",\"subexp\":\"$SUBEXP\",\"run_id\":\"$RUN_ID\",\"event\":\"$event\"$extra}" \
        >> "$HEARTBEAT_LEDGER"
}

# ── Fix #3 PREFLIGHT CHECKS (any failure = exit 78 EX_CONFIG) ──

# Check A: venv binary executable
VENV_PYTHON="$REPO_ROOT/.venv/bin/python3"
if [ ! -x "$VENV_PYTHON" ]; then
    log_preflight "PREFLIGHT FAIL [A]: venv python missing or not executable: $VENV_PYTHON"
    emit_heartbeat "preflight_failed" ",\"check\":\"venv_binary\""
    exit 78
fi

# Check B: required Python imports succeed
REQUIRED_IMPORTS="json sys time"
for mod in $REQUIRED_IMPORTS; do
    if ! "$VENV_PYTHON" -c "import $mod" 2>/dev/null; then
        log_preflight "PREFLIGHT FAIL [B]: required import failed: $mod"
        emit_heartbeat "preflight_failed" ",\"check\":\"import_$mod\""
        exit 78
    fi
done

# Check C: .env.local exists as REGULAR FILE (not symlink, not missing) — Fix #2
ENV_FILE="$REPO_ROOT/.env.local"
if [ ! -e "$ENV_FILE" ]; then
    log_preflight "PREFLIGHT FAIL [C]: .env.local does not exist: $ENV_FILE"
    emit_heartbeat "preflight_failed" ",\"check\":\"env_local_missing\""
    exit 78
fi
if [ -L "$ENV_FILE" ]; then
    log_preflight "PREFLIGHT FAIL [C]: .env.local is a symlink (must be regular file per Fix #2): $ENV_FILE"
    emit_heartbeat "preflight_failed" ",\"check\":\"env_local_symlink\""
    exit 78
fi

# Check D: required API keys non-empty after sourcing
set -a
source "$ENV_FILE"
set +a

case "$SUBEXP" in
    # subexp1 = original 9-endpoint matrix (narrowed at 2026-05-25 launch to openai+anthropic).
    #   Typo fix 2026-05-30: VERCEL_AI_GATEWAY_KEY → VERCEL_AI_GATEWAY_API_KEY (matches
    #   the .env.local naming convention; pre-fix subexp1 would always fail preflight here
    #   even with a valid key).
    # subexp1b = v2 (2026-05-31): scope reduction after Sub-exp 1B v1 Fire 0
    #   (2026-05-30T07:47Z) returned 9/50 OK on mistral (free-tier RPS HTTP 429)
    #   and 5/50 OK on vercel-ai-gateway/gpt-4o-mini ('Free tier ... Upgrade to
    #   paid credits'). Anthropic + Google clean (50/50 each). Operator decision
    #   2026-05-31: drop both rate-limited endpoints; ship 2-endpoint design for
    #   2026-06-10 launch.
    subexp1)  REQUIRED_KEYS="OPENAI_API_KEY ANTHROPIC_API_KEY GOOGLE_API_KEY VERCEL_AI_GATEWAY_API_KEY MISTRAL_API_KEY XAI_API_KEY" ;;
    subexp1b) REQUIRED_KEYS="ANTHROPIC_API_KEY GOOGLE_API_KEY" ;;  # v2: mistral + vercel-ai-gateway dropped
    subexp2)  REQUIRED_KEYS="" ;;  # Ollama is local, no API key
    subexp3)  REQUIRED_KEYS="OPENAI_API_KEY ANTHROPIC_API_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY" ;;
    test)     REQUIRED_KEYS="OPENAI_API_KEY" ;;  # for preflight test fixture
    *)        REQUIRED_KEYS="" ;;
esac

for key in $REQUIRED_KEYS; do
    val="${!key:-}"
    if [ -z "$val" ]; then
        log_preflight "PREFLIGHT FAIL [D]: required API key empty after sourcing: $key"
        emit_heartbeat "preflight_failed" ",\"check\":\"key_$key\""
        exit 78
    fi
done

log_preflight "PREFLIGHT OK"

# Dry-run mode exits here after preflight succeeds (smoke-fire uses this)
if [ "$DRY_RUN" = true ]; then
    log_preflight "DRY_RUN mode: preflight passed; exiting before collection"
    emit_heartbeat "dry_run_complete"
    exit 0
fi

# ── Fire start ──
emit_heartbeat "fire_started"

# Delegate to Python driver (Fix #4 raw-data preservation handled there)
RAW_PATH="$REPO_ROOT/.claude/shared/hadf/phase2bis-raw-${SUBEXP}-${RUN_ID}.jsonl"
"$VENV_PYTHON" "$REPO_ROOT/scripts/hadf-phase2bis-collect.py" \
    --subexp "$SUBEXP" --run-id "$RUN_ID" --raw-out "$RAW_PATH"
COLLECT_RC=$?

# ── Fire end ──
RECORDS=0
if [ -f "$RAW_PATH" ]; then
    RECORDS=$(wc -l < "$RAW_PATH")
fi
emit_heartbeat "fire_ended" ",\"records_landed\":$RECORDS,\"collect_rc\":$COLLECT_RC"

# Cost log entry (T2-C)
COST_LOG="$REPO_ROOT/.claude/shared/hadf/phase2bis-cost-log.jsonl"
COST=$("$VENV_PYTHON" "$REPO_ROOT/scripts/hadf-cost-estimate.py" \
    --provider openai --endpoint gpt-4o-mini --calls "$RECORDS" --avg-output-tokens 200 2>/dev/null || echo "0")
echo "{\"timestamp\":\"$(date -u +%FT%TZ)\",\"subexp\":\"$SUBEXP\",\"run_id\":\"$RUN_ID\",\"records\":$RECORDS,\"estimated_cost_usd\":$COST}" \
    >> "$COST_LOG"

exit $COLLECT_RC
