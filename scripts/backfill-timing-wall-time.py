#!/usr/bin/env python3
"""
Backfill ``timing.total_wall_time_minutes`` for post-v6 features that have
per-phase timing but no aggregate wall-time — but ONLY where the derivation is
honest.

Why this script is conservative
-------------------------------
``total_wall_time_minutes`` is *active working time*, not calendar-elapsed span.
Empirically (2026-06-10 corpus scan) the convention in the 17 already-populated
features is ``total_wall_time_minutes ≈ sum of per-phase durations`` for clean
same-session features. For multi-day features the calendar span balloons to
days/weeks while the real active time stays small, and for features with
out-of-order / negative phase timestamps no honest derivation exists at all.

So this script derives a value ONLY for features that pass all three gates:
  1. every phase with both timestamps is monotonic (ended_at >= started_at)
  2. summed active duration > 0
  3. both summed duration AND calendar span are < SANE_MAX_MINUTES (24h)

Features that fail any gate are NOT fabricated. They are tagged in-place with
``timing.wall_time_backfill`` = ``"excluded-multiday"`` or
``"excluded-dirty-timestamps"`` so the exclusion is transparent and queryable,
and they are reported on stdout for operator review. This mirrors the
soak-window-discipline "freeze, don't fake" rule (CLAUDE.md).

Every value written carries provenance:
  timing.total_wall_time_minutes_provenance =
      "backfill-derived-from-phase-durations-<date>"

Usage:
    scripts/backfill-timing-wall-time.py            # dry-run (default)
    scripts/backfill-timing-wall-time.py --apply    # write changes
    scripts/backfill-timing-wall-time.py --apply --date 2026-06-10

Exit codes:
    0  ran successfully (dry-run or apply)
    1  no features dir
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
V6_SHIP_DATE = "2026-04-16"
SANE_MAX_MINUTES = 24 * 60  # 24h: anything larger is multi-day, not one session


def _parse(ts: str):
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def _created(d: dict) -> str:
    return (d.get("created_at") or d.get("created") or "")[:10]


def _phase_intervals(d: dict):
    """Return list of (start, end) datetimes for phases with both timestamps."""
    timing = d.get("timing") or {}
    phases = timing.get("phases") or {}
    out = []
    for v in phases.values():
        if not isinstance(v, dict):
            continue
        s, e = _parse(v.get("started_at")), _parse(v.get("ended_at"))
        if s and e:
            out.append((s, e))
    return out


def classify(d: dict):
    """Return (status, minutes_or_None).

    status in {"already_set", "no_per_phase", "derivable", "multiday", "dirty"}.
    """
    timing = d.get("timing") or {}
    wt = timing.get("total_wall_time_minutes")
    if isinstance(wt, (int, float)) and wt > 0:
        return "already_set", None

    intervals = _phase_intervals(d)
    if not intervals:
        return "no_per_phase", None

    if any(e < s for s, e in intervals):
        return "dirty", None

    summed = sum((e - s).total_seconds() / 60.0 for s, e in intervals)
    span = (max(e for _, e in intervals) - min(s for s, _ in intervals)).total_seconds() / 60.0
    if summed <= 0:
        return "dirty", None
    if summed > SANE_MAX_MINUTES or span > SANE_MAX_MINUTES:
        return "multiday", None

    # Honest active-time estimate: summed phase durations, but never exceeding the
    # calendar span (phases may overlap → span is the true elapsed in that case).
    minutes = round(min(summed, span) if summed > span else summed, 1)
    return "derivable", minutes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="write changes (default: dry-run)")
    ap.add_argument("--date", default=datetime.now(timezone.utc).strftime("%Y-%m-%d"),
                    help="provenance date stamp (default: today UTC)")
    args = ap.parse_args()

    if not FEATURES_DIR.is_dir():
        print("no features dir")
        return 1

    buckets = {"derivable": [], "multiday": [], "dirty": [], "already_set": [],
               "no_per_phase": []}
    writes = []

    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        name = state_path.parent.name
        try:
            d = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            continue
        if _created(d) < V6_SHIP_DATE:
            continue  # pre-v6 features are expected to lack this field

        status, minutes = classify(d)
        buckets[status].append((name, minutes))
        if status in ("already_set", "no_per_phase"):
            continue

        timing = d.setdefault("timing", {})
        if status == "derivable":
            timing["total_wall_time_minutes"] = minutes
            timing["total_wall_time_minutes_provenance"] = (
                f"backfill-derived-from-phase-durations-{args.date}")
            timing.pop("wall_time_backfill", None)  # clear any prior exclusion tag
        else:  # multiday / dirty — transparent exclusion, NO fabricated value
            timing["wall_time_backfill"] = f"excluded-{'multiday' if status == 'multiday' else 'dirty-timestamps'}"
        writes.append((state_path, d, status, minutes))

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"=== backfill-timing-wall-time [{mode}] (provenance date {args.date}) ===\n")
    print(f"DERIVED ({len(buckets['derivable'])}) — total_wall_time_minutes written:")
    for n, m in buckets["derivable"]:
        print(f"   {n:50s} {m:>8.1f} min")
    print(f"\nEXCLUDED multi-day ({len(buckets['multiday'])}) — tagged excluded-multiday, no value fabricated:")
    for n, _ in buckets["multiday"]:
        print(f"   {n}")
    print(f"\nEXCLUDED dirty-timestamps ({len(buckets['dirty'])}) — tagged excluded-dirty-timestamps, FLAG for review:")
    for n, _ in buckets["dirty"]:
        print(f"   {n}")
    print(f"\nuntouched: already_set={len(buckets['already_set'])} no_per_phase={len(buckets['no_per_phase'])}")

    if args.apply:
        for state_path, d, _status, _m in writes:
            state_path.write_text(json.dumps(d, indent=2) + "\n")
        print(f"\nwrote {len(writes)} state.json files.")
    else:
        print(f"\n(dry-run — {len(writes)} files would change. Re-run with --apply.)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
