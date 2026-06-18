#!/usr/bin/env python3
"""figma-mirror-staleness — advisory drift check between code tokens and the Figma mirror.

Gap D mechanical complement (feature `figma-design-architecture`, 2026-06-18).

Premise: code is canonical; the Figma design-system library is a manually-
maintained mirror (Code Connect publish is disabled on the Figma Pro plan).
Without a mechanical backstop the mirror silently drifts from code — the
FT2-FH-005 failure mode. This check compares the CODE token inventory
(`design-tokens/tokens.json`) against the LAST-AUDITED mirror snapshot
(`.claude/shared/figma-mirror-snapshot.json`) and surfaces:

  * tokens added in code but absent from the snapshot  → mirror likely missing them
  * tokens removed in code but still in the snapshot    → mirror likely stale
  * snapshot older than the staleness horizon (default 90 days) → re-verify

ADVISORY ONLY — never blocks a commit. Emits a Mechanism A coverage row
(gate FIGMA_MIRROR_STALENESS) to .claude/logs/gate-coverage.jsonl so the
F17 last-fired index + GATE_COVERAGE_ZERO meta-check can see it. Exit 0
always (advisory). Fail-soft: any unexpected error prints a warning and
exits 0.

Usage:
    python3 scripts/figma-mirror-staleness.py            # report
    python3 scripts/figma-mirror-staleness.py --update-snapshot  # rewrite snapshot from current code keys (after a live re-verify)
    python3 scripts/figma-mirror-staleness.py --horizon-days 60
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOKENS = REPO_ROOT / "design-tokens" / "tokens.json"
SNAPSHOT = REPO_ROOT / ".claude" / "shared" / "figma-mirror-snapshot.json"
COVERAGE_LEDGER = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
GATE = "FIGMA_MIRROR_STALENESS"
DEFAULT_HORIZON_DAYS = 90

# tokens.json category -> Figma code-mirror variable name prefix.
# Only the categories that live in the "code mirror" variable collection
# (985:2 iOS) are compared; typography/shadow/motion are text/effect styles
# + the Motion collection, not part of the code-mirror variable set.
_SCALAR_PREFIX = {
    "spacing": "spacing",
    "borderRadius": "radius",
    "opacity": "opacity",
    "size": "size",
    "layout": "layout",
}


def code_token_keys() -> set[str]:
    """Flatten tokens.json into the slash-named keys the Figma mirror uses."""
    data = json.loads(TOKENS.read_text())
    keys: set[str] = set()
    color = data.get("color", {})
    for group, members in color.items():
        if not isinstance(members, dict):
            continue
        for key in members:
            keys.add(f"{group}/{key}")
    for cat, prefix in _SCALAR_PREFIX.items():
        members = data.get(cat, {})
        if isinstance(members, dict):
            for key in members:
                keys.add(f"{prefix}/{key}")
    return keys


def load_snapshot() -> dict:
    if not SNAPSHOT.exists():
        return {}
    try:
        return json.loads(SNAPSHOT.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def emit_coverage(checked: bool, skip_reason: str | None) -> None:
    """Emit one Mechanism A coverage row for this gate."""
    try:
        from gate_coverage import GateCoverage  # local import; scripts/ on path
    except Exception:
        sys.path.insert(0, str(REPO_ROOT / "scripts"))
        try:
            from gate_coverage import GateCoverage
        except Exception:
            return  # fail-soft: coverage emission is best-effort
    cov = GateCoverage(mode="cycle")
    cov.candidate(GATE)
    if checked:
        cov.checked(GATE)
    else:
        cov.skip(GATE, skip_reason or "no_snapshot")
    cov.write_jsonl(COVERAGE_LEDGER)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--horizon-days", type=int, default=DEFAULT_HORIZON_DAYS)
    ap.add_argument("--update-snapshot", action="store_true",
                    help="Rewrite the snapshot's token_keys from current code (use after a live mirror re-verify).")
    ap.add_argument("--today", default=None, help="Override today's date (YYYY-MM-DD) for testing.")
    args = ap.parse_args()

    try:
        code_keys = code_token_keys()
    except (json.JSONDecodeError, OSError) as e:
        print(f"⚠ figma-mirror-staleness: could not read tokens.json ({e}) — skipping", file=sys.stderr)
        return 0

    snap = load_snapshot()

    if args.update_snapshot:
        snap.setdefault("ios", {})
        snap["ios"]["token_keys"] = sorted(code_keys)
        snap["audited_at"] = (args.today or date.today().isoformat())
        snap["updated_by"] = "figma-mirror-staleness --update-snapshot"
        SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
        SNAPSHOT.write_text(json.dumps(snap, indent=2) + "\n")
        print(f"✓ snapshot refreshed: {len(code_keys)} iOS code-mirror token keys @ {snap['audited_at']}")
        emit_coverage(checked=True, skip_reason=None)
        return 0

    if not snap or "ios" not in snap or "token_keys" not in snap.get("ios", {}):
        print("⚠ FIGMA_MIRROR_STALENESS (advisory): no mirror snapshot found — run "
              "`python3 scripts/figma-mirror-staleness.py --update-snapshot` after a live mirror verify.")
        emit_coverage(checked=False, skip_reason="no_snapshot")
        return 0

    snap_keys = set(snap["ios"]["token_keys"])
    added_in_code = sorted(code_keys - snap_keys)      # mirror likely missing these
    removed_in_code = sorted(snap_keys - code_keys)    # mirror likely stale

    # Staleness horizon
    today = date.fromisoformat(args.today) if args.today else date.today()
    stale = False
    audited = snap.get("audited_at")
    if audited:
        try:
            age = (today - date.fromisoformat(audited)).days
            stale = age > args.horizon_days
        except ValueError:
            age = None
    else:
        age = None

    findings = []
    if added_in_code:
        findings.append(f"{len(added_in_code)} token(s) in code but NOT in mirror snapshot (mirror likely missing): {added_in_code}")
    if removed_in_code:
        findings.append(f"{len(removed_in_code)} token(s) in mirror snapshot but NOT in code (mirror likely stale): {removed_in_code}")
    if stale:
        findings.append(f"mirror snapshot is {age} days old (> {args.horizon_days}d horizon) — re-verify node IDs live")

    emit_coverage(checked=True, skip_reason=None)

    if findings:
        print(f"⚠ FIGMA_MIRROR_STALENESS (advisory) — {len(findings)} finding(s):")
        for f in findings:
            print(f"  • {f}")
        print("  → propagate per docs/design-system/figma-mirror-maintenance-protocol.md, then --update-snapshot")
    else:
        n = len(code_keys)
        print(f"✓ FIGMA_MIRROR_STALENESS: code ({n} tokens) matches mirror snapshot @ {audited}; no drift.")
    return 0  # advisory: never non-zero


if __name__ == "__main__":
    raise SystemExit(main())
