#!/usr/bin/env bash
# count-framework-tokens.sh — Counts tokens across framework layers
# Output: .claude/shared/token-budget.json
# Requires: python3 with tiktoken installed
# Usage: bash scripts/count-framework-tokens.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 << 'PYEOF'
import json
import os
import glob
from datetime import datetime, timezone

try:
    import tiktoken
    enc = tiktoken.encoding_for_model("gpt-4")
    tokenizer_name = "tiktoken-cl100k_base"
except ImportError:
    # Fallback: estimate tokens as words * 1.3 (rough approximation)
    enc = None
    tokenizer_name = "word-count-estimate"
    print("WARNING: tiktoken not installed. Using word count * 1.3 as estimate.")
    print("Install for accuracy: pip3 install tiktoken")

project_root = os.environ.get("PROJECT_ROOT", os.getcwd())

def count_tokens(text):
    if enc:
        return len(enc.encode(text))
    else:
        return int(len(text.split()) * 1.3)

def count_tokens_in_files(pattern):
    files = glob.glob(pattern, recursive=True)
    total = 0
    count = 0
    for f in files:
        if os.path.isfile(f):
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as fh:
                    total += count_tokens(fh.read())
                count += 1
            except Exception:
                pass
    return count, total

layers = {}

files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/skills/*/SKILL.md"))
layers["skills"] = {"files": files, "tokens": tokens}

files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/cache/**/*.json"))
layers["cache"] = {"files": files, "tokens": tokens}

files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/shared/*.json"))
layers["shared"] = {"files": files, "tokens": tokens}

files, tokens = count_tokens_in_files(os.path.join(project_root, ".claude/integrations/**/*"))
layers["adapters"] = {"files": files, "tokens": tokens}

total_tokens = sum(l["tokens"] for l in layers.values())
for key in layers:
    layers[key]["pct_of_total"] = round(layers[key]["tokens"] / total_tokens, 4) if total_tokens > 0 else 0.0

output = {
    "measured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "model": "claude-opus-4-6",
    "tokenizer": tokenizer_name,
    "layers": layers,
    "total_tokens": total_tokens,
    "context_budget_pct": round(total_tokens / 1_000_000, 6)
}

output_path = os.path.join(project_root, ".claude/shared/token-budget.json")
with open(output_path, "w") as f:
    json.dump(output, f, indent=2)

print(f"Token budget written to {output_path}")
print(f"  Skills:   {layers['skills']['tokens']:>8,} tokens ({layers['skills']['files']} files)")
print(f"  Cache:    {layers['cache']['tokens']:>8,} tokens ({layers['cache']['files']} files)")
print(f"  Shared:   {layers['shared']['tokens']:>8,} tokens ({layers['shared']['files']} files)")
print(f"  Adapters: {layers['adapters']['tokens']:>8,} tokens ({layers['adapters']['files']} files)")
print(f"  TOTAL:    {total_tokens:>8,} tokens ({round(total_tokens/1000, 1)}K, {output['context_budget_pct']*100:.2f}% of 1M context)")
PYEOF
