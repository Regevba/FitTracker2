#!/usr/bin/env python3
"""
Weekly trend scan — extends framework-status-weekly.yml with:

(A2) Mechanism A gate-coverage zero-drift detection:
     A gate that previously emitted coverage telemetry but no longer does
     is a silent-pass risk (observed-patterns.md #3). Compare CURRENT
     distinct-gate set vs the union of all previously-seen gates from
     `.claude/shared/gate-coverage-weekly.jsonl`. Missing gates → regression.

(A4) Per-dimension adoption trend nudge:
     The existing weekly cron only watches `fully_adopted` + `any_adopted`.
     This adds the four dimension percentages (timing, per_phase, cache_hits,
     cu_v2) — the master plan (data-integrity §2.5) explicitly flags
     `cu_v2 ≥50%` chronic miss and `fully_adopted_post_v6` regression
     (27.3%→8.3%) as targets to watch.

Outputs:
  - Digest fragment (markdown) → stdout (suitable for $GITHUB_ENV heredoc)
  - GitHub Actions outputs → $GITHUB_OUTPUT (when set):
      a2_gate_regression=true|false
      a2_gates_current=N
      a2_gates_ever_seen=N
      a2_gates_missing=<csv>
      a4_dim_regression=true|false
      a4_dim_deltas=<json>

Side-effect: appends one row to `.claude/shared/gate-coverage-weekly.jsonl`
each run, unless --no-append is passed (test mode).

Exit code 0 always — regression flagging is via outputs only. The orchestrating
workflow OR's these flags into the existing measurement-adoption regression.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GATE_COV = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
WEEKLY_GATE_LEDGER = REPO_ROOT / ".claude" / "shared" / "gate-coverage-weekly.jsonl"
ADOPT = REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json"
ADOPT_HIST = REPO_ROOT / ".claude" / "shared" / "measurement-adoption-history.json"

DIMENSION_KEYS = ("timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2")


def load_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def current_distinct_gates() -> set[str]:
    if not GATE_COV.exists():
        return set()
    gates: set[str] = set()
    for line in GATE_COV.read_text().splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
            g = d.get("gate")
            if g:
                gates.add(g)
        except json.JSONDecodeError:
            continue
    return gates


def ever_seen_gates() -> set[str]:
    """Union of all distinct_gates fields from prior weekly rows."""
    if not WEEKLY_GATE_LEDGER.exists():
        return set()
    seen: set[str] = set()
    for line in WEEKLY_GATE_LEDGER.read_text().splitlines():
        if not line.strip():
            continue
        try:
            row = json.loads(line)
            for g in row.get("distinct_gates", []):
                seen.add(g)
        except json.JSONDecodeError:
            continue
    return seen


def append_weekly_row(gates: set[str], append: bool) -> None:
    if not append:
        return
    WEEKLY_GATE_LEDGER.parent.mkdir(parents=True, exist_ok=True)
    row = {
        "date": dt.date.today().isoformat(),
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "distinct_gate_count": len(gates),
        "distinct_gates": sorted(gates),
    }
    with WEEKLY_GATE_LEDGER.open("a") as f:
        f.write(json.dumps(row, separators=(",", ":")) + "\n")


def dim_deltas() -> tuple[dict, bool]:
    """Return per-dimension deltas vs prior snapshot + regression flag.

    Regression = any dimension percentage dropped vs prior snapshot.
    Note: cu_v2 chronic-miss is informational; only DROP triggers regression.
    """
    cur = load_json(ADOPT)
    hist = load_json(ADOPT_HIST)
    snaps = hist.get("snapshots", [])

    cur_dim = cur.get("dimension_coverage", {})
    prior_dim = (snaps[-1] if snaps else {}).get("dimension_coverage", {})
    prior_date = (snaps[-1] if snaps else {}).get("date", "(no prior)")

    deltas = {}
    regression = False
    for k in DIMENSION_KEYS:
        cur_pct = cur_dim.get(k, {}).get("post_v6_percent", 0)
        prior_pct = prior_dim.get(k, {}).get("post_v6_percent", 0)
        delta = round(cur_pct - prior_pct, 1)
        deltas[k] = {
            "current": cur_pct,
            "prior": prior_pct,
            "delta": delta,
        }
        if delta < 0:
            regression = True

    # Also surface fully_adopted_post_v6 since master-plan §2.5 calls it out
    cur_sum = cur.get("summary", {})
    prior_sum = (snaps[-1] if snaps else {}).get("summary", {})
    cur_fa = cur_sum.get("fully_adopted_post_v6", 0)
    prior_fa = prior_sum.get("fully_adopted_post_v6", 0)
    fa_delta = cur_fa - prior_fa
    deltas["fully_adopted_post_v6"] = {
        "current": cur_fa,
        "prior": prior_fa,
        "delta": fa_delta,
    }
    if fa_delta < 0:
        regression = True

    deltas["__meta__"] = {"prior_date": prior_date}
    return deltas, regression


def write_github_outputs(payload: dict) -> None:
    out_path = os.environ.get("GITHUB_OUTPUT")
    if not out_path:
        return
    with open(out_path, "a") as f:
        for k, v in payload.items():
            if isinstance(v, (dict, list)):
                v = json.dumps(v, separators=(",", ":"))
            f.write(f"{k}={v}\n")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--no-append", action="store_true",
                    help="Don't append to the weekly gate ledger (test mode)")
    ap.add_argument("--json", action="store_true",
                    help="Output a single JSON blob instead of the markdown digest")
    args = ap.parse_args()

    cur_gates = current_distinct_gates()
    prior_gates = ever_seen_gates()
    missing = sorted(prior_gates - cur_gates)
    a2_regression = bool(missing)

    deltas, a4_regression = dim_deltas()

    append_weekly_row(cur_gates, append=not args.no_append)

    payload = {
        "a2_gate_regression": "true" if a2_regression else "false",
        "a2_gates_current": len(cur_gates),
        "a2_gates_ever_seen": len(prior_gates),
        "a2_gates_missing": ",".join(missing),
        "a4_dim_regression": "true" if a4_regression else "false",
        "a4_dim_deltas": deltas,
    }
    write_github_outputs(payload)

    if args.json:
        print(json.dumps({
            "a2": {
                "regression": a2_regression,
                "current_count": len(cur_gates),
                "ever_seen_count": len(prior_gates),
                "missing": missing,
                "current_gates": sorted(cur_gates),
            },
            "a4": {
                "regression": a4_regression,
                "deltas": deltas,
            },
        }, indent=2))
        return 0

    lines = []
    lines.append("### Weekly trend scan (Mechanism A + per-dimension)")
    lines.append("")
    if a2_regression:
        lines.append(f"**A2 — Gate coverage REGRESSION:** {len(missing)} gate(s) previously emitted but no longer do:")
        for g in missing:
            lines.append(f"  - `{g}`")
    else:
        lines.append(f"**A2 — Gate coverage OK:** {len(cur_gates)} distinct gates currently emitting "
                     f"(ever-seen: {len(prior_gates)}).")
    lines.append("")
    lines.append(f"**A4 — Per-dimension adoption** (vs {deltas['__meta__']['prior_date']}):")
    lines.append("")
    lines.append("| Dimension | Current | Prior | Δ |")
    lines.append("|---|---|---|---|")
    for k in DIMENSION_KEYS:
        d = deltas[k]
        sign = "+" if d["delta"] > 0 else ""
        flag = " ⚠" if d["delta"] < 0 else ""
        lines.append(f"| {k} | {d['current']}% | {d['prior']}% | {sign}{d['delta']}{flag} |")
    fa = deltas["fully_adopted_post_v6"]
    sign = "+" if fa["delta"] > 0 else ""
    flag = " ⚠" if fa["delta"] < 0 else ""
    lines.append(f"| fully_adopted_post_v6 | {fa['current']} | {fa['prior']} | {sign}{fa['delta']}{flag} |")
    lines.append("")
    if a4_regression:
        lines.append("⚠ At least one dimension regressed; opens digest issue per workflow regression rule.")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
