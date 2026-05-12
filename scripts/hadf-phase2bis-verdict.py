"""Per-sub-exp verdict computation per spec §10.

Loads all phase2bis-raw-<subexp>-*.jsonl files in --raw-dir,
filters status=='ok', computes silhouette score at k=5 over (ttft_s, tps),
checks against pre-registered thresholds → emits PASS/FAIL/INCONCLUSIVE.
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

def load_records(raw_dir):
    records = []
    for path in Path(raw_dir).glob("*.jsonl"):
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

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw-dir", required=True)
    p.add_argument("--subexp", required=True)
    p.add_argument("--silhouette-min", type=float, default=0.5)
    p.add_argument("--yield-min", type=int, default=600)
    p.add_argument("--clusters-min", type=int, default=3)
    p.add_argument("--k", type=int, default=5)
    args = p.parse_args()

    records = load_records(args.raw_dir)
    n_valid = len(records)

    if n_valid < args.yield_min:
        print(json.dumps({
            "subexp": args.subexp,
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

if __name__ == "__main__":
    main()
