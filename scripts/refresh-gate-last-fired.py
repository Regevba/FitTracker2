#!/usr/bin/env python3
"""F17 — Refresh `.claude/shared/gate-last-fired.json` index from gate-coverage.jsonl.

Reads `.claude/logs/gate-coverage.jsonl` line-by-line (append-only Mechanism A
telemetry stream) and writes a per-gate aggregate index to
`.claude/shared/gate-last-fired.json`. The index is the AWS Config Rules
`LastSuccessfulInvocationTime` pattern — readers query "when did this gate
last fire?" in O(1) instead of scanning O(records × gates).

Output schema (gate-last-fired.json):

    {
      "schema_version": 1,
      "refreshed_at": "2026-06-04T13:50:00Z",
      "source_ledger": ".claude/logs/gate-coverage.jsonl",
      "source_rows_read": 1900,
      "source_rows_malformed": 0,
      "gates": {
        "<GATE_NAME>": {
          "last_fired_at": "2026-06-04T13:45:00Z",     // most recent ts where checked >= 1
          "last_checked_at": "2026-06-04T13:45:00Z",   // most recent ts where the gate ran (checked or skipped)
          "last_skipped_at": "2026-06-04T13:40:00Z",   // most recent ts where skipped >= 1
          "first_seen_at": "2026-05-07T00:00:00Z",
          "total_firings": 18,    // sum of `checked`
          "total_skips": 132,     // sum of `skipped`
          "total_candidates": 150 // sum of `candidates`
        },
        ...
      }
    }

Designed to be invoked from:
  - `make gate-last-fired` (Makefile target, direct)
  - `make integrity-check` (chains gate-last-fired before integrity)
  - `scripts/daily-integrity-checkpoint.py` (daily fresh refresh)
  - `.github/workflows/framework-status-weekly.yml` (weekly nightly)

Performance: ~1900 rows scanned in <2s on standard hardware (canonical
ledger size at v7.9.1 ship). Linear in row count.

Resilience: malformed JSON rows are counted and skipped, not crashed on.
The schema_version field allows future readers to detect format drift.

Spec: docs/master-plan/infra-master-plan-2026-05-12.md §3.1 Theme G F17 (RICE 66.7).
Linear: FIT-89.

Usage:
    scripts/refresh-gate-last-fired.py             # write index to default path
    scripts/refresh-gate-last-fired.py --dry-run   # print summary, no write
    scripts/refresh-gate-last-fired.py --quiet     # suppress stdout summary

Exit codes:
    0  index written (or dry-run completed) successfully
    1  ledger missing or unreadable
    2  output path unwritable
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# `REPO_ROOT_OVERRIDE` env var support (Q6 fix from F16 — see PR #611).
_REPO_ROOT_OVERRIDE = os.environ.get("REPO_ROOT_OVERRIDE")
if _REPO_ROOT_OVERRIDE:
    REPO_ROOT = Path(_REPO_ROOT_OVERRIDE).resolve()
else:
    REPO_ROOT = Path(__file__).resolve().parent.parent

LEDGER_PATH = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
INDEX_PATH = REPO_ROOT / ".claude" / "shared" / "gate-last-fired.json"
SCHEMA_VERSION = 1


def refresh_index(ledger: Path, *, now_iso: str | None = None) -> dict[str, Any]:
    """Build the index dict from a gate-coverage ledger.

    Args:
        ledger: path to `.claude/logs/gate-coverage.jsonl`
        now_iso: refresh timestamp to record. If None, uses current UTC.

    Returns:
        Index dict ready to JSON-serialize.

    Raises:
        FileNotFoundError: if `ledger` does not exist.
    """
    if not ledger.exists():
        raise FileNotFoundError(f"gate-coverage ledger not found: {ledger}")

    gates: dict[str, dict[str, Any]] = {}
    rows_read = 0
    rows_malformed = 0

    with ledger.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows_read += 1
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                rows_malformed += 1
                continue

            gate = row.get("gate")
            ts = row.get("timestamp")
            if not isinstance(gate, str) or not isinstance(ts, str):
                rows_malformed += 1
                continue

            candidates = _as_int(row.get("candidates", 0))
            checked = _as_int(row.get("checked", 0))
            skipped = _as_int(row.get("skipped", 0))

            entry = gates.setdefault(
                gate,
                {
                    "last_fired_at": None,
                    "last_checked_at": None,
                    "last_skipped_at": None,
                    "first_seen_at": ts,
                    "total_firings": 0,
                    "total_skips": 0,
                    "total_candidates": 0,
                },
            )

            # Track first_seen_at as the earliest timestamp.
            if ts < entry["first_seen_at"]:
                entry["first_seen_at"] = ts

            # last_checked_at = most recent ts where the gate ran at all
            # (either checked OR skipped is recorded with a timestamp).
            if entry["last_checked_at"] is None or ts > entry["last_checked_at"]:
                entry["last_checked_at"] = ts

            # last_fired_at = most recent ts where `checked >= 1`. This is
            # the strict "the gate actually evaluated against something"
            # signal — the input to the planned GATE_COVERAGE_ZERO meta-check.
            if checked > 0:
                if (
                    entry["last_fired_at"] is None
                    or ts > entry["last_fired_at"]
                ):
                    entry["last_fired_at"] = ts

            # last_skipped_at = most recent ts where `skipped >= 1`. Useful
            # for "this gate hasn't actually run in N days" diagnostics.
            if skipped > 0:
                if (
                    entry["last_skipped_at"] is None
                    or ts > entry["last_skipped_at"]
                ):
                    entry["last_skipped_at"] = ts

            entry["total_candidates"] += candidates
            entry["total_firings"] += checked
            entry["total_skips"] += skipped

    return {
        "schema_version": SCHEMA_VERSION,
        "refreshed_at": now_iso or _utc_iso(),
        "source_ledger": str(ledger.relative_to(REPO_ROOT)) if ledger.is_absolute() and _is_relative_to(ledger, REPO_ROOT) else str(ledger),
        "source_rows_read": rows_read,
        "source_rows_malformed": rows_malformed,
        "gates": gates,
    }


def write_index(index: dict[str, Any], path: Path) -> None:
    """Serialize the index dict to JSON at `path`. Creates parent dirs."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, sort_keys=False)
        f.write("\n")


def _as_int(v: Any) -> int:
    """Coerce a JSON value to int; default 0 on type mismatch."""
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        return int(v)
    return 0


def _utc_iso() -> str:
    """Return current UTC time in ISO-8601 with Z suffix."""
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z")
    )


def _is_relative_to(path: Path, base: Path) -> bool:
    """Path.is_relative_to backport for older Python."""
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--ledger",
        default=str(LEDGER_PATH),
        help="Path to gate-coverage.jsonl (default: .claude/logs/gate-coverage.jsonl)",
    )
    parser.add_argument(
        "--output",
        default=str(INDEX_PATH),
        help="Path to write gate-last-fired.json (default: .claude/shared/gate-last-fired.json)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Compute the index but do not write it; print summary to stdout",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress stdout summary (errors still go to stderr)",
    )
    args = parser.parse_args()

    ledger = Path(args.ledger)
    output = Path(args.output)

    try:
        index = refresh_index(ledger)
    except FileNotFoundError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if not args.dry_run:
        try:
            write_index(index, output)
        except OSError as e:
            print(f"error: cannot write {output}: {e}", file=sys.stderr)
            return 2

    if not args.quiet:
        gate_count = len(index["gates"])
        rows = index["source_rows_read"]
        malformed = index["source_rows_malformed"]
        action = "Would write" if args.dry_run else "Wrote"
        print(
            f"{action} {output.relative_to(REPO_ROOT) if _is_relative_to(output, REPO_ROOT) else output}: "
            f"{gate_count} gates from {rows} rows ({malformed} malformed)."
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
