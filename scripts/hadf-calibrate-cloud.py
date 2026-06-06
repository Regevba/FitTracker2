#!/usr/bin/env python3
"""HADF signature-expansion T6 — cloud-endpoint calibration harness.

Calibrates NEW cloud endpoints into reference-signatures.json as `instrumented`
`class:cloud` rows, reusing the proven per-provider streaming call functions from
`hadf-phase2bis-collect.py` (the Sub-exp collector). Each candidate is pre-probed
with one call; unreachable / bad-model-id / rate-limited candidates are dropped
(no fabricated row — an instrumented row must have real measured samples).

Usage:
    hadf-calibrate-cloud.py --endpoint openai:gpt-4.1-mini --endpoint google:gemini-2.5-flash \
        --n 80 [--env-file <path/.env.local>] [--out <reference-signatures.json>] [--as-of YYYY-MM-DD]

Providers: openai, anthropic, google, xai, mistral, vercel-ai-gateway, aws-bedrock.
Keys are read from --env-file (default: the Sub-exp impl worktree .env.local).
"""
import argparse
import importlib.util
import json
import os
import sys

try:
    import numpy as np
except ImportError:
    print("ERROR: numpy required", file=sys.stderr)
    sys.exit(2)

COLLECTOR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hadf-phase2bis-collect.py")
DEFAULT_ENV = "/Volumes/DevSSD/FitTracker2-feature-hadf-phase2bis-impl/.env.local"
PROMPT = "In one sentence, describe a productive morning routine."
TIMEOUT = 60

# openai-compatible base URLs (provider -> base_url). Mistral is routed here too,
# matching the Sub-exp collector's proven dispatch (api.mistral.ai/v1), not _call_mistral.
OPENAI_COMPAT = {
    "openai": "https://api.openai.com/v1",
    "xai": "https://api.x.ai/v1",
    "vercel-ai-gateway": "https://ai-gateway.vercel.sh/v1",
    "mistral": "https://api.mistral.ai/v1",
}
OPENAI_COMPAT_KEY = {
    "openai": "OPENAI_API_KEY", "xai": "XAI_API_KEY",
    "vercel-ai-gateway": "VERCEL_AI_GATEWAY_API_KEY", "mistral": "MISTRAL_API_KEY",
}


def load_env(path):
    if not os.path.exists(path):
        print(f"ERROR: env file not found: {path}", file=sys.stderr)
        sys.exit(1)
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def load_collector():
    spec = importlib.util.spec_from_file_location("hadf_collect", COLLECTOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def call(mod, provider, model):
    """Dispatch one streaming call; return {ttft_s, tps, ...} or raise."""
    if provider in OPENAI_COMPAT:
        return mod._call_openai_compat(os.environ[OPENAI_COMPAT_KEY[provider]], OPENAI_COMPAT[provider], model, PROMPT, TIMEOUT)
    if provider == "anthropic":
        return mod._call_anthropic(os.environ["ANTHROPIC_API_KEY"], model, PROMPT, TIMEOUT)
    if provider == "google":
        return mod._call_google(os.environ["GOOGLE_API_KEY"], model, PROMPT, TIMEOUT)
    if provider == "aws-bedrock":
        return mod._call_bedrock(model, PROMPT, TIMEOUT, os.environ.get("AWS_REGION", "us-east-1"))
    raise ValueError(f"unknown provider {provider}")


def quantiles(xs):
    a = np.array(xs)
    q = np.percentile(a, [5, 25, 50, 75, 95])
    return {"p05": round(float(q[0]), 6), "p25": round(float(q[1]), 6),
            "median": round(float(q[2]), 6), "p75": round(float(q[3]), 6),
            "p95": round(float(q[4]), 6), "mean": round(float(a.mean()), 6),
            "std": round(float(a.std()), 6)}


def upsert(out_path, row):
    store = json.load(open(out_path)) if os.path.exists(out_path) else {"schema_version": 1, "endpoints": []}
    eps = store.setdefault("endpoints", [])
    key = (row["provider"], row["endpoint"])
    eps[:] = [e for e in eps if (e.get("provider"), e.get("endpoint")) != key]
    eps.append(row)
    store["endpoint_count"] = len(eps)
    json.dump(store, open(out_path, "w"), indent=2)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--endpoint", action="append", required=True, dest="endpoints",
                   help="provider:model, e.g. openai:gpt-4.1-mini (repeatable)")
    p.add_argument("--n", type=int, default=80)
    p.add_argument("--env-file", default=DEFAULT_ENV)
    p.add_argument("--out", default=".claude/shared/hadf/reference-signatures.json")
    p.add_argument("--as-of", default=None)
    p.add_argument("--min-valid", type=int, default=50)
    args = p.parse_args()

    load_env(args.env_file)
    mod = load_collector()

    written, skipped = [], []
    for spec in args.endpoints:
        provider, model = spec.split(":", 1)
        # pre-probe (1 call) — drop unreachable / bad-model / rate-limited candidates
        try:
            call(mod, provider, model)
        except Exception as e:  # noqa: BLE001
            print(f"SKIP {spec}: pre-probe failed ({str(e)[:120]})", file=sys.stderr)
            skipped.append({"endpoint": spec, "reason": str(e)[:160]})
            continue
        ttfts, tpss = [], []
        for i in range(args.n):
            try:
                r = call(mod, provider, model)
                if r["tps"] > 0:
                    ttfts.append(r["ttft_s"])
                    tpss.append(r["tps"])
            except Exception as e:  # noqa: BLE001 — soft per-call failure (rate limit etc.)
                print(f"  {spec} call {i} failed: {str(e)[:80]}", file=sys.stderr)
            if (i + 1) % 20 == 0:
                print(f"  {spec} {i + 1}/{args.n} ({len(ttfts)} valid)", file=sys.stderr)
        if len(ttfts) < args.min_valid:
            print(f"SKIP {spec}: only {len(ttfts)} valid (< {args.min_valid})", file=sys.stderr)
            skipped.append({"endpoint": spec, "reason": f"only {len(ttfts)} valid"})
            continue
        X = np.column_stack([ttfts, tpss])
        cov = np.cov(X.T)
        row = {
            "provider": provider, "endpoint": model, "n": len(ttfts),
            "ttft_s": quantiles(ttfts), "tps": quantiles(tpss),
            "mean": [round(float(X.mean(0)[0]), 6), round(float(X.mean(0)[1]), 6)],
            "cov": [[round(float(cov[0][0]), 6), round(float(cov[0][1]), 6)],
                    [round(float(cov[1][0]), 6), round(float(cov[1][1]), 6)]],
            "provenance": {"method": "hadf-calibrate-cloud", "as_of": args.as_of or "unspecified",
                           "n_requested": args.n, "n_valid": len(ttfts)},
            "calibration_status": "instrumented", "class": "cloud",
        }
        upsert(args.out, row)
        written.append({"endpoint": spec, "n_valid": len(ttfts),
                        "ttft_median": row["ttft_s"]["median"], "tps_median": row["tps"]["median"]})
        print(f"  WROTE {spec}: n={len(ttfts)} ttft_med={row['ttft_s']['median']:.3f} tps_med={row['tps']['median']:.1f}", file=sys.stderr)

    print(json.dumps({"written": written, "skipped": skipped}, indent=2))


if __name__ == "__main__":
    main()
