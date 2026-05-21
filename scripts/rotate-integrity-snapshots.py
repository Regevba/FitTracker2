#!/usr/bin/env python3
"""
rotate-integrity-snapshots.py — R20 from 2026-05-19 dev-env audit.

Rotates / prunes integrity-check snapshots under
.claude/integrity/snapshots/<TIMESTAMP>.json to prevent the snapshot
directory from growing unbounded after months of `make integrity-snapshot`
invocations.

Companion to R2 (rotate-checkpoint-snapshots.py) — same retention policy,
different target dir. R2 handles `~/Documents/FitTracker2-backups/daily/`;
R20 handles `.claude/integrity/snapshots/`.

Retention policy (default):
- Last 30 snapshots: kept uncompressed
- First-of-month anchors (any snapshot dated YYYY-MM-01): kept permanently
- All other older snapshots: removed

Calendar safety:
- Pure file-system housekeeping; no state.json mutation, no gate impact
- Snapshot files are JSON metadata only; no other code reads them after
  the next `make integrity-snapshot` comparison consumes the prior file

Usage:
  python3 scripts/rotate-integrity-snapshots.py            # dry-run
  python3 scripts/rotate-integrity-snapshots.py --execute  # actually rotate
  python3 scripts/rotate-integrity-snapshots.py --keep-count=60 --execute

Exit codes:
  0 — success (or dry-run completed without errors)
  1 — error during rotation
  2 — snapshot dir not found
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SNAPSHOT_DIR = REPO_ROOT / ".claude" / "integrity" / "snapshots"
DEFAULT_KEEP_COUNT = 30

# Filenames look like: 2026-05-12T07-22-35Z.json
SNAPSHOT_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})T\d{2}-\d{2}-\d{2}Z\.json$")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--snapshot-dir", type=Path, default=DEFAULT_SNAPSHOT_DIR,
                   help="Directory containing snapshot JSON files")
    p.add_argument("--keep-count", type=int, default=DEFAULT_KEEP_COUNT,
                   help=f"Most-recent N snapshots to keep (default {DEFAULT_KEEP_COUNT})")
    p.add_argument("--execute", action="store_true",
                   help="Actually delete; without this flag, dry-run only")
    p.add_argument("--quiet", action="store_true",
                   help="Suppress progress; errors still print")
    return p.parse_args()


def is_first_of_month(name: str) -> bool:
    m = SNAPSHOT_RE.match(name)
    return bool(m and m.group(3) == "01")


def parse_date(name: str) -> dt.date | None:
    m = SNAPSHOT_RE.match(name)
    if not m:
        return None
    try:
        return dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def main() -> int:
    args = parse_args()
    log = (lambda *a, **kw: None) if args.quiet else print

    if not args.snapshot_dir.exists():
        log(f"Snapshot dir not found: {args.snapshot_dir}", file=sys.stderr)
        return 2

    # Gather snapshots with valid name pattern
    candidates = []
    for p in sorted(args.snapshot_dir.glob("*.json")):
        d = parse_date(p.name)
        if d is None:
            log(f"  skip (unparseable name): {p.name}")
            continue
        candidates.append((d, p))

    if not candidates:
        log(f"No snapshots found in {args.snapshot_dir}")
        return 0

    # Sort by date descending — most recent first
    candidates.sort(key=lambda t: t[0], reverse=True)

    # Decide who to keep
    keep_recent = set(p for _, p in candidates[:args.keep_count])
    keep_anchors = set(p for _, p in candidates if is_first_of_month(p.name))
    keep = keep_recent | keep_anchors

    to_remove = [p for _, p in candidates if p not in keep]

    log(f"=== Integrity-snapshot retention ===")
    log(f"  Dir:          {args.snapshot_dir}")
    log(f"  Total:        {len(candidates)} snapshots")
    log(f"  Keep (recent):  {len(keep_recent)} (last {args.keep_count})")
    log(f"  Keep (anchors): {len(keep_anchors)} (first-of-month)")
    log(f"  Keep (union):   {len(keep)}")
    log(f"  Remove:         {len(to_remove)}")

    if not to_remove:
        log(f"\n✓ Nothing to remove")
        return 0

    log(f"\nRemoval list:")
    for p in to_remove:
        log(f"  - {p.name}")

    if not args.execute:
        log(f"\n[dry-run] Re-run with --execute to apply")
        return 0

    log(f"\n[execute] removing {len(to_remove)} snapshot(s)...")
    errors = 0
    for p in to_remove:
        try:
            p.unlink()
        except Exception as e:
            log(f"  ERROR removing {p.name}: {e}", file=sys.stderr)
            errors += 1
    if errors:
        log(f"\n⚠ {errors} error(s) during removal")
        return 1
    log(f"\n✓ Removed {len(to_remove)} snapshot(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
