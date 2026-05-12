import json
import subprocess
import tempfile
from pathlib import Path
import random

REPO_ROOT = Path(__file__).resolve().parents[2]

def write_jsonl(path, records):
    with open(path, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

def synthetic_phase2_like_data(n_per_endpoint=100, n_endpoints=9):
    """Generate data with separable cluster structure (silhouette ~0.5)"""
    random.seed(42)
    records = []
    for i in range(n_endpoints):
        provider = f"provider{i}"
        endpoint = f"endpoint{i}"
        center_ttft = 0.3 + i * 0.2
        center_tps = 30.0 + i * 5.0
        for _ in range(n_per_endpoint):
            records.append({
                "provider": provider,
                "endpoint": endpoint,
                "ttft_s": center_ttft + random.gauss(0, 0.05),
                "tps": center_tps + random.gauss(0, 2.0),
                "status": "ok",
            })
    return records

def test_verdict_pass():
    """Synthetic separable data → silhouette > 0.5, clusters >= 3 → PASS"""
    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "raw.jsonl"
        write_jsonl(raw, synthetic_phase2_like_data(n_per_endpoint=100, n_endpoints=9))
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-verdict.py"),
             "--raw-dir", str(raw.parent),
             "--subexp", "test",
             "--silhouette-min", "0.4",
             "--yield-min", "600",
             "--clusters-min", "3",
             "--k", "5"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["verdict"] == "PASS", f"got {report}"
        assert report["yield"] >= 600
        assert report["silhouette"] > 0.4
        assert report["clusters"] >= 3

def test_verdict_fail_low_yield():
    """Only 100 records → yield < 600 → FAIL"""
    with tempfile.TemporaryDirectory() as td:
        raw = Path(td) / "raw.jsonl"
        write_jsonl(raw, synthetic_phase2_like_data(n_per_endpoint=10, n_endpoints=10))
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-verdict.py"),
             "--raw-dir", str(raw.parent),
             "--subexp", "test",
             "--silhouette-min", "0.4",
             "--yield-min", "600",
             "--clusters-min", "3",
             "--k", "5"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["verdict"] == "FAIL"
        assert report["fail_reason"] == "low_yield"
