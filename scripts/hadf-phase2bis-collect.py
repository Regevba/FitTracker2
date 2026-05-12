"""HADF Phase 2-bis collection driver. Called by hadf-phase2bis-collect.sh after preflight.

Per spec §2 + §4: 50 calls per endpoint, max_output_tokens=200, temp=0.7,
60s timeout (600s for Ollama), streaming required, no system prompt, no tools.

Writes raw .jsonl atomically (Fix #4): one line per call with TTFT, TPS, total_tokens, status.

NOTE: This is a SCAFFOLD per the implementation plan. Provider-specific call code
is stubbed pending operator API key + endpoint verification at smoke-fire time (Task A5).
The full driver is filled in iteratively during the soak window (post-A5).
"""
import argparse
import json
import sys
import time
from pathlib import Path

# Endpoint matrices per sub-exp (spec §2)
ENDPOINTS = {
    "subexp1": [
        ("openai", "gpt-4o-mini", "direct"),
        ("openai", "gpt-4o", "direct"),
        ("anthropic", "claude-haiku-4-5", "direct"),
        ("anthropic", "claude-sonnet-4-6", "direct"),
        ("google", "gemini-2-flash", "direct"),
        ("google", "gemini-2-pro", "direct"),
        ("vercel-ai-gateway", "gpt-4o-mini", "gateway"),
        ("mistral", "mistral-large-latest", "direct"),
        ("xai", "grok-4-1", "direct"),
    ],
    "subexp2": [
        ("ollama", "llama3.2:3b", "local"),
    ],
    "subexp3": [
        ("openai", "gpt-4o-mini", "direct"),
        ("anthropic", "claude-haiku-4-5", "direct"),
        ("aws-bedrock", "anthropic.claude-haiku-4-5", "bedrock"),
    ],
}

CALLS_PER_FIRE = 50
MAX_OUTPUT_TOKENS = 200
TEMPERATURE = 0.7
TIMEOUT_S = 60
OLLAMA_TIMEOUT_S = 600


def call_endpoint(provider, endpoint, prompt):
    """Stub. Replaced with provider-specific code post-A5 smoke-fire verification."""
    raise NotImplementedError(
        f"Provider call code not yet implemented for {provider}/{endpoint}. "
        "Filled in iteratively during soak window after Task A5 smoke-fire passes."
    )


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--subexp", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--raw-out", required=True)
    args = p.parse_args()

    if args.subexp not in ENDPOINTS:
        print(f"unknown sub-exp: {args.subexp}", file=sys.stderr)
        sys.exit(2)

    raw_path = Path(args.raw_out)
    raw_path.parent.mkdir(parents=True, exist_ok=True)

    # Load frozen prompt set (created in Task A5b — smoke-fire prerequisite)
    prompt_set_path = Path(__file__).parent.parent / ".claude/shared/hadf/phase2bis-prompt-set.json"
    if not prompt_set_path.exists():
        print(f"prompt set not found: {prompt_set_path}", file=sys.stderr)
        print("Run Task A5 to scaffold + freeze the 50-prompt set", file=sys.stderr)
        sys.exit(2)
    prompts = json.loads(prompt_set_path.read_text())["prompts"]
    assert len(prompts) == CALLS_PER_FIRE, f"prompt set must have exactly {CALLS_PER_FIRE} entries"

    # Atomic write: tmp file + rename
    tmp_path = raw_path.with_suffix(raw_path.suffix + ".tmp")
    written = 0
    with tmp_path.open("w") as f:
        for provider, endpoint, api_kind in ENDPOINTS[args.subexp]:
            for i, prompt in enumerate(prompts):
                t_start = time.time()
                try:
                    result = call_endpoint(provider, endpoint, prompt)
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "api_kind": api_kind,
                        "prompt_idx": i,
                        "ttft_s": result["ttft_s"],
                        "tps": result["tps"],
                        "output_tokens": result["output_tokens"],
                        "total_s": time.time() - t_start,
                        "status": "ok",
                    }
                except NotImplementedError as e:
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "prompt_idx": i,
                        "status": "stub",
                        "error": str(e),
                    }
                except Exception as e:
                    record = {
                        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "subexp": args.subexp,
                        "run_id": args.run_id,
                        "provider": provider,
                        "endpoint": endpoint,
                        "prompt_idx": i,
                        "status": "error",
                        "error": str(e),
                    }
                f.write(json.dumps(record) + "\n")
                written += 1
    # Atomic rename (Fix #4: raw-data preservation never partially-written)
    tmp_path.replace(raw_path)
    print(f"wrote {written} records to {raw_path}")


if __name__ == "__main__":
    main()
