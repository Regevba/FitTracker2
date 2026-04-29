#!/usr/bin/env bash
# HADF Phase 2 collection wrapper.
# Designed to be invoked by launchd (or cron) on a 5x/day schedule across
# 3 calendar days to satisfy the pre-registration in
# .claude/shared/hadf/phase2-preregistration.json.
#
# Loads API keys from .env.local (gitignored), tags each call with the
# current UTC time-of-day window so analysis can group by TOD post-hoc,
# and writes both a per-invocation log and the raw jsonl appended by the
# harness itself.
#
# Manual usage (not via launchd):
#   bash scripts/hadf-phase2-collect.sh                    # 50 calls/endpoint
#   HADF_TAG=verification bash scripts/hadf-phase2-collect.sh

set -euo pipefail

REPO="/Volumes/DevSSD/FitTracker2"
cd "$REPO"

# ---------- env / API keys ----------
# .env.local is gitignored and expected to contain at minimum:
#   OPENAI_API_KEY=sk-...
#   ANTHROPIC_API_KEY=sk-ant-...
# Optional:
#   OLLAMA_HOST=http://localhost:11434
#   OLLAMA_MODEL=llama3.2:3b
if [ -f "$REPO/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO/.env.local"
  set +a
fi

# ---------- TOD window tag ----------
# Pre-registered windows: 02/08/14/18/22 UTC. We bucket the actual UTC
# hour at invocation time into the nearest window so analysis can
# aggregate by TOD even if launchd fires a few minutes off.
UTC_HOUR=$(date -u +%H)
case "$UTC_HOUR" in
  00|01|02|03|04) WINDOW="window-02utc" ;;
  05|06|07|08|09|10) WINDOW="window-08utc" ;;
  11|12|13|14|15) WINDOW="window-14utc" ;;
  16|17|18|19) WINDOW="window-18utc" ;;
  20|21|22|23) WINDOW="window-22utc" ;;
  *) WINDOW="window-unknown" ;;
esac
TAG="${HADF_TAG:-$WINDOW}"

# ---------- python ----------
# Prefer a project-local venv if present; fall back to system python3.
PYTHON="$REPO/.venv-hadf-phase2/bin/python3"
if [ ! -x "$PYTHON" ]; then
  PYTHON="$(command -v python3)"
fi

# ---------- logging ----------
LOG_DIR="$REPO/.claude/shared/hadf/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/collect-$(date -u +%Y%m%d-%H%M%S)-${TAG}.log"

{
  echo "[$(date -u +%FT%TZ)] start tag=$TAG utc_hour=$UTC_HOUR python=$PYTHON"
  "$PYTHON" "$REPO/scripts/hadf-phase2-fingerprint.py" \
    --endpoints "${HADF_ENDPOINTS:-openai,anthropic,local}" \
    --runs "${HADF_RUNS:-1}" \
    --calls-per-run "${HADF_CALLS_PER_RUN:-50}" \
    --tag "$TAG"
  echo "[$(date -u +%FT%TZ)] done tag=$TAG"
} 2>&1 | tee -a "$LOG_FILE"
