#!/usr/bin/env python3
"""One-shot backfill: insert state_owner: 'ft2' into all .claude/features/*/state.json.

Phase 2 v7.8.3 deliverable per spec §3.3.
Idempotent: features already having state_owner are skipped."""
from __future__ import annotations
import json
import glob
import sys


def main() -> int:
    backfilled = []
    already_set = []
    for path in sorted(glob.glob(".claude/features/*/state.json")):
        with open(path) as f:
            state = json.load(f)
        if "state_owner" in state:
            already_set.append(path)
            continue
        # Insert state_owner as second key (after "name")
        new_state = {}
        inserted = False
        for k, v in state.items():
            new_state[k] = v
            if k == "name" and not inserted:
                new_state["state_owner"] = "ft2"
                inserted = True
        if not inserted:  # defensive: append if no name field
            new_state["state_owner"] = "ft2"
        with open(path, "w") as f:
            json.dump(new_state, f, indent=2)
            f.write("\n")
        backfilled.append(path)

    print(f"Backfilled: {len(backfilled)}")
    print(f"Already set: {len(already_set)}")
    if backfilled:
        for p in backfilled:
            print(f"  + {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
