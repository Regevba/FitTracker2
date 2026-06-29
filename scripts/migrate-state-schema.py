#!/usr/bin/env python3
"""
migrate-state-schema.py — DE-R18 (FIT-184) state.json schema versioning + migration runner.

Gives every `.claude/features/<slug>/state.json` a top-level integer
`schema_version` and a deterministic, ordered migration path so the schema
can evolve safely over time without ad-hoc field-rename incidents (the
`created`/`created_at` #7/#9 class).

How it works:
  - CURRENT_SCHEMA_VERSION is the canonical version every state.json should
    reach. Today = 1 (baseline; just stamps the field).
  - MIGRATIONS is an ordered registry of (from_v, to_v, transform) steps.
    To evolve the schema, append a step that mutates `state` in place and
    bump CURRENT_SCHEMA_VERSION. The runner applies every step whose
    from_v >= a file's current version, in order, until it reaches CURRENT.
  - A file with no `schema_version` is treated as version 0 and migrated up.
  - Idempotent: a file already at CURRENT is left byte-for-byte unchanged.

Usage:
  python3 scripts/migrate-state-schema.py            # dry-run (report)
  python3 scripts/migrate-state-schema.py --execute  # apply + write
  python3 scripts/migrate-state-schema.py --check    # report only, exit 0

Exit codes:
  0 — success / dry-run clean
  1 — a migration step raised
  2 — features dir not found
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"

CURRENT_SCHEMA_VERSION = 1


# ── Migration registry ──────────────────────────────────────────────────
# Each entry: (from_version, to_version, transform). `transform(state)`
# mutates the dict in place. Append future steps here and bump
# CURRENT_SCHEMA_VERSION. Example for a future v1→v2:
#   def _v1_to_v2(state): state["new_field"] = derive(state)
#   MIGRATIONS.append((1, 2, _v1_to_v2))

def _v0_to_v1(state: dict) -> None:
    """Baseline: no field transforms — stamping schema_version is the migration."""
    return None


MIGRATIONS: list[tuple[int, int, callable]] = [
    (0, 1, _v0_to_v1),
]


def current_version(state: dict) -> int:
    v = state.get("schema_version")
    return v if isinstance(v, int) else 0


def migrate_state(state: dict) -> tuple[dict, int, int]:
    """Apply all pending migrations in order. Returns (state, from_v, to_v)."""
    start = current_version(state)
    v = start
    while v < CURRENT_SCHEMA_VERSION:
        step = next((s for s in MIGRATIONS if s[0] == v), None)
        if step is None:
            raise RuntimeError(f"no migration step from schema_version {v}")
        _from, to, transform = step
        transform(state)
        v = to
    state["schema_version"] = CURRENT_SCHEMA_VERSION
    return state, start, v


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--execute", action="store_true", help="write changes (default dry-run)")
    ap.add_argument("--check", action="store_true", help="report only; never write")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not FEATURES_DIR.is_dir():
        print(f"migrate-state-schema: features dir not found: {FEATURES_DIR}", file=sys.stderr)
        return 2

    dist: dict[int, int] = {}
    migrated: list[str] = []
    for sj in sorted(FEATURES_DIR.glob("*/state.json")):
        try:
            raw = sj.read_text()
            state = json.loads(raw)
        except (OSError, json.JSONDecodeError):
            if not args.quiet:
                print(f"  ! skip unreadable: {sj.parent.name}")
            continue
        before = current_version(state)
        dist[before] = dist.get(before, 0) + 1
        if before == CURRENT_SCHEMA_VERSION:
            continue
        try:
            migrate_state(state)
        except RuntimeError as e:
            print(f"migrate-state-schema: {sj.parent.name}: {e}", file=sys.stderr)
            return 1
        migrated.append(sj.parent.name)
        if args.execute and not args.check:
            sj.write_text(json.dumps(state, indent=2) + "\n")

    if not args.quiet:
        mode = "EXECUTE" if (args.execute and not args.check) else "dry-run"
        print(f"migrate-state-schema [{mode}] — CURRENT_SCHEMA_VERSION={CURRENT_SCHEMA_VERSION}")
        print(f"  version distribution (before): "
              + ", ".join(f"v{k}={v}" for k, v in sorted(dist.items())))
        print(f"  needing migration: {len(migrated)}")
        if migrated and mode == "dry-run":
            for s in migrated[:10]:
                print(f"      - {s}")
            if len(migrated) > 10:
                print(f"      … and {len(migrated) - 10} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
