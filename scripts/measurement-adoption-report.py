#!/usr/bin/env python3
"""
Audit every feature's state.json for v6.0 measurement-adoption coverage.

Moves Gemini audit Tier 1.1 ("Automated time and event-based metrics") from
narrative "partial" to auditable "partial with known delta". Reports which
features have populated v6.0 measurement fields and which don't.

The v6.0 recommendation was to instrument:
- timing.total_wall_time_minutes (T1 — Instrumented)
- timing.phases[*].started_at / ended_at (T1 per phase)
- cache_hits[] entries (T1 — Deterministic cache counters)
- complexity.cu_version=2 with continuous factors (T2 — Declared)

A feature is counted as "v6.0-adopted" only when all four dimensions have
non-trivial content. Pre-v6.0 features are expected to lack this data; the
report distinguishes them via the state.json.created timestamp.

Usage:
    scripts/measurement-adoption-report.py                  # print to stdout
    scripts/measurement-adoption-report.py --output PATH    # write JSON

Exit codes:
    0  report generated (non-zero adoption count or not)
    1  no features found
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
V6_SHIP_DATE = "2026-04-16"  # framework-measurement-v6 shipped this day


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def has_timing_wall_time(d: dict) -> bool:
    """True if timing.total_wall_time_minutes is a non-null positive number."""
    timing = d.get("timing")
    if not isinstance(timing, dict):
        return False
    wt = timing.get("total_wall_time_minutes")
    return isinstance(wt, (int, float)) and wt > 0


def has_per_phase_timing(d: dict) -> bool:
    """True if timing.phases has at least one phase with started_at + ended_at."""
    timing = d.get("timing")
    if not isinstance(timing, dict):
        return False
    phases = timing.get("phases")
    if not isinstance(phases, dict):
        return False
    for phase_data in phases.values():
        if not isinstance(phase_data, dict):
            continue
        if phase_data.get("started_at") and phase_data.get("ended_at"):
            return True
    return False


def has_cache_hits(d: dict) -> bool:
    """True if cache_hits is a populated list (not None, not empty)."""
    ch = d.get("cache_hits")
    return isinstance(ch, list) and len(ch) > 0


def has_cu_v2(d: dict) -> bool:
    """True if complexity.cu_version is 2 (or "v2")."""
    c = d.get("complexity")
    if not isinstance(c, dict):
        return False
    v = c.get("cu_version")
    return v in (2, "2", "v2")


def classify_feature(d: dict) -> dict:
    """Compute the 4-dimension adoption vector for one feature."""
    return {
        "timing_wall_time": has_timing_wall_time(d),
        "per_phase_timing": has_per_phase_timing(d),
        "cache_hits": has_cache_hits(d),
        "cu_v2": has_cu_v2(d),
    }


def post_v6(created: str) -> bool:
    """True if the feature was created on or after v6.0's ship date."""
    if not created:
        return False
    return created[:10] >= V6_SHIP_DATE


def build_report() -> dict:
    features = []
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        name = state_path.parent.name
        try:
            d = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            features.append({
                "feature": name,
                "created": None,
                "post_v6": False,
                "error": "invalid_json",
            })
            continue

        created = d.get("created") or ""
        adoption = classify_feature(d)
        all_four = all(adoption.values())
        any_field = any(adoption.values())
        features.append({
            "feature": name,
            "created": created[:10] if created else None,
            "post_v6": post_v6(created),
            "current_phase": d.get("current_phase") or d.get("phase"),
            "adoption": adoption,
            "fully_adopted": all_four,
            "any_adopted": any_field,
        })

    total = len(features)
    if total == 0:
        return {}

    # Aggregate slices
    post_v6_features = [f for f in features if f["post_v6"]]
    pre_v6_features = [f for f in features if not f["post_v6"]]
    fully_adopted = [f for f in features if f.get("fully_adopted")]
    partial_adopted = [f for f in features if f.get("any_adopted") and not f.get("fully_adopted")]
    zero_adopted = [f for f in features if not f.get("any_adopted") and "error" not in f]

    dimension_coverage: dict[str, dict] = {}
    for dim in ("timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2"):
        present = sum(1 for f in features if f.get("adoption", {}).get(dim))
        post_v6_present = sum(1 for f in post_v6_features if f.get("adoption", {}).get(dim))
        dimension_coverage[dim] = {
            "overall_present": present,
            "overall_percent": round(present / total * 100, 1),
            "post_v6_present": post_v6_present,
            "post_v6_percent": round(post_v6_present / max(len(post_v6_features), 1) * 100, 1),
        }

    return {
        "version": "1.0",
        "updated": utc_now(),
        "v6_ship_date": V6_SHIP_DATE,
        "description": "Gemini audit Tier 1.1 adoption inventory. Counts which features have v6.0 measurement fields (timing.total_wall_time_minutes, per-phase timing, cache_hits, CU v2) in their state.json.",
        "summary": {
            "features_total": total,
            "features_post_v6": len(post_v6_features),
            "features_pre_v6": len(pre_v6_features),
            "fully_adopted": len(fully_adopted),
            "partial_adopted": len(partial_adopted),
            "zero_adopted": len(zero_adopted),
            "fully_adopted_post_v6": sum(1 for f in post_v6_features if f.get("fully_adopted")),
            "tier_1_1_status": (
                "shipped" if len(fully_adopted) == total
                else "partial" if len(fully_adopted) > 0
                else "not_adopted"
            ),
        },
        "dimension_coverage": dimension_coverage,
        "fully_adopted_features": [f["feature"] for f in fully_adopted],
        "partial_adopted_features": [
            {"feature": f["feature"], "adoption": f["adoption"]}
            for f in partial_adopted
        ],
        "zero_adopted_features": [
            {"feature": f["feature"], "created": f["created"], "post_v6": f["post_v6"]}
            for f in zero_adopted
        ],
        "features": features,
    }


def append_history_snapshot(history_path: Path, report: dict, trigger: str) -> tuple[bool, str]:
    """Append a dated snapshot to the append-only history file.

    Dedup rule: at most one snapshot per date. Subsequent runs the same day
    are no-ops (returns False, "already exists for today"). This keeps the
    history idempotent under multiple PR-bot runs and weekly-cron retries.

    Returns (appended, message).
    """
    today = report["updated"][:10]
    if history_path.exists():
        try:
            history = json.loads(history_path.read_text())
        except json.JSONDecodeError:
            history = {"version": "1.0", "snapshots": []}
    else:
        history = {
            "version": "1.0",
            "description": (
                "Append-only daily snapshots of Tier 1.1 measurement adoption. "
                "Dedup by date — at most one snapshot per day. Mirrors the "
                "documentation-debt history pattern; enables Tier 1.1 trend "
                "analysis after 3+ daily snapshots accumulate."
            ),
            "snapshots": [],
        }
    snapshots = history.setdefault("snapshots", [])
    if any(snap.get("date") == today for snap in snapshots):
        return False, f"snapshot for {today} already exists, skipped"
    snapshots.append({
        "date": today,
        "generated_at": report["updated"],
        "trigger": trigger,
        "summary": report["summary"],
        "dimension_coverage": report["dimension_coverage"],
    })
    history["updated"] = report["updated"]
    # Atomic write via temp file + rename (POSIX guarantees atomicity within fs).
    tmp_path = history_path.with_suffix(history_path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(history, indent=2) + "\n")
    tmp_path.replace(history_path)
    return True, f"appended snapshot for {today} ({trigger})"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json"),
        help="Where to write the JSON report (default: .claude/shared/measurement-adoption.json).",
    )
    parser.add_argument(
        "--history-output",
        default=str(REPO_ROOT / ".claude" / "shared" / "measurement-adoption-history.json"),
        help="Where to append the daily history snapshot.",
    )
    parser.add_argument(
        "--snapshot-trigger",
        choices=["manual", "scheduled_cycle", "pr_bot", "weekly_status"],
        default="manual",
        help="Annotates the history snapshot with what fired this run.",
    )
    parser.add_argument("--stdout", action="store_true", help="Also print a summary to stdout.")
    args = parser.parse_args()

    report = build_report()
    if not report:
        print("No features found in .claude/features/", file=__import__("sys").stderr)
        return 1

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n")

    # Append to dated history (Phase 2b — enables trend analysis).
    history_path = Path(args.history_output)
    history_path.parent.mkdir(parents=True, exist_ok=True)
    appended, history_msg = append_history_snapshot(history_path, report, args.snapshot_trigger)

    s = report["summary"]
    print(f"Tier 1.1 measurement-adoption inventory — {report['updated']}")
    print(f"  Features: {s['features_total']} (post-v6: {s['features_post_v6']}, pre-v6: {s['features_pre_v6']})")
    print(f"  Fully adopted: {s['fully_adopted']} ({s['fully_adopted_post_v6']} of {s['features_post_v6']} post-v6)")
    print(f"  Partial adoption: {s['partial_adopted']}")
    print(f"  Zero adoption: {s['zero_adopted']}")
    print(f"  Tier 1.1 status: {s['tier_1_1_status']}")
    print()
    print("Per-dimension coverage:")
    for dim, v in report["dimension_coverage"].items():
        print(f"  {dim}: {v['overall_present']}/{s['features_total']} overall ({v['overall_percent']}%); "
              f"{v['post_v6_present']}/{s['features_post_v6']} post-v6 ({v['post_v6_percent']}%)")
    print()
    print(f"Report written to: {output_path}")
    print(f"History: {history_msg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
