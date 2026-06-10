#!/usr/bin/env python3
"""
Multi-anchor normalized adoption comparison.

``make integrity-diff`` compares the live platform against ONE frozen anchor and
reports raw percentage deltas. That view is misleading whenever the feature
corpus grew between captures: a new feature with empty adoption metrics enters
the denominator and drags every percentage down even though nothing regressed on
the features that existed before. This is "denominator dilution" (CLAUDE.md
soak-window discipline) and it produces phantom regression alerts.

This tool normalizes across SEVERAL anchors at different points in time and
separates real movement from dilution by reporting three views per dimension:

  1. RAW %        — adoption over the full corpus at each anchor (what
                    integrity-diff shows; diluted by corpus growth)
  2. COHORT %     — adoption restricted to the set of features present in BOTH
                    the anchor and the latest snapshot (apples-to-apples; a drop
                    here is a REAL regression, immune to dilution)
  3. NUMERATOR    — absolute count of adopted features (a count that only ever
                    goes up across anchors cannot be a regression, regardless of %)

It also attributes dilution explicitly: for each older anchor it lists how many
features are NEW in the latest snapshot and how many of those carry each metric,
so "the % fell because we added N empty-metric features" is a quantified,
visible fact rather than a silent alert.

Anchors are discovered from a built-in registry (the off-SSD baseline backups)
plus the live platform. Each anchor must expose a ``measurement-adoption.json``
with a per-feature ``features[]`` list; anchors without one are skipped with a note.

Usage:
    scripts/integrity-multi-anchor.py                     # table to stdout
    scripts/integrity-multi-anchor.py --json PATH         # also write JSON
    scripts/integrity-multi-anchor.py --anchor LABEL=PATH # add an ad-hoc anchor

Exit codes:
    0  ran (regression or not)
    2  a COHORT-normalized regression was detected AND --exit-on-regression set
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
BACKUPS = HOME / "Documents" / "FitTracker2-backups"
DIMENSIONS = ["timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2"]

# Built-in anchor registry: (label, candidate paths to measurement-adoption.json).
# First existing candidate wins. Order = chronological.
ANCHOR_REGISTRY = [
    ("2026-05-12-pre-v7.9", [
        BACKUPS / "2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline" / "measurement-adoption.json",
    ]),
    ("2026-05-14-platform", [
        BACKUPS / "2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14" / "platform-baseline" / "measurement-adoption.json",
    ]),
    ("2026-06-10-telemetry-backfill", [
        BACKUPS / "2026-06-10-telemetry-backfill-anchor" / "platform-baseline" / "measurement-adoption.json",
    ]),
]
LIVE = ("live", [REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json"])


def load_anchor(label: str, candidates: list[Path]):
    """Return (label, {feature_name: adoption_dict}, created_map) or None."""
    for c in candidates:
        if c.is_file():
            try:
                d = json.loads(c.read_text())
            except json.JSONDecodeError:
                continue
            feats = d.get("features")
            if not isinstance(feats, list):
                continue
            adoption = {}
            for f in feats:
                name = f.get("feature")
                if name:
                    adoption[name] = f.get("adoption", {})
            return label, adoption, str(c).replace(str(HOME), "~")
    return None


def pct(num: int, den: int) -> float:
    return round(100.0 * num / den, 1) if den else 0.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="write the structured report to this path")
    ap.add_argument("--anchor", action="append", default=[],
                    help="ad-hoc anchor LABEL=PATH (repeatable)")
    ap.add_argument("--exit-on-regression", action="store_true",
                    help="exit 2 if any COHORT-normalized dimension regressed")
    args = ap.parse_args()

    registry = list(ANCHOR_REGISTRY)
    for spec in args.anchor:
        if "=" in spec:
            lbl, pth = spec.split("=", 1)
            registry.append((lbl, [Path(pth).expanduser()]))
    registry.append(LIVE)

    loaded, skipped = [], []
    for label, cands in registry:
        r = load_anchor(label, cands)
        (loaded.append if r else skipped.append)(r if r else label)

    if len(loaded) < 2:
        print("need >=2 loadable anchors; found", len(loaded))
        return 0

    latest_label, latest_adopt, latest_src = loaded[-1]
    latest_names = set(latest_adopt)

    print("=== Multi-anchor normalized adoption comparison ===")
    print(f"latest = {latest_label} ({len(latest_names)} features) [{latest_src}]")
    if skipped:
        print(f"skipped (no per-feature measurement-adoption.json): {', '.join(skipped)}")
    print()

    report = {"latest": latest_label, "anchors": [], "regressions": []}

    for label, adopt, src in loaded[:-1]:
        anchor_names = set(adopt)
        cohort = anchor_names & latest_names
        new_in_latest = latest_names - anchor_names
        print(f"── anchor {label}  ({len(anchor_names)} feats; cohort∩latest={len(cohort)}; "
              f"new-in-latest={len(new_in_latest)}) ──")
        header = f"  {'dimension':22s} {'RAW@anchor':>11s} {'RAW@latest':>11s} | {'COHORT@anc':>11s} {'COHORT@now':>11s} {'Δcohort':>8s} | {'NUM@anc':>8s} {'NUM@now':>8s}"
        print(header)
        anchor_rec = {"label": label, "n_anchor": len(anchor_names),
                      "cohort_size": len(cohort), "new_in_latest": len(new_in_latest),
                      "dimensions": {}}
        for dim in DIMENSIONS:
            raw_anc = pct(sum(1 for a in adopt.values() if a.get(dim)), len(anchor_names))
            raw_now = pct(sum(1 for a in latest_adopt.values() if a.get(dim)), len(latest_names))
            coh_anc_n = sum(1 for n in cohort if adopt[n].get(dim))
            coh_now_n = sum(1 for n in cohort if latest_adopt[n].get(dim))
            coh_anc = pct(coh_anc_n, len(cohort))
            coh_now = pct(coh_now_n, len(cohort))
            dcoh = round(coh_now - coh_anc, 1)
            num_anc = sum(1 for a in adopt.values() if a.get(dim))
            num_now = sum(1 for a in latest_adopt.values() if a.get(dim))
            flag = " ⚠REGRESSION" if dcoh < 0 else ""
            print(f"  {dim:22s} {raw_anc:>10.1f}% {raw_now:>10.1f}% | "
                  f"{coh_anc:>10.1f}% {coh_now:>10.1f}% {dcoh:>+7.1f}% | "
                  f"{num_anc:>8d} {num_now:>8d}{flag}")
            anchor_rec["dimensions"][dim] = {
                "raw_anchor": raw_anc, "raw_latest": raw_now,
                "cohort_anchor": coh_anc, "cohort_latest": coh_now,
                "cohort_delta": dcoh, "num_anchor": num_anc, "num_latest": num_now,
            }
            if dcoh < 0:
                report["regressions"].append({"anchor": label, "dimension": dim, "cohort_delta": dcoh})
        # dilution attribution
        print(f"  dilution: {len(new_in_latest)} new features since {label}; of those, adopted:",
              ", ".join(f"{dim}={sum(1 for n in new_in_latest if latest_adopt[n].get(dim))}" for dim in DIMENSIONS))
        print()
        report["anchors"].append(anchor_rec)

    if report["regressions"]:
        print(f"COHORT-normalized regressions (REAL, not dilution): {len(report['regressions'])}")
        for r in report["regressions"]:
            print(f"  - {r['anchor']} :: {r['dimension']} {r['cohort_delta']:+.1f}%")
    else:
        print("No COHORT-normalized regressions — all percentage drops vs anchors are denominator dilution.")

    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2) + "\n")
        print(f"\nwrote {args.json}")

    return 2 if (report["regressions"] and args.exit_on_regression) else 0


if __name__ == "__main__":
    raise SystemExit(main())
