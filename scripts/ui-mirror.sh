#!/usr/bin/env bash
# scripts/ui-mirror.sh <label>
# Captures booted-simulator screenshot to .build/mirrors/<label>.png
# for before/after visual verification during UI-audit burndown.
set -euo pipefail

LABEL="${1:-}"
if [ -z "$LABEL" ]; then
  echo "Usage: $0 <label>" >&2
  echo "Example: $0 OnboardingAuthView-before-light" >&2
  exit 1
fi

MIRROR_DIR=".build/mirrors"
mkdir -p "$MIRROR_DIR"

OUT="$MIRROR_DIR/$LABEL.png"
xcrun simctl io booted screenshot "$OUT"
echo "Captured: $OUT"
