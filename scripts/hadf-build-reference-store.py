#!/usr/bin/env python3
"""HADF Phase 3A — Reference-signature store builder (T1).

Reads the locked sub-experiment raw `.jsonl` data and materializes a per-endpoint
reference-distribution catalog at `.claude/shared/hadf/reference-signatures.json`.
This is the read-only baseline the sensing layer (attestation + drift monitor)
compares live traffic against. It makes NO dispatch decisions — Phase 3A is
detection/observability only; the acting/routing layer is gated on RQ4 (Phase 3B).

Each reference entry is keyed by (provider, endpoint) and records the TTFT/TPS
marginal quantiles, the 2-D mean + covariance (for Mahalanobis attestation), n,
and provenance (which sub-exps + source files contributed). Built from the closed
HADF Phase 2-bis collections (all 4 sub-exps PASS, 2026-06-05).

Usage:
    hadf-build-reference-store.py --raw-dir <dir> [--raw-dir <dir> ...] \
        [--out .claude/shared/hadf/reference-signatures.json] [--as-of YYYY-MM-DD]
"""
import argparse
import glob
import json
import os
import sys
from collections import defaultdict

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy required (pip install -r scripts/requirements-hadf-phase2.txt)", file=sys.stderr)
    sys.exit(2)

SCHEMA_VERSION = 1


def load_valid(raw_dirs):
    """Yield (provider, endpoint, ttft_s, tps, source_file) for status==ok records."""
    seen_files = set()
    for d in raw_dirs:
        for f in sorted(glob.glob(os.path.join(d, "phase2bis-raw-*.jsonl"))):
            base = os.path.basename(f)
            if base in seen_files:  # de-dupe identical filenames across mirrored dirs
                continue
            seen_files.add(base)
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
                ttft, tps = r.get("ttft_s"), r.get("tps")
                if prov and ep and ttft is not None and tps is not None:
                    yield prov, ep, float(ttft), float(tps), base


def quantiles(xs):
    a = np.array(xs)
    q = np.percentile(a, [5, 25, 50, 75, 95])
    return {"p05": round(float(q[0]), 6), "p25": round(float(q[1]), 6),
            "median": round(float(q[2]), 6), "p75": round(float(q[3]), 6),
            "p95": round(float(q[4]), 6), "mean": round(float(a.mean()), 6),
            "std": round(float(a.std()), 6)}


def subexp_of(filename):
    # phase2bis-raw-<subexp>-<rest>.jsonl
    parts = filename.split("-")
    return parts[2] if len(parts) > 2 else "?"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw-dir", action="append", required=True, dest="raw_dirs")
    p.add_argument("--out", default=".claude/shared/hadf/reference-signatures.json")
    p.add_argument("--as-of", default=None, help="ISO date stamp (avoids nondeterministic now())")
    p.add_argument("--min-n", type=int, default=50,
                   help="exclude endpoints with fewer than this many valid records "
                        "(filters rate-limited partials, e.g. the v1 1B mistral/vercel 429 runs)")
    p.add_argument("--max-ttft", type=float, default=30.0,
                   help="drop records whose TTFT exceeds this many seconds as connection-stall / "
                        "retry artifacts (NOT streaming-latency samples). Default 30s drops only "
                        "the Sub-exp 1B Fire-0 launch-probe stalls (995s/886s/124s) whose variance "
                        "would otherwise swallow the per-endpoint covariance.")
    args = p.parse_args()

    ttft = defaultdict(list)
    tps = defaultdict(list)
    sources = defaultdict(set)
    subexps = defaultdict(set)
    dropped = defaultdict(int)
    for prov, ep, t, s, src in load_valid(args.raw_dirs):
        key = (prov, ep)
        if t > args.max_ttft:
            dropped[key] += 1
            continue
        ttft[key].append(t)
        tps[key].append(s)
        sources[key].add(src)
        subexps[key].add(subexp_of(src))

    if not ttft:
        print("ERROR: no valid records found in raw-dirs", file=sys.stderr)
        sys.exit(1)

    endpoints = []
    excluded = []
    for key in sorted(ttft):
        prov, ep = key
        if len(ttft[key]) < args.min_n:
            excluded.append({"provider": prov, "endpoint": ep, "n": len(ttft[key])})
            continue
        X = np.column_stack([ttft[key], tps[key]])
        cov = np.cov(X.T)
        endpoints.append({
            "provider": prov,
            "endpoint": ep,
            "n": len(ttft[key]),
            "ttft_s": quantiles(ttft[key]),
            "tps": quantiles(tps[key]),
            "mean": [round(float(X.mean(0)[0]), 6), round(float(X.mean(0)[1]), 6)],
            "cov": [[round(float(cov[0][0]), 6), round(float(cov[0][1]), 6)],
                    [round(float(cov[1][0]), 6), round(float(cov[1][1]), 6)]],
            "provenance": {"sub_exps": sorted(subexps[key]), "n_source_files": len(sources[key]),
                           "dropped_implausible_ttft": dropped.get(key, 0)},
        })

    store = {
        "schema_version": SCHEMA_VERSION,
        "built_as_of": args.as_of or "unspecified",
        "source": "HADF Phase 2-bis closed collections (Sub-exps 1/2/3/1B, all PASS 2026-06-05)",
        "note": ("Sensing-layer reference baseline. Detection/observability ONLY — "
                 "no dispatch decisions (acting layer gated on RQ4 / Phase 3B)."),
        "endpoint_count": len(endpoints),
        "min_n": args.min_n,
        "max_ttft_s": args.max_ttft,
        "dropped_implausible_ttft_total": sum(dropped.values()),
        "excluded_low_n": excluded,
        "endpoints": endpoints,
    }
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    json.dump(store, open(args.out, "w"), indent=2)
    print(f"wrote {args.out}: {len(endpoints)} endpoints, "
          f"{sum(e['n'] for e in endpoints)} total valid records")


if __name__ == "__main__":
    main()
