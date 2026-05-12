"""HADF Phase 2-bis cost estimator. Reads provider-rates.json + per-call params -> $ estimate.

Usage:
    python3 scripts/hadf-cost-estimate.py \
      --provider openai --endpoint gpt-4o-mini \
      --calls 50 --avg-output-tokens 200 [--avg-input-tokens 100]
"""
import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RATES_PATH = REPO_ROOT / ".claude/shared/hadf/provider-rates.json"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True)
    p.add_argument("--endpoint", required=True)
    p.add_argument("--calls", type=int, required=True)
    p.add_argument("--avg-output-tokens", type=int, required=True)
    p.add_argument("--avg-input-tokens", type=int, default=100)
    args = p.parse_args()

    rates = json.loads(RATES_PATH.read_text())["rates"]
    if args.provider not in rates:
        print(f"unknown provider: {args.provider}", file=sys.stderr)
        sys.exit(2)
    if args.endpoint not in rates[args.provider]:
        print(f"unknown endpoint for {args.provider}: {args.endpoint}", file=sys.stderr)
        sys.exit(2)

    rate = rates[args.provider][args.endpoint]
    total_input_tokens = args.calls * args.avg_input_tokens
    total_output_tokens = args.calls * args.avg_output_tokens
    cost = (total_input_tokens / 1_000_000) * rate["input"] + \
           (total_output_tokens / 1_000_000) * rate["output"]
    print(f"{cost:.6f}")

if __name__ == "__main__":
    main()
