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
    3  fewer than 2 anchors loaded — registry paths did not resolve (config/path
       error); a LOUD stderr warning is emitted. This is NOT "no regression".
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
# Anchor backups moved during the 2026-07-07 ~/Developer/FitMe consolidation
# (backups now live under ~/Developer/FitMe/backups/FitTracker2-backups/). The legacy
# ~/Documents/FitTracker2-backups path is kept as a fallback so pre-consolidation
# checkouts still resolve. Each anchor lists BOTH roots as candidates and load_anchor()
# takes the first that exists — mirroring scripts/integrity-diff.py's dual-path resolver.
# (History: integrity-diff got this fix at consolidation; this tool + integrity-data-lake
# were missed and silently loaded 0 registry anchors until 2026-07-21 — the reader/path
# drift class the framework polices as W24/W40.)
_BACKUP_ROOTS = (
    HOME / "Developer" / "FitMe" / "backups" / "FitTracker2-backups",
    HOME / "Documents" / "FitTracker2-backups",
)


def _anchor_candidates(*leaf_parts: str) -> list[Path]:
    """Candidate paths for one anchor's measurement-adoption.json, one per backup root."""
    return [root.joinpath(*leaf_parts) for root in _BACKUP_ROOTS]


DIMENSIONS = ["timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2"]

# CANONICAL regression anchor — must match scripts/integrity-diff.py DEFAULT_BASELINE
# and data-integrity-and-rollback sub-plan §2.3/§2.5. The cohort-normalized regression
# verdict is computed against THIS anchor specifically; other anchors are trend context.
#
# INVARIANT (FT2-FH-004 lesson — enforced by test_multi_anchor_canonical_invariance.py):
# adding anchors to the registry must NEVER change which anchor gates the verdict. The
# canonical anchor is selected by LABEL (== CANONICAL_ANCHOR), never by order/position,
# and only the canonical anchor's REAL_REGRESSIONs gate (see `and is_canonical` below).
# 2026-05-14 stays canonical, non-superseding: newer anchors are advisory trend context
# ONLY. Do NOT change this label or point integrity-diff.DEFAULT_BASELINE at a newer dir.
CANONICAL_ANCHOR = "2026-05-14-platform"

# Built-in anchor registry: (label, candidate paths to measurement-adoption.json).
# First existing candidate wins. Order = chronological (display only; NOT gating).
# The 2026-06-10-telemetry-backfill snapshot is registered as TREND CONTEXT ONLY
# (advisory; never gates) so the dilution trend has a mid-window point between the
# canonical 2026-05-14 anchor and live. It does NOT supersede canonical (FT2-FH-004).
ANCHOR_REGISTRY = [
    ("2026-05-12-pre-v7.9", _anchor_candidates(
        "2026-05-12-framework-v7-8-branch-isolation-pre-v7-9-baseline", "measurement-adoption.json")),
    ("2026-05-14-platform", _anchor_candidates(
        "2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14", "platform-baseline", "measurement-adoption.json")),
    ("2026-06-10-telemetry-backfill", _anchor_candidates(
        "2026-06-10-telemetry-backfill-anchor", "platform-baseline", "measurement-adoption.json")),
]
LIVE = ("live", [REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json"])


def classify_delta(anchor_adopt: dict, latest_adopt: dict, dimension: str) -> dict:
    """Dilution-aware regression classifier for one adoption dimension.

    Shared logic consumed by integrity-diff.py and the data-lake analyzer so the
    regression *definition* is single-sourced. Compares an anchor's per-feature
    adoption map against the latest map and returns three deltas plus a verdict.

    - raw_delta:       Δ adoption-% over each side's FULL corpus (dilution-SENSITIVE)
    - cohort_delta:    Δ adoption-% over features present in BOTH (apples-to-apples)
    - numerator_delta: Δ absolute count of adopted features (monotonicity check)

    Verdict rule (data-integrity sub-plan §2.6):
      * cohort_delta < 0  OR  numerator_delta < 0  -> "REAL_REGRESSION"
      * raw_delta < 0  but cohort_delta >= 0 and numerator_delta >= 0 -> "dilution"
      * otherwise -> "improved" (or "flat" when all zero)
    """
    anchor_names = set(anchor_adopt)
    latest_names = set(latest_adopt)
    cohort = anchor_names & latest_names

    def _pct(num, den):
        return round(100.0 * num / den, 1) if den else 0.0

    raw_anc = _pct(sum(1 for a in anchor_adopt.values() if a.get(dimension)), len(anchor_names))
    raw_now = _pct(sum(1 for a in latest_adopt.values() if a.get(dimension)), len(latest_names))
    coh_anc = _pct(sum(1 for n in cohort if anchor_adopt[n].get(dimension)), len(cohort))
    coh_now = _pct(sum(1 for n in cohort if latest_adopt[n].get(dimension)), len(cohort))
    num_anc = sum(1 for a in anchor_adopt.values() if a.get(dimension))
    num_now = sum(1 for a in latest_adopt.values() if a.get(dimension))

    raw_delta = round(raw_now - raw_anc, 1)
    cohort_delta = round(coh_now - coh_anc, 1)
    numerator_delta = num_now - num_anc

    if cohort_delta < 0 or numerator_delta < 0:
        verdict = "REAL_REGRESSION"
    elif raw_delta < 0:
        verdict = "dilution"
    elif raw_delta > 0 or cohort_delta > 0 or numerator_delta > 0:
        verdict = "improved"
    else:
        verdict = "flat"

    return {
        "dimension": dimension, "raw_delta": raw_delta, "cohort_delta": cohort_delta,
        "numerator_delta": numerator_delta, "raw_anchor": raw_anc, "raw_latest": raw_now,
        "cohort_anchor": coh_anc, "cohort_latest": coh_now,
        "num_anchor": num_anc, "num_latest": num_now, "verdict": verdict,
    }


def load_adoption_features(path: Path, instrumented_only: bool = False) -> dict | None:
    """Load a measurement-adoption.json into {feature_name: adoption_dict}, or None.

    When instrumented_only=True, a dimension counts as adopted ONLY if its provenance
    is 'instrumented' (derived backfills are dropped) — the strict T1 view. Older
    snapshots without a `provenance` block are treated as fully instrumented (the
    field didn't exist when they were captured)."""
    if not path.is_file():
        return None
    try:
        d = json.loads(path.read_text())
    except json.JSONDecodeError:
        return None
    feats = d.get("features")
    if not isinstance(feats, list):
        return None
    out = {}
    for f in feats:
        name = f.get("feature")
        if not name:
            continue
        adoption = dict(f.get("adoption", {}))
        if instrumented_only:
            prov = f.get("provenance") or {}
            for dim, present in list(adoption.items()):
                if present and prov.get(dim) == "derived":
                    adoption[dim] = False
        out[name] = adoption
    return out


def load_anchor(label: str, candidates: list[Path], instrumented_only: bool = False):
    """Return (label, {feature_name: adoption_dict}, source_path) or None."""
    for c in candidates:
        if c.is_file():
            adoption = load_adoption_features(c, instrumented_only=instrumented_only)
            if adoption is not None:
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
    ap.add_argument("--canonical-only", action="store_true",
                    help=f"only compare vs the canonical anchor ({CANONICAL_ANCHOR})")
    ap.add_argument("--instrumented-only", action="store_true",
                    help="strict T1 view — count only instrumented values, drop derived backfills")
    args = ap.parse_args()

    registry = list(ANCHOR_REGISTRY)
    for spec in args.anchor:
        if "=" in spec:
            lbl, pth = spec.split("=", 1)
            registry.append((lbl, [Path(pth).expanduser()]))
    registry.append(LIVE)

    loaded, skipped = [], []
    for label, cands in registry:
        r = load_anchor(label, cands, instrumented_only=args.instrumented_only)
        (loaded.append if r else skipped.append)(r if r else label)

    if len(loaded) < 2:
        # LOUD + non-zero: too few anchors means the registry paths did not resolve
        # (config/path drift), NOT "no regression". Returning 0 here would be a
        # silent-pass — the exact failure that stranded this tool 2026-07-07 → -21.
        roots = ", ".join(str(r).replace(str(HOME), "~") for r in _BACKUP_ROOTS)
        print(
            f"⚠ MULTI-ANCHOR UNAVAILABLE: loaded {len(loaded)} anchor(s), need >=2. "
            f"Registry anchors did not resolve under any backup root ({roots}). "
            "This is a config/path error — dilution vs regression was NOT checked.",
            file=sys.stderr,
        )
        return 3

    latest_label, latest_adopt, latest_src = loaded[-1]
    latest_names = set(latest_adopt)

    print("=== Multi-anchor normalized adoption comparison ===")
    print(f"latest = {latest_label} ({len(latest_names)} features) [{latest_src}]")
    if skipped:
        print(f"skipped (no per-feature measurement-adoption.json): {', '.join(skipped)}")
    print()

    report = {"latest": latest_label, "canonical_anchor": CANONICAL_ANCHOR,
              "anchors": [], "regressions": []}

    anchors_to_compare = loaded[:-1]
    if args.canonical_only:
        anchors_to_compare = [a for a in anchors_to_compare if a[0] == CANONICAL_ANCHOR]

    for label, adopt, src in anchors_to_compare:
        is_canonical = label == CANONICAL_ANCHOR
        anchor_names = set(adopt)
        cohort = anchor_names & latest_names
        new_in_latest = latest_names - anchor_names
        tag = "  [CANONICAL regression reference]" if is_canonical else "  (trend context)"
        print(f"── anchor {label}{tag}  ({len(anchor_names)} feats; cohort∩latest={len(cohort)}; "
              f"new-in-latest={len(new_in_latest)}) ──")
        header = f"  {'dimension':22s} {'RAW@anc':>9s} {'RAW@now':>9s} | {'COH@anc':>8s} {'COH@now':>8s} {'Δcoh':>7s} | {'NUM@anc':>8s} {'NUM@now':>8s}  verdict"
        print(header)
        anchor_rec = {"label": label, "is_canonical": is_canonical, "n_anchor": len(anchor_names),
                      "cohort_size": len(cohort), "new_in_latest": len(new_in_latest),
                      "dimensions": {}}
        for dim in DIMENSIONS:
            c = classify_delta(adopt, latest_adopt, dim)
            mark = {"REAL_REGRESSION": " ⚠REAL_REGRESSION", "dilution": " ·dilution",
                    "improved": " ✓", "flat": ""}[c["verdict"]]
            print(f"  {dim:22s} {c['raw_anchor']:>8.1f}% {c['raw_latest']:>8.1f}% | "
                  f"{c['cohort_anchor']:>7.1f}% {c['cohort_latest']:>7.1f}% {c['cohort_delta']:>+6.1f}% | "
                  f"{c['num_anchor']:>8d} {c['num_latest']:>8d}{mark}")
            anchor_rec["dimensions"][dim] = c
            # Only the CANONICAL anchor's REAL_REGRESSIONs gate; trend anchors are advisory.
            if c["verdict"] == "REAL_REGRESSION" and is_canonical:
                report["regressions"].append({"anchor": label, "dimension": dim,
                                              "cohort_delta": c["cohort_delta"],
                                              "numerator_delta": c["numerator_delta"]})
        print(f"  dilution: {len(new_in_latest)} new features since {label}; of those, adopted:",
              ", ".join(f"{dim}={sum(1 for n in new_in_latest if latest_adopt[n].get(dim))}" for dim in DIMENSIONS))
        print()
        report["anchors"].append(anchor_rec)

    if report["regressions"]:
        print(f"REAL regressions vs canonical anchor {CANONICAL_ANCHOR} (cohort<0 or numerator<0): {len(report['regressions'])}")
        for r in report["regressions"]:
            print(f"  - {r['dimension']}  cohortΔ {r['cohort_delta']:+.1f}%  numeratorΔ {r['numerator_delta']:+d}")
    else:
        print(f"No REAL regressions vs canonical anchor {CANONICAL_ANCHOR} — "
              "raw percentage drops are denominator dilution (cohort flat-or-up, numerator non-decreasing).")

    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2) + "\n")
        print(f"\nwrote {args.json}")

    return 2 if (report["regressions"] and args.exit_on_regression) else 0


if __name__ == "__main__":
    raise SystemExit(main())
