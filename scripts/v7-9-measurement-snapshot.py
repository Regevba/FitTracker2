#!/usr/bin/env python3
"""v7.9 measurement-window snapshot — read v7.8 advisory ledgers and produce
the +7d / +14d / +21d decision-input report the spec calls for.

v7.8 ships six advisory mechanisms that accumulate data into three ledgers:

1. `.claude/logs/gate-coverage.jsonl` (Mechanism A) — per-run
   `{candidates, checked, skipped, skip_reasons}` for every write-time gate.
2. `.claude/logs/_session-*.events.jsonl` (Mechanism C) — session-level
   PostToolUse:Read events with active-feature attribution.
3. `.claude/logs/reducer-misses.json` (path-reducers advisory) — per-entry
   false-positive counts.

The v7.9 spec (`docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md`
§7.2) calls three decision points off these ledgers:

  +7d (2026-05-11):  first measurement-window snapshot — what's safe to keep advisory?
  +14d (2026-05-18): flip zero-FP reducers advisory → enforced; calibrate cache_hits N
  +21d (2026-05-25): v7.9 design lock — Mechanism H (CRDT) ship/no-ship call

This script produces a single JSON + Markdown report from whatever data has
accumulated. Run it any time post-v7.8 ship; the report is meaningful from
the first commit forward but only design-actionable at +7d.

Usage:
    scripts/v7-9-measurement-snapshot.py                     # ASCII summary
    scripts/v7-9-measurement-snapshot.py --format=json       # full JSON to stdout
    scripts/v7-9-measurement-snapshot.py --output=report.md  # write Markdown report
    scripts/v7-9-measurement-snapshot.py --window-start=2026-05-04
                                                             # only count entries after a date

Exit 0 always — read-only advisory.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
LOGS_DIR = REPO_ROOT / ".claude" / "logs"

V7_8_SHIP_DATE = "2026-05-04"
DEFAULT_WINDOW_START = V7_8_SHIP_DATE


@dataclass
class GateCoverageRollup:
    gate: str
    runs: int = 0
    total_candidates: int = 0
    total_checked: int = 0
    total_skipped: int = 0
    skip_reason_counts: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    last_seen_at: str = ""

    @property
    def checked_ratio(self) -> float:
        if self.total_candidates == 0:
            return 0.0
        return self.total_checked / self.total_candidates

    @property
    def silent_pass_risk(self) -> str:
        """Categorize the gate's silent-pass risk."""
        if self.runs == 0:
            return "no_runs"
        if self.total_checked == 0:
            return "silent_pass_candidate"
        if self.checked_ratio < 0.05:
            return "low_coverage"
        return "ok"


def _parse_window_start(arg: str | None) -> str:
    if arg is None:
        return DEFAULT_WINDOW_START
    try:
        datetime.strptime(arg, "%Y-%m-%d")
    except ValueError:
        raise SystemExit(f"--window-start must be YYYY-MM-DD, got: {arg!r}")
    return arg


def _gate_coverage_path() -> Path:
    return LOGS_DIR / "gate-coverage.jsonl"


def _session_event_paths() -> list[Path]:
    if not LOGS_DIR.exists():
        return []
    return sorted(LOGS_DIR.glob("_session-*.events.jsonl"))


def _reducer_misses_path() -> Path:
    return LOGS_DIR / "reducer-misses.json"


def load_gate_coverage(window_start: str) -> dict[str, GateCoverageRollup]:
    """Group all gate-coverage entries by gate name with totals."""
    path = _gate_coverage_path()
    rollups: dict[str, GateCoverageRollup] = {}
    if not path.exists():
        return rollups
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = (entry.get("timestamp") or "")[:10]
        if ts < window_start:
            continue
        gate = entry.get("gate") or entry.get("check_code") or "?"
        r = rollups.setdefault(gate, GateCoverageRollup(gate=gate))
        r.runs += 1
        r.total_candidates += int(entry.get("candidates", 0))
        r.total_checked += int(entry.get("checked", 0))
        r.total_skipped += int(entry.get("skipped", 0))
        for reason, count in (entry.get("skip_reasons") or {}).items():
            r.skip_reason_counts[reason] = r.skip_reason_counts.get(reason, 0) + int(count)
        if ts > r.last_seen_at:
            r.last_seen_at = entry.get("timestamp", "")
    return rollups


def load_session_attribution(window_start: str) -> dict:
    """Read PostToolUse:Read session events and roll up cache_hits attribution."""
    total_events = 0
    attributed_events = 0
    unattributed_events = 0
    feature_counts: dict[str, int] = defaultdict(int)
    sessions = 0
    for path in _session_event_paths():
        sessions += 1
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = (e.get("timestamp") or "")[:10]
            if ts < window_start:
                continue
            if e.get("kind") != "tool_read":
                # Mechanism C only emits these; skip other event kinds.
                continue
            total_events += 1
            feat = e.get("active_feature") or ""
            if feat:
                attributed_events += 1
                feature_counts[feat] += 1
            else:
                unattributed_events += 1
    attribution_rate = (
        attributed_events / total_events if total_events > 0 else 0.0
    )
    return {
        "sessions": sessions,
        "total_read_events": total_events,
        "attributed_events": attributed_events,
        "unattributed_events": unattributed_events,
        "attribution_rate": attribution_rate,
        "events_per_feature": dict(feature_counts),
    }


def load_reducer_misses() -> dict:
    """Read .claude/logs/reducer-misses.json — empty when no merge conflicts hit."""
    path = _reducer_misses_path()
    if not path.exists():
        return {"misses": [], "note": "file does not exist — no merge conflicts have hit a reducer yet"}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {"misses": [], "note": "file present but invalid JSON"}


def render_snapshot(window_start: str) -> dict:
    coverage = load_gate_coverage(window_start)
    attribution = load_session_attribution(window_start)
    reducer_misses = load_reducer_misses()
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    days_open = _days_since(window_start)

    silent_pass_candidates = [
        g for g, r in coverage.items() if r.silent_pass_risk == "silent_pass_candidate"
    ]
    promotion_ready = [
        g for g, r in coverage.items()
        if r.silent_pass_risk == "ok" and r.runs >= 5 and r.checked_ratio >= 0.5
    ]

    return {
        "generated_at": now,
        "window_start": window_start,
        "days_open": days_open,
        "v7_8_ship_date": V7_8_SHIP_DATE,
        "gate_coverage_summary": {
            "gates_observed": len(coverage),
            "total_runs": sum(r.runs for r in coverage.values()),
            "silent_pass_candidates": silent_pass_candidates,
            "promotion_ready_gates": promotion_ready,
            "by_gate": {
                g: {
                    "runs": r.runs,
                    "candidates": r.total_candidates,
                    "checked": r.total_checked,
                    "skipped": r.total_skipped,
                    "checked_ratio": round(r.checked_ratio, 3),
                    "silent_pass_risk": r.silent_pass_risk,
                    "skip_reasons": dict(r.skip_reason_counts),
                    "last_seen_at": r.last_seen_at,
                } for g, r in sorted(coverage.items())
            },
        },
        "session_attribution": attribution,
        "reducer_misses": reducer_misses,
        "decision_points": _decision_points(days_open),
    }


def _days_since(start: str) -> int:
    try:
        d0 = datetime.strptime(start, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        return -1
    return (datetime.now(timezone.utc).date() - d0.date()).days


def _decision_points(days_open: int) -> dict:
    """Map current age to spec §7.2 decision phase."""
    if days_open < 7:
        phase = "pre_first_snapshot"
        next_action = f"+{7 - days_open}d until first measurement-window snapshot"
    elif days_open < 14:
        phase = "first_window_open"
        next_action = f"+{14 - days_open}d until promotion decisions (flip reducer modes, calibrate N)"
    elif days_open < 21:
        phase = "second_window_open"
        next_action = f"+{21 - days_open}d until v7.9 design lock"
    elif days_open < 28:
        phase = "design_lock_window"
        next_action = f"+{28 - days_open}d until v7.9 ship"
    else:
        phase = "v7_9_ship_window"
        next_action = "v7.9 ratification window — ship or hold-and-re-measure"
    return {"phase": phase, "next_action": next_action, "days_open": days_open}


def render_markdown(snapshot: dict) -> str:
    out: list[str] = []
    out.append(f"# v7.9 Measurement Snapshot — {snapshot['generated_at']}")
    out.append("")
    out.append(f"**Window opened:** {snapshot['window_start']} (v7.8 ship)")
    out.append(f"**Days open:** {snapshot['days_open']}")
    out.append(f"**Phase:** `{snapshot['decision_points']['phase']}`")
    out.append(f"**Next action:** {snapshot['decision_points']['next_action']}")
    out.append("")
    cov = snapshot["gate_coverage_summary"]
    out.append("## Mechanism A — gate coverage")
    out.append("")
    out.append(
        f"- Gates observed: **{cov['gates_observed']}**"
    )
    out.append(f"- Total runs: **{cov['total_runs']}**")
    if cov["silent_pass_candidates"]:
        out.append(
            f"- ⚠️ **Silent-pass candidates** (checked=0 across all runs): "
            f"{', '.join(cov['silent_pass_candidates'])}"
        )
    else:
        out.append("- ✅ Silent-pass candidates: none")
    if cov["promotion_ready_gates"]:
        out.append(
            f"- ✅ Promotion-ready gates (≥5 runs, ≥50% coverage): "
            f"{', '.join(cov['promotion_ready_gates'])}"
        )
    out.append("")
    out.append("| Gate | Runs | Cand | Checked | Skipped | Ratio | Risk |")
    out.append("|---|---:|---:|---:|---:|---:|---|")
    for g, r in cov["by_gate"].items():
        out.append(
            f"| `{g}` | {r['runs']} | {r['candidates']} | {r['checked']} | "
            f"{r['skipped']} | {r['checked_ratio']:.0%} | `{r['silent_pass_risk']}` |"
        )
    out.append("")
    a = snapshot["session_attribution"]
    out.append("## Mechanism C — session attribution")
    out.append("")
    out.append(f"- Sessions tracked: **{a['sessions']}**")
    out.append(f"- Total Read events: **{a['total_read_events']}**")
    out.append(
        f"- Attribution rate: **{a['attribution_rate']:.1%}** "
        f"(attributed {a['attributed_events']}, unattributed {a['unattributed_events']})"
    )
    out.append("")
    rm = snapshot["reducer_misses"]
    out.append("## Path-reducers — false-positive misses")
    out.append("")
    misses = rm.get("misses", []) if isinstance(rm, dict) else []
    if not misses:
        out.append(f"- ✅ No misses recorded.")
        if rm.get("note"):
            out.append(f"- {rm['note']}")
    else:
        out.append(f"- Total miss entries: **{len(misses)}**")
    out.append("")
    out.append("---")
    out.append("")
    out.append("Generated by `scripts/v7-9-measurement-snapshot.py`.")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--format", choices=["ascii", "json"], default="ascii")
    ap.add_argument("--output", help="write Markdown report to this path")
    ap.add_argument("--window-start", help="YYYY-MM-DD (default: v7.8 ship date)")
    args = ap.parse_args()

    window = _parse_window_start(args.window_start)
    snapshot = render_snapshot(window)

    if args.output:
        Path(args.output).write_text(render_markdown(snapshot))
        print(f"wrote {args.output}", file=sys.stderr)
        return 0

    if args.format == "json":
        json.dump(snapshot, sys.stdout, indent=2, default=str)
        sys.stdout.write("\n")
    else:
        print(render_markdown(snapshot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
