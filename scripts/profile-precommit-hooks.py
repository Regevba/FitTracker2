#!/usr/bin/env python3
"""
scripts/profile-precommit-hooks.py — FIT-181 (dev-env 2026-05-19 audit R15).

Profiles the **latency of the pre-commit hook's checks** so hook slowdown is a
measured, budget-able number instead of a "feels slow lately" complaint. For
each check the hook runs, it times N invocations, reports P50 / P95 / max, and
compares the total P95 against a budget.

**Methodology (honest about what it measures).** Each check is invoked as
`<interpreter> <script> --help` — a side-effect-free path that still pays the
full interpreter cold-start + module-import cost. For a git hook that cost is
the dominant, developer-felt latency (the checks themselves scan only the small
staged set). The number is therefore a stable *floor* on hook latency, not a
worst-case; it is what makes `git commit` feel slow. Machine-dependent, so the
report is informational and the `--check` budget is deliberately generous.

Usage:
    python3 scripts/profile-precommit-hooks.py                 # profile + write report
    python3 scripts/profile-precommit-hooks.py --samples 9      # more samples
    python3 scripts/profile-precommit-hooks.py --check          # exit 1 if over budget (CI)

Writes .claude/shared/precommit-hook-latency.json + a stdout table.

Exit codes:
    0  profiled OK (and, in --check mode, within budget)
    1  --check mode and total P95 exceeded the budget
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SCHEMA_VERSION = 1
REPO_ROOT = Path(
    os.environ.get("REPO_ROOT_OVERRIDE", Path(__file__).resolve().parent.parent)
)
REPORT_PATH = REPO_ROOT / ".claude" / "shared" / "precommit-hook-latency.json"

# The checks the .githooks/pre-commit hook invokes, in order. Each entry is a
# side-effect-free invocation that still pays the full startup cost.
CHECKS = [
    {"name": "check-state-schema",
     "argv": [sys.executable, "scripts/check-state-schema.py", "--help"]},
    {"name": "check-case-study-preflight",
     "argv": [sys.executable, "scripts/check-case-study-preflight.py", "--help"]},
    {"name": "check-prereg-lock",
     "argv": ["bash", "scripts/check-prereg-lock.sh", "--help"]},
]

# Budgets (seconds). Generous on purpose — this gates only egregious regressions
# (e.g. a check that starts importing a heavy dependency). Override via CLI.
DEFAULT_PER_CHECK_P95 = 3.0
DEFAULT_TOTAL_P95 = 8.0


def percentile(sorted_vals: list[float], q: float) -> float:
    """Linear-interpolation percentile. q in [0,1]. `sorted_vals` must be sorted."""
    if not sorted_vals:
        return 0.0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    pos = q * (len(sorted_vals) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(sorted_vals) - 1)
    frac = pos - lo
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * frac


def summarize(durations: list[float]) -> dict:
    s = sorted(durations)
    return {
        "samples": len(s),
        "p50": round(percentile(s, 0.50), 4),
        "p95": round(percentile(s, 0.95), 4),
        "max": round(s[-1], 4) if s else 0.0,
        "mean": round(sum(s) / len(s), 4) if s else 0.0,
    }


def time_command(argv: list[str], samples: int) -> list[float]:
    """Run argv `samples` times from REPO_ROOT, returning wall-clock seconds each.
    Non-zero exit codes are fine — we time the invocation regardless (--help on a
    script without an argparse handler may exit non-zero)."""
    out = []
    for _ in range(samples):
        t0 = time.perf_counter()
        try:
            subprocess.run(argv, cwd=REPO_ROOT, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=60)
        except (OSError, subprocess.TimeoutExpired):
            out.append(60.0)
            continue
        out.append(time.perf_counter() - t0)
    return out


def build_report(check_durations: dict[str, list[float]], budgets: dict) -> dict:
    """Assemble the report from per-check duration samples. Pure — the unit test
    feeds synthetic durations so it never shells out."""
    checks = {}
    total_p95 = 0.0
    over = []
    for name, durs in check_durations.items():
        stats = summarize(durs)
        total_p95 += stats["p95"]
        if stats["p95"] > budgets["per_check_p95"]:
            over.append(name)
        checks[name] = stats
    total_p95 = round(total_p95, 4)
    total_over = total_p95 > budgets["total_p95"]
    return {
        "schema_version": SCHEMA_VERSION,
        "budgets": budgets,
        "checks": checks,
        "total_p95": total_p95,
        "over_budget": {
            "per_check": sorted(over),
            "total": total_over,
        },
        "within_budget": (not over) and (not total_over),
    }


def _print_table(report: dict) -> None:
    b = report["budgets"]
    print(f"\n  pre-commit hook latency  (budget: per-check P95 <= {b['per_check_p95']}s, "
          f"total P95 <= {b['total_p95']}s)")
    print(f"  {'CHECK':<30} {'P50':>7} {'P95':>7} {'MAX':>7}  {'N':>3}")
    for name, s in report["checks"].items():
        flag = "  ⚠ OVER" if name in report["over_budget"]["per_check"] else ""
        print(f"  {name:<30} {s['p50']:>7.3f} {s['p95']:>7.3f} {s['max']:>7.3f}  {s['samples']:>3}{flag}")
    verdict = "WITHIN budget" if report["within_budget"] else "OVER budget"
    print(f"  {'TOTAL P95':<30} {report['total_p95']:>15.3f}  → {verdict}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Profile pre-commit hook check latency (FIT-181/R15).")
    ap.add_argument("--samples", type=int, default=5, help="samples per check (default 5)")
    ap.add_argument("--per-check-p95", type=float, default=DEFAULT_PER_CHECK_P95)
    ap.add_argument("--total-p95", type=float, default=DEFAULT_TOTAL_P95)
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if any budget is exceeded (CI gate mode)")
    args = ap.parse_args()

    budgets = {"per_check_p95": args.per_check_p95, "total_p95": args.total_p95}
    durations = {}
    for c in CHECKS:
        script = REPO_ROOT / c["argv"][1]
        if not script.exists():
            print(f"  skip {c['name']}: {c['argv'][1]} not found", file=sys.stderr)
            continue
        durations[c["name"]] = time_command(c["argv"], args.samples)

    report = build_report(durations, budgets)
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    _print_table(report)
    print(f"\n  wrote {REPORT_PATH.relative_to(REPO_ROOT)}")

    if args.check and not report["within_budget"]:
        print("FAIL: pre-commit hook latency over budget.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
