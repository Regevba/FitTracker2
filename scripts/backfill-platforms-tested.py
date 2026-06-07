#!/usr/bin/env python3
"""backfill-platforms-tested — populate `platforms_tested` on complete features.

T14 (t14-platform-parity-state-field) Q1 backfill. For every feature whose
state.json is current_phase=complete and lacks `platforms_tested`, derive the
field from state-level text signals (offline; no network), tag it with a
`platforms_tested_provenance` marker, and insert both keys.

Provenance values:
  - exempt:framework_meta            — work_type=chore / work_subtype=framework_feature
  - backfill-heuristic-<date>        — ≥1 platform inferred from signals
  - backfill-heuristic-low-confidence — platform-bearing feature, no signal found
                                        (operator may spot-check ONLY these)

Insertion is textual (2 lines after the `current_phase` line) to keep diffs
minimal + reviewable; the result is re-parsed to guarantee valid JSON. Idempotent:
features that already have `platforms_tested` are skipped.

Usage:
  scripts/backfill-platforms-tested.py            # dry-run report
  scripts/backfill-platforms-tested.py --apply     # write the files
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
BACKFILL_DATE = "2026-06-07"

PLATFORM_KEYWORDS = {
    "ios": ["ios", "swift", "swiftui", "fittracker/", "xcode", "healthkit",
            "xctest", "appcomponents", "settingsview", "designtokens.swift"],
    "web": ["fitme-story", "website", "dashboard", "control-room", "control room",
            "next.js", "nextjs", "astro", "react", ".tsx", "glossary",
            "showcase", "vercel"],
    "backend": ["supabase", "railway", "cloudkit", "syncservice", "sync service",
                "edge function", "upstash", "redis", "webauthn", "passkey"],
    "ai": ["ai-engine", "aiorchestrator", "ai engine", "cohort", "fastapi",
           "recommendation", "readinessengine", "readiness engine"],
}


def _signal_text(state: dict) -> str:
    parts = [
        state.get("feature_name"),
        state.get("scope_summary"),
        state.get("case_study"),
        state.get("case_study_showcase"),
        state.get("primary_metric"),
        " ".join(t.get("description", "") if isinstance(t, dict) else str(t)
                 for t in (state.get("tasks") or [])),
    ]
    return " ".join(str(p) for p in parts if p).lower()


def derive_platforms_tested(state: dict) -> tuple[dict, str]:
    """Return (platforms_tested, provenance) for one feature state.

    Pure function (no I/O) — the unit-tested core of the backfill.
    """
    # Q2 exemption: framework-meta work ships no product-platform code.
    if str(state.get("work_type", "")).lower() == "chore" or \
            state.get("work_subtype") == "framework_feature":
        return {}, "exempt:framework_meta"

    text = _signal_text(state)
    pt = {p: any(kw in text for kw in kws) for p, kws in PLATFORM_KEYWORDS.items()}
    # has_ui implies the iOS app surface was exercised.
    if state.get("has_ui") is True:
        pt["ios"] = True

    if not any(pt.values()):
        # Platform-bearing feature with no inferable signal → flag for spot-check.
        return pt, "backfill-heuristic-low-confidence"
    return pt, f"backfill-heuristic-{BACKFILL_DATE}"


_CURRENT_PHASE_LINE = re.compile(r'^(\s*)"current_phase"\s*:\s*".*?",\s*$', re.M)


def _insert_keys(text: str, pt: dict, provenance: str) -> str | None:
    """Insert the 2 keys after the current_phase line. Returns new text, or
    None if the anchor isn't found."""
    m = _CURRENT_PHASE_LINE.search(text)
    if not m:
        return None
    indent = m.group(1)
    pt_json = json.dumps(pt)
    block = (f'\n{indent}"platforms_tested": {pt_json},'
             f'\n{indent}"platforms_tested_provenance": "{provenance}",')
    return text[:m.end()] + block + text[m.end():]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true", help="Write the files (default: dry-run)")
    args = ap.parse_args()

    changed, skipped_present, exempt, low_conf, errors = [], 0, 0, 0, []
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        try:
            text = state_path.read_text()
            state = json.loads(text)
        except (OSError, json.JSONDecodeError) as e:
            errors.append(f"{state_path.parent.name}: {e}")
            continue
        if state.get("current_phase") != "complete":
            continue
        if "platforms_tested" in state:
            skipped_present += 1
            continue

        pt, prov = derive_platforms_tested(state)
        new_text = _insert_keys(text, pt, prov)
        if new_text is None:
            errors.append(f"{state_path.parent.name}: no current_phase anchor")
            continue
        try:
            json.loads(new_text)  # guarantee validity before writing
        except json.JSONDecodeError as e:
            errors.append(f"{state_path.parent.name}: would produce invalid JSON: {e}")
            continue

        slug = state_path.parent.name
        if prov.startswith("exempt:"):
            exempt += 1
        elif prov.endswith("low-confidence"):
            low_conf += 1
        changed.append((slug, pt, prov))
        if args.apply:
            state_path.write_text(new_text)

    mode = "APPLIED" if args.apply else "DRY-RUN"
    print(f"[{mode}] {len(changed)} features to backfill "
          f"({exempt} exempt:framework_meta, {low_conf} low-confidence, "
          f"{len(changed) - exempt - low_conf} inferred) · "
          f"{skipped_present} already have the field.")
    if low_conf:
        print("\nLow-confidence (optional operator spot-check):")
        for slug, pt, prov in changed:
            if prov.endswith("low-confidence"):
                print(f"  - {slug}")
    if errors:
        print(f"\n{len(errors)} error(s):")
        for e in errors:
            print(f"  ! {e}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
