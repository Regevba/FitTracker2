#!/usr/bin/env bash
#
# check-ssd-health.sh — pre-flight SSD health probe for /Volumes/DevSSD.
#
# Exits:
#   0 — healthy or no critical signals
#   1 — warning (free space < 10% OR SMART degraded but readable)
#   2 — critical (mount missing OR SMART FAIL)
#
# Output: human-readable status lines to stdout; one final summary line.
#
# Probes (in order, best-effort):
#   1. Mount presence    (diskutil info /Volumes/DevSSD)
#   2. Free space        (df -h)
#   3. SMART status      (smartctl if installed, falls back to diskutil)
#   4. Recent I/O errors (last 24h log show, macOS only)
#
# Linear: FIT-171
# Plan:   docs/research/2026-05-19-dev-env-audit-stability-and-scale.md (R5)

set -u

MOUNT="${1:-/Volumes/DevSSD}"
WARN_FREE_PCT="${SSD_HEALTH_WARN_FREE_PCT:-10}"

EXIT_CODE=0
WARN=0
CRIT=0

print_line() {
  printf '  %s\n' "$1"
}

# 1. Mount presence
if [[ ! -d "$MOUNT" ]]; then
  print_line "✗ MOUNT MISSING: $MOUNT not mounted"
  echo "SSD health: CRITICAL (mount missing)"
  exit 2
fi
print_line "✓ Mount: $MOUNT"

# 2. Free space
if df -h "$MOUNT" >/dev/null 2>&1; then
  FREE_LINE=$(df -h "$MOUNT" | tail -1)
  CAP=$(printf '%s' "$FREE_LINE" | awk '{print $2}')
  USED=$(printf '%s' "$FREE_LINE" | awk '{print $3}')
  AVAIL=$(printf '%s' "$FREE_LINE" | awk '{print $4}')
  CAPACITY=$(printf '%s' "$FREE_LINE" | awk '{print $5}' | tr -d '%')
  FREE_PCT=$((100 - CAPACITY))
  print_line "✓ Disk: $USED of $CAP used ($AVAIL free, ${FREE_PCT}% free)"
  if (( FREE_PCT < WARN_FREE_PCT )); then
    print_line "⚠ Free space ${FREE_PCT}% < ${WARN_FREE_PCT}% threshold"
    WARN=1
  fi
else
  print_line "⚠ df failed on $MOUNT"
  WARN=1
fi

# 3. SMART (best-effort)
SMART_LINE=""
if command -v smartctl >/dev/null 2>&1; then
  # Pick the parent disk from diskutil
  DEV_ID=$(diskutil info "$MOUNT" 2>/dev/null | awk -F': *' '/Device Identifier:/ {print $2}')
  PARENT_DISK=$(printf '%s' "$DEV_ID" | sed -E 's/(disk[0-9]+).*/\1/')
  if [[ -n "$PARENT_DISK" ]]; then
    # Try generic, then SAT (most USB-SATA bridges respond to -d sat)
    SMART_OUT=$(smartctl -d sat,auto -H "/dev/$PARENT_DISK" 2>&1 || true)
    if printf '%s' "$SMART_OUT" | grep -qiE "SMART (overall|Health Status):.*(PASSED|OK)"; then
      SMART_LINE="✓ SMART: PASSED (via smartctl)"
    elif printf '%s' "$SMART_OUT" | grep -qiE "SMART (overall|Health Status):.*(FAILED|FAIL)"; then
      SMART_LINE="✗ SMART: FAILED (via smartctl)"
      CRIT=1
    else
      SMART_LINE="• SMART: not readable via smartctl (USB bridge limitation)"
    fi
  fi
fi
if [[ -z "$SMART_LINE" ]]; then
  # Fall back to diskutil's view
  SMART_STATUS=$(diskutil info "$MOUNT" 2>/dev/null | awk -F': *' '/SMART Status:/ {print $2}')
  if [[ "$SMART_STATUS" == "Verified" ]]; then
    SMART_LINE="✓ SMART: Verified (via diskutil)"
  elif [[ "$SMART_STATUS" == "Failing" ]]; then
    SMART_LINE="✗ SMART: Failing (via diskutil)"
    CRIT=1
  elif [[ -n "$SMART_STATUS" ]]; then
    SMART_LINE="• SMART: $SMART_STATUS (via diskutil)"
  else
    SMART_LINE="• SMART: unavailable"
  fi
fi
print_line "$SMART_LINE"

# 4. Recent I/O errors (macOS only, last 1h). Opt-in via SSD_HEALTH_CHECK_IO=1
# since `log show` can take 10-30s. Default skip keeps preflight under 2s.
if [[ "${SSD_HEALTH_CHECK_IO:-0}" == "1" && "$(uname)" == "Darwin" ]] \
   && command -v log >/dev/null 2>&1; then
  IO_ERR_COUNT=$(
    log show --predicate 'process == "kernel"' --last 1h 2>/dev/null \
      | grep -ciE "I/O error|disk error|read error|write error" \
      || true
  )
  IO_ERR_COUNT="${IO_ERR_COUNT:-0}"
  if [[ "$IO_ERR_COUNT" -gt 0 ]]; then
    print_line "⚠ Recent I/O errors (last 1h): $IO_ERR_COUNT"
    WARN=1
  else
    print_line "✓ No recent I/O errors (last 1h)"
  fi
fi

# Final summary
if (( CRIT > 0 )); then
  echo "SSD health: CRITICAL"
  EXIT_CODE=2
elif (( WARN > 0 )); then
  echo "SSD health: WARNING"
  EXIT_CODE=1
else
  echo "SSD health: OK"
  EXIT_CODE=0
fi

exit "$EXIT_CODE"
