import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def write_jsonl(path, records):
    with open(path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

def test_anchor_drift_within_tolerance():
    """Sub-exp 1 + Sub-exp 3 anchor distributions are similar → p > 0.01 → no drift"""
    with tempfile.TemporaryDirectory() as td:
        s1 = Path(td) / "s1.jsonl"
        s3 = Path(td) / "s3.jsonl"
        records1 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.01*i, "tps": 50.0, "status": "ok"} for i in range(50)]
        records3 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.01*i, "tps": 50.0, "status": "ok"} for i in range(50)]
        write_jsonl(s1, records1)
        write_jsonl(s3, records3)
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-anchor-drift-check.py"),
             "--sub-exp-1-raw", str(s1),
             "--sub-exp-3-raw", str(s3),
             "--anchor-provider", "openai",
             "--anchor-endpoint", "gpt-4o-mini"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["drift_detected"] is False
        assert report["ks_p_value"] > 0.01

def test_anchor_drift_detected():
    """Sub-exp 3 has shifted TTFT distribution → p < 0.01 → drift detected"""
    with tempfile.TemporaryDirectory() as td:
        s1 = Path(td) / "s1.jsonl"
        s3 = Path(td) / "s3.jsonl"
        records1 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 0.5 + 0.005*i, "tps": 50.0, "status": "ok"} for i in range(100)]
        records3 = [{"provider": "openai", "endpoint": "gpt-4o-mini", "ttft_s": 2.0 + 0.005*i, "tps": 50.0, "status": "ok"} for i in range(100)]
        write_jsonl(s1, records1)
        write_jsonl(s3, records3)
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-anchor-drift-check.py"),
             "--sub-exp-1-raw", str(s1),
             "--sub-exp-3-raw", str(s3),
             "--anchor-provider", "openai",
             "--anchor-endpoint", "gpt-4o-mini"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["drift_detected"] is True
        assert report["ks_p_value"] < 0.01
