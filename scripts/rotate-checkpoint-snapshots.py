#!/usr/bin/env python3
"""
rotate-checkpoint-snapshots.py — R2 from 2026-05-19 dev-env audit.

Rotates / prunes daily-integrity-checkpoint snapshots under
~/Documents/FitTracker2-backups/daily/ to prevent silent backup-pipeline
failure when the internal disk fills up.

Retention policy (default):
- Last 30 daily snapshots: kept uncompressed
- First-of-month anchors (e.g. 2026-04-01, 2026-05-01, ...): kept permanently,
  optionally compressed to .tar.zst if older than 30 days
- All other older daily snapshots: removed

Companion to scripts/daily-integrity-checkpoint.py. Invoked manually
or via `make checkpoint-rotate`. The daily-checkpoint cron does NOT
call this automatically — operator runs weekly OR when disk usage
crosses a threshold.

Calendar safety:
- Pure file-system housekeeping; no state.json mutation, no infra-glob
  outside scripts/ itself, no gate impact.
- Backup root is on the macOS internal disk (NOT the SSD); no impact
  on canonical repo state.

Usage:
  python3 scripts/rotate-checkpoint-snapshots.py             # dry-run by default
  python3 scripts/rotate-checkpoint-snapshots.py --execute   # actually rotate
  python3 scripts/rotate-checkpoint-snapshots.py --keep-days=60 --execute  # custom retention

Exit codes:
  0 - success (or dry-run completed without errors)
  1 - error during rotation (partial state may exist; investigate)
  2 - backup root not found
"""
from __future__ import annotations

import argparse
import datetime as dt
import shutil
import subprocess
import sys
from pathlib import Path

DEFAULT_BACKUP_ROOT = Path.home() / "Documents" / "FitTracker2-backups" / "daily"
DEFAULT_KEEP_DAYS = 30


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--backup-root", type=Path, default=DEFAULT_BACKUP_ROOT,
                   help=f"Backup directory (default: {DEFAULT_BACKUP_ROOT})")
    p.add_argument("--keep-days", type=int, default=DEFAULT_KEEP_DAYS,
                   help=f"Keep uncompressed snapshots from the last N days (default: {DEFAULT_KEEP_DAYS})")
    p.add_argument("--execute", action="store_true",
                   help="Actually perform the rotation (default is dry-run)")
    p.add_argument("--compress-anchors", action="store_true",
                   help="Compress first-of-month anchors older than --keep-days to .tar.zst")
    return p.parse_args()


def list_snapshot_dirs(root: Path) -> list[Path]:
    """Return all YYYY-MM-DD dirs under backup root, sorted ascending."""
    if not root.is_dir():
        return []
    out = []
    for child in root.iterdir():
        if child.is_dir():
            try:
                dt.date.fromisoformat(child.name)
                out.append(child)
            except ValueError:
                continue
    return sorted(out, key=lambda p: p.name)


def is_first_of_month_anchor(snap_dir: Path) -> bool:
    try:
        d = dt.date.fromisoformat(snap_dir.name)
        return d.day == 1
    except ValueError:
        return False


def main() -> int:
    args = parse_args()
    root = args.backup_root

    if not root.is_dir():
        print(f"[rotate] Backup root not found: {root}", file=sys.stderr)
        return 2

    snapshots = list_snapshot_dirs(root)
    if not snapshots:
        print(f"[rotate] No snapshots found under {root}")
        return 0

    today = dt.date.today()
    cutoff = today - dt.timedelta(days=args.keep_days)

    to_remove: list[Path] = []
    to_compress: list[Path] = []
    kept: list[Path] = []

    for snap in snapshots:
        try:
            d = dt.date.fromisoformat(snap.name)
        except ValueError:
            continue

        if d >= cutoff:
            kept.append(snap)
            continue

        if is_first_of_month_anchor(snap):
            already_compressed = snap.with_suffix(".tar.zst").exists()
            if args.compress_anchors and not already_compressed:
                to_compress.append(snap)
            else:
                kept.append(snap)
            continue

        to_remove.append(snap)

    mode_label = "DRY-RUN" if not args.execute else "EXECUTE"
    print(f"[rotate] {mode_label} — backup root: {root}")
    print(f"[rotate]   cutoff date (keep newer than): {cutoff.isoformat()}")
    print(f"[rotate]   snapshots inspected: {len(snapshots)}")
    print(f"[rotate]   to keep:     {len(kept)}")
    print(f"[rotate]   to remove:   {len(to_remove)}")
    print(f"[rotate]   to compress: {len(to_compress)}")
    print()

    if to_remove:
        print("  Snapshots to remove:")
        for p in to_remove:
            size_kb = sum(f.stat().st_size for f in p.rglob("*") if f.is_file()) // 1024
            print(f"    - {p.name}  ({size_kb:,} KB)")
    if to_compress:
        print("  Snapshots to compress (first-of-month anchors > keep-days):")
        for p in to_compress:
            print(f"    + {p.name} → {p.name}.tar.zst")

    if not args.execute:
        print()
        print("[rotate] dry-run complete; re-run with --execute to apply changes.")
        return 0

    errors = 0

    for p in to_compress:
        archive = p.with_suffix(".tar.zst")
        try:
            print(f"[rotate] compressing {p.name} → {archive.name}")
            subprocess.run(
                ["tar", "--zstd", "-cf", str(archive), "-C", str(p.parent), p.name],
                check=True, capture_output=True,
            )
            shutil.rmtree(p)
        except (subprocess.CalledProcessError, OSError) as e:
            print(f"[rotate] ERROR compressing {p}: {e}", file=sys.stderr)
            errors += 1

    for p in to_remove:
        try:
            print(f"[rotate] removing {p.name}")
            shutil.rmtree(p)
        except OSError as e:
            print(f"[rotate] ERROR removing {p}: {e}", file=sys.stderr)
            errors += 1

    if errors:
        print(f"[rotate] completed with {errors} error(s).", file=sys.stderr)
        return 1

    print(f"[rotate] done. {len(kept)} snapshot(s) retained.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
