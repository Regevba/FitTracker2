#!/usr/bin/env python3
"""HADF signature-expansion T3 — on-device calibration harness.

Generalizes Sub-exp 2 (ollama-on-M2) into a reusable per-chip runner: stream N
completions from a LOCAL inference endpoint, measure per-request TTFT + TPS,
aggregate with the same math the cloud reference-store builder uses, and emit ONE
`instrumented` `class:on_device` row into reference-signatures.json.

This is the honest answer to "expand HADF into new chip families": the *mechanism*
to calibrate a real signature for any chip the operator physically has — not a
fabricated spec-sheet row. A chip you can't run on doesn't get an instrumented row.

Usage:
    hadf-calibrate-device.py --device-label apple_m4 --model llama3.2:3b --n 250 \
        [--endpoint-url http://localhost:11434/api/generate] \
        [--prompt "..."] [--out .claude/shared/hadf/reference-signatures.json] [--as-of YYYY-MM-DD]

The --endpoint-url default targets ollama. Any server speaking the ollama
streaming JSON-lines protocol works; tests point it at a stdlib http.server mock.
"""
import argparse
import json
import os
import sys
import time
import urllib.request

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy required", file=sys.stderr)
    sys.exit(2)

DEFAULT_URL = "http://localhost:11434/api/generate"
DEFAULT_PROMPT = "In one sentence, describe a productive morning routine."


def quantiles(xs):
    a = np.array(xs)
    q = np.percentile(a, [5, 25, 50, 75, 95])
    return {"p05": round(float(q[0]), 6), "p25": round(float(q[1]), 6),
            "median": round(float(q[2]), 6), "p75": round(float(q[3]), 6),
            "p95": round(float(q[4]), 6), "mean": round(float(a.mean()), 6),
            "std": round(float(a.std()), 6)}


def stream_one(url, model, prompt, timeout=60):
    """Return (ttft_s, tps) for one streaming generation, or None on failure."""
    body = json.dumps({"model": model, "prompt": prompt, "stream": True}).encode()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    t0 = time.monotonic()
    ttft = None
    n_tokens = 0
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            for line in resp:
                line = line.strip()
                if not line:
                    continue
                try:
                    chunk = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if chunk.get("response"):
                    if ttft is None:
                        ttft = time.monotonic() - t0  # time to first token
                    n_tokens += 1
                if chunk.get("done"):
                    break
    except Exception as e:  # noqa: BLE001 — network/host errors are per-request soft failures
        print(f"  request failed: {e}", file=sys.stderr)
        return None
    total = time.monotonic() - t0
    if ttft is None or n_tokens == 0 or total <= 0:
        return None
    tps = n_tokens / total
    return ttft, tps


def upsert_endpoint(out_path, row):
    """Idempotent: replace the row for the same (provider, endpoint) or append."""
    if os.path.exists(out_path):
        store = json.load(open(out_path))
    else:
        store = {"schema_version": 1, "endpoints": []}
    eps = store.setdefault("endpoints", [])
    key = (row["provider"], row["endpoint"])
    eps[:] = [e for e in eps if (e.get("provider"), e.get("endpoint")) != key]
    eps.append(row)
    store["endpoint_count"] = len(eps)
    json.dump(store, open(out_path, "w"), indent=2)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--device-label", required=True, help="e.g. apple_m4, apple_a16")
    p.add_argument("--model", required=True, help="local model id, e.g. llama3.2:3b")
    p.add_argument("--n", type=int, default=250, help="number of streaming samples")
    p.add_argument("--endpoint-url", default=DEFAULT_URL)
    p.add_argument("--prompt", default=DEFAULT_PROMPT)
    p.add_argument("--out", default=".claude/shared/hadf/reference-signatures.json")
    p.add_argument("--as-of", default=None)
    p.add_argument("--min-valid", type=int, default=50,
                   help="abort (no write) if fewer than this many valid samples collected")
    args = p.parse_args()

    ttfts, tpss = [], []
    for i in range(args.n):
        r = stream_one(args.endpoint_url, args.model, args.prompt)
        if r is not None:
            ttfts.append(r[0])
            tpss.append(r[1])
        if (i + 1) % 25 == 0:
            print(f"  {i + 1}/{args.n} ({len(ttfts)} valid)", file=sys.stderr)

    if len(ttfts) < args.min_valid:
        print(f"ERROR: only {len(ttfts)} valid samples (< --min-valid {args.min_valid}); "
              f"NOT writing a row — an instrumented row must have real n.", file=sys.stderr)
        sys.exit(1)

    X = np.column_stack([ttfts, tpss])
    cov = np.cov(X.T)
    row = {
        "provider": "on-device",
        "endpoint": args.device_label,
        "n": len(ttfts),
        "ttft_s": quantiles(ttfts),
        "tps": quantiles(tpss),
        "mean": [round(float(X.mean(0)[0]), 6), round(float(X.mean(0)[1]), 6)],
        "cov": [[round(float(cov[0][0]), 6), round(float(cov[0][1]), 6)],
                [round(float(cov[1][0]), 6), round(float(cov[1][1]), 6)]],
        "provenance": {"method": "hadf-calibrate-device", "host": args.device_label,
                       "model": args.model, "as_of": args.as_of or "unspecified",
                       "n_requested": args.n, "n_valid": len(ttfts)},
        "calibration_status": "instrumented",
        "class": "on_device",
    }
    upsert_endpoint(args.out, row)
    print(json.dumps({"wrote": args.device_label, "n_valid": len(ttfts),
                      "ttft_median": row["ttft_s"]["median"], "tps_median": row["tps"]["median"],
                      "out": args.out}, indent=2))


if __name__ == "__main__":
    main()
