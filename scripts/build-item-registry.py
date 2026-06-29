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

Convention spec: docs/process/cross-layer-item-naming-convention.md

Usage:
  python3 scripts/build-item-registry.py            # write + report
  python3 scripts/build-item-registry.py --check    # report only, no write
  python3 scripts/build-item-registry.py --quiet

Exit codes:
  0 — success
  2 — features dir not found
"""
from __future__ import annotations

import argparse
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
    ap.add_argument("--check", action="store_true", help="report only; do not write registry")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not FEATURES_DIR.is_dir():
        print(f"build-item-registry: features dir not found: {FEATURES_DIR}", file=sys.stderr)
        return 2

    reg = build()
    if not args.check:
        REGISTRY.write_text(json.dumps(reg, indent=2) + "\n")

    cov = reg["coverage"]
    if not args.quiet:
        where = "(check-only, not written)" if args.check else f"→ {REGISTRY.relative_to(REPO_ROOT)}"
        print(f"item-registry: {cov['total']} features {where}")
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
