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

# Read the SHARED ledger (git common worktree) so the index aggregates firings
# from every worktree, not just whichever checkout this runs in. Env overrides win.
try:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from gate_coverage import canonical_ledger_path
    LEDGER_PATH = canonical_ledger_path(REPO_ROOT)
except Exception:
    LEDGER_PATH = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
INDEX_PATH = REPO_ROOT / ".claude" / "shared" / "gate-last-fired.json"
SNAPSHOTS_DIR = REPO_ROOT / ".claude" / "integrity" / "snapshots"
# v2 (T13): each gate gains `last_failed_at` / `total_failure_snapshots` /
# `last_failure_severity` derived from the integrity-snapshot history — so the
# index distinguishes "stopped running" (no recent coverage) from "running but
# catching violations" (recent failures). Schema-versioned so readers detect drift.
SCHEMA_VERSION = 2


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
            # Most Mechanism A rows use `timestamp`; some coverage-emitting hook
            # events (e.g. the W9 auto-isolation hook, `w9.auto_isolate`) use the
            # shorter `ts` field. Accept both so those rows are indexed rather than
            # miscounted as malformed (they share the candidates/checked/skipped
            # schema the aggregate needs).
            ts = row.get("timestamp") or row.get("ts")
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
                    # T13 (v2) failure-history fields — populated below from the
                    # integrity-snapshot history. None until a snapshot records
                    # this gate code in its findings.
                    "last_failed_at": None,
                    "total_failure_snapshots": 0,
                    "last_failure_severity": None,
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

    # T13: overlay failure history from the integrity-snapshot stream. Derive
    # the snapshots dir RELATIVE TO THE LEDGER (ledger is <root>/.claude/logs/...;
    # snapshots are <root>/.claude/integrity/snapshots) so a tmp-dir ledger in
    # tests resolves to a non-existent (empty) snapshots dir and the merge is a
    # no-op — keeping tests hermetic while production resolves the real dir.
    snapshots_dir = ledger.parent.parent / "integrity" / "snapshots"
    snapshots_scanned = merge_failure_history(gates, snapshots_dir)

    return {
        "schema_version": SCHEMA_VERSION,
        "refreshed_at": now_iso or _utc_iso(),
        "source_ledger": str(ledger.relative_to(REPO_ROOT)) if ledger.is_absolute() and _is_relative_to(ledger, REPO_ROOT) else str(ledger),
        "source_rows_read": rows_read,
        "source_rows_malformed": rows_malformed,
        "failure_source_snapshots": snapshots_scanned,
        "failure_history_note": (
            "last_failed_at is derived from .claude/integrity/snapshots/*.json "
            "(cycle-time findings). Write-time gates BLOCK commits rather than "
            "logging, so their blocks are not captured here — last_failed_at is "
            "meaningful for cycle-time + advisory codes (T13.1 may add a "
            "write-time block ledger)."
        ),
        "gates": gates,
    }


def merge_failure_history(gates: dict[str, dict[str, Any]], snapshots_dir: Path) -> int:
    """Overlay per-gate failure history from the integrity-snapshot stream.

    Each `.claude/integrity/snapshots/<ts>.json` records `timestamp` + a
    `findings[]` array of `{code, severity, ...}`. For every gate code seen, we
    set `last_failed_at` (most recent snapshot timestamp where the code appeared),
    `total_failure_snapshots` (count of distinct snapshots), and
    `last_failure_severity` (severity in the most-recent failing snapshot).

    Gates that appear ONLY in failure history (a cycle-time code with no coverage
    row) get a minimal entry created so the index is complete.

    Returns the number of snapshots scanned. Best-effort: a missing dir or a
    malformed snapshot is skipped, never raised.
    """
    if not snapshots_dir.is_dir():
        return 0
    scanned = 0
    for snap_path in sorted(snapshots_dir.glob("*.json")):
        try:
            snap = json.loads(snap_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        ts = snap.get("timestamp")
        findings = snap.get("findings")
        if not isinstance(ts, str) or not isinstance(findings, list):
            continue
        scanned += 1
        # codes seen in THIS snapshot (dedup so total_failure_snapshots counts
        # snapshots, not individual findings).
        seen_here: dict[str, str] = {}
        for f in findings:
            if not isinstance(f, dict):
                continue
            code = f.get("code")
            if not isinstance(code, str):
                continue
            # keep the first (any) severity for this code in this snapshot
            seen_here.setdefault(code, f.get("severity") or "")
        for code, severity in seen_here.items():
            entry = gates.setdefault(
                code,
                {
                    "last_fired_at": None,
                    "last_checked_at": None,
                    "last_skipped_at": None,
                    "first_seen_at": ts,
                    "total_firings": 0,
                    "total_skips": 0,
                    "total_candidates": 0,
                    "last_failed_at": None,
                    "total_failure_snapshots": 0,
                    "last_failure_severity": None,
                },
            )
            entry["total_failure_snapshots"] += 1
            if entry["last_failed_at"] is None or ts > entry["last_failed_at"]:
                entry["last_failed_at"] = ts
                entry["last_failure_severity"] = severity or None
    return scanned


def _min_iso(a: str | None, b: str | None) -> str | None:
    """Earliest of two ISO timestamps; tolerates None on either side."""
    vals = [v for v in (a, b) if v]
    return min(vals) if vals else None


def _max_iso(a: str | None, b: str | None) -> str | None:
    """Most-recent of two ISO timestamps; tolerates None on either side."""
    vals = [v for v in (a, b) if v]
    return max(vals) if vals else None


def merge_indexes(
    fresh: dict[str, Any], existing: dict[str, Any]
) -> tuple[dict[str, dict[str, Any]], int]:
    """Union-merge freshly-derived per-gate stats with an existing committed index.

    Rationale (the #745 regression class): `.claude/logs/gate-coverage.jsonl` is
    gitignored and session-local, so the freshly-derived index reflects ONLY the
    rows present in *this* checkout's ledger. A fresh clone / isolated worktree
    has a thin (or empty) ledger, so a plain overwrite would shrink the committed
    index — dropping gates and resetting high-water-mark counts that earlier,
    fuller sessions recorded. Merging makes the committed index a monotonic
    high-water mark that a thin local log cannot regress.

    Merge rule, per gate present in either side:
      - counters (`total_*`)    → max (never shrink; high-water mark)
      - `first_seen_at`         → min (earliest wins)
      - `last_*_at` timestamps  → max (most-recent wins, None-tolerant)
      - `last_failure_severity` → from whichever side has the later `last_failed_at`
      - gate only in `existing`  → carried over verbatim (never dropped)

    Returns (merged_gates, carried_over_count) where carried_over_count is the
    number of gates that existed only in the committed index (pure carry-overs).
    """
    fresh_gates: dict[str, dict[str, Any]] = fresh.get("gates", {})
    existing_gates: dict[str, dict[str, Any]] = (
        existing.get("gates", {}) if isinstance(existing, dict) else {}
    )

    merged: dict[str, dict[str, Any]] = {}
    carried_over = 0
    counters = (
        "total_firings",
        "total_skips",
        "total_candidates",
        "total_failure_snapshots",
    )

    for gate in set(fresh_gates) | set(existing_gates):
        f = fresh_gates.get(gate)
        e = existing_gates.get(gate)
        if f is None:
            # Gate known only to the committed index — carry over so a thin
            # local ledger can't drop it.
            merged[gate] = dict(e)
            carried_over += 1
            continue
        if e is None:
            merged[gate] = dict(f)
            continue
        # Present in both — take the high-water mark field-wise.
        m = dict(f)
        for c in counters:
            m[c] = max(_as_int(f.get(c, 0)), _as_int(e.get(c, 0)))
        m["first_seen_at"] = _min_iso(f.get("first_seen_at"), e.get("first_seen_at"))
        m["last_fired_at"] = _max_iso(f.get("last_fired_at"), e.get("last_fired_at"))
        m["last_checked_at"] = _max_iso(f.get("last_checked_at"), e.get("last_checked_at"))
        m["last_skipped_at"] = _max_iso(f.get("last_skipped_at"), e.get("last_skipped_at"))
        m["last_failed_at"] = _max_iso(f.get("last_failed_at"), e.get("last_failed_at"))
        # Severity follows the most-recent failure.
        if (e.get("last_failed_at") or "") > (f.get("last_failed_at") or ""):
            m["last_failure_severity"] = e.get("last_failure_severity")
        merged[gate] = m

    return merged, carried_over


def load_existing_index(path: Path) -> dict[str, Any]:
    """Load an existing committed index; return {} if absent or unparseable."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return {}


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
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help=(
            "Pure overwrite from the ledger — do NOT union-merge with the existing "
            "committed index. Use only for an intentional reset; the default merge "
            "prevents a thin/empty local ledger from regressing the committed index "
            "(the #745 regression class)."
        ),
    )
    args = parser.parse_args()

    ledger = Path(args.ledger)
    output = Path(args.output)

    try:
        index = refresh_index(ledger)
    except FileNotFoundError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    # Default: union-merge with the existing committed index so a thin local
    # ledger (fresh clone / isolated worktree) cannot shrink it. `--rebuild`
    # opts into the old pure-overwrite behavior for intentional resets.
    merged_carried_over = 0
    merged = False
    if not args.rebuild:
        existing = load_existing_index(output)
        if existing.get("gates"):
            index["gates"], merged_carried_over = merge_indexes(index, existing)
            merged = True
    index["merged_with_committed"] = merged
    index["merged_carried_over_gates"] = merged_carried_over

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
