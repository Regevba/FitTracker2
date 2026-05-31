"""Per-sub-exp verdict computation per spec §10.

Loads all phase2bis-raw-<subexp>-*.jsonl files in --raw-dir, filters
status=='ok', computes either:

  --metric silhouette  (default, Sub-exp 1 + 1B)
    Silhouette score at k=5 over (ttft_s, tps); PASS if silhouette ≥
    threshold AND yield ≥ yield_min AND clusters ≥ clusters_min.

  --metric ks  (Sub-exp 2 cloud-vs-local; added 2026-05-30)
    Two-sample Kolmogorov-Smirnov test comparing the target sub-exp's
    (ttft_s, tps) marginal distributions to an anchor sub-exp's pooled
    cloud distribution. PASS if BOTH p-values < p_threshold (i.e. local
    is statistically distinguishable from cloud on both signature
    dimensions) AND yield ≥ yield_min. Per Sub-exp 2 prereg primary
    metric `pass_ks_p_max=0.01` + `pass_yield_min=250`.

  --metric signature_delta_ratio  (Sub-exp 3 Bedrock-vs-Anthropic-direct
    routing test; added 2026-05-31)
    Mahalanobis-distance effect-size between the routing-test target
    provider's records (default: aws-bedrock) and the routing-anchor
    provider's records (default: anthropic), expressed in units of the
    intra-anchor noise floor (Mahalanobis radius within the anchor
    relative to itself). Per Sub-exp 3 prereg verdict_thresholds:
      ratio > 2.0  → PASS  (Bedrock distinguishable from Anthropic-direct
                            — central HADF dispatch claim survives)
      ratio < 1.0  → FAIL  (signatures indistinguishable — HADF claim
                            REFUTED on this metric)
      1.0 ≤ r ≤ 2.0 → INCONCLUSIVE

The --subexp argument selects target records from filenames matching
`phase2bis-raw-<subexp>-*.jsonl`. For --metric ks, --anchor-subexp
selects the anchor (default: subexp1) from the same --raw-dir. For
--metric signature_delta_ratio, --routing-target-provider and
--routing-anchor-provider slice within the --subexp's records.
"""
import argparse
import json
import sys
from pathlib import Path

try:
    import numpy as np
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score
except ImportError:
    print("scikit-learn + numpy required", file=sys.stderr)
    sys.exit(2)


def load_records(raw_dir, subexp_filter=None):
    """Load all status='ok' records from raw_dir.

    If subexp_filter is set, only load files whose name matches
    `phase2bis-raw-<filter>-*.jsonl`. This lets one --raw-dir hold
    multiple sub-exps' data and still cleanly partition for KS
    comparisons.
    """
    records = []
    for path in Path(raw_dir).glob("*.jsonl"):
        if subexp_filter is not None:
            prefix = f"phase2bis-raw-{subexp_filter}-"
            if not path.name.startswith(prefix):
                continue
        for line in path.read_text().splitlines():
            if not line.strip():
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if r.get("status") == "ok" and "ttft_s" in r and "tps" in r:
                records.append(r)
    return records


def _silhouette_verdict(args, records):
    n_valid = len(records)
    if n_valid < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "silhouette",
            "yield": int(n_valid),
            "verdict": "FAIL",
            "fail_reason": "low_yield",
            "yield_min_required": int(args.yield_min),
        }))
        return

    X = np.array([[r["ttft_s"], r["tps"]] for r in records])
    # Normalize features for fair clustering
    X_norm = (X - X.mean(axis=0)) / (X.std(axis=0) + 1e-9)

    km = KMeans(n_clusters=args.k, random_state=42, n_init=10)
    labels = km.fit_predict(X_norm)
    silhouette = silhouette_score(X_norm, labels)
    n_clusters = len(set(labels))

    verdict = "PASS"
    fail_reason = None
    if silhouette < args.silhouette_min:
        verdict = "FAIL"
        fail_reason = "low_silhouette"
    elif n_clusters < args.clusters_min:
        verdict = "FAIL"
        fail_reason = "too_few_clusters"

    report = {
        "subexp": args.subexp,
        "metric": "silhouette",
        "yield": int(n_valid),
        "silhouette": float(silhouette),
        "clusters": int(n_clusters),
        "k_attempted": int(args.k),
        "thresholds": {
            "silhouette_min": float(args.silhouette_min),
            "yield_min": int(args.yield_min),
            "clusters_min": int(args.clusters_min),
        },
        "verdict": str(verdict),
        "fail_reason": fail_reason,
    }
    print(json.dumps(report))


def _ks_verdict(args, target_records):
    """Sub-exp 2 cloud-vs-local KS-distinguishability verdict.

    Two-sample KS test on TTFT and TPS marginals against an anchor
    sub-exp (default: subexp1). PASS if BOTH p-values < p_threshold
    AND yield ≥ yield_min. The KS test requires scipy.
    """
    try:
        from scipy.stats import ks_2samp
    except ImportError:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "ks",
            "verdict": "ERROR",
            "fail_reason": "scipy_unavailable",
        }))
        sys.exit(2)

    anchor_records = load_records(args.raw_dir, subexp_filter=args.anchor_subexp)

    n_target = len(target_records)
    n_anchor = len(anchor_records)

    if n_target < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "ks",
            "yield_target": int(n_target),
            "yield_anchor": int(n_anchor),
            "anchor_subexp": args.anchor_subexp,
            "verdict": "FAIL",
            "fail_reason": "low_yield_target",
            "yield_min_required": int(args.yield_min),
        }))
        return

    if n_anchor < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "ks",
            "yield_target": int(n_target),
            "yield_anchor": int(n_anchor),
            "anchor_subexp": args.anchor_subexp,
            "verdict": "INCONCLUSIVE",
            "fail_reason": "low_yield_anchor",
            "yield_min_required": int(args.yield_min),
        }))
        return

    target_ttft = [r["ttft_s"] for r in target_records]
    target_tps = [r["tps"] for r in target_records]
    anchor_ttft = [r["ttft_s"] for r in anchor_records]
    anchor_tps = [r["tps"] for r in anchor_records]

    ks_ttft = ks_2samp(target_ttft, anchor_ttft)
    ks_tps = ks_2samp(target_tps, anchor_tps)

    distinguishable_ttft = ks_ttft.pvalue < args.p_threshold
    distinguishable_tps = ks_tps.pvalue < args.p_threshold

    if distinguishable_ttft and distinguishable_tps:
        verdict = "PASS"
        fail_reason = None
    elif not distinguishable_ttft and not distinguishable_tps:
        verdict = "FAIL"
        fail_reason = "ks_indistinguishable_both"
    elif not distinguishable_ttft:
        verdict = "FAIL"
        fail_reason = "ks_indistinguishable_ttft"
    else:
        verdict = "FAIL"
        fail_reason = "ks_indistinguishable_tps"

    report = {
        "subexp": args.subexp,
        "metric": "ks",
        "yield_target": int(n_target),
        "yield_anchor": int(n_anchor),
        "anchor_subexp": args.anchor_subexp,
        "ks_ttft": {
            "statistic": float(ks_ttft.statistic),
            "p_value": float(ks_ttft.pvalue),
            "distinguishable": bool(distinguishable_ttft),
        },
        "ks_tps": {
            "statistic": float(ks_tps.statistic),
            "p_value": float(ks_tps.pvalue),
            "distinguishable": bool(distinguishable_tps),
        },
        "thresholds": {
            "p_threshold": float(args.p_threshold),
            "yield_min": int(args.yield_min),
        },
        "verdict": str(verdict),
        "fail_reason": fail_reason,
    }
    print(json.dumps(report))


def _signature_delta_ratio_verdict(args, target_records):
    """Sub-exp 3 Bedrock-vs-Anthropic-direct routing-test verdict.

    Computes the inter-provider Mahalanobis distance between the routing-
    test target provider (default aws-bedrock) and the routing anchor
    provider (default anthropic) on (ttft_s, tps), then expresses it in
    units of the intra-anchor noise floor (median per-fire centroid
    spread within the anchor). Per Sub-exp 3 prereg verdict thresholds:

      ratio > pass_threshold  → PASS  (HADF dispatch claim survives)
      ratio < fail_threshold  → FAIL  (HADF claim REFUTED on this metric)
      between thresholds      → INCONCLUSIVE

    Requires scipy + numpy.
    """
    try:
        import numpy as np
    except ImportError:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "signature_delta_ratio",
            "verdict": "ERROR",
            "fail_reason": "numpy_unavailable",
        }))
        sys.exit(2)

    def _filter(records, provider, endpoint):
        out = []
        for r in records:
            if r.get("provider") != provider:
                continue
            if endpoint is not None and r.get("endpoint") != endpoint:
                continue
            out.append(r)
        return out

    anchor_records = _filter(
        target_records,
        args.routing_anchor_provider,
        args.routing_anchor_endpoint,
    )
    routing_records = _filter(
        target_records,
        args.routing_target_provider,
        args.routing_target_endpoint,
    )

    n_anchor = len(anchor_records)
    n_routing = len(routing_records)

    if n_routing < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "signature_delta_ratio",
            "yield_target": int(n_routing),
            "yield_anchor": int(n_anchor),
            "routing_target_provider": args.routing_target_provider,
            "routing_anchor_provider": args.routing_anchor_provider,
            "verdict": "FAIL",
            "fail_reason": "low_yield_target",
            "yield_min_required": int(args.yield_min),
        }))
        return

    if n_anchor < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
            "metric": "signature_delta_ratio",
            "yield_target": int(n_routing),
            "yield_anchor": int(n_anchor),
            "routing_target_provider": args.routing_target_provider,
            "routing_anchor_provider": args.routing_anchor_provider,
            "verdict": "INCONCLUSIVE",
            "fail_reason": "low_yield_anchor",
            "yield_min_required": int(args.yield_min),
        }))
        return

    X_anchor = np.array([[r["ttft_s"], r["tps"]] for r in anchor_records])
    X_routing = np.array([[r["ttft_s"], r["tps"]] for r in routing_records])

    mean_anchor = X_anchor.mean(axis=0)
    mean_routing = X_routing.mean(axis=0)
    diff = mean_routing - mean_anchor

    # Intra-anchor covariance — the noise floor scale
    cov_anchor = np.cov(X_anchor.T)
    # Add tiny ridge for numerical stability when ttft + tps are tightly correlated
    ridge = 1e-9 * np.trace(cov_anchor) * np.eye(2)
    cov_inv = np.linalg.pinv(cov_anchor + ridge)

    inter_mahalanobis = float(np.sqrt(diff @ cov_inv @ diff))

    # Intra-anchor noise floor: expected Mahalanobis radius of anchor points
    # from anchor mean using the same covariance. This is 1.0 in expectation
    # if the cov is well-fit, so the ratio = inter / 1 in units of "anchor std-dev".
    intra_distances = np.array([
        np.sqrt((p - mean_anchor) @ cov_inv @ (p - mean_anchor))
        for p in X_anchor
    ])
    intra_noise = float(np.median(intra_distances))
    intra_noise = max(intra_noise, 1e-9)  # avoid division by zero

    ratio = inter_mahalanobis / intra_noise

    if ratio > args.pass_threshold:
        verdict = "PASS"
        fail_reason = None
    elif ratio < args.fail_threshold:
        verdict = "FAIL"
        fail_reason = "signatures_indistinguishable"
    else:
        verdict = "INCONCLUSIVE"
        fail_reason = "in_inconclusive_band"

    report = {
        "subexp": args.subexp,
        "metric": "signature_delta_ratio",
        "yield_target": int(n_routing),
        "yield_anchor": int(n_anchor),
        "routing_target_provider": args.routing_target_provider,
        "routing_target_endpoint": args.routing_target_endpoint,
        "routing_anchor_provider": args.routing_anchor_provider,
        "routing_anchor_endpoint": args.routing_anchor_endpoint,
        "inter_mahalanobis": inter_mahalanobis,
        "intra_anchor_noise_floor": intra_noise,
        "signature_delta_ratio": ratio,
        "thresholds": {
            "pass_threshold": float(args.pass_threshold),
            "fail_threshold": float(args.fail_threshold),
            "yield_min": int(args.yield_min),
        },
        "verdict": str(verdict),
        "fail_reason": fail_reason,
    }
    print(json.dumps(report))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw-dir", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument(
        "--metric",
        choices=["silhouette", "ks", "signature_delta_ratio"],
        default="silhouette",
        help="silhouette = Sub-exp 1/1B fingerprint clustering; "
             "ks = Sub-exp 2 cloud-vs-local Kolmogorov-Smirnov test; "
             "signature_delta_ratio = Sub-exp 3 Bedrock-vs-Anthropic-direct "
             "routing-test Mahalanobis effect size",
    )
    # Silhouette-mode args
    p.add_argument("--silhouette-min", type=float, default=0.5)
    p.add_argument("--clusters-min", type=int, default=3)
    p.add_argument("--k", type=int, default=5)
    # KS-mode args
    p.add_argument(
        "--anchor-subexp",
        default="subexp1",
        help="For --metric ks: anchor sub-exp to compare against",
    )
    p.add_argument(
        "--p-threshold",
        type=float,
        default=0.01,
        help="For --metric ks: KS p-value below which distributions "
             "are considered distinguishable. Sub-exp 2 prereg = 0.01.",
    )
    # signature_delta_ratio mode args (Sub-exp 3 routing test)
    p.add_argument(
        "--routing-target-provider",
        default="aws-bedrock",
        help="For --metric signature_delta_ratio: routing-test target provider",
    )
    p.add_argument(
        "--routing-target-endpoint",
        default=None,
        help="For --metric signature_delta_ratio: optional endpoint filter on target",
    )
    p.add_argument(
        "--routing-anchor-provider",
        default="anthropic",
        help="For --metric signature_delta_ratio: routing-anchor provider",
    )
    p.add_argument(
        "--routing-anchor-endpoint",
        default=None,
        help="For --metric signature_delta_ratio: optional endpoint filter on anchor",
    )
    p.add_argument(
        "--pass-threshold",
        type=float,
        default=2.0,
        help="For --metric signature_delta_ratio: ratio above which routing test PASSes. "
             "Sub-exp 3 prereg = 2.0.",
    )
    p.add_argument(
        "--fail-threshold",
        type=float,
        default=1.0,
        help="For --metric signature_delta_ratio: ratio below which routing test FAILs. "
             "Sub-exp 3 prereg = 1.0.",
    )
    # Shared
    p.add_argument(
        "--yield-min",
        type=int,
        default=600,
        help="Minimum yield to compute verdict. "
             "Sub-exp 2 prereg = 250; Sub-exp 1/3 = 600.",
    )
    args = p.parse_args()

    target_records = load_records(args.raw_dir, subexp_filter=args.subexp)

    if args.metric == "silhouette":
        _silhouette_verdict(args, target_records)
    elif args.metric == "ks":
        _ks_verdict(args, target_records)
    elif args.metric == "signature_delta_ratio":
        _signature_delta_ratio_verdict(args, target_records)


if __name__ == "__main__":
    main()
