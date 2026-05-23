#!/usr/bin/env bash
#
# scripts/check-vercel-project-link.sh — SessionStart preflight for
# stale `.vercel/project.json` references.
#
# Closes cadence-followups §C8 + ucc-passkey-auth-case-study §99 quirk #4:
# during the 2026-05-16 UCC cutover, the operator's local `.vercel/project.json`
# in /Volumes/DevSSD/fitme-story was still pointing at the legacy
# `fit-tracker2` project (the now-deprecated Astro dashboard) rather than
# `fitme-story`. The first Upstash install ran against the wrong project
# before the operator noticed. Mid-session re-link via `vercel link --yes
# --project fitme-story` recovered the state.
#
# This script emits a loud stderr warning at SessionStart when the
# project link points at a deprecated or unexpected project name.
#
# Deprecated names (warn loudly):
#   - fit-tracker2  → legacy Astro dashboard, replaced by fitme-story
#
# Expected by working directory:
#   - cwd contains "FitTracker2"     → expect projectName=fittracker2 OR (no link)
#   - cwd contains "fitme-story"     → expect projectName=fitme-story
#
# Disable: CLAUDE_DISABLE_VERCEL_LINK_CHECK=1
# Quiet (no output on PASS): CLAUDE_VERCEL_LINK_CHECK_QUIET=1
#
# Exit: always 0 (informational; never blocks session start).

set -u

[ "${CLAUDE_DISABLE_VERCEL_LINK_CHECK:-}" = "1" ] && exit 0

LINK_FILE=".vercel/project.json"
[ ! -f "$LINK_FILE" ] && exit 0  # no link → nothing to check

# Need jq to parse; fall back to grep if missing.
if command -v jq >/dev/null; then
  PROJECT_NAME=$(jq -r '.projectName // ""' "$LINK_FILE" 2>/dev/null)
else
  PROJECT_NAME=$(grep -oE '"projectName"\s*:\s*"[^"]*"' "$LINK_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
fi

[ -z "$PROJECT_NAME" ] && exit 0  # malformed link → don't false-alarm

PWD_LOWER=$(echo "$PWD" | tr '[:upper:]' '[:lower:]')

# ── working-directory ↔ project-name mismatch (the real bug pattern) ──
# Only warn loudly when cwd CLEARLY suggests a different project than
# what the link references. The `fit-tracker2` Astro dashboard is still
# alive (per CLAUDE.md "Operations control room") — only flag it when
# the operator is clearly working on fitme-story but the link is stale.
case "$PWD_LOWER" in
  *fitme-story*)
    if [ "$PROJECT_NAME" != "fitme-story" ]; then
      cat >&2 <<EOF
⚠  STALE VERCEL LINK DETECTED
    Working directory contains 'fitme-story' but .vercel/project.json
    points at project: '$PROJECT_NAME'

    This is the documented case-study §99 quirk #4 from the 2026-05-16
    UCC cutover: the first \`vercel integration add\` ran against the
    wrong project before being noticed. Any \`vercel env\` / \`vercel
    deploy\` / \`vercel integration\` calls from this cwd will misroute
    to '$PROJECT_NAME' instead of fitme-story.

    Fix:  vercel link --yes --project fitme-story
          (or remove the link entirely: rm -rf .vercel/)

    Reference: docs/case-studies/ucc-passkey-auth-case-study.md §99 quirk #4
    Disable this check: export CLAUDE_DISABLE_VERCEL_LINK_CHECK=1
EOF
    fi
    ;;
  *fittracker2*)
    # FT2 cwd with a fit-tracker2 link is OK (the Astro dashboard at
    # dashboard/ still ships from this repo). Info-print only.
    if [ "${CLAUDE_VERCEL_LINK_CHECK_QUIET:-}" != "1" ]; then
      echo "ℹ  vercel project link in FT2: '$PROJECT_NAME' (Astro dashboard at dashboard/)" >&2
    fi
    ;;
esac

exit 0
