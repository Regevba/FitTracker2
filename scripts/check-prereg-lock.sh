#!/usr/bin/env bash
# check-prereg-lock — HADF Phase 2-bis preregistration lock gate.
#
# Rejects commits that modify a LOCKED preregistration JSON, with one
# exemption (F-LOCK-INTRODUCING-COMMIT-PERMIT, v7.9.1):
#
#   * UNLOCK commit — the same commit removes the `<prereg>.lock` file → allow.
#   * LOCK-INTRODUCING commit — the same commit ADDS the `<prereg>.lock` file
#     AND the sha256 recorded in that staged lock matches the sha256 of the
#     staged prereg content → allow. This is exactly the commit produced by
#     scripts/hadf-phase2bis-lock-prereg.sh; before this exemption it could
#     only land with --no-verify (observed 2026-05-30 on bd0db7e + 6cad3c7).
#   * FORWARD EDIT — lock pre-exists and the prereg is modified without an
#     unlock → block (the original contract).
#
# Operates on the staged index (git diff --cached). Exit 0 = ok, 1 = violation.
set -u

PREREG_RE='^\.claude/shared/hadf/preregistration-phase2bis-subexp[1-3]\.json$'

rc=0
for prereg in $(git diff --cached --name-only | grep -E "$PREREG_RE" || true); do
    lock="${prereg}.lock"
    [ -f "$lock" ] || continue

    # UNLOCK: lock being removed in this commit → legitimate unlock.
    if git diff --cached --name-only --diff-filter=D | grep -q "^${lock}$"; then
        continue
    fi

    # LOCK-INTRODUCING: lock being ADDED in this commit, sha256 matches staged
    # prereg content → the lock ceremony's own commit. Permit.
    if git diff --cached --name-only --diff-filter=A | grep -q "^${lock}$"; then
        staged_prereg_sha=$(git show ":${prereg}" | shasum -a 256 | awk '{print $1}')
        lock_sha=$(git show ":${lock}" | python3 -c \
            "import sys,json; print(json.load(sys.stdin).get('sha256',''))" 2>/dev/null)
        if [ -n "$lock_sha" ] && [ "$staged_prereg_sha" = "$lock_sha" ]; then
            echo "OK: lock-introducing commit for $prereg (sha256=$(echo "$lock_sha" | cut -c1-12)…) — permitted"
            continue
        fi
        echo "ERROR: $lock is being added but its sha256 does not match the staged $prereg content."
        echo "       lock=$lock_sha"
        echo "       staged=$staged_prereg_sha"
        echo "       Re-run scripts/hadf-phase2bis-lock-prereg.sh so the lock records the final content."
        rc=1
        continue
    fi

    # FORWARD EDIT against an existing lock → block.
    echo "ERROR: $prereg is locked at $lock — refusing to modify without removing the lock"
    echo "       To unlock: git rm $lock + audit-log entry, then re-stage prereg edit"
    rc=1
done

exit "$rc"
