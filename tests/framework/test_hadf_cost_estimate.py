import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_cost_estimate_openai_gpt4o_mini():
    """50 calls × 200 output tokens × OpenAI gpt-4o-mini rate ($0.60/M output) = $0.006"""
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "openai",
         "--endpoint", "gpt-4o-mini",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    cost = float(result.stdout.strip())
    assert 0.005 < cost < 0.008, f"expected ~$0.006, got ${cost}"

def test_cost_estimate_anthropic_haiku_4_5():
    """50 calls × 200 output tokens × Anthropic haiku rate"""
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "anthropic",
         "--endpoint", "claude-haiku-4-5",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    cost = float(result.stdout.strip())
    assert cost > 0, "cost should be positive"

def test_cost_estimate_unknown_provider_fails():
    result = subprocess.run(
        ["python3", str(REPO_ROOT / "scripts/hadf-cost-estimate.py"),
         "--provider", "nonexistent",
         "--endpoint", "fake",
         "--calls", "50",
         "--avg-output-tokens", "200"],
        capture_output=True, text=True
    )
    assert result.returncode != 0
    assert "unknown provider" in result.stderr.lower()
