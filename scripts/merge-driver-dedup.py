#!/usr/bin/env python3
"""Custom git merge driver: union-dedup-by-key for append-only ledgers.

v7.8 Mechanism E (bridge design §4.5). Resolves merge conflicts on
append-only ledgers like .claude/shared/measurement-adoption-history.json
and .claude/shared/documentation-debt.json by computing the union of a
configured array field, deduplicating by a stable key, and sorting.

Why a custom driver:
  - Both ledgers accumulate dated/ID'd snapshots from concurrent worktrees
    (HADF Phase 2 demonstrated the failure mode — two unattended jobs
    appended snapshots on different days, git's default merge produced
    conflict markers requiring manual resolution).
  - Union-dedup is the semantically correct merge for these files: every
    append is an independent observation, never a destructive overwrite.
  - Custom driver adds zero new dependencies (vs CRDT / Automerge).
  - Held in reserve for v7.9 promotion to a CRDT layer if observed
    collisions in v7.8 measurement window justify the upgrade.

Git invocation contract (per git-merge-driver(7)):
  %O = ancestor's version (we ignore — pure union-dedup is more robust
       than 3-way for append-only ledgers; ancestor is a subset of both
       sides by construction).
  %A = "ours" (current branch's version) — also the OUTPUT path; git
       expects the merge result written back here.
  %B = "theirs" (other branch's version).
  %P = real pathname (used to look up which ledger config applies).

Exit codes:
  0 = success, %A contains merged result.
  1 = registered path but parse / structural error → git surfaces a
      conflict and the user resolves manually. Safer than silently
      clobbering malformed data.
  2 = usage error (wrong arg count).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


# Registry: relative-path suffix → merge config.
# Add new ledgers here as they accumulate with the union-dedup pattern.
LEDGER_CONFIG = {
    ".claude/shared/measurement-adoption-history.json": {
        "array": "snapshots",
        "key": "date",
    },
    ".claude/shared/documentation-debt.json": {
        "array": "debt_items",
        "key": "id",
    },
}


def _config_for(path: str) -> dict | None:
    """Look up the merge config for `path` by suffix match.

    Git passes %P as a repo-relative path; we accept either form.
    Returns None (caller bails to git's default conflict markers) if
    the path isn't registered.
    """
    for registered_suffix, cfg in LEDGER_CONFIG.items():
        if path.endswith(registered_suffix):
            return cfg
    return None


def merge(
    path_ancestor: str,
    path_ours: str,
    path_theirs: str,
    path_real: str,
) -> int:
    cfg = _config_for(path_real)
    if cfg is None:
        print(
            f"merge-driver-dedup: {path_real} is not registered in "
            f"LEDGER_CONFIG; falling through to git default conflict resolution",
            file=sys.stderr,
        )
        return 1

    try:
        ours = json.loads(Path(path_ours).read_text())
        theirs = json.loads(Path(path_theirs).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(
            f"merge-driver-dedup: parse error on {path_real}: {exc}",
            file=sys.stderr,
        )
        return 1

    array_name = cfg["array"]
    key_name = cfg["key"]

    ours_arr = ours.get(array_name) or []
    theirs_arr = theirs.get(array_name) or []
    if not isinstance(ours_arr, list) or not isinstance(theirs_arr, list):
        print(
            f"merge-driver-dedup: {array_name} is not a list in both inputs "
            f"on {path_real}",
            file=sys.stderr,
        )
        return 1

    # Union by key. On collision: theirs wins (last writer wins by branch
    # ordering convention; in practice the weekly cron is the authoritative
    # writer and dominates either way). Items missing the dedup key are
    # silently dropped — they're malformed entries that shouldn't survive
    # the merge.
    by_key: dict[str, dict] = {}
    for item in ours_arr + theirs_arr:
        if not isinstance(item, dict):
            continue
        k = item.get(key_name)
        if k is None:
            continue
        by_key[k] = item

    merged_arr = sorted(
        by_key.values(),
        key=lambda x: str(x.get(key_name, "")),
    )

    # Take ours' structural base (preserves top-level fields like
    # `version`, `description`, `updated`), replace the array.
    merged = dict(ours)
    merged[array_name] = merged_arr

    # Per git contract: write the merged result back to %A (path_ours).
    # Trailing newline matches the existing files' convention.
    Path(path_ours).write_text(json.dumps(merged, indent=2) + "\n")
    return 0


def main() -> int:
    if len(sys.argv) != 5:
        print(f"usage: {sys.argv[0]} %O %A %B %P", file=sys.stderr)
        return 2
    return merge(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])


if __name__ == "__main__":
    sys.exit(main())
