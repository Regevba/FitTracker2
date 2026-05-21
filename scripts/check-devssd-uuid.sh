#!/usr/bin/env bash
#
# check-devssd-uuid.sh — replug-detection watcher for /Volumes/DevSSD.
#
# Reads the SSD's current Volume UUID via diskutil, compares against the
# baseline captured by R3 in the daily integrity checkpoint ledger, and
# emits a loud notification if they differ. Silent no-op when they match.
#
# Designed to be invoked by a launchd watcher (StartInterval=300s) installed
# via `make install-devssd-watcher`. Also safe to call manually.
#
# Exit codes:
#   0 — UUID matches baseline (or no baseline yet — R3 hasn't fired)
#   1 — UUID changed; replug or drive-swap detected; warning emitted
#   2 — probe failed (mount missing, ledger unreadable, diskutil missing)
#
# Output:
#   - On match: silent unless --verbose
#   - On change: stderr WARNING + macOS osascript notification + audit-log entry
#                in .claude/logs/devssd-uuid-watcher.log
#
# Linear: FIT-170
# Plan: docs/research/2026-05-19-dev-env-audit-stability-and-scale.md (R4)

set -u

MOUNT="/Volumes/DevSSD"
REPO_ROOT="${DEVSSD_WATCHER_REPO_ROOT:-/Volumes/DevSSD/FitTracker2}"
LEDGER="$REPO_ROOT/.claude/shared/integrity-checkpoint-ledger.jsonl"
AUDIT_LOG="$REPO_ROOT/.claude/logs/devssd-uuid-watcher.log"
VERBOSE="${1:-}"

log_audit() {
  mkdir -p "$(dirname "$AUDIT_LOG")"
  printf '%s\n' "$1" >> "$AUDIT_LOG"
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# 1. Probe current UUID
if [[ "$(uname)" != "Darwin" ]] || ! command -v diskutil >/dev/null 2>&1; then
  [[ "$VERBOSE" == "--verbose" ]] && echo "Non-darwin or no diskutil — skipping"
  exit 0
fi
if [[ ! -d "$MOUNT" ]]; then
  msg="$(now) probe_failed mount_missing=$MOUNT"
  log_audit "$msg"
  echo "WARNING: $msg" >&2
  exit 2
fi

CURRENT_UUID=$(diskutil info "$MOUNT" 2>/dev/null \
  | awk -F': *' '/Volume UUID:/ {print $2}')

if [[ -z "$CURRENT_UUID" ]]; then
  msg="$(now) probe_failed uuid_unreadable mount=$MOUNT"
  log_audit "$msg"
  echo "WARNING: $msg" >&2
  exit 2
fi

# 2. Read baseline from R3's ledger (last JSON row with hardware.volume_uuid)
if [[ ! -f "$LEDGER" ]]; then
  [[ "$VERBOSE" == "--verbose" ]] && echo "No ledger yet — baseline-pending"
  log_audit "$(now) baseline_pending no_ledger uuid=$CURRENT_UUID"
  exit 0
fi

BASELINE_UUID=$(python3 -c "
import json, sys
last = None
try:
    with open('$LEDGER') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                row = json.loads(line)
                if row.get('hardware', {}).get('volume_uuid'):
                    last = row['hardware']['volume_uuid']
            except json.JSONDecodeError:
                continue
    print(last or '')
except Exception:
    pass
" 2>/dev/null)

if [[ -z "$BASELINE_UUID" ]]; then
  [[ "$VERBOSE" == "--verbose" ]] && echo "No baseline UUID in ledger — pending first R3 fire"
  log_audit "$(now) baseline_pending no_uuid_in_ledger current=$CURRENT_UUID"
  exit 0
fi

# 3. Compare
if [[ "$CURRENT_UUID" == "$BASELINE_UUID" ]]; then
  [[ "$VERBOSE" == "--verbose" ]] && echo "✓ UUID matches baseline: $CURRENT_UUID"
  exit 0
fi

# 4. Mismatch — alert
TS="$(now)"
msg="$TS UUID_CHANGED baseline=$BASELINE_UUID current=$CURRENT_UUID"
log_audit "$msg"

cat >&2 <<EOF
⚠ ⚠ ⚠  DEVSSD UUID CHANGED — REPLUG OR DRIVE SWAP DETECTED  ⚠ ⚠ ⚠

  Baseline (last R3 checkpoint): $BASELINE_UUID
  Current ($MOUNT):               $CURRENT_UUID

  This indicates the drive at $MOUNT is not the same one R3 last captured.
  Action: investigate before continuing work. Possible causes:
    - SSD replug (most likely)
    - Drive swap to a backup/clone
    - Different volume mounted at the same path

  Audit log: $AUDIT_LOG
  Re-baseline: run \`make daily-checkpoint-force\` to capture the new UUID.

EOF

# Best-effort macOS notification (silent if osascript missing or no display session)
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"Baseline: ${BASELINE_UUID:0:8}… Current: ${CURRENT_UUID:0:8}…\" with title \"DevSSD UUID Changed\" sound name \"Basso\"" 2>/dev/null || true
fi

exit 1
