#!/usr/bin/env bash
# Set the active feature for Mechanism C cache-event attribution.
#
# Writes <feature-name> to .claude/active-feature so observe-cache-hit.py
# (the PostToolUse:Read hook) tags subsequent Read events with the right
# feature in .claude/logs/_session-<id>.events.jsonl.
#
# /pm-workflow writes this lockfile automatically on entry. Use this
# script when working outside /pm-workflow (ad-hoc edits, debugging,
# investigating a non-feature task that should still attribute its
# Reads to a particular feature for the v7.9 measurement window).
#
# The lockfile is gitignored (per-clone, per-developer). To clear:
#   ./scripts/set-active-feature.sh --clear
#
# Per docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md §4.3.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
lockfile="$repo_root/.claude/active-feature"

if [[ "${1:-}" == "--clear" ]]; then
    rm -f "$lockfile"
    echo "Cleared active feature."
    exit 0
fi

if [[ $# -lt 1 ]]; then
    if [[ -f "$lockfile" ]]; then
        echo "Active feature: $(cat "$lockfile")"
    else
        echo "No active feature set."
    fi
    echo ""
    echo "Usage: $0 <feature-name>"
    echo "       $0 --clear"
    exit 0
fi

feature="$1"
feature_dir="$repo_root/.claude/features/$feature"

if [[ ! -d "$feature_dir" ]]; then
    echo "Warning: .claude/features/$feature/ does not exist." >&2
    echo "Setting anyway — the lockfile is just a string; cache events will" >&2
    echo "attribute to '$feature' regardless." >&2
fi

mkdir -p "$repo_root/.claude"
echo "$feature" > "$lockfile"
echo "Active feature set: $feature"
echo "(.claude/active-feature lockfile written)"
