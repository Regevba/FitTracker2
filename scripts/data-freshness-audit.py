#!/usr/bin/env python3
"""N6 — Quarterly Data Freshness Audit (infra-master-plan §3.5.3).

The meta-check that would have caught the `cache_hits` keying drift the moment
it landed instead of weeks later via a test failure. Runs every 90 days
(first run 2026-08-12; recurring 2026-11-12, 2027-02-12, 2027-05-12) and
asserts four freshness invariants across the gate-telemetry stack:

  A1  Emission-key ↔ canonical-name parity — every gate emitting Mechanism A
      coverage (F17 `gate-last-fired.json`) maps to a canonical gate in
      `gate-catalog.json`; no orphan emission keys (the rename-drift class).
  A2  Recent candidacy — every emitting gate has been a candidate in
      `gate-coverage.jsonl` within the freshness window (default 30d), using
      the F17 index for O(1) lookup. Event-gated gates (only checked when
      specific files are staged) are ADVISORY, not FAIL.
  A3  Fire freshness vs introduction — a gate that has NEVER fired despite
      being well past its introduction date is a silent-pass suspect —
      UNLESS it is a healthy-zero gate (has candidates, 0 violations) or a
      0-candidate mis-wire (which GATE_COVERAGE_ZERO owns).
  A4  Test-reference currency — each catalog gate's `test_files` exist on disk
      and the gate name is referenced in at least one of them (no `KeyError`
      on a renamed gate).

Read-only. Exit 0 by default (advisory tooling, matching cross-layer-freshness).
`--strict` exits 1 on any FAIL finding so a future CI/cron can gate on it.

Usage:
    python3 scripts/data-freshness-audit.py                 # text, advisory
    python3 scripts/data-freshness-audit.py --format json
    python3 scripts/data-freshness-audit.py --strict        # exit 1 on FAIL
    make data-freshness-audit

Pattern reference: AWS Config Rules conformance-pack drift evaluation — assert
that the control plane's own metadata is internally consistent on a cadence.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
from pathlib import Path

_DEFAULT_ROOT = Path(__file__).resolve().parent.parent


def _resolve_root(repo_root=None) -> Path:
    """Resolve the repo root, honoring an explicit arg > REPO_ROOT_OVERRIDE env >
    the script's own location. Read at call time so tests + the F16 try-repo
    harness can redirect the audit without reimporting the module."""
    return Path(repo_root or os.environ.get("REPO_ROOT_OVERRIDE") or _DEFAULT_ROOT)

DEFAULT_WINDOW_DAYS = 30

# Gates that legitimately emit NO Mechanism A coverage — excluded from A1/A2.
# CASE_STUDY_MISSING_FIELDS is hosted in check-case-study-preflight.py and emits
# no coverage row (documented in FRAMEWORK-FACTS.md "Live (34) vs instrumented").
NO_COVERAGE_EXEMPT = {"CASE_STUDY_MISSING_FIELDS"}

# Event-gated gates: only reach a candidate when specific files are staged
# (schema/sync/analytics/plist/figma changes) or on a concurrency event. A stale
# `last_checked_at` for these is expected, not a silent-pass — so A2/A3 downgrade
# them to ADVISORY. Kept small + explicit; unknown stale gates still FAIL loudly.
EVENT_GATED = {
    "SCHEMA_DIFF",            # backend/supabase/migrations/*.sql or SupabaseSyncService
    "CSV_TAXONOMY_DRIFT",     # AnalyticsProvider.swift staged
    "GA4_MCP_DISCONNECTED",   # analytics-affecting code staged
    "FIGMA_MIRROR_STALENESS", # tokens.json vs figma snapshot (own target)
    "w9.concurrency",         # PostToolUse drift — concurrency offer event
    "w9.auto_isolate",        # PostToolUse drift — branch-flip event
    "BRANCH_ISOLATION_LAUNCHD_DRIFT",  # macOS-only cycle advisory
}

SEV_FAIL = "FAIL"
SEV_ADVISORY = "ADVISORY"


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def _parse_ts(ts):
    """Parse an ISO-8601 timestamp (tolerating 'Z' and +00:00) → aware UTC dt, or None."""
    if not ts or not isinstance(ts, str):
        return None
    s = ts.strip().replace("Z", "+00:00")
    try:
        dt = _dt.datetime.fromisoformat(s)
    except ValueError:
        # tolerate fractional-second + offset combos fromisoformat may reject on older pythons
        m = re.match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", s)
        if not m:
            return None
        dt = _dt.datetime.fromisoformat(m.group(1))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=_dt.timezone.utc)
    return dt.astimezone(_dt.timezone.utc)


def _finding(code, severity, gate, detail):
    return {"code": code, "severity": severity, "gate": gate, "detail": detail}


def audit(now: _dt.datetime, window_days: int = DEFAULT_WINDOW_DAYS,
          repo_root=None, event_gated=EVENT_GATED, no_coverage_exempt=NO_COVERAGE_EXEMPT) -> dict:
    """Run all four assertions. Returns a structured result dict.

    `repo_root` is resolved at call time (arg > REPO_ROOT_OVERRIDE env > script
    location) so tests can point the audit at a synthetic tree with
    deliberately-drifted telemetry. `event_gated` / `no_coverage_exempt` are
    injectable so tests exercise those code paths with SYNTHETIC gate names —
    keeping real gate-name strings out of the test file (which gate-catalog.py
    scans for test↔gate association).
    """
    findings: list[dict] = []
    repo_root = _resolve_root(repo_root)

    catalog_raw = _load_json(repo_root / ".claude" / "shared" / "gate-catalog.json")
    catalog = catalog_raw.get("gates", catalog_raw)
    f17 = _load_json(repo_root / ".claude" / "shared" / "gate-last-fired.json").get("gates", {})

    catalog_names = set(catalog.keys())
    f17_names = set(f17.keys())

    # ---- A1: emission-key ↔ canonical-name parity -----------------------------
    orphan_keys = sorted(f17_names - catalog_names)
    for k in orphan_keys:
        findings.append(_finding(
            "A1_ORPHAN_EMISSION_KEY", SEV_FAIL, k,
            f"'{k}' emits Mechanism A coverage but is absent from gate-catalog.json — "
            f"likely a renamed/removed gate whose emission site was not updated (the "
            f"cache_hits keying drift class)."))
    # Catalog gates with no coverage that are NOT in the known no-coverage allowlist
    # are reported by A2/A3 (they may be event-gated or genuinely never-fired), so
    # A1 only owns the orphan direction (emission key with no canonical home).

    # ---- A2: recent candidacy within the freshness window ---------------------
    cutoff = now - _dt.timedelta(days=window_days)
    for name, g in sorted(f17.items()):
        if name in no_coverage_exempt:
            continue
        last_checked = _parse_ts(g.get("last_checked_at"))
        if last_checked is None:
            # in the index but never a candidate — 0-candidate mis-wire territory (A3 owns it)
            continue
        if last_checked < cutoff:
            age = (now - last_checked).days
            sev = SEV_ADVISORY if name in event_gated else SEV_FAIL
            note = " (event-gated — expected to lag; verify its trigger path is intact)" if sev == SEV_ADVISORY else ""
            findings.append(_finding(
                "A2_STALE_CANDIDACY", sev, name,
                f"last candidate {age}d ago ({g.get('last_checked_at')}) > {window_days}d window{note}."))

    # ---- A3: fire freshness vs introduction -----------------------------------
    for name, g in sorted(f17.items()):
        if name in no_coverage_exempt:
            continue
        last_fired = _parse_ts(g.get("last_fired_at"))
        first_seen = _parse_ts(g.get("first_seen_at"))
        total_candidates = g.get("total_candidates", 0) or 0
        total_firings = g.get("total_firings", 0) or 0
        if last_fired is not None:
            continue  # has fired — fresh enough for A3's purpose
        # never fired. Classify:
        if total_candidates == 0:
            # runs but never reaches a candidate — the 0-candidate mis-wire class.
            # GATE_COVERAGE_ZERO is the live meta-check that owns this; N6 mirrors it
            # as an ADVISORY cross-check so the quarterly audit is self-contained.
            findings.append(_finding(
                "A3_ZERO_CANDIDATE", SEV_ADVISORY, name,
                "0 candidates ever — check site runs but never reaches a candidate "
                "(mis-wire suspect; GATE_COVERAGE_ZERO owns enforcement)."))
        elif total_candidates > 0 and total_firings == 0:
            # healthy-zero: has candidates, simply never found a violation. NOT a suspect.
            continue
        else:
            sev = SEV_ADVISORY if name in event_gated else SEV_FAIL
            age = (now - first_seen).days if first_seen else "?"
            findings.append(_finding(
                "A3_NEVER_FIRED", sev, name,
                f"introduced ~{age}d ago (first_seen {g.get('first_seen_at')}), "
                f"{total_candidates} candidates, but last_fired_at is null — silent-pass suspect."))

    # ---- A4: test-reference currency ------------------------------------------
    for name, g in sorted(catalog.items()):
        test_files = g.get("test_files") or []
        if not test_files:
            findings.append(_finding(
                "A4_NO_TEST_FILES", SEV_ADVISORY, name,
                "gate-catalog lists no test_files (T1 GATE_TEST_MISSING precursor)."))
            continue
        referenced_anywhere = False
        for tf in test_files:
            rel = tf.get("file") if isinstance(tf, dict) else tf
            if not rel:
                continue
            path = repo_root / rel
            if not path.exists():
                findings.append(_finding(
                    "A4_MISSING_TEST_FILE", SEV_FAIL, name,
                    f"gate-catalog references test file '{rel}' which does not exist on disk."))
                continue
            try:
                if name in path.read_text():
                    referenced_anywhere = True
            except OSError:
                pass
        if not referenced_anywhere:
            findings.append(_finding(
                "A4_TEST_NAME_DRIFT", SEV_FAIL, name,
                f"none of the {len(test_files)} catalog test_files reference the string "
                f"'{name}' — a rename would KeyError here without a test catching it."))

    fails = [f for f in findings if f["severity"] == SEV_FAIL]
    advisories = [f for f in findings if f["severity"] == SEV_ADVISORY]
    return {
        "audit": "data-freshness-audit",
        "spec": "infra-master-plan-2026-05-12.md §3.5.3",
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "window_days": window_days,
        "gates_in_catalog": len(catalog_names),
        "gates_emitting_coverage": len(f17_names),
        "findings": findings,
        "summary": {"fail": len(fails), "advisory": len(advisories), "total": len(findings)},
    }


def _render_text(result: dict) -> str:
    s = result["summary"]
    lines = [
        f"=== Data Freshness Audit (N6, §3.5.3) — {result['generated_at']} ===",
        f"  catalog gates: {result['gates_in_catalog']} · emitting coverage: {result['gates_emitting_coverage']} · window: {result['window_days']}d",
        f"  findings: {s['fail']} FAIL + {s['advisory']} advisory",
        "",
    ]
    if not result["findings"]:
        lines.append("  ✓ all four freshness invariants (A1–A4) hold — no drift.")
    else:
        for f in result["findings"]:
            mark = "✗" if f["severity"] == SEV_FAIL else "·"
            lines.append(f"  {mark} [{f['code']}] {f['gate']}: {f['detail']}")
    return "\n".join(lines)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="N6 Quarterly Data Freshness Audit (§3.5.3)")
    ap.add_argument("--format", choices=["text", "json"], default="text")
    ap.add_argument("--strict", action="store_true", help="exit 1 on any FAIL finding")
    ap.add_argument("--window-days", type=int, default=DEFAULT_WINDOW_DAYS)
    ap.add_argument("--now", help="override 'now' as ISO-8601 (for tests/reproducibility)")
    args = ap.parse_args(argv)

    now = _parse_ts(args.now) if args.now else _dt.datetime.now(_dt.timezone.utc)
    if now is None:
        print(f"error: could not parse --now '{args.now}'", file=sys.stderr)
        return 2

    result = audit(now, window_days=args.window_days)
    if args.format == "json":
        print(json.dumps(result, indent=2))
    else:
        print(_render_text(result))

    if args.strict and result["summary"]["fail"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
