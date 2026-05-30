"""HADF Phase 2-bis collection driver. Called by hadf-phase2bis-collect.sh after preflight.

Per spec §2 + §4: 50 calls per endpoint, max_output_tokens=200, temp=0.7,
60s timeout (600s for Ollama), streaming required, no system prompt, no tools.

Writes raw .jsonl atomically (Fix #4): one line per call with TTFT, TPS, total_tokens, status.

Provider-specific streaming code: cloud providers implemented 2026-05-25 (Task A5);
Ollama added 2026-05-28 ahead of Sub-exp 2 launch.
5 unique paths cover all 13 (provider, endpoint, api_kind) tuples across the 3 sub-exps:
  - openai SDK with base_url override → openai direct, vercel-ai-gateway, xai
  - anthropic SDK → anthropic direct
  - google.genai SDK → google direct
  - mistralai SDK → mistral direct
  - urllib + Ollama /api/generate streaming → ollama local (no SDK dep — stdlib only)
  - (aws-bedrock not implemented in this pass — scoped to ship before Sub-exp 3 launch)

Required env vars:
  OPENAI_API_KEY                openai endpoints
  ANTHROPIC_API_KEY             anthropic endpoints
  GOOGLE_API_KEY                google endpoints (or GEMINI_API_KEY fallback)
  MISTRAL_API_KEY               mistral endpoints
  XAI_API_KEY                   xai endpoint (uses openai SDK + base_url override)
  VERCEL_AI_GATEWAY_API_KEY     vercel-ai-gateway endpoint
  VERCEL_AI_GATEWAY_BASE_URL    optional — defaults to https://ai-gateway.vercel.sh/v1
  OLLAMA_BASE_URL               optional — defaults to http://localhost:11434
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

# Endpoint matrices per sub-exp (spec §2)
ENDPOINTS = {
    "subexp1": [
        # 2026-05-25 launch matrix narrowed to original Phase 2 intent
        # (openai + anthropic) per operator decision after smoke-fire revealed:
        # - gemini-2.5-flash + gemini-2.5-pro are reasoning models (different signal class)
        # - mistral/xai/vercel-ai-gateway had placeholder keys
        # Full 9-endpoint matrix (subexp1-full) queued for follow-up Sub-exp 1B after
        # key acquisition + reasoning-model investigation. See docs/master-plan/
        # hadf-phase2bis-key-acquisition-runbook-2026-05-25.md
        ("openai", "gpt-4o-mini", "direct"),
        ("openai", "gpt-4o", "direct"),
        ("anthropic", "claude-haiku-4-5", "direct"),
        ("anthropic", "claude-sonnet-4-6", "direct"),
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


def _measure(stream_iter, first_token_predicate):
    """Drive a streaming iterator, return (ttft_s, total_s, output_tokens_approx).

    first_token_predicate(event) -> True when the event carries the first token.
    output_tokens_approx counts non-empty deltas; final SDKs that return usage
    in the closing event override this in call_*().
    """
    t_start = time.time()
    ttft = None
    output_tokens = 0
    for event in stream_iter:
        if ttft is None and first_token_predicate(event):
            ttft = time.time() - t_start
            output_tokens = 1
        elif ttft is not None:
            output_tokens += 1
    total = time.time() - t_start
    if ttft is None:
        # stream produced 0 deltas — server returned empty or only metadata
        ttft = total
    return ttft, total, output_tokens


def _result(ttft_s, total_s, output_tokens):
    if total_s <= ttft_s or output_tokens <= 1:
        # avoid divide-by-zero; degenerate runs report TPS as 0
        tps = 0.0
    else:
        tps = (output_tokens - 1) / (total_s - ttft_s)
    return {"ttft_s": ttft_s, "tps": tps, "output_tokens": output_tokens}


def _call_openai_compat(api_key, base_url, model, prompt, timeout_s):
    """openai SDK against an OpenAI-compatible API. Covers openai-direct,
    vercel-ai-gateway, and xai (each with a different base_url)."""
    from openai import OpenAI

    client = OpenAI(api_key=api_key, base_url=base_url, timeout=timeout_s)
    stream = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        max_completion_tokens=MAX_OUTPUT_TOKENS,
        temperature=TEMPERATURE,
        stream=True,
        stream_options={"include_usage": True},
    )
    t_start = time.time()
    ttft = None
    output_tokens = 0
    final_usage = None
    for chunk in stream:
        if getattr(chunk, "usage", None) is not None:
            final_usage = chunk.usage
            continue
        choices = getattr(chunk, "choices", None) or []
        if not choices:
            continue
        delta = getattr(choices[0], "delta", None)
        content = getattr(delta, "content", None) if delta else None
        if content:
            if ttft is None:
                ttft = time.time() - t_start
                output_tokens = 1
            else:
                output_tokens += 1
    total = time.time() - t_start
    if ttft is None:
        ttft = total
    # Prefer server-reported usage when available
    if final_usage is not None and getattr(final_usage, "completion_tokens", None):
        output_tokens = final_usage.completion_tokens
    return _result(ttft, total, output_tokens)


def _call_anthropic(api_key, model, prompt, timeout_s):
    """anthropic SDK streaming. Covers anthropic-direct."""
    from anthropic import Anthropic

    client = Anthropic(api_key=api_key, timeout=timeout_s)
    t_start = time.time()
    ttft = None
    output_tokens = 0
    final_usage = None
    with client.messages.stream(
        model=model,
        max_tokens=MAX_OUTPUT_TOKENS,
        temperature=TEMPERATURE,
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        for text in stream.text_stream:
            if text:
                if ttft is None:
                    ttft = time.time() - t_start
                    output_tokens = 1
                else:
                    output_tokens += 1
        final_message = stream.get_final_message()
        final_usage = getattr(final_message, "usage", None)
    total = time.time() - t_start
    if ttft is None:
        ttft = total
    if final_usage is not None and getattr(final_usage, "output_tokens", None):
        output_tokens = final_usage.output_tokens
    return _result(ttft, total, output_tokens)


def _call_google(api_key, model, prompt, timeout_s):
    """google.genai SDK streaming. Covers google-direct."""
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)
    t_start = time.time()
    ttft = None
    output_tokens = 0
    final_usage = None
    config = types.GenerateContentConfig(
        max_output_tokens=MAX_OUTPUT_TOKENS,
        temperature=TEMPERATURE,
    )
    # google-genai's stream method is generate_content_stream (sync) — uses request_options for timeout
    stream = client.models.generate_content_stream(
        model=model,
        contents=prompt,
        config=config,
    )
    for chunk in stream:
        text = getattr(chunk, "text", None)
        if text:
            if ttft is None:
                ttft = time.time() - t_start
                output_tokens = 1
            else:
                output_tokens += 1
        # usage_metadata may appear on every chunk (cumulative) or final chunk
        usage = getattr(chunk, "usage_metadata", None)
        if usage is not None:
            final_usage = usage
    total = time.time() - t_start
    if ttft is None:
        ttft = total
    if final_usage is not None and getattr(final_usage, "candidates_token_count", None):
        output_tokens = final_usage.candidates_token_count
    return _result(ttft, total, output_tokens)


def _call_mistral(api_key, model, prompt, timeout_s):
    """mistralai SDK streaming. Covers mistral-direct."""
    from mistralai import Mistral

    client = Mistral(api_key=api_key, timeout_ms=int(timeout_s * 1000))
    t_start = time.time()
    ttft = None
    output_tokens = 0
    final_usage = None
    stream = client.chat.stream(
        model=model,
        max_tokens=MAX_OUTPUT_TOKENS,
        temperature=TEMPERATURE,
        messages=[{"role": "user", "content": prompt}],
    )
    for event in stream:
        # mistralai 1.x stream returns CompletionEvent wrapping data.choices[].delta.content
        data = getattr(event, "data", None)
        if data is None:
            continue
        choices = getattr(data, "choices", None) or []
        if choices:
            delta = getattr(choices[0], "delta", None)
            content = getattr(delta, "content", None) if delta else None
            if content:
                if ttft is None:
                    ttft = time.time() - t_start
                    output_tokens = 1
                else:
                    output_tokens += 1
        usage = getattr(data, "usage", None)
        if usage is not None:
            final_usage = usage
    total = time.time() - t_start
    if ttft is None:
        ttft = total
    if final_usage is not None and getattr(final_usage, "completion_tokens", None):
        output_tokens = final_usage.completion_tokens
    return _result(ttft, total, output_tokens)


def _call_ollama(base_url, model, prompt, timeout_s):
    """Ollama local streaming via stdlib urllib (no SDK dep).

    Streams NDJSON from POST /api/generate; each non-final line carries a
    `response` field (the generated chunk). Final line has `done: true` plus
    `eval_count` (output token count). Wall-clock TTFT semantics match cloud
    providers so signatures are comparable.
    """
    import urllib.request
    import urllib.error

    url = f"{base_url.rstrip('/')}/api/generate"
    body = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "stream": True,
            "options": {
                "temperature": TEMPERATURE,
                "num_predict": MAX_OUTPUT_TOKENS,
            },
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}
    )

    t_start = time.time()
    ttft = None
    output_tokens = 0
    server_eval_count = None

    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            for raw in resp:
                line = raw.decode("utf-8").strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if obj.get("done"):
                    if obj.get("eval_count"):
                        server_eval_count = int(obj["eval_count"])
                    break
                chunk = obj.get("response", "")
                if chunk:
                    if ttft is None:
                        ttft = time.time() - t_start
                        output_tokens = 1
                    else:
                        output_tokens += 1
    except urllib.error.URLError as e:
        raise RuntimeError(
            f"Ollama unreachable at {base_url}: {e}. "
            f"Verify daemon is running (`ollama serve`) and model is pulled "
            f"(`ollama pull {model}`)."
        )

    total = time.time() - t_start
    if ttft is None:
        ttft = total
    if server_eval_count:
        output_tokens = server_eval_count
    return _result(ttft, total, output_tokens)


def call_endpoint(provider, endpoint, prompt):
    """Provider-specific streaming call. Returns dict {ttft_s, tps, output_tokens}.

    Raises NotImplementedError for providers outside sub-exp 1 scope (ollama, aws-bedrock).
    Raises RuntimeError if the required env var is missing.
    """
    timeout_s = OLLAMA_TIMEOUT_S if provider == "ollama" else TIMEOUT_S

    if provider == "openai":
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY not set")
        return _call_openai_compat(api_key, "https://api.openai.com/v1", endpoint, prompt, timeout_s)

    if provider == "anthropic":
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        return _call_anthropic(api_key, endpoint, prompt, timeout_s)

    if provider == "google":
        api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GOOGLE_API_KEY (or GEMINI_API_KEY) not set")
        return _call_google(api_key, endpoint, prompt, timeout_s)

    if provider == "mistral":
        # Mistral's API is OpenAI-compatible — route via the openai SDK with
        # base_url override (avoids mistralai 2.4.7's restructured namespace
        # which dropped top-level `Mistral` export). Discovered 2026-05-25.
        api_key = os.environ.get("MISTRAL_API_KEY")
        if not api_key:
            raise RuntimeError("MISTRAL_API_KEY not set")
        return _call_openai_compat(api_key, "https://api.mistral.ai/v1", endpoint, prompt, timeout_s)

    if provider == "xai":
        # xai is OpenAI-compatible — base_url override
        api_key = os.environ.get("XAI_API_KEY")
        if not api_key:
            raise RuntimeError("XAI_API_KEY not set")
        return _call_openai_compat(api_key, "https://api.x.ai/v1", endpoint, prompt, timeout_s)

    if provider == "vercel-ai-gateway":
        # Vercel AI Gateway is OpenAI-compatible — base_url override
        api_key = os.environ.get("VERCEL_AI_GATEWAY_API_KEY")
        if not api_key:
            raise RuntimeError("VERCEL_AI_GATEWAY_API_KEY not set")
        base_url = os.environ.get(
            "VERCEL_AI_GATEWAY_BASE_URL", "https://ai-gateway.vercel.sh/v1"
        )
        return _call_openai_compat(api_key, base_url, endpoint, prompt, timeout_s)

    if provider == "ollama":
        base_url = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")
        return _call_ollama(base_url, endpoint, prompt, timeout_s)

    # aws-bedrock (Sub-exp 3) — ships in follow-up commit before Sub-exp 3 launch.
    raise NotImplementedError(
        f"Provider {provider!r} (endpoint {endpoint!r}) not implemented yet. "
        f"This implementation covers Sub-exp 1 + Sub-exp 2 providers "
        f"(openai/anthropic/google/mistral/xai/vercel-ai-gateway/ollama). "
        f"aws-bedrock (Sub-exp 3) ships in a follow-up commit before Sub-exp 3 launch."
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
            for i, prompt_obj in enumerate(prompts):
                # Prompt set entries are {id, category, text} dicts; APIs expect a string.
                # First caught 2026-05-25 (commit 3b1938a, lost in 2026-05-29 worktree reset).
                # Re-applied 2026-05-30 04:55 UTC after Sub-exp 2 launch fire failed
                # 50/50 with HTTP 400 (dict-as-prompt → Ollama "Bad Request").
                prompt = prompt_obj["text"] if isinstance(prompt_obj, dict) else prompt_obj
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
