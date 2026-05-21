#!/usr/bin/env python3
"""
rotate-feature-logs.py — R8 from 2026-05-19 dev-env audit.

Rotates `.claude/logs/<feature>.log.json` files when they exceed a size
threshold (default 5MB). The rotated file is moved into
`.claude/logs/_archive/<feature>.log.json.<timestamp>` so Tier 2.2
contemporaneous-log lineage is preserved — never deleted, only moved.

After rotation, the original file path is recreated as an empty JSON array
`[]` so subsequent log-append operations continue cleanly.

Critical safety: this rotation does NOT touch:
  - `_session-*.events.jsonl` files (Mechanism C — see R9 for that)
  - `devssd-uuid-watcher.log` (R4 audit; small + caller-managed)
  - `README.md`
  - any file outside `.claude/logs/`

Usage:
  python3 scripts/rotate-feature-logs.py             # dry-run
  python3 scripts/rotate-feature-logs.py --execute   # actually rotate
  python3 scripts/rotate-feature-logs.py --threshold-mb=10 --execute

Exit codes:
  0 — success (or dry-run completed cleanly)
  1 — error during rotation
  2 — logs dir not found
"""
from __future__ import annotations

import argparse
import datetime as dt
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOGS_DIR = REPO_ROOT / ".claude" / "logs"
DEFAULT_THRESHOLD_MB = 5

EXCLUDE_NAMES = {"README.md", "devssd-uuid-watcher.log"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--logs-dir", type=Path, default=DEFAULT_LOGS_DIR)
    p.add_argument("--threshold-mb", type=int, default=DEFAULT_THRESHOLD_MB,
                   help=f"Files larger than this many MB get rotated (default {DEFAULT_THRESHOLD_MB})")
    p.add_argument("--execute", action="store_true",
                   help="Actually rotate; without this flag, dry-run only")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args()


def is_feature_log(p: Path) -> bool:
    """Skip Mechanism C session ledgers + excluded names + archive subdir."""
    if not p.is_file():
        return False
    if p.name in EXCLUDE_NAMES:
        return False
    if p.name.startswith("_session-"):
        return False
    # Only .log.json
    if not p.name.endswith(".log.json"):
        return False
    return True


def main() -> int:
    args = parse_args()
    log = (lambda *a, **kw: None) if args.quiet else print

    if not args.logs_dir.exists():
        print(f"Logs dir not found: {args.logs_dir}", file=sys.stderr)
        return 2

    threshold_bytes = args.threshold_mb * 1024 * 1024
    archive_dir = args.logs_dir / "_archive"

    log(f"=== Feature-log rotation ===")
    log(f"  Logs dir:    {args.logs_dir}")
    log(f"  Archive dir: {archive_dir}")
    log(f"  Threshold:   {args.threshold_mb} MB")
    log("")

    candidates = []
    total_count = 0
    for p in sorted(args.logs_dir.iterdir()):
        if not is_feature_log(p):
            continue
        total_count += 1
        size = p.stat().st_size
        if size > threshold_bytes:
            candidates.append((p, size))

    log(f"  Total feature logs: {total_count}")
    log(f"  Over threshold:     {len(candidates)}")

    if not candidates:
        log(f"\n✓ Nothing to rotate")
        return 0

    log(f"\nRotation list:")
    for p, size in candidates:
        size_mb = size / (1024 * 1024)
        log(f"  - {p.name} ({size_mb:.1f} MB)")

    if not args.execute:
        log(f"\n[dry-run] Re-run with --execute to apply")
        return 0

    log(f"\n[execute] rotating {len(candidates)} file(s)...")
    archive_dir.mkdir(parents=True, exist_ok=True)
    errors = 0
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for p, _ in candidates:
        target = archive_dir / f"{p.name}.{ts}"
        try:
            shutil.move(str(p), str(target))
            p.write_text("[]\n")  # reset to empty JSON array
            log(f"  ✓ {p.name} → _archive/{target.name}")
        except Exception as e:
            log(f"  ERROR {p.name}: {e}", file=sys.stderr)
            errors += 1
    if errors:
        log(f"\n⚠ {errors} error(s) during rotation")
        return 1
    log(f"\n✓ Rotated {len(candidates)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
