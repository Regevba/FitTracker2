#!/usr/bin/env python3
"""
W9 auto-isolation status readout — feature w9-drift-triggered-auto-isolation, T5.

Summarizes recent `w9.auto_isolate` Mechanism A rows from gate-coverage.jsonl:
total drift events seen, isolations performed, offers, opt-outs, and the
false-trigger rate (PRD secondary metric S2).

Usage:
    python3 scripts/w9_isolation_status.py            # human summary
    python3 scripts/w9_isolation_status.py --json      # machine summary
    make w9-isolation-status

Exit code: 0 always (read-only readout).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(os.environ.get("REPO_ROOT_OVERRIDE", Path(__file__).resolve().parent.parent))
LEDGER = Path(os.environ.get("GATE_COVERAGE_LEDGER", str(REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl")))


def collect() -> dict:
    rows = []
    if LEDGER.exists():
        for line in LEDGER.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if row.get("gate") == "w9.auto_isolate":
                rows.append(row)

    by_outcome: dict[str, int] = {}
    for r in rows:
        by_outcome[r.get("outcome", "unknown")] = by_outcome.get(r.get("outcome", "unknown"), 0) + 1

    drift_events = len(rows)              # one row per drift fire
    isolated = by_outcome.get("isolated", 0)
    offers = by_outcome.get("offer", 0)
    opt_outs = by_outcome.get("opt_out", 0)
    errors = by_outcome.get("error", 0)
    noops = by_outcome.get("noop", 0)
    # False-trigger = a fire that produced no real isolation need (noop on a
    # tree we thought was dirty) — best-effort proxy until S2 is fully wired.
    acted = isolated + errors
    false_triggers = noops
    false_trigger_rate = (false_triggers / drift_events) if drift_events else 0.0

    return {
        "drift_events": drift_events,
        "isolated": isolated,
        "offers": offers,
        "opt_outs": opt_outs,
        "errors": errors,
        "noops": noops,
        "acted": acted,
        "false_trigger_rate": round(false_trigger_rate, 3),
        "by_outcome": by_outcome,
        "ledger": str(LEDGER),
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="W9 auto-isolation status readout (T5)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    s = collect()
    if args.json:
        print(json.dumps(s, indent=2))
        return 0

    print("=== W9 auto-isolation status ===")
    if s["drift_events"] == 0:
        print("  No w9.auto_isolate telemetry yet (no drift events recorded).")
        print(f"  Ledger: {s['ledger']}")
        return 0
    print(f"  Drift events seen:     {s['drift_events']}")
    print(f"  Auto-isolated:         {s['isolated']}")
    print(f"  Offers (advisory):     {s['offers']}")
    print(f"  Opt-outs:              {s['opt_outs']}")
    print(f"  Errors (recoverable):  {s['errors']}")
    print(f"  No-ops (clean tree):   {s['noops']}")
    print(f"  False-trigger rate:    {s['false_trigger_rate'] * 100:.1f}%  (S2 target <=10%)")
    print(f"  Ledger: {s['ledger']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
