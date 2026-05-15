#!/usr/bin/env python3
"""
Integrity diff — compare current platform state vs a frozen baseline anchor.

Default baseline: the 2026-05-14 pre-v7.9 platform-integrity baseline captured
by the analytics-observability feature. Override via --baseline <path> or env
INTEGRITY_DIFF_BASELINE.

Reads identical surfaces from both sides:
  - measurement-adoption.json  (summary + dimension_coverage)
  - documentation-debt.json    (summary.open_debt_items)
  - integrity-check-output.txt (parsed 'Findings: N + M advisory ()')

Outputs a delta table to stdout and exits non-zero on regression. The
regression definition matches scripts/daily-integrity-checkpoint.py:
  - findings / blocking / debt UP   → regression
  - fully_adopted / adoption% DOWN  → regression
  - distinct gates DOWN             → regression

Designed for two callers:
  - `make integrity-diff` — operator-facing readout
  - daily-integrity-checkpoint.py post-hook — regression flag complement
    (the checkpoint already diffs vs prior row; this diffs vs anchor)

Rationale (data-integrity-and-rollback-2026-05-14.md §2.1 + §2.3): the 96h
gap between the weekly cron (Mon 05:00 UTC) and the 72h cycle can hide
drift accumulating across multiple commits. The daily checkpoint catches
day-over-day deltas; integrity-diff catches drift against the calibration
anchor. Both together close the gap.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASELINE = (
    Path.home()
    / "Documents"
    / "FitTracker2-backups"
    / "2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14"
    / "platform-baseline"
)


def load_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def parse_integrity_findings(text: str) -> tuple[int, int]:
    """Parse 'Findings: N + M advisory ()' line. Returns (findings, advisory)."""
    for line in text.splitlines():
        if line.strip().startswith("Findings:"):
            try:
                _, rhs = line.split(":", 1)
                left = rhs.strip().split("+")[0].strip()
                advisory_part = rhs.split("+", 1)[1] if "+" in rhs else "0"
                adv_n = "".join(c for c in advisory_part if c.isdigit())
                return int(left), int(adv_n or "0")
            except (ValueError, IndexError):
                continue
    return -1, -1


def collect_metrics_from_dir(d: Path) -> dict:
    """Read metrics from a snapshot directory (baseline OR current shared/)."""
    adopt = load_json(d / "measurement-adoption.json")
    s = adopt.get("summary", {})
    dim = adopt.get("dimension_coverage", {})

    debt = load_json(d / "documentation-debt.json")
    debt_open = debt.get("summary", {}).get("open_debt_items", -1)

    findings_path = d / "integrity-check-output.txt"
    if findings_path.exists():
        findings, advisory = parse_integrity_findings(findings_path.read_text())
    else:
        findings, advisory = -1, -1

    return {
        "integrity_findings": findings,
        "integrity_advisory": advisory,
        "doc_debt_open": debt_open,
        "features_total": s.get("features_total", -1),
        "features_post_v6": s.get("features_post_v6", -1),
        "fully_adopted": s.get("fully_adopted", -1),
        "fully_adopted_post_v6": s.get("fully_adopted_post_v6", -1),
        "adoption_pct_post_v6": round(
            100 * s.get("fully_adopted_post_v6", 0)
            / max(s.get("features_post_v6", 1), 1),
            1,
        ),
        "timing_wall_time_pct_post_v6": dim.get("timing_wall_time", {}).get("post_v6_percent", -1),
        "per_phase_timing_pct_post_v6": dim.get("per_phase_timing", {}).get("post_v6_percent", -1),
        "cache_hits_pct_post_v6": dim.get("cache_hits", {}).get("post_v6_percent", -1),
        "cu_v2_pct_post_v6": dim.get("cu_v2", {}).get("post_v6_percent", -1),
    }


def collect_current_metrics() -> dict:
    """Read metrics from the live repo (shared/ ledgers + a fresh integrity check)."""
    import subprocess

    shared = REPO_ROOT / ".claude" / "shared"

    adopt = load_json(shared / "measurement-adoption.json")
    s = adopt.get("summary", {})
    dim = adopt.get("dimension_coverage", {})

    debt = load_json(shared / "documentation-debt.json")
    debt_open = debt.get("summary", {}).get("open_debt_items", -1)

    rc = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts" / "integrity-check.py"), "--findings-only"],
        capture_output=True, text=True, timeout=300, check=False,
    )
    findings, advisory = parse_integrity_findings(rc.stdout + rc.stderr)

    return {
        "integrity_findings": findings,
        "integrity_advisory": advisory,
        "doc_debt_open": debt_open,
        "features_total": s.get("features_total", -1),
        "features_post_v6": s.get("features_post_v6", -1),
        "fully_adopted": s.get("fully_adopted", -1),
        "fully_adopted_post_v6": s.get("fully_adopted_post_v6", -1),
        "adoption_pct_post_v6": round(
            100 * s.get("fully_adopted_post_v6", 0)
            / max(s.get("features_post_v6", 1), 1),
            1,
        ),
        "timing_wall_time_pct_post_v6": dim.get("timing_wall_time", {}).get("post_v6_percent", -1),
        "per_phase_timing_pct_post_v6": dim.get("per_phase_timing", {}).get("post_v6_percent", -1),
        "cache_hits_pct_post_v6": dim.get("cache_hits", {}).get("post_v6_percent", -1),
        "cu_v2_pct_post_v6": dim.get("cu_v2", {}).get("post_v6_percent", -1),
    }


HIGHER_IS_WORSE = ("integrity_findings", "doc_debt_open")
LOWER_IS_WORSE = (
    "fully_adopted_post_v6",
    "adoption_pct_post_v6",
    "timing_wall_time_pct_post_v6",
    "per_phase_timing_pct_post_v6",
    "cache_hits_pct_post_v6",
    "cu_v2_pct_post_v6",
)


def is_regression(key: str, delta: float) -> bool:
    if key in HIGHER_IS_WORSE and delta > 0:
        return True
    if key in LOWER_IS_WORSE and delta < 0:
        return True
    return False


def format_row(key: str, baseline: float, current: float) -> tuple[str, bool]:
    delta = round(current - baseline, 2) if isinstance(current, (int, float)) and isinstance(baseline, (int, float)) else 0
    is_regr = is_regression(key, delta)
    sign = "+" if delta > 0 else ""
    flag = "⚠" if is_regr else " "
    return f"| {flag} {key:<32} | {baseline:>10} | {current:>10} | {sign}{delta:>8} |", is_regr


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--baseline",
        default=os.environ.get("INTEGRITY_DIFF_BASELINE", str(DEFAULT_BASELINE)),
        help=f"Path to baseline snapshot dir (default: {DEFAULT_BASELINE})",
    )
    ap.add_argument(
        "--exit-on-regression",
        action="store_true",
        help="Exit 1 if any regression detected (default: exit 0 even on regression)",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Output machine-readable JSON instead of human table",
    )
    args = ap.parse_args()

    baseline_dir = Path(args.baseline)
    if not baseline_dir.exists():
        print(f"✗ Baseline not found: {baseline_dir}", file=sys.stderr)
        print(
            "  Override via --baseline <path> or env INTEGRITY_DIFF_BASELINE.",
            file=sys.stderr,
        )
        sys.exit(2)

    baseline = collect_metrics_from_dir(baseline_dir)
    current = collect_current_metrics()

    keys = (
        "integrity_findings",
        "integrity_advisory",
        "doc_debt_open",
        "features_total",
        "features_post_v6",
        "fully_adopted",
        "fully_adopted_post_v6",
        "adoption_pct_post_v6",
        "timing_wall_time_pct_post_v6",
        "per_phase_timing_pct_post_v6",
        "cache_hits_pct_post_v6",
        "cu_v2_pct_post_v6",
    )

    rows = []
    regressions = []
    for k in keys:
        b = baseline.get(k, -1)
        c = current.get(k, -1)
        row_text, regr = format_row(k, b, c)
        rows.append(row_text)
        if regr:
            regressions.append({"key": k, "baseline": b, "current": c, "delta": round(c - b, 2)})

    if args.json:
        print(json.dumps({
            "baseline_dir": str(baseline_dir),
            "baseline": baseline,
            "current": current,
            "regressions": regressions,
            "has_regression": bool(regressions),
        }, indent=2))
    else:
        print(f"=== Integrity diff vs {baseline_dir.name} ===\n")
        print(f"| {'⚠':1} {'Metric':<32} | {'Baseline':>10} | {'Current':>10} | {'Delta':>9} |")
        print(f"|---|{'-'*34}|{'-'*12}|{'-'*12}|{'-'*11}|")
        for r in rows:
            print(r)
        print()
        if regressions:
            print(f"⚠ {len(regressions)} regression(s) vs baseline:")
            for r in regressions:
                print(f"  - {r['key']}: {r['baseline']} → {r['current']} (Δ {r['delta']:+})")
        else:
            print("✓ No regression vs baseline.")

    if regressions and args.exit_on_regression:
        sys.exit(1)


if __name__ == "__main__":
    main()
