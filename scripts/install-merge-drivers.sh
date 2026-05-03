#!/usr/bin/env bash
# Install custom git merge drivers for v7.8 Mechanism E.
#
# Registers the `union-dedup-by-key` driver in this clone's git config.
# Files that opt in via .gitattributes (the merge=union-dedup-by-key
# attribute) will use the driver instead of git's default 3-way merge,
# resolving append-only ledger conflicts via union-dedup.
#
# Per docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md §4.5.
# Idempotent — safe to re-run.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
driver_script="scripts/merge-driver-dedup.py"

if [[ ! -x "$repo_root/$driver_script" ]]; then
    echo "Error: $driver_script not found or not executable at $repo_root" >&2
    exit 1
fi

git -C "$repo_root" config merge.union-dedup-by-key.name \
    "Union-dedup ledger merger (v7.8 Mechanism E)"
git -C "$repo_root" config merge.union-dedup-by-key.driver \
    "$driver_script %O %A %B %P"

echo "✓ merge-driver-dedup installed in $repo_root/.git/config"

if [[ -f "$repo_root/.gitattributes" ]]; then
    registered="$(grep -E 'merge=union-dedup-by-key' "$repo_root/.gitattributes" \
        | awk '{print $1}' | tr '\n' ' ')"
    if [[ -n "$registered" ]]; then
        echo "  Registered ledgers: $registered"
    else
        echo "  (no .gitattributes entries opt in yet — see bridge design §4.5)"
    fi
fi
