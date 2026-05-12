"""KS-test on anchor endpoint distributions between Sub-exp 1 and Sub-exp 3.
If p < 0.01, append methodology note to Sub-exp 3 case study (do NOT abort).
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from scipy import stats
except ImportError:
    print("scipy required: pip install scipy", file=sys.stderr)
    sys.exit(2)

def load_anchor_records(path, provider, endpoint):
    records = []
    for line in Path(path).read_text().splitlines():
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if r.get("provider") == provider and r.get("endpoint") == endpoint and r.get("status") == "ok":
            records.append(r)
    return records

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--sub-exp-1-raw", required=True)
    p.add_argument("--sub-exp-3-raw", required=True)
    p.add_argument("--anchor-provider", required=True)
    p.add_argument("--anchor-endpoint", required=True)
    p.add_argument("--p-threshold", type=float, default=0.01)
    args = p.parse_args()

    s1 = load_anchor_records(args.sub_exp_1_raw, args.anchor_provider, args.anchor_endpoint)
    s3 = load_anchor_records(args.sub_exp_3_raw, args.anchor_provider, args.anchor_endpoint)

    if len(s1) < 30 or len(s3) < 30:
        print(json.dumps({
            "error": f"insufficient samples: s1={len(s1)}, s3={len(s3)}, need ≥30 each",
            "drift_detected": None,
        }))
        sys.exit(2)

    ttft_s1 = [r["ttft_s"] for r in s1]
    ttft_s3 = [r["ttft_s"] for r in s3]
    ttft_stat, ttft_p = stats.ks_2samp(ttft_s1, ttft_s3)

    tps_s1 = [r["tps"] for r in s1]
    tps_s3 = [r["tps"] for r in s3]
    tps_stat, tps_p = stats.ks_2samp(tps_s1, tps_s3)

    # Take the more sensitive (lower p) of the two
    p_value = min(ttft_p, tps_p)

    print(json.dumps({
        "anchor_provider": args.anchor_provider,
        "anchor_endpoint": args.anchor_endpoint,
        "n_subexp1": len(s1),
        "n_subexp3": len(s3),
        "ks_ttft_stat": float(ttft_stat),
        "ks_ttft_p": float(ttft_p),
        "ks_tps_stat": float(tps_stat),
        "ks_tps_p": float(tps_p),
        "ks_p_value": float(p_value),
        "p_threshold": float(args.p_threshold),
        "drift_detected": bool(p_value < args.p_threshold),
    }))

if __name__ == "__main__":
    main()
