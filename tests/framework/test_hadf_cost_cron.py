import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_cost_cron_under_ceiling():
    """Cumulative $5 over the day for subexp1 → exit 0, no bootout"""
    with tempfile.TemporaryDirectory() as td:
        log = Path(td) / "cost.jsonl"
        log.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":1.0}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":1.5}\n'
            '{"timestamp":"2026-05-23T14:00:00Z","subexp":"subexp1","records":50,"estimated_cost_usd":2.5}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-cost-cron.py"),
             "--log", str(log),
             "--subexp", "subexp1",
             "--ceiling-usd", "15",
             "--check-only"],
            capture_output=True, text=True
        )
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert report["cumulative_usd"] == 5.0
        assert report["exceeded"] is False
        assert report["bootout_recommended"] is False

def test_cost_cron_over_ceiling():
    """Cumulative $20 → exceeds $15 ceiling → exit 0 with bootout_recommended=true"""
    with tempfile.TemporaryDirectory() as td:
        log = Path(td) / "cost.jsonl"
        log.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","estimated_cost_usd":7.0}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","estimated_cost_usd":8.0}\n'
            '{"timestamp":"2026-05-23T14:00:00Z","subexp":"subexp1","estimated_cost_usd":5.0}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-cost-cron.py"),
             "--log", str(log),
             "--subexp", "subexp1",
             "--ceiling-usd", "15",
             "--check-only"],
            capture_output=True, text=True
        )
        assert result.returncode == 0
        report = json.loads(result.stdout)
        assert report["cumulative_usd"] == 20.0
        assert report["exceeded"] is True
        assert report["bootout_recommended"] is True
