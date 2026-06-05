#!/usr/bin/env bash
# HADF signature-expansion experiment — one-command runner.
#
# Calibrates the device + cloud endpoints listed in the manifest
# (.claude/shared/hadf/signature-expansion-endpoints.json) into
# reference-signatures.json as `instrumented` rows, then re-tags the catalogs and
# reports the instrumented count.
#
#   scripts/hadf-signature-expansion-run.sh              # FIRE (cloud = paid API calls)
#   scripts/hadf-signature-expansion-run.sh --dry-run    # print the plan, no calls
#   PY=/path/to/python scripts/hadf-signature-expansion-run.sh   # override interpreter
#
# Needs a python with the cloud SDKs (openai, anthropic, google-genai, boto3,
# mistralai) for the cloud leg, and a running local ollama for the device leg.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MANIFEST=".claude/shared/hadf/signature-expansion-endpoints.json"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# Pick an interpreter that has the cloud SDKs; fall back to python3.
PY="${PY:-}"
if [ -z "$PY" ]; then
  for cand in \
    "/Volumes/DevSSD/FitTracker2-hadf-phase2bis-subexp3/.venv/bin/python3" \
    "/Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl/.venv/bin/python3" \
    "python3"; do
    if command -v "$cand" >/dev/null 2>&1 || [ -x "$cand" ]; then PY="$cand"; break; fi
  done
fi

# Read manifest fields (python — always available).
read_field() { python3 -c "import json,sys;print(json.load(open('$MANIFEST'))$1)"; }
AS_OF="$(read_field "['as_of']")"
N_CLOUD="$(read_field "['n_cloud']")"
N_DEVICE="$(read_field "['n_device']")"
ENV_FILE="$(read_field "['env_file']")"
OUT="$(read_field "['out']")"
DEVICE_JSON="$(python3 -c "import json;print('\n'.join(d['label']+':'+d['model'] for d in json.load(open('$MANIFEST'))['device_endpoints']))")"
CLOUD_ARGS=$(python3 -c "import json;print(' '.join('--endpoint '+e for e in json.load(open('$MANIFEST'))['cloud_endpoints']))")

instrumented() { python3 -c "import json;d=json.load(open('$OUT'));print(sum(1 for e in d['endpoints'] if e.get('calibration_status')=='instrumented'))"; }

echo "=== HADF signature-expansion experiment ==="
echo "interpreter : $PY"
echo "as_of       : $AS_OF   n_cloud=$N_CLOUD n_device=$N_DEVICE"
echo "env_file    : $ENV_FILE"
echo "device      : $DEVICE_JSON"
echo "cloud       : $CLOUD_ARGS"
echo "instrumented BEFORE: $(instrumented)"
if [ "$DRY_RUN" = "1" ]; then
  echo "--- DRY RUN: no calls made. Re-run without --dry-run to fire (cloud = paid). ---"
  exit 0
fi

echo "--- device leg (local ollama; free) ---"
while IFS= read -r de; do
  [ -z "$de" ] && continue
  label="${de%%:*}"; model="${de#*:}"
  "$PY" scripts/hadf-calibrate-device.py --device-label "$label" --model "$model" \
    --n "$N_DEVICE" --out "$OUT" --as-of "$AS_OF" || echo "  device $label failed (ollama running?)"
done <<< "$DEVICE_JSON"

echo "--- cloud leg (paid API calls; pre-probed, bad endpoints dropped) ---"
# shellcheck disable=SC2086
"$PY" scripts/hadf-calibrate-cloud.py $CLOUD_ARGS --n "$N_CLOUD" --env-file "$ENV_FILE" \
  --out "$OUT" --as-of "$AS_OF" || echo "  cloud leg had failures (see above)"

echo "--- re-tag catalogs (idempotent) ---"
python3 scripts/hadf-migrate-calibration-status.py >/dev/null

echo "=== DONE. instrumented AFTER: $(instrumented) ==="
