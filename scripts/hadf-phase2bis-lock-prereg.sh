#!/bin/bash
# Hash-lock a pre-registration JSON. Once locked:
# - .lock sibling file written with sha256 + timestamp + git commit
# - git tag created and pushed
# - pre-commit hook rejects further edits (unless lock is also removed)
#
# Usage: scripts/hadf-phase2bis-lock-prereg.sh <subexp-id>

set -euo pipefail

SUBEXP="${1:-}"
if [ -z "$SUBEXP" ]; then
    echo "ERROR: subexp-id required" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREREG="$REPO_ROOT/.claude/shared/hadf/preregistration-phase2bis-${SUBEXP}.json"
LOCK="${PREREG}.lock"

if [ ! -f "$PREREG" ]; then
    echo "ERROR: prereg not found: $PREREG" >&2
    exit 2
fi
if [ -f "$LOCK" ]; then
    echo "ERROR: already locked: $LOCK" >&2
    exit 2
fi

# Validate JSON parses
python3 -c "import json; json.load(open('$PREREG'))"

# Compute sha256
SHA=$(shasum -a 256 "$PREREG" | awk '{print $1}')
TS=$(date -u +%FT%TZ)
USER=$(git config user.email)
COMMIT=$(git rev-parse HEAD)

# Write lock
cat > "$LOCK" <<LOCKEOF
{
  "sha256": "$SHA",
  "locked_at": "$TS",
  "locked_by": "$USER",
  "locked_commit": "$COMMIT"
}
LOCKEOF

# Git tag
TAG="prereg-phase2bis-${SUBEXP}-locked-$(date -u +%Y-%m-%d)"
git add "$PREREG" "$LOCK"
git commit -m "chore(hadf-phase2bis): lock prereg ${SUBEXP} (sha256=${SHA:0:12})"
git tag -a "$TAG" -m "Pre-registration locked for ${SUBEXP} at sha256=${SHA:0:12}"
git push origin "$TAG"

echo "Locked: $LOCK"
echo "Tag: $TAG"
echo "SHA: $SHA"
