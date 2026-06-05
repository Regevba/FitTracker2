#!/usr/bin/env python3
"""HADF Phase 3A — Anchor drift monitor (T3, ADVISORY).

Compares a window of recent streaming samples against the locked reference
baseline (`reference-signatures.json`) per endpoint, and emits a drift verdict
using the same statistics as the Sub-exp verdicts: KS on the TTFT/TPS marginals
plus a Mahalanobis shift of the window mean (in baseline-σ units). Appends one
JSON line per (endpoint, run) to `drift-monitor.jsonl`.

ADVISORY ONLY — this surfaces "the substrate moved since baseline" so an operator
can decide whether to re-baseline. It makes NO dispatch decisions (acting layer
gated on RQ4 / Phase 3B). Drift is EXPECTED over time (provider infra changes);
flagging it is the point, not a failure.

Thresholds (pre-registered, mirror Sub-exp 1B anchor-drift framing):
    Mahalanobis mean shift  < 1σ  -> stable
                            1-3σ  -> minor_drift
                            > 3σ  -> significant_drift  (re-baseline recommended)
    KS p < 0.01 on either marginal independently raises a `ks_diverged` flag.

Usage:
    hadf-drift-monitor.py --window <raw.jsonl> [--window <raw.jsonl> ...] \
        [--store .claude/shared/hadf/reference-signatures.json] \
        [--out .claude/shared/hadf/drift-monitor.jsonl] [--as-of YYYY-MM-DD]
"""
import argparse
import json
import os
import sys
from collections import defaultdict

try:
    import numpy as np
    from scipy import stats
except ImportError:
    print("ERROR: numpy + scipy required", file=sys.stderr)
    sys.exit(2)

STABLE, SIGNIFICANT = 1.0, 3.0
MIN_WINDOW_N = 30  # below this a per-endpoint verdict is too noisy to trust


def mahalanobis_mean_shift(window_pts, mean, cov):
    diff = np.array(window_pts).mean(0) - np.array(mean)
    ridge = 1e-9 * np.trace(cov) * np.eye(2)
    cinv = np.linalg.pinv(np.array(cov) + ridge)
    return float(np.sqrt(diff @ cinv @ diff))


def load_window(window_files):
    pts = defaultdict(list)  # (prov, ep) -> [(ttft, tps), ...]
    for f in window_files:
        for line in open(f):
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if r.get("status") != "ok":
                continue
            prov, ep = r.get("provider"), r.get("endpoint")
            t, s = r.get("ttft_s"), r.get("tps")
            if prov and ep and t is not None and s is not None:
                pts[(prov, ep)].append((float(t), float(s)))
    return pts


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--store", default=".claude/shared/hadf/reference-signatures.json")
    p.add_argument("--window", action="append", required=True, dest="windows")
    p.add_argument("--out", default=".claude/shared/hadf/drift-monitor.jsonl")
    p.add_argument("--as-of", default=None)
    args = p.parse_args()

    store = json.load(open(args.store))
    ref = {(e["provider"], e["endpoint"]): e for e in store["endpoints"]}
    window = load_window(args.windows)

    results = []
    for key, pts in sorted(window.items()):
        prov, ep = key
        if key not in ref:
            results.append({"as_of": args.as_of or "unspecified", "provider": prov,
                            "endpoint": ep, "n_window": len(pts),
                            "disposition": "no_baseline", "advisory": True})
            continue
        if len(pts) < MIN_WINDOW_N:
            results.append({"as_of": args.as_of or "unspecified", "provider": prov,
                            "endpoint": ep, "n_window": len(pts),
                            "disposition": "insufficient_window", "advisory": True})
            continue
        e = ref[key]
        shift = mahalanobis_mean_shift(pts, e["mean"], e["cov"])
        # KS on each marginal vs baseline quantile-implied normal isn't available;
        # compare window marginal against baseline mean/std via a one-sample KS to normal.
        wt = np.array([x[0] for x in pts])
        ws = np.array([x[1] for x in pts])
        bt, bs = e["ttft_s"], e["tps"]
        ks_t = stats.ks_1samp(wt, stats.norm(loc=bt["mean"], scale=max(bt["std"], 1e-6)).cdf)
        ks_s = stats.ks_1samp(ws, stats.norm(loc=bs["mean"], scale=max(bs["std"], 1e-6)).cdf)
        ks_diverged = bool(ks_t.pvalue < 0.01 or ks_s.pvalue < 0.01)
        if shift < STABLE:
            disp = "stable"
        elif shift < SIGNIFICANT:
            disp = "minor_drift"
        else:
            disp = "significant_drift"
        results.append({
            "as_of": args.as_of or "unspecified",
            "provider": prov, "endpoint": ep, "n_window": len(pts),
            "mahalanobis_mean_shift_sigma": round(shift, 3),
            "ttft_window_median": round(float(np.median(wt)), 4),
            "ttft_baseline_median": bt["median"],
            "ks_ttft_p": float(f"{ks_t.pvalue:.3e}"),
            "ks_tps_p": float(f"{ks_s.pvalue:.3e}"),
            "ks_diverged": ks_diverged,
            "disposition": disp,
            "rebaseline_recommended": disp == "significant_drift",
            "advisory": True,
        })

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "a") as fh:
        for r in results:
            fh.write(json.dumps(r) + "\n")
    flagged = [r for r in results if r.get("disposition") in ("minor_drift", "significant_drift")]
    print(json.dumps({"endpoints": len(results), "flagged": len(flagged),
                      "significant": sum(1 for r in results if r.get("disposition") == "significant_drift"),
                      "appended_to": args.out}, indent=2))


if __name__ == "__main__":
    main()
