#!/usr/bin/env python3
"""FIT-206 / DI-Q3 — off-SSD backup verification.

Re-verifies the sha256 CHECKSUMS.sha256 manifest of the N most-recent daily
snapshot directories in BOTH storage locations:

  1. internal (authoritative):  ~/Documents/FitTracker2-backups/daily/YYYY-MM-DD/
  2. off-SSD (secondary):       /Volumes/DevSSD/FitTracker2-snapshots/YYYY-MM-DD/

This is the Python equivalent of `shasum -a 256 -c CHECKSUMS.sha256` run inside
each dated snapshot dir — it detects silent bit-rot / partial-write corruption
that the daily checkpoint (which only *writes* checksums) never re-checks.

Design posture (matches the launchd-drift lessons in CLAUDE.md):
  * Filesystem-only — no `gh`, no network, so it is safe under launchd cron
    context where the keychain/GitHub auth may be unavailable.
  * A MISSING off-SSD root is NOT a failure (the SSD is frequently unmounted);
    it is recorded `present: false` and skipped. Only a checksum MISMATCH or a
    file listed-but-MISSING inside a present snapshot is a real failure.
  * Writes a machine-readable result to `.claude/shared/backup-verify-result.json`
    and, on failure, a `.claude/shared/backup-verify-failed.flag` sentinel that a
    monitoring surface (daily checkpoint / weekly cron) can read. Exit code is
    non-zero on any real failure so launchd/`launchctl list` surfaces it.

Usage:
    python3 scripts/verify-backups.py [--recent N] [--json]

Env overrides (primarily for tests):
    BACKUP_VERIFY_LOCAL_ROOT   overrides the internal daily root
    BACKUP_VERIFY_SSD_ROOT     overrides the off-SSD snapshot root
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

DEFAULT_LOCAL_ROOT = Path.home() / "Documents" / "FitTracker2-backups" / "daily"
DEFAULT_SSD_ROOT = Path("/Volumes/DevSSD/FitTracker2-snapshots")

RESULT_FILE = REPO_ROOT / ".claude" / "shared" / "backup-verify-result.json"
FAILED_FLAG = REPO_ROOT / ".claude" / "shared" / "backup-verify-failed.flag"

# Daily snapshot dirs are named by ISO date (YYYY-MM-DD), so lexical sort == chronological.
_DATE_DIR_RE = re.compile(r"^\d{4}-\d{2}-\d{2}")
# CHECKSUMS.sha256 lines: "<64-hex>  ./<relative/path>"
_CHECKSUM_LINE_RE = re.compile(r"^([0-9a-fA-F]{64})\s+\.?/?(.+)$")


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def recent_snapshot_dirs(root: Path, recent: int) -> list[Path]:
    """Return the `recent` most-recent dated snapshot dirs under `root`, newest first."""
    if not root.is_dir():
        return []
    dated = [p for p in root.iterdir() if p.is_dir() and _DATE_DIR_RE.match(p.name)]
    dated.sort(key=lambda p: p.name, reverse=True)
    return dated[:recent]


def verify_snapshot_dir(snap_dir: Path) -> dict:
    """Verify one snapshot dir against its CHECKSUMS.sha256.

    Returns {dir, status, failures:[{file, reason}]}.
    status: "ok" | "no_checksums" | "failed".
    A dir with no CHECKSUMS.sha256 is `no_checksums` (skipped, not failed — it may
    be a mid-write or legacy dir); it never contributes to the failure count.
    """
    checksums = snap_dir / "CHECKSUMS.sha256"
    if not checksums.is_file():
        return {"dir": snap_dir.name, "status": "no_checksums", "failures": []}

    failures: list[dict] = []
    for line in checksums.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        m = _CHECKSUM_LINE_RE.match(line)
        if not m:
            failures.append({"file": line[:80], "reason": "malformed_checksum_line"})
            continue
        expected, rel = m.group(1).lower(), m.group(2)
        target = snap_dir / rel
        if not target.is_file():
            failures.append({"file": rel, "reason": "missing"})
            continue
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if actual != expected:
            failures.append({"file": rel, "reason": "mismatch"})

    return {
        "dir": snap_dir.name,
        "status": "failed" if failures else "ok",
        "failures": failures,
    }


def verify_location(label: str, root: Path, recent: int) -> dict:
    """Verify the N most-recent snapshots at one location."""
    present = root.is_dir()
    dirs_result = [verify_snapshot_dir(d) for d in recent_snapshot_dirs(root, recent)]
    failures = sum(len(d["failures"]) for d in dirs_result)
    return {
        "label": label,
        "root": str(root),
        "present": present,
        "snapshots": dirs_result,
        "snapshots_checked": sum(1 for d in dirs_result if d["status"] != "no_checksums"),
        "failures": failures,
    }


def verify_backups(local_root: Path, ssd_root: Path, recent: int = 7) -> dict:
    """Verify both locations. `ok` is False only on a real corruption signal
    (checksum mismatch or missing/malformed file inside a present snapshot).
    A missing SSD root is tolerated."""
    locations = [
        verify_location("local", local_root, recent),
        verify_location("ssd", ssd_root, recent),
    ]
    total_failures = sum(loc["failures"] for loc in locations)
    return {
        "checked_at": _now_iso(),
        "recent": recent,
        "locations": locations,
        "total_failures": total_failures,
        "ok": total_failures == 0,
    }


def _resolve_roots() -> tuple[Path, Path]:
    local = Path(os.environ.get("BACKUP_VERIFY_LOCAL_ROOT", str(DEFAULT_LOCAL_ROOT)))
    ssd = Path(os.environ.get("BACKUP_VERIFY_SSD_ROOT", str(DEFAULT_SSD_ROOT)))
    return local, ssd


def main() -> int:
    ap = argparse.ArgumentParser(description="FIT-206 off-SSD backup verification.")
    ap.add_argument("--recent", type=int, default=7,
                    help="Number of most-recent dated snapshots to verify per location (default 7).")
    ap.add_argument("--json", action="store_true", help="Emit the full result as JSON to stdout.")
    args = ap.parse_args()

    local_root, ssd_root = _resolve_roots()
    result = verify_backups(local_root, ssd_root, recent=args.recent)

    # Persist the result + failure sentinel for monitoring surfaces.
    RESULT_FILE.parent.mkdir(parents=True, exist_ok=True)
    RESULT_FILE.write_text(json.dumps(result, indent=2))
    if result["ok"]:
        if FAILED_FLAG.exists():
            FAILED_FLAG.unlink()
    else:
        FAILED_FLAG.write_text(json.dumps({
            "checked_at": result["checked_at"],
            "total_failures": result["total_failures"],
            "failing_locations": [
                {"label": loc["label"], "root": loc["root"],
                 "failures": [d for d in loc["snapshots"] if d["failures"]]}
                for loc in result["locations"] if loc["failures"]
            ],
        }, indent=2))

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for loc in result["locations"]:
            if not loc["present"]:
                print(f"  · {loc['label']:5} {loc['root']}  — not mounted, skipped")
                continue
            status = "✓" if loc["failures"] == 0 else "✗"
            print(f"  {status} {loc['label']:5} {loc['root']}  — "
                  f"{loc['snapshots_checked']} verified, {loc['failures']} failure(s)")
            for snap in loc["snapshots"]:
                for fail in snap["failures"]:
                    print(f"        ✗ {snap['dir']}/{fail['file']}: {fail['reason']}")
        if result["ok"]:
            print("✓ Backup verification passed.")
        else:
            print(f"✗ Backup verification FAILED: {result['total_failures']} corrupt/missing file(s). "
                  f"Flag: {FAILED_FLAG}")

    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
