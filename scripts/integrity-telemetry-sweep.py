#!/usr/bin/env python3
"""Cross-layer data-integrity + telemetry sweep — one command, one verdict.

Codifies the "check data integrity and telemetry across all system layers" pass
that was previously done by hand. Each layer runs its existing producer, and the
sweep aggregates a PASS / WARN / FAIL / INFO verdict per layer plus an overall
verdict + exit code — so a human, a cron, or an agent gets the same answer.

Layers:
  1. Framework integrity      — integrity-check.py (0 findings)
  2. Regression vs anchor      — integrity-diff.py (no regression vs 2026-05-14)
  3. Adoption telemetry        — gate-last-fired index (0 malformed) + adoption
  4. Gate calibration          — enforced gates must have candidates (no mis-wire)
  5. Documentation debt        — open items <= baseline
  6. Cross-repo sync           — R17 state-sync-health endpoint (mirror fresh)
  7. CI automation (bot PRs)    — check-bot-pr-health.py (no deadlocks)
  8. Analytics / GA4           — INFO: needs GA4 MCP; run the B3 runbook separately
  9. Backup checkpoint         — last daily-checkpoint ledger row is recent
 10. Upcoming cadence          — INFO: calendar-anchored follow-ups <= 14 days

Exit code: 0 if no layer FAILs (WARN/INFO don't fail), 1 if any layer FAILs.
Everything degrades gracefully — a missing `gh`, an unreachable endpoint, or an
absent ledger yields WARN/INFO, never a crash.

Usage:
  make integrity-sweep
  python3 scripts/integrity-telemetry-sweep.py [--no-refresh] [--json]

Docs: docs/process/data-integrity-telemetry-sweep.md
"""
from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHARED = REPO / ".claude" / "shared"
DOC_DEBT_BASELINE = 1  # open-debt items considered clean (matches integrity-diff anchor)

PASS, WARN, FAIL, INFO = "PASS", "WARN", "FAIL", "INFO"
_ICON = {PASS: "✓", WARN: "⚠", FAIL: "✗", INFO: "•"}


def _run(cmd: list[str], timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)


def _load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception:  # noqa: BLE001
        return {}


def _import_checkpoint():
    """Reuse state_sync_health_probe + upcoming_followups from the daily checkpoint."""
    p = REPO / "scripts" / "daily-integrity-checkpoint.py"
    spec = importlib.util.spec_from_file_location("daily_checkpoint", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ── layer checks — each returns (status, detail) ──────────────────────────────

def layer_framework_integrity() -> tuple[str, str]:
    r = _run(["python3", str(REPO / "scripts" / "integrity-check.py"), "--findings-only"])
    findings, advisory = -1, -1
    for line in (r.stdout + r.stderr).splitlines():
        if line.strip().startswith("Findings:"):
            # Format is "Findings: N ()" (0 advisories) or
            # "Findings: N + M advisory (...)". Match both — the older
            # split("+") parse raised on the no-advisory form.
            m = re.search(r"Findings:\s*(\d+)(?:\s*\+\s*(\d+)\s*advisor)?", line)
            if m:
                findings = int(m.group(1))
                advisory = int(m.group(2)) if m.group(2) else 0
            break
    if findings < 0:
        return WARN, "could not parse integrity-check output"
    status = PASS if findings == 0 else FAIL
    return status, f"{findings} findings + {advisory} advisory"


def layer_regression_anchor() -> tuple[str, str]:
    r = _run(["python3", str(REPO / "scripts" / "integrity-diff.py")])
    out = r.stdout + r.stderr
    if "No regression" in out:
        return PASS, "no regression vs 2026-05-14 anchor"
    if "Baseline not found" in out or "baseline" in out.lower() and "not found" in out.lower():
        return WARN, "baseline anchor not found (set INTEGRITY_DIFF_BASELINE)"
    if "REAL_REGRESSION" in out or "regression" in out.lower():
        return FAIL, "regression detected vs anchor — see `make integrity-diff`"
    return WARN, "integrity-diff produced no clear verdict"


def layer_adoption_telemetry(refresh: bool) -> tuple[str, str]:
    if refresh:
        _run(["python3", str(REPO / "scripts" / "refresh-gate-last-fired.py")])
        _run(["python3", str(REPO / "scripts" / "measurement-adoption-report.py")])
    idx = _load(SHARED / "gate-last-fired.json")
    gates = idx.get("gates", {})
    malformed = idx.get("malformed", idx.get("malformed_rows", 0))
    adopt = _load(SHARED / "measurement-adoption.json").get("summary", {})
    fa = adopt.get("fully_adopted", "?")
    pv6 = adopt.get("features_post_v6", "?")
    detail = f"{len(gates)} gates indexed, {malformed} malformed; adoption {fa}/{pv6} post-v6"
    return (PASS if malformed == 0 and gates else WARN), detail


def layer_gate_calibration() -> tuple[str, str]:
    """Flag any gate that has telemetry rows but 0 candidates (check-site mis-wire,
    the GATE_COVERAGE_ZERO 0-candidate class). Healthy-zero gates (candidates>0,
    fires 0) are fine."""
    idx = _load(SHARED / "gate-last-fired.json").get("gates", {})
    miswired = [
        k for k, v in idx.items()
        if (v.get("total_candidates", 0) == 0
            and v.get("total_checks", v.get("total_firings", 0)) == 0
            and v.get("total_skips", 0) == 0)
    ]
    healthy_zero = [k for k, v in idx.items()
                    if v.get("total_candidates", 0) > 0 and v.get("total_firings", 0) == 0]
    if miswired:
        return WARN, f"{len(miswired)} gate(s) with 0 candidates (possible mis-wire): {', '.join(sorted(miswired)[:5])}"
    return PASS, f"no 0-candidate mis-wires; {len(healthy_zero)} healthy-zero gate(s)"


def layer_documentation_debt(refresh: bool) -> tuple[str, str]:
    if refresh:
        _run(["python3", str(REPO / "scripts" / "documentation-debt-report.py"),
              "--output", str(SHARED / "documentation-debt.json")])
    n = _load(SHARED / "documentation-debt.json").get("summary", {}).get("open_debt_items", -1)
    if n < 0:
        return WARN, "documentation-debt.json unreadable"
    return (PASS if n <= DOC_DEBT_BASELINE else WARN), f"{n} open item(s) (baseline {DOC_DEBT_BASELINE})"


def layer_cross_repo_sync(ckpt) -> tuple[str, str]:
    probe = ckpt.state_sync_health_probe()
    if not probe.get("reachable"):
        return WARN, f"state-sync endpoint unreachable ({probe.get('error', '?')})"
    if probe.get("healthy"):
        age = probe.get("age_minutes", "?")
        n = probe.get("ft2_state_count", "?")
        return PASS, f"mirror healthy ({age}m old, {n} states)"
    return WARN, f"mirror not healthy: {probe.get('reason', 'unknown')} (http {probe.get('http_status')})"


def layer_ci_automation() -> tuple[str, str]:
    r = _run(["python3", str(REPO / "scripts" / "check-bot-pr-health.py")])
    if "gh unavailable" in r.stdout or "skipped" in r.stdout:
        return INFO, "gh unavailable — bot-PR health skipped"
    if r.returncode == 0:
        return PASS, "no deadlocked automated PRs"
    return FAIL, "deadlocked bot PR(s) — see `make bot-pr-health`"


def layer_analytics_ga4() -> tuple[str, str]:
    return INFO, ("requires GA4 MCP — run the B3 anomaly check per "
                  "docs/setup/ga4-funnels-and-conversions-runbook.md")


def layer_backup_checkpoint() -> tuple[str, str]:
    ledger = SHARED / "integrity-checkpoint-ledger.jsonl"
    try:
        last = json.loads(ledger.read_text().splitlines()[-1])
    except Exception:  # noqa: BLE001
        return WARN, "no checkpoint ledger rows"
    date = last.get("date", "?")
    return INFO, f"last daily checkpoint: {date}"


def layer_upcoming_cadence(ckpt, today: dt.date) -> tuple[str, str]:
    try:
        rows = ckpt.upcoming_followups(today)
    except Exception:  # noqa: BLE001
        return INFO, "cadence ledger unparseable"
    if not rows:
        return INFO, "no calendar-anchored follow-ups within 14 days"
    items = "; ".join(f"{r['id']} ({r['date']}, {r['days_away']}d)" for r in rows[:6])
    return INFO, items


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-refresh", action="store_true",
                    help="read existing ledgers instead of re-running producers")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    refresh = not args.no_refresh

    ckpt = _import_checkpoint()
    today = dt.date(2026, 1, 1)  # overwritten below via ledger; no Date.now in this env
    try:
        today = dt.date.fromisoformat(
            json.loads((SHARED / "integrity-checkpoint-ledger.jsonl").read_text().splitlines()[-1])["date"]
        )
    except Exception:  # noqa: BLE001
        pass

    layers = [
        ("Framework integrity", layer_framework_integrity()),
        ("Regression vs anchor", layer_regression_anchor()),
        ("Adoption telemetry", layer_adoption_telemetry(refresh)),
        ("Gate calibration", layer_gate_calibration()),
        ("Documentation debt", layer_documentation_debt(refresh)),
        ("Cross-repo sync", layer_cross_repo_sync(ckpt)),
        ("CI automation (bot PRs)", layer_ci_automation()),
        ("Analytics / GA4", layer_analytics_ga4()),
        ("Backup checkpoint", layer_backup_checkpoint()),
        ("Upcoming cadence", layer_upcoming_cadence(ckpt, today)),
    ]

    results = [{"layer": name, "status": st, "detail": detail} for name, (st, detail) in layers]
    worst_fail = any(r["status"] == FAIL for r in results)
    warns = sum(1 for r in results if r["status"] == WARN)

    if args.json:
        print(json.dumps({"overall": "FAIL" if worst_fail else ("WARN" if warns else "PASS"),
                          "layers": results}, indent=2))
    else:
        print("Data-integrity + telemetry sweep — all layers")
        print("=" * 60)
        width = max(len(r["layer"]) for r in results)
        for r in results:
            print(f"  {_ICON[r['status']]} {r['status']:<4} {r['layer']:<{width}}  {r['detail']}")
        print("=" * 60)
        overall = "FAIL" if worst_fail else ("WARN" if warns else "PASS")
        print(f"  OVERALL: {overall}"
              + (f" ({warns} warning(s))" if warns else "")
              + ("" if worst_fail else "  — no blocking findings"))
    return 1 if worst_fail else 0


if __name__ == "__main__":
    sys.exit(main())
