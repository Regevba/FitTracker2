#!/usr/bin/env python3
"""
Weekly trend scan — extends framework-status-weekly.yml with:

(A2) Mechanism A gate-coverage zero-drift detection:
     A gate that previously emitted coverage telemetry but no longer does
     is a silent-pass risk (observed-patterns.md #3). Compare CURRENT
     distinct-gate set vs the union of all previously-seen gates from
     `.claude/shared/gate-coverage-weekly.jsonl`. Missing gates → regression.

     Source (R1 fix, 2026-06-11): the CURRENT distinct-gate set is read from
     the committed F17 index `.claude/shared/gate-last-fired.json`, NOT the
     gitignored `.claude/logs/gate-coverage.jsonl`. The raw ledger is absent
     on CI runners, which previously made this observer persist
     distinct_gate_count=0 every week — structurally blind to the very drift
     it exists to catch. The raw ledger remains a fallback for local /
     pre-F17 environments where the index is absent.

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
# v7.9.1 F17 per-gate index. Committed + CI-durable; the primary source for
# the distinct-gate set (see current_distinct_gates). GATE_COV is gitignored
# and absent on CI runners, which previously made this observer blind (R1).
GATE_LAST_FIRED = REPO_ROOT / ".claude" / "shared" / "gate-last-fired.json"
WEEKLY_GATE_LEDGER = REPO_ROOT / ".claude" / "shared" / "gate-coverage-weekly.jsonl"
ADOPT = REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json"
ADOPT_HIST = REPO_ROOT / ".claude" / "shared" / "measurement-adoption-history.json"
# E-3 / OQ-4: UCC auth audit log, synced from the fitme-story Blob store via the
# B7 UCC_AUDIT_BLOB_URL sync. Absent until the sync runs — treated as clean.
UCC_AUTH_LOG = REPO_ROOT / ".claude" / "logs" / "ucc-auth-events.jsonl"

DIMENSION_KEYS = ("timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2")
# Security-relevant lockout events (open a digest issue). auth_lockout_cleared is
# informational (lockout expired) — counted but never sets `detected`.
LOCKOUT_ALARM_EVENTS = ("auth_lockout_triggered", "auth_lockout_blocked_attempt")
AUTH_LOCKOUT_WINDOW_DAYS = 7


def load_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def _gates_from_index(index_path: Path) -> set[str]:
    """Distinct gate names from the committed F17 gate-last-fired index.

    The index is the canonical, version-controlled materialization of every
    gate that has emitted Mechanism A coverage (or appeared in integrity-
    snapshot failure history). Unlike the raw ledger it is tracked, so it is
    present on CI runners — making it the consistent cross-environment source.
    """
    try:
        d = json.loads(index_path.read_text())
    except (OSError, json.JSONDecodeError):
        return set()
    gates = d.get("gates", {})
    return {g for g in gates} if isinstance(gates, dict) else set()


def compute_silent_gate_candidates(index: dict, top_n: int = 3) -> list[dict]:
    """(A5, R19) Rank "silent-gate candidates" from the F17 gate-last-fired
    index: gates that reached >=1 candidate but whose check has NEVER fired
    (``total_firings == 0``, where firings = sum of the ledger's ``checked``
    field). Ordered by candidate volume (loudest-but-silent first), truncated
    to ``top_n``.

    Interpretation is deliberately *informational*, not a regression: a
    zero-firing gate is often healthy — it simply never found a violation (e.g.
    ``STATE_OWNER_MISSING``: many candidates, all compliant). The value is
    pre-promotion calibration attention: if a gate is about to flip
    advisory->enforced but has never once fired, an operator should eyeball
    whether that is healthy-zero or a mis-wire that never reaches its finding
    branch. Reads the *committed* F17 index, so it is CI-available (the raw
    gate-coverage ledger is gitignored / absent on runners).
    """
    gates = index.get("gates", {})
    if not isinstance(gates, dict):
        return []
    out = []
    for name, e in gates.items():
        if not isinstance(e, dict):
            continue
        cands = e.get("total_candidates", 0) or 0
        firings = e.get("total_firings", 0) or 0
        if cands > 0 and firings == 0:
            out.append({
                "gate": name,
                "candidates": cands,
                "skips": e.get("total_skips", 0) or 0,
                "last_checked_at": e.get("last_checked_at"),
            })
    out.sort(key=lambda r: r["candidates"], reverse=True)
    return out[: max(0, top_n)]


def silent_gate_candidates(top_n: int = 3, index_path: Path = GATE_LAST_FIRED) -> list[dict]:
    """Load the committed F17 index and compute the A5 silent-gate list."""
    return compute_silent_gate_candidates(load_json(index_path), top_n)


def _gates_from_ledger(ledger_path: Path) -> set[str]:
    """Distinct gate names from the raw (gitignored) gate-coverage ledger.

    Fallback source for local / pre-F17 environments where the index is
    absent. Empty on CI runners (the ledger is not committed) — which is
    exactly why it cannot be the primary source.
    """
    if not ledger_path.exists():
        return set()
    gates: set[str] = set()
    for line in ledger_path.read_text().splitlines():
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


def current_distinct_gates(
    index_path: Path = GATE_LAST_FIRED,
    ledger_path: Path = GATE_COV,
) -> set[str]:
    """The current distinct-gate set for A2 zero-drift detection.

    Prefers the committed F17 index (CI-durable, consistent across
    environments) and falls back to the raw ledger only when the index is
    absent or lists no gates. Sourcing from the index closes the 2026-06-11
    R1 finding: the gitignored ledger is empty on CI runners, so the weekly
    observer used to persist distinct_gate_count=0 every week and could never
    fire its own "a gate stopped emitting" alert.
    """
    from_index = _gates_from_index(index_path)
    if from_index:
        return from_index
    return _gates_from_ledger(ledger_path)


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


def _parse_ts(raw) -> "dt.datetime | None":
    """Parse an ISO-8601 UTC timestamp (trailing 'Z' tolerated). None on failure."""
    if not isinstance(raw, str) or not raw:
        return None
    try:
        return dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None


def auth_lockout_activity(
    log_path: Path = UCC_AUTH_LOG,
    window_days: int = AUTH_LOCKOUT_WINDOW_DAYS,
    ref_date: str | None = None,
) -> dict:
    """E-3 / OQ-4: count UCC auth-lockout events within the trailing window.

    Reads the synced audit log and tallies lockout events in the last
    `window_days`. `detected` is True when any ALARM event (triggered / blocked)
    falls in the window — that flag drives the workflow's issue-open condition.
    `auth_lockout_cleared` is counted but informational (never sets detected).

    Fail-safe: a missing log (sync hasn't run) or malformed/undated lines yield
    a clean, non-detecting result rather than an error — the digest must never
    crash the Monday cron over an absent optional input.
    """
    now = _parse_ts(ref_date) if ref_date else dt.datetime.now(dt.timezone.utc)
    if now is None:
        now = dt.datetime.now(dt.timezone.utc)
    cutoff = now - dt.timedelta(days=window_days)

    result = {
        "log_present": log_path.exists(),
        "window_days": window_days,
        "triggered": 0,
        "blocked": 0,
        "cleared": 0,
        "detected": False,
    }
    if not result["log_present"]:
        return result

    for line in log_path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = _parse_ts(ev.get("timestamp"))
        if ts is None or ts < cutoff:
            continue
        et = ev.get("event_type")
        if et == "auth_lockout_triggered":
            result["triggered"] += 1
        elif et == "auth_lockout_blocked_attempt":
            result["blocked"] += 1
        elif et == "auth_lockout_cleared":
            result["cleared"] += 1

    result["detected"] = (result["triggered"] + result["blocked"]) > 0
    return result


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

    a5_silent = silent_gate_candidates()

    lockout = auth_lockout_activity()

    append_weekly_row(cur_gates, append=not args.no_append)

    payload = {
        "a2_gate_regression": "true" if a2_regression else "false",
        "a2_gates_current": len(cur_gates),
        "a2_gates_ever_seen": len(prior_gates),
        "a2_gates_missing": ",".join(missing),
        "a4_dim_regression": "true" if a4_regression else "false",
        "a4_dim_deltas": deltas,
        "a5_silent_count": len(a5_silent),
        "a5_silent_gates": ",".join(r["gate"] for r in a5_silent),
        "auth_lockout_detected": "true" if lockout["detected"] else "false",
        "auth_lockout_triggered": lockout["triggered"],
        "auth_lockout_blocked": lockout["blocked"],
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
            "a5": {
                "silent_gate_candidates": a5_silent,
                "note": "informational — zero-firing may be healthy (never violated); verify healthy-zero vs mis-wire before promotion",
            },
            "a6_auth_lockout": lockout,
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
    lines.append("")
    lines.append(f"**A5 — Silent-gate candidates** (top {len(a5_silent)}; informational, not a regression):")
    if a5_silent:
        lines.append("")
        lines.append("Gates with candidates but zero firings — verify healthy-zero vs mis-wire before any promotion:")
        lines.append("")
        lines.append("| Gate | Candidates | Skips | Last checked |")
        lines.append("|---|---|---|---|")
        for r in a5_silent:
            lines.append(f"| `{r['gate']}` | {r['candidates']} | {r['skips']} | {r['last_checked_at'] or '—'} |")
    else:
        lines.append(" none — every gate with candidates has fired at least once.")
    lines.append("")
    lines.append(f"**A6 — UCC auth-lockout activity** (last {lockout['window_days']}d):")
    if not lockout["log_present"]:
        lines.append(" audit log not synced yet (`ucc-auth-events.jsonl` absent) — no lockout data.")
    elif lockout["detected"]:
        lines.append(
            f" ⚠ **{lockout['triggered']} lockout(s) triggered + {lockout['blocked']} blocked "
            f"attempt(s)** in the window (cleared: {lockout['cleared']}). Opens digest issue — "
            f"investigate the fitme-story auth audit log for the operator/IP pattern."
        )
    else:
        lines.append(
            f" ✓ no lockouts (triggered=0, blocked=0, cleared={lockout['cleared']}) — "
            f"auth surface healthy."
        )
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
