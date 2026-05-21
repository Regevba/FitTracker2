#!/usr/bin/env python3
"""
compact-session-ledgers.py — R9 from 2026-05-19 dev-env audit.

Archives Mechanism C session-event ledgers (`_session-*.events.jsonl`)
that are older than N days (default 30). Sessions are MOVED — never
deleted — to `.claude/logs/_archive/sessions/` so Mechanism C session
attribution remains queryable post-archive.

Critical safety: Mechanism C reads recent session ledgers for the
PostToolUse:Read attribution loop. This script must NEVER touch a
session younger than --min-age-days (default 30). The default is
intentionally conservative — Mechanism C lookup windows are typically
days, not weeks.

Usage:
  python3 scripts/compact-session-ledgers.py            # dry-run
  python3 scripts/compact-session-ledgers.py --execute  # actually archive
  python3 scripts/compact-session-ledgers.py --min-age-days=60 --execute

Exit codes:
  0 — success (or dry-run completed cleanly)
  1 — error during archive
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
DEFAULT_MIN_AGE_DAYS = 30


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--logs-dir", type=Path, default=DEFAULT_LOGS_DIR)
    p.add_argument("--min-age-days", type=int, default=DEFAULT_MIN_AGE_DAYS,
                   help=f"Only archive sessions older than this many days (default {DEFAULT_MIN_AGE_DAYS})")
    p.add_argument("--execute", action="store_true",
                   help="Actually move; without this flag, dry-run only")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    log = (lambda *a, **kw: None) if args.quiet else print

    if not args.logs_dir.exists():
        print(f"Logs dir not found: {args.logs_dir}", file=sys.stderr)
        return 2

    archive_dir = args.logs_dir / "_archive" / "sessions"
    cutoff = dt.datetime.now() - dt.timedelta(days=args.min_age_days)

    log(f"=== Mechanism C session-ledger compaction ===")
    log(f"  Logs dir:     {args.logs_dir}")
    log(f"  Archive dir:  {archive_dir}")
    log(f"  Cutoff:       sessions older than {args.min_age_days}d")
    log(f"                (mtime before {cutoff.strftime('%Y-%m-%d')})")
    log("")

    all_sessions = sorted(args.logs_dir.glob("_session-*.events.jsonl"))
    candidates = []
    for p in all_sessions:
        mtime = dt.datetime.fromtimestamp(p.stat().st_mtime)
        if mtime < cutoff:
            candidates.append((p, mtime))

    log(f"  Total session ledgers: {len(all_sessions)}")
    log(f"  Older than cutoff:     {len(candidates)}")

    if not candidates:
        log(f"\n✓ Nothing to archive")
        return 0

    log(f"\nArchive list:")
    for p, mtime in candidates:
        size_kb = p.stat().st_size / 1024
        log(f"  - {p.name} ({size_kb:.1f} KB, last touched {mtime.strftime('%Y-%m-%d')})")

    if not args.execute:
        log(f"\n[dry-run] Re-run with --execute to apply")
        return 0

    log(f"\n[execute] archiving {len(candidates)} session(s)...")
    archive_dir.mkdir(parents=True, exist_ok=True)
    errors = 0
    for p, _ in candidates:
        target = archive_dir / p.name
        try:
            shutil.move(str(p), str(target))
            log(f"  ✓ {p.name} → _archive/sessions/")
        except Exception as e:
            log(f"  ERROR {p.name}: {e}", file=sys.stderr)
            errors += 1
    if errors:
        log(f"\n⚠ {errors} error(s) during archive")
        return 1
    log(f"\n✓ Archived {len(candidates)} session(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
