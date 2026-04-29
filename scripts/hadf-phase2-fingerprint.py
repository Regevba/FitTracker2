#!/usr/bin/env python3
"""
HADF Phase 2 — Cloud Inference Fingerprinting Harness

Collects TTFT/TPS measurements per endpoint by issuing N identical-shape
streaming completions and recording timing from the stream chunks.

Output: appends one JSON object per call to
    .claude/shared/hadf/phase2-fingerprint-raw.jsonl
(gitignored — raw observational data, not committed).

Pre-registration (governs verdict): .claude/shared/hadf/phase2-preregistration.json
Plan: /Users/regevbarak/.claude/plans/floofy-finding-boole.md

Endpoints (configured via --endpoints arg, comma-separated):
    openai     — gpt-4o-mini via OpenAI SDK, requires OPENAI_API_KEY
    anthropic  — claude-haiku-4-5-20251001 via Anthropic SDK, requires ANTHROPIC_API_KEY
    local      — Ollama at OLLAMA_HOST (default http://localhost:11434), model OLLAMA_MODEL

Usage:
    # one quick verification run (50 calls per endpoint, ~$0.05)
    python3 scripts/hadf-phase2-fingerprint.py --endpoints openai,anthropic,local --runs 1

    # full collection campaign (run from cron/launchd 5x/day for 3 days)
    python3 scripts/hadf-phase2-fingerprint.py --endpoints openai,anthropic,local --runs 1 --tag morning
"""

from __future__ import annotations

import argparse
import json
import os
import random
import string
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_PATH = REPO_ROOT / ".claude" / "shared" / "hadf" / "phase2-fingerprint-raw.jsonl"
PREREG_PATH = REPO_ROOT / ".claude" / "shared" / "hadf" / "phase2-preregistration.json"

NONCE_WORDS = [
    "lantern", "river", "compass", "harvest", "ember", "whistle", "anvil",
    "thicket", "gravel", "pylon", "marble", "trellis", "nettle", "satchel",
    "beacon", "cobalt", "drizzle", "fennel", "garnet", "hollow", "ivory",
    "juniper", "kestrel", "linnet", "meadow", "nimbus", "obsidian", "parsley",
    "quartz", "rookery", "sable", "tallow", "umber", "verbena", "willow",
    "xerus", "yarrow", "zephyr", "almanac", "barley", "clover", "dapple",
]

PROMPT_TEMPLATE = "Write one paragraph (3-5 sentences) about the word: {nonce}."


def random_nonce() -> str:
    """Random English-ish noun. Falls back to gibberish if word list exhausted."""
    if NONCE_WORDS:
        return random.choice(NONCE_WORDS)
    return "".join(random.choices(string.ascii_lowercase, k=8))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def append_raw(record: dict) -> None:
    RAW_PATH.parent.mkdir(parents=True, exist_ok=True)
    with RAW_PATH.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, separators=(",", ":")) + "\n")


# ---------- Endpoint adapters ----------

def call_openai(prompt: str, max_tokens: int, temperature: float) -> dict:
    """Returns timing dict or raises.

    Uses `with OpenAI(...)` and `with ...stream` to guarantee socket cleanup
    after each call. Without these, openai-python issue #763 leaves the TCP
    socket in CLOSE_WAIT and the next streaming call hangs on socket.recv_into.
    """
    try:
        from openai import OpenAI  # type: ignore
    except ImportError as e:
        raise RuntimeError("openai SDK not installed (pip install openai)") from e

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not set")

    model = "gpt-4o-mini"
    first_token_at: float | None = None
    output_tokens = 0
    full_text_parts: list[str] = []

    request_sent = time.perf_counter()
    with OpenAI(api_key=api_key) as client:
        with client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=max_tokens,
            temperature=temperature,
            stream=True,
        ) as stream:
            for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta
                content = getattr(delta, "content", None)
                if content:
                    if first_token_at is None:
                        first_token_at = time.perf_counter()
                    full_text_parts.append(content)
                    output_tokens += 1
    end_at = time.perf_counter()

    # OpenAI streaming does not return final usage by default; approximate via word count.
    if output_tokens == 0:
        output_tokens = max(1, len("".join(full_text_parts).split()))

    if first_token_at is None:
        raise RuntimeError("openai stream produced no content tokens")

    ttft_ms = (first_token_at - request_sent) * 1000.0
    decode_seconds = max(end_at - first_token_at, 1e-6)
    tps = output_tokens / decode_seconds
    return {
        "model": model,
        "ttft_ms": ttft_ms,
        "tps": tps,
        "total_latency_ms": (end_at - request_sent) * 1000.0,
        "output_tokens": output_tokens,
    }


def call_anthropic(prompt: str, max_tokens: int, temperature: float) -> dict:
    try:
        import anthropic  # type: ignore
    except ImportError as e:
        raise RuntimeError("anthropic SDK not installed (pip install anthropic)") from e

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set")

    model = "claude-haiku-4-5-20251001"
    first_token_at: float | None = None
    output_tokens = 0
    final_message = None

    request_sent = time.perf_counter()
    with anthropic.Anthropic(api_key=api_key) as client:
        with client.messages.stream(
            model=model,
            max_tokens=max_tokens,
            temperature=temperature,
            messages=[{"role": "user", "content": prompt}],
        ) as stream:
            for chunk in stream.text_stream:
                if chunk:
                    if first_token_at is None:
                        first_token_at = time.perf_counter()
                    output_tokens += 1  # chunk approximation
            final_message = stream.get_final_message()
    end_at = time.perf_counter()

    # Anthropic returns usage in the final message — prefer real count.
    if final_message and getattr(final_message, "usage", None):
        usage_out = getattr(final_message.usage, "output_tokens", None)
        if usage_out:
            output_tokens = usage_out

    if first_token_at is None:
        raise RuntimeError("anthropic stream produced no content tokens")

    ttft_ms = (first_token_at - request_sent) * 1000.0
    decode_seconds = max(end_at - first_token_at, 1e-6)
    tps = output_tokens / decode_seconds
    return {
        "model": model,
        "ttft_ms": ttft_ms,
        "tps": tps,
        "total_latency_ms": (end_at - request_sent) * 1000.0,
        "output_tokens": output_tokens,
    }


def call_local(prompt: str, max_tokens: int, temperature: float) -> dict:
    """Ollama streaming. Requires `ollama serve` running locally."""
    try:
        import urllib.request
    except ImportError as e:  # stdlib, but defensive
        raise RuntimeError("urllib unavailable") from e

    host = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
    model = os.environ.get("OLLAMA_MODEL", "llama3.2:3b")
    url = host.rstrip("/") + "/api/generate"
    body = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": True,
        "options": {
            "temperature": temperature,
            "num_predict": max_tokens,
        },
    }).encode("utf-8")

    request_sent = time.perf_counter()
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})

    first_token_at: float | None = None
    output_tokens = 0

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            for line in resp:
                if not line:
                    continue
                try:
                    obj = json.loads(line.decode("utf-8"))
                except json.JSONDecodeError:
                    continue
                token = obj.get("response", "")
                if token:
                    if first_token_at is None:
                        first_token_at = time.perf_counter()
                    output_tokens += 1
                if obj.get("done"):
                    eval_count = obj.get("eval_count")
                    if eval_count:
                        output_tokens = eval_count
                    break
    except Exception as e:
        raise RuntimeError(f"ollama call failed: {e}") from e

    end_at = time.perf_counter()

    if first_token_at is None:
        raise RuntimeError("ollama stream produced no content tokens")

    ttft_ms = (first_token_at - request_sent) * 1000.0
    decode_seconds = max(end_at - first_token_at, 1e-6)
    tps = output_tokens / decode_seconds
    return {
        "model": model,
        "ttft_ms": ttft_ms,
        "tps": tps,
        "total_latency_ms": (end_at - request_sent) * 1000.0,
        "output_tokens": output_tokens,
    }


ENDPOINTS = {
    "openai": call_openai,
    "anthropic": call_anthropic,
    "local": call_local,
}


# ---------- Run loop ----------

def run_one(endpoint: str, run_id: str, tag: str, max_tokens: int, temperature: float, call_idx: int = 0, total: int = 0) -> dict:
    nonce = random_nonce()
    prompt = PROMPT_TEMPLATE.format(nonce=nonce)
    record_base = {
        "call_id": str(uuid.uuid4()),
        "run_id": run_id,
        "tag": tag,
        "endpoint": endpoint,
        "prompt_nonce": nonce,
        "timestamp_utc": now_iso(),
    }
    progress = f"[{call_idx}/{total}]" if total else ""
    print(f"  -> {progress} {endpoint:10s} ...", file=sys.stderr, flush=True, end="")
    t_start = time.perf_counter()
    try:
        timing = ENDPOINTS[endpoint](prompt, max_tokens, temperature)
        record = {**record_base, "ok": True, **timing}
        elapsed = time.perf_counter() - t_start
        print(f"\r  <- {progress} {endpoint:10s} OK   {elapsed:5.2f}s ttft={timing.get('ttft_ms', 0):.0f}ms tps={timing.get('tps', 0):.1f}",
              file=sys.stderr, flush=True)
    except Exception as e:
        record = {**record_base, "ok": False, "error": str(e)}
        elapsed = time.perf_counter() - t_start
        print(f"\r  <- {progress} {endpoint:10s} ERR  {elapsed:5.2f}s {str(e)[:80]}",
              file=sys.stderr, flush=True)
    append_raw(record)
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description="HADF Phase 2 fingerprinting harness")
    parser.add_argument("--endpoints", default="openai,anthropic,local",
                        help="comma-separated subset of {openai,anthropic,local}")
    parser.add_argument("--runs", type=int, default=1,
                        help="number of 'runs' to execute in this invocation; one run = N calls per endpoint")
    parser.add_argument("--calls-per-run", type=int, default=50,
                        help="calls per endpoint per run (preregistration default: 50)")
    parser.add_argument("--max-tokens", type=int, default=200)
    parser.add_argument("--temperature", type=float, default=0.7)
    parser.add_argument("--tag", default="adhoc",
                        help="free-form tag stored on each record (e.g. 'morning', 'verification')")
    parser.add_argument("--seed", type=int, default=None,
                        help="seed nonces for reproducibility (omit for normal runs)")
    parser.add_argument("--dry-run", action="store_true",
                        help="validate config and SDK availability, write nothing")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    requested = [e.strip() for e in args.endpoints.split(",") if e.strip()]
    unknown = [e for e in requested if e not in ENDPOINTS]
    if unknown:
        print(f"unknown endpoints: {unknown}; known: {list(ENDPOINTS)}", file=sys.stderr)
        return 2

    if not PREREG_PATH.exists():
        print(f"missing preregistration at {PREREG_PATH} — refusing to collect data without it",
              file=sys.stderr)
        return 3

    if args.dry_run:
        print(f"dry-run ok. endpoints={requested} runs={args.runs} calls_per_run={args.calls_per_run}")
        return 0

    total_calls = 0
    total_errors = 0
    started_at = time.perf_counter()
    grand_total = args.runs * len(requested) * args.calls_per_run
    print(f"running {grand_total} calls ({args.runs} runs x {len(requested)} endpoints x {args.calls_per_run} calls)",
          file=sys.stderr, flush=True)

    call_idx = 0
    for run_idx in range(args.runs):
        run_id = f"{now_iso()}--{uuid.uuid4().hex[:8]}"
        for endpoint in requested:
            for _ in range(args.calls_per_run):
                call_idx += 1
                rec = run_one(endpoint, run_id, args.tag, args.max_tokens, args.temperature,
                              call_idx=call_idx, total=grand_total)
                total_calls += 1
                if not rec.get("ok"):
                    total_errors += 1

    elapsed = time.perf_counter() - started_at
    print(f"done: {total_calls} calls, {total_errors} errors, {elapsed:.1f}s elapsed")
    print(f"appended to: {RAW_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
