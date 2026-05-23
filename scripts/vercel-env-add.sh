#!/usr/bin/env bash
#
# scripts/vercel-env-add.sh — REST API wrapper for `vercel env add`.
#
# Closes cadence-followups §C7. The Vercel CLI's `env add` command
# silently writes empty values in headless mode (this CLI version, as
# of 2026-05-16). Both `--value <v> --yes --non-interactive` and
# `< file` stdin-redirect forms fail. The Vercel REST API
# `POST /v10/projects/{projectId}/env` works reliably — this script
# wraps it.
#
# Usage:
#   scripts/vercel-env-add.sh <NAME> <VALUE> [TARGET]
#
#   NAME      — env var key (e.g. UCC_AUTH_MODE)
#   VALUE     — env var value (e.g. both)
#   TARGET    — comma-separated targets: production,preview,development
#               (default: production)
#
# Reads from $PWD/.vercel/project.json (must run inside a linked repo).
# Requires $VERCEL_TOKEN to be exported. Get a token at
# https://vercel.com/account/tokens.
#
# Examples:
#   export VERCEL_TOKEN=vercel_xxx
#   cd /Volumes/DevSSD/fitme-story
#   scripts/vercel-env-add.sh MY_VAR my_value production
#   scripts/vercel-env-add.sh MY_VAR my_value production,preview
#
# Exit codes:
#   0 — success
#   1 — usage error
#   2 — environment error (missing token, project link, or required tools)
#   3 — API error (Vercel API returned non-2xx)

set -euo pipefail

# ── arg parsing ────────────────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "Usage: $0 <NAME> <VALUE> [TARGET]" >&2
  echo "  TARGET defaults to 'production'. Comma-separated for multi." >&2
  exit 1
fi

NAME="$1"
VALUE="$2"
TARGET="${3:-production}"

# ── env + tooling checks ───────────────────────────────────────────────
if [ -z "${VERCEL_TOKEN:-}" ]; then
  echo "error: VERCEL_TOKEN env var not set" >&2
  echo "  → get a token at https://vercel.com/account/tokens" >&2
  exit 2
fi

if ! command -v jq >/dev/null; then
  echo "error: jq is required (brew install jq)" >&2
  exit 2
fi

if [ ! -f .vercel/project.json ]; then
  echo "error: .vercel/project.json not found in \$PWD" >&2
  echo "  → run \`vercel link\` first, or cd into a linked repo" >&2
  exit 2
fi

PROJECT_ID=$(jq -r .projectId .vercel/project.json)
ORG_ID=$(jq -r .orgId .vercel/project.json)

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
  echo "error: could not read projectId from .vercel/project.json" >&2
  exit 2
fi

# ── build the JSON payload ─────────────────────────────────────────────
# Vercel REST API expects `target` as an array of strings.
TARGET_JSON=$(echo "$TARGET" | jq -R 'split(",")')
PAYLOAD=$(jq -n \
  --arg key "$NAME" \
  --arg val "$VALUE" \
  --argjson tgt "$TARGET_JSON" \
  '{
    key: $key,
    value: $val,
    target: $tgt,
    type: "encrypted"
  }')

# ── POST to Vercel REST API ────────────────────────────────────────────
URL="https://api.vercel.com/v10/projects/$PROJECT_ID/env"
if [ -n "${ORG_ID:-}" ] && [ "$ORG_ID" != "null" ]; then
  URL="$URL?teamId=$ORG_ID"
fi

RESP=$(curl -sS -X POST "$URL" \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# ── parse response ────────────────────────────────────────────────────
if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
  echo "error: Vercel API returned an error:" >&2
  echo "$RESP" | jq . >&2
  exit 3
fi

CREATED_ID=$(echo "$RESP" | jq -r '.created[0].id // .id // empty')
if [ -z "$CREATED_ID" ]; then
  echo "warning: created OK but no id in response (Vercel response shape may have changed):" >&2
  echo "$RESP" | jq . >&2
fi

echo "✓ Vercel env var '$NAME' added to targets: $TARGET"
echo "  project: $PROJECT_ID"
[ -n "$CREATED_ID" ] && echo "  env_id:  $CREATED_ID"
