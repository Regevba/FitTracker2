#!/usr/bin/env python3
"""HADF Phase 3A — Backend attestation (T2, ADVISORY).

Given an observed streaming sample (ttft_s, tps), score similarity to each
reference endpoint in `reference-signatures.json` (Mahalanobis distance, same
math as the Sub-exp 3 verdict) and report the best match + a confidence band.

ADVISORY ONLY. Per-request single-shot classification accuracy is unvalidated
(that is RQ5, Phase 3B). Output ALWAYS carries a confidence band and an
"uncertain" disposition when no endpoint is a clear match — never present this
as authoritative, and never route on it (the acting layer is gated on RQ4).

Usage:
    hadf-attest.py --ttft 1.47 --tps 170 [--store .claude/shared/hadf/reference-signatures.json]
    hadf-attest.py --jsonl <file>   # attest each ok record, print summary
"""
import argparse
import json
import sys

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy required", file=sys.stderr)
    sys.exit(2)

# Mahalanobis distance bands → confidence. <2σ = strong, 2-4σ = weak, >4σ = none.
STRONG, WEAK = 2.0, 4.0


def mahalanobis(point, mean, cov):
    diff = np.array(point) - np.array(mean)
    ridge = 1e-9 * np.trace(cov) * np.eye(2)
    cinv = np.linalg.pinv(np.array(cov) + ridge)
    return float(np.sqrt(diff @ cinv @ diff))


def attest(ttft, tps, store):
    scored = []
    for e in store["endpoints"]:
        d = mahalanobis([ttft, tps], e["mean"], e["cov"])
        scored.append((d, e["provider"], e["endpoint"]))
    scored.sort()
    best_d, prov, ep = scored[0]
    second_d = scored[1][0] if len(scored) > 1 else float("inf")
    # confidence: close to best AND clearly closer than 2nd-best
    if best_d <= STRONG and second_d - best_d >= 1.0:
        band, disp = "strong", f"{prov}/{ep}"
    elif best_d <= WEAK:
        band, disp = "weak", f"{prov}/{ep}"
    else:
        band, disp = "uncertain", "unknown / unseen substrate"
    return {
        "observed": {"ttft_s": ttft, "tps": tps},
        "attestation": disp,
        "confidence_band": band,
        "best_distance_sigma": round(best_d, 3),
        "second_best_sigma": round(second_d, 3),
        "advisory": True,
        "caveat": "Single-shot accuracy unvalidated (RQ5). Do NOT route on this. Detection-only.",
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--store", default=".claude/shared/hadf/reference-signatures.json")
    p.add_argument("--ttft", type=float)
    p.add_argument("--tps", type=float)
    p.add_argument("--jsonl", help="attest each status=ok record in a raw .jsonl file")
    args = p.parse_args()
    store = json.load(open(args.store))

    if args.jsonl:
        from collections import Counter
        bands, hits, total = Counter(), Counter(), 0
        for line in open(args.jsonl):
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            if r.get("status") != "ok":
                continue
            total += 1
            res = attest(r["ttft_s"], r["tps"], store)
            bands[res["confidence_band"]] += 1
            if res["confidence_band"] in ("strong", "weak"):
                hits[res["attestation"]] += 1
        print(json.dumps({"n": total, "bands": dict(bands), "top_attestations": dict(hits.most_common(5))}, indent=2))
    elif args.ttft is not None and args.tps is not None:
        print(json.dumps(attest(args.ttft, args.tps, store), indent=2))
    else:
        p.error("provide --ttft + --tps, or --jsonl")


if __name__ == "__main__":
    main()
