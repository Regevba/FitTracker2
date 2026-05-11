#!/usr/bin/env bash
# scripts/snapshot-phase-completion.sh
#
# Per-phase snapshot to off-SSD backup. Spec §10.
#
# Usage: ./scripts/snapshot-phase-completion.sh <phase-or-pause-id> <feature-name>
# Example: ./scripts/snapshot-phase-completion.sh phase-0-complete cross-repo-state-sync-impl

set -euo pipefail

PHASE_ID="${1:?phase-or-pause-id required (e.g., phase-0-complete, pause-end-of-session)}"
FEATURE_NAME="${2:?feature-name required}"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="$HOME/Documents/FitTracker2-backups/${DATE}-${FEATURE_NAME}-${PHASE_ID}"

mkdir -p "$BACKUP_DIR"

# Copy feature artifacts (preserve mtimes)
if [ -d ".claude/features/${FEATURE_NAME}" ]; then
    cp -p ".claude/features/${FEATURE_NAME}"/* "$BACKUP_DIR/" 2>/dev/null || true
fi
if [ -f ".claude/logs/${FEATURE_NAME}.log.json" ]; then
    cp -p ".claude/logs/${FEATURE_NAME}.log.json" "$BACKUP_DIR/"
fi

# Allow caller to extend via EXTRA_FILES env var (space-separated)
for f in ${EXTRA_FILES:-}; do
    if [ -e "$f" ]; then
        cp -p "$f" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

# Capture git context
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "(no git)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "(no git)")

# Generate sha256 manifest (only of files actually copied)
cd "$BACKUP_DIR"
if compgen -G "*" > /dev/null; then
    shasum -a 256 * 2>/dev/null | grep -v "CHECKSUMS.sha256" > CHECKSUMS.sha256 || true
fi

# Write MANIFEST.md
cat > MANIFEST.md <<EOF
# Snapshot — ${FEATURE_NAME} ${PHASE_ID}

**Created:** $(date -u +%FT%TZ)
**Branch:** ${BRANCH}
**Commit SHA:** ${COMMIT_SHA}
**Feature:** ${FEATURE_NAME}
**Phase/Pause ID:** ${PHASE_ID}

## Files preserved

$(ls -1 | grep -v MANIFEST.md | grep -v CHECKSUMS.sha256 | sed 's/^/- /')

## Verification

\`\`\`bash
cd ${BACKUP_DIR}
shasum -a 256 -c CHECKSUMS.sha256
\`\`\`

## Source spec / plan

- Spec: docs/superpowers/specs/2026-05-11-cross-repo-state-sync-impl-design.md
- Plan: docs/superpowers/plans/2026-05-11-cross-repo-state-sync-impl.md

## Drive risk context

This backup lives on internal Mac storage, NOT the SanDisk Extreme
\`/Volumes/DevSSD/\`, per the established convention from
\`reference_devssd_hardware_issue.md\`.
EOF

echo "Snapshot created: $BACKUP_DIR"
echo "Files: $(ls | wc -l | tr -d ' ')"
