#!/usr/bin/env python3
"""
build-item-registry.py — the cross-layer crosswalk generator (FIT-200).

Reads every `.claude/features/<slug>/state.json` and emits
`.claude/shared/item-registry.json`: the single join table that ties the
canonical key (feature slug) to the tracking key (`linear_id` = FIT-NNN),
the thematic labels (`thematic_codes`, scheme-prefixed), a unified status,
and the merged-PR set.

Also prints an ADVISORY list of features missing `linear_id` (the join
gap). Advisory only — never exits non-zero for a missing join.

FRESHNESS (added 2026-07-23). The registry is a DERIVED index with no
scheduled producer — `make crosswalk` was manual-only, so it silently rotted
to 118 items while the corpus grew to 131 (missing `t4-ios-snapshot-testing`
+ `t9-backend-chaos-tests` entirely). Nothing surfaced the drift, because a
stale derived index looks exactly like a fresh one.

The fix is a `source_fingerprint` — sha256 over the canonicalized derived
items list. It is deliberately NOT a wall-clock `generated_at`: a timestamp
would make every regeneration a diff (churn on an append-only-ish shared
file) while still not proving the CONTENT matches the corpus. A content
fingerprint is idempotent (same corpus → byte-identical file) and answers
the real question — "does this index still describe the features on disk?"

`--check` recomputes from the live corpus and compares against the committed
registry, so the staleness verdict is exact rather than heuristic.

Convention spec: docs/process/cross-layer-item-naming-convention.md

Usage:
  python3 scripts/build-item-registry.py            # write + report
  python3 scripts/build-item-registry.py --check    # freshness verdict, no write
  python3 scripts/build-item-registry.py --check --json   # machine-readable verdict
  python3 scripts/build-item-registry.py --quiet

Exit codes:
  0 — success (and, under --check, the registry is FRESH)
  2 — features dir not found
  3 — --check only: registry is STALE (missing/unreadable/fingerprint mismatch)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
REGISTRY = REPO_ROOT / ".claude" / "shared" / "item-registry.json"
SCHEMA_VERSION = 1

# state.json current_phase -> unified status (see convention §3).
TERMINAL = {"complete"}
PLANNING = {"research", "prd", "tasks", "discovery"}


def unified_status(state: dict) -> str:
    phase = (state.get("current_phase") or "").lower()
    if phase in TERMINAL:
        return "Done"
    # Won't-Do (terminal park / cancelled) — checked BEFORE the Blocked
    # signals because a Won't-Do feature is also `paused: true`, and the
    # terminal decision must win over the resumable-Blocked coarsening.
    # Canonical marker is `wont_do: true`; the Linear mirror status
    # (`linear_status` == Canceled) is accepted as a secondary signal.
    if state.get("wont_do") or (state.get("linear_status") or "").lower() in ("canceled", "cancelled"):
        return "Won't-Do"
    # Blocked signals (paused / external dependency).
    if state.get("paused") or state.get("blocked") or state.get("blocked_on"):
        return "Blocked"
    rn = state.get("resume_notes")
    if isinstance(rn, (list, str)) and rn and "paused" in json.dumps(rn).lower():
        return "Blocked"
    if not phase:
        return "Backlog"
    if phase in PLANNING:
        return "Planned"
    return "In Progress"


def collect_prs(state: dict) -> list[int]:
    prs: set[int] = set()
    for n in state.get("related_prs") or []:
        if isinstance(n, int):
            prs.add(n)
        elif isinstance(n, str) and n.isdigit():
            prs.add(int(n))
    phases = state.get("phases")
    if isinstance(phases, dict):
        merge = phases.get("merge")
        if isinstance(merge, dict) and isinstance(merge.get("pr_number"), int):
            prs.add(merge["pr_number"])
    for t in state.get("tasks") or []:
        if isinstance(t, dict) and isinstance(t.get("pr_number"), int):
            prs.add(t["pr_number"])
    return sorted(prs)


def fingerprint(items: list[dict]) -> str:
    """Content fingerprint of the derived item set.

    Hashes the canonicalized items list — not raw state.json bytes — so that
    state.json edits which do not change any join-relevant field produce no
    registry churn, while any change that DOES affect the crosswalk (a new
    feature, a phase advance, a linear_id backfill, a merged PR) changes the
    fingerprint. Deterministic: no clock, no path, no iteration-order input.
    """
    return hashlib.sha256(
        json.dumps(items, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def freshness() -> dict:
    """Compare the committed registry against a freshly derived one.

    Returns {stale, reason, registry_items, live_items, fingerprint_match}.
    A missing or unreadable registry is stale (there is nothing to trust).
    """
    live = build()
    live_items = live["coverage"]["total"]
    live_fp = live["source_fingerprint"]

    if not REGISTRY.exists():
        return {"stale": True, "reason": "registry_missing", "registry_items": None,
                "live_items": live_items, "fingerprint_match": False}
    try:
        on_disk = json.loads(REGISTRY.read_text())
    except (OSError, json.JSONDecodeError):
        return {"stale": True, "reason": "registry_unreadable", "registry_items": None,
                "live_items": live_items, "fingerprint_match": False}

    disk_fp = on_disk.get("source_fingerprint")
    disk_items = (on_disk.get("coverage") or {}).get("total")
    if disk_fp is None:
        # Pre-fingerprint registry — cannot prove freshness, so treat as stale
        # (this is the exact state that let the 118-vs-131 drift hide).
        return {"stale": True, "reason": "no_fingerprint_pre_2026_07_23_format",
                "registry_items": disk_items, "live_items": live_items,
                "fingerprint_match": False}

    match = disk_fp == live_fp
    return {
        "stale": not match,
        "reason": "fresh" if match else "fingerprint_mismatch",
        "registry_items": disk_items,
        "live_items": live_items,
        "fingerprint_match": match,
    }


def build() -> dict:
    items = []
    for sj in sorted(FEATURES_DIR.glob("*/state.json")):
        slug = sj.parent.name
        try:
            state = json.loads(sj.read_text())
        except (OSError, json.JSONDecodeError):
            items.append({"slug": slug, "error": "unreadable state.json"})
            continue
        items.append({
            "slug": slug,
            "linear_id": state.get("linear_id"),
            "thematic_codes": state.get("thematic_codes") or [],
            "status": unified_status(state),
            "current_phase": state.get("current_phase"),
            "work_type": state.get("work_type"),
            "case_study": state.get("case_study") or state.get("case_study_showcase"),
            "prs": collect_prs(state),
        })
    total = len(items)
    with_id = sum(1 for it in items if it.get("linear_id"))
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_note": "derived from .claude/features/*/state.json — do not hand-edit; run `make crosswalk`",
        "source_fingerprint": fingerprint(items),
        "items": items,
        "coverage": {
            "total": total,
            "with_linear_id": with_id,
            "missing_linear_id": total - with_id,
            "with_thematic_codes": sum(1 for it in items if it.get("thematic_codes")),
        },
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="freshness verdict only; do not write registry (exit 3 if stale)")
    ap.add_argument("--json", action="store_true",
                    help="with --check: emit the verdict as one JSON line")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not FEATURES_DIR.is_dir():
        print(f"build-item-registry: features dir not found: {FEATURES_DIR}", file=sys.stderr)
        return 2

    if args.check:
        verdict = freshness()
        if args.json:
            print(json.dumps(verdict, sort_keys=True))
        elif not args.quiet:
            if verdict["stale"]:
                print(f"item-registry: ⚠ STALE ({verdict['reason']}) — "
                      f"registry has {verdict['registry_items']} item(s), "
                      f"corpus has {verdict['live_items']}. Run `make crosswalk`.")
            else:
                print(f"item-registry: FRESH — {verdict['live_items']} items, fingerprint matches.")
        return 3 if verdict["stale"] else 0

    reg = build()
    REGISTRY.write_text(json.dumps(reg, indent=2) + "\n")

    cov = reg["coverage"]
    if not args.quiet:
        print(f"item-registry: {cov['total']} features → {REGISTRY.relative_to(REPO_ROOT)}")
        print(f"  linear_id join: {cov['with_linear_id']}/{cov['total']} "
              f"({cov['missing_linear_id']} missing) · "
              f"thematic_codes: {cov['with_thematic_codes']}/{cov['total']}")
        missing = [it["slug"] for it in reg["items"] if not it.get("linear_id")]
        if missing:
            print(f"\n  ⚠ ADVISORY — {len(missing)} feature(s) missing linear_id join "
                  f"(add `linear_id` to state.json):")
            for slug in missing[:40]:
                print(f"      - {slug}")
            if len(missing) > 40:
                print(f"      … and {len(missing) - 40} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
