#!/usr/bin/env python3
"""
HADF Phase 2 — Cluster analysis & verdict

Reads the raw jsonl produced by hadf-phase2-fingerprint.py, runs k-means
on (ttft_ms, tps) joint space across the k values declared in the
preregistration, and writes a committed summary JSON containing the
mechanical verdict.

The verdict is a pure function of (preregistration thresholds, observed data).
No judgment, no narrative.

Inputs (read-only):
    .claude/shared/hadf/phase2-preregistration.json   — verdict thresholds (committed)
    .claude/shared/hadf/phase2-fingerprint-raw.jsonl  — observed data (gitignored)

Output (committed):
    .claude/shared/hadf/phase2-fingerprint-summary.json

Usage:
    python3 scripts/hadf-phase2-analyze.py
    python3 scripts/hadf-phase2-analyze.py --raw <path> --summary <path>
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PREREG_PATH = REPO_ROOT / ".claude" / "shared" / "hadf" / "phase2-preregistration.json"
RAW_PATH = REPO_ROOT / ".claude" / "shared" / "hadf" / "phase2-fingerprint-raw.jsonl"
SUMMARY_PATH = REPO_ROOT / ".claude" / "shared" / "hadf" / "phase2-fingerprint-summary.json"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def load_records(raw_path: Path) -> list[dict]:
    if not raw_path.exists():
        return []
    out: list[dict] = []
    with raw_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def per_endpoint_stats(records: list[dict]) -> dict:
    """Aggregate stats per endpoint over valid (ok=true) records."""
    by_endpoint: dict[str, list[dict]] = {}
    for r in records:
        if not r.get("ok"):
            continue
        by_endpoint.setdefault(r["endpoint"], []).append(r)

    out: dict = {}
    for endpoint, rows in by_endpoint.items():
        ttfts = [r["ttft_ms"] for r in rows if isinstance(r.get("ttft_ms"), (int, float))]
        tpss = [r["tps"] for r in rows if isinstance(r.get("tps"), (int, float))]
        if not ttfts or not tpss:
            continue
        ttft_mean = statistics.fmean(ttfts)
        tps_mean = statistics.fmean(tpss)
        ttft_stdev = statistics.pstdev(ttfts) if len(ttfts) > 1 else 0.0
        tps_stdev = statistics.pstdev(tpss) if len(tpss) > 1 else 0.0
        out[endpoint] = {
            "n": len(rows),
            "ttft_ms": {
                "mean": round(ttft_mean, 2),
                "median": round(statistics.median(ttfts), 2),
                "p95": round(_percentile(ttfts, 95), 2),
                "min": round(min(ttfts), 2),
                "stdev": round(ttft_stdev, 2),
            },
            "tps": {
                "mean": round(tps_mean, 3),
                "median": round(statistics.median(tpss), 3),
                "p95": round(_percentile(tpss, 95), 3),
                "stdev": round(tps_stdev, 3),
                "cov": round(tps_stdev / tps_mean, 4) if tps_mean > 0 else None,
            },
        }
    return out


def _percentile(values: list[float], pct: float) -> float:
    if not values:
        return float("nan")
    s = sorted(values)
    k = (len(s) - 1) * pct / 100.0
    lo = int(k)
    hi = min(lo + 1, len(s) - 1)
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def run_kmeans(records: list[dict], k_values: list[int], random_state: int, n_init: int) -> dict:
    """Run k-means on z-scored (ttft_ms, tps) for each k. Returns metrics per k."""
    try:
        import numpy as np  # type: ignore
        from sklearn.cluster import KMeans  # type: ignore
        from sklearn.metrics import silhouette_score  # type: ignore
        from sklearn.preprocessing import StandardScaler  # type: ignore
    except ImportError as e:
        raise RuntimeError("clustering needs scikit-learn + numpy (pip install scikit-learn)") from e

    valid = [r for r in records
             if r.get("ok") and isinstance(r.get("ttft_ms"), (int, float))
             and isinstance(r.get("tps"), (int, float))]
    if len(valid) < max(k_values) + 1:
        return {
            "ran": False,
            "reason": f"insufficient valid points: {len(valid)} < {max(k_values) + 1}",
            "valid_points": len(valid),
        }

    X = np.array([[r["ttft_ms"], r["tps"]] for r in valid], dtype=float)
    endpoints = [r["endpoint"] for r in valid]
    Xs = StandardScaler().fit_transform(X)

    per_k: dict[int, dict] = {}
    best_k = None
    best_silhouette = -2.0
    for k in k_values:
        km = KMeans(n_clusters=k, n_init=n_init, random_state=random_state)
        labels = km.fit_predict(Xs)
        sil = float(silhouette_score(Xs, labels)) if k >= 2 else 0.0
        purities = _cluster_endpoint_purities(labels.tolist(), endpoints)
        per_k[k] = {
            "silhouette": round(sil, 4),
            "inertia": round(float(km.inertia_), 4),
            "cluster_endpoint_purities": purities,
        }
        if sil > best_silhouette:
            best_silhouette = sil
            best_k = k

    return {
        "ran": True,
        "valid_points": len(valid),
        "per_k": per_k,
        "best_k": best_k,
        "max_silhouette_score_across_k": round(best_silhouette, 4),
    }


def _cluster_endpoint_purities(labels: list[int], endpoints: list[str]) -> dict:
    """For each cluster, return (size, dominant_endpoint, purity)."""
    by_cluster: dict[int, list[str]] = {}
    for label, ep in zip(labels, endpoints):
        by_cluster.setdefault(label, []).append(ep)
    out: dict[str, dict] = {}
    for cluster_id, eps in by_cluster.items():
        counts: dict[str, int] = {}
        for e in eps:
            counts[e] = counts.get(e, 0) + 1
        dominant = max(counts, key=counts.get)
        purity = counts[dominant] / len(eps)
        out[str(cluster_id)] = {
            "size": len(eps),
            "dominant_endpoint": dominant,
            "purity": round(purity, 4),
        }
    return out


def evaluate_verdict(prereg: dict, kmeans: dict, total_points: int, per_endpoint: dict) -> dict:
    """Apply the pre-registered verdict function. No judgment."""
    abort_conditions: list[str] = []

    min_total = prereg["validity_thresholds"]["minimum_total_data_points"]
    if total_points < min_total:
        abort_conditions.append(
            f"total_data_points {total_points} < minimum_total_data_points {min_total}"
        )

    min_per = prereg["validity_thresholds"]["minimum_data_points_per_endpoint"]
    insufficient = [ep for ep, s in per_endpoint.items() if s["n"] < min_per]
    excluded_endpoints = insufficient

    if abort_conditions:
        return {
            "status": "aborted",
            "abort_conditions": abort_conditions,
            "clusters_found": None,
            "best_k": None,
            "max_silhouette_score": None,
            "excluded_endpoints": excluded_endpoints,
        }

    if not kmeans.get("ran"):
        return {
            "status": "aborted",
            "abort_conditions": [kmeans.get("reason", "kmeans did not run")],
            "clusters_found": None,
            "best_k": None,
            "max_silhouette_score": None,
            "excluded_endpoints": excluded_endpoints,
        }

    threshold = prereg["verdict_function"]["primary_threshold"]
    score = kmeans["max_silhouette_score_across_k"]
    op = threshold["operator"]
    val = threshold["value"]
    if op == ">":
        clusters_found = score > val
    elif op == ">=":
        clusters_found = score >= val
    else:
        raise ValueError(f"unsupported operator in preregistration: {op}")

    return {
        "status": "complete",
        "abort_conditions": [],
        "clusters_found": clusters_found,
        "best_k": kmeans["best_k"],
        "max_silhouette_score": score,
        "threshold": {"operator": op, "value": val},
        "excluded_endpoints": excluded_endpoints,
        "path_b_recommendation": (
            "green-lit" if clusters_found else "not-recommended"
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="HADF Phase 2 cluster analysis")
    parser.add_argument("--raw", default=str(RAW_PATH))
    parser.add_argument("--summary", default=str(SUMMARY_PATH))
    parser.add_argument("--prereg", default=str(PREREG_PATH))
    parser.add_argument("--print-only", action="store_true",
                        help="print summary to stdout, do not overwrite committed summary file")
    args = parser.parse_args()

    raw_path = Path(args.raw)
    prereg_path = Path(args.prereg)
    summary_path = Path(args.summary)

    if not prereg_path.exists():
        print(f"missing preregistration: {prereg_path}", file=sys.stderr)
        return 3

    prereg = json.loads(prereg_path.read_text(encoding="utf-8"))
    records = load_records(raw_path)
    valid_count = sum(1 for r in records if r.get("ok"))
    error_count = sum(1 for r in records if not r.get("ok"))

    per_endpoint = per_endpoint_stats(records)
    k_values = prereg["analysis"]["k_values_tested"]
    random_state = prereg["analysis"]["tooling"]["kmeans_random_state"]
    n_init = prereg["analysis"]["tooling"]["kmeans_n_init"]

    try:
        kmeans = run_kmeans(records, k_values, random_state, n_init)
    except RuntimeError as e:
        kmeans = {"ran": False, "reason": str(e), "valid_points": valid_count}

    verdict = evaluate_verdict(prereg, kmeans, valid_count, per_endpoint)

    summary = {
        "schema": "hadf-phase2-summary-v1",
        "version": "1.0",
        "computed_at": now_iso(),
        "preregistration_path": str(prereg_path.relative_to(REPO_ROOT)),
        "raw_path": str(raw_path.relative_to(REPO_ROOT)) if raw_path.exists() else None,
        "totals": {
            "valid_records": valid_count,
            "error_records": error_count,
            "total_records": len(records),
        },
        "per_endpoint": per_endpoint,
        "kmeans": kmeans,
        "verdict": verdict,
    }

    text = json.dumps(summary, indent=2, sort_keys=False) + "\n"
    if args.print_only:
        print(text)
    else:
        summary_path.parent.mkdir(parents=True, exist_ok=True)
        summary_path.write_text(text, encoding="utf-8")
        print(f"wrote summary: {summary_path.relative_to(REPO_ROOT)}")
        print(f"verdict: status={verdict['status']} clusters_found={verdict.get('clusters_found')} "
              f"best_k={verdict.get('best_k')} silhouette={verdict.get('max_silhouette_score')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
