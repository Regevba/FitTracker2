import json
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

def test_audit_detects_missed_fires():
    """Plist expects 5 fires; ledger has only 3 fire_started events → 2 missed."""
    with tempfile.TemporaryDirectory() as td:
        ledger = Path(td) / "heartbeat.jsonl"
        ledger.write_text(
            '{"timestamp":"2026-05-23T02:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T02:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
            '{"timestamp":"2026-05-23T08:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T08:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
            '{"timestamp":"2026-05-23T22:00:00Z","subexp":"subexp1","event":"fire_started"}\n'
            '{"timestamp":"2026-05-23T22:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}\n'
        )
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-heartbeat-audit.py"),
             "--ledger", str(ledger),
             "--subexp", "subexp1",
             "--date", "2026-05-23",
             "--expected-times", "02:00,08:00,14:00,18:00,22:00"],
            capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout)
        assert report["fires_expected"] == 5
        assert report["fires_started"] == 3
        assert report["fires_completed"] == 3
        assert sorted(report["missed_fires"]) == ["14:00", "18:00"]

def test_audit_no_missed_fires():
    with tempfile.TemporaryDirectory() as td:
        ledger = Path(td) / "heartbeat.jsonl"
        events = []
        for hh in ["02:00", "08:00", "14:00", "18:00", "22:00"]:
            events.append(f'{{"timestamp":"2026-05-23T{hh}:00Z","subexp":"subexp1","event":"fire_started"}}')
            events.append(f'{{"timestamp":"2026-05-23T{hh.split(":")[0]}:11:00Z","subexp":"subexp1","event":"fire_ended","records_landed":50}}')
        ledger.write_text("\n".join(events) + "\n")
        result = subprocess.run(
            ["python3", str(REPO_ROOT / "scripts/hadf-phase2bis-heartbeat-audit.py"),
             "--ledger", str(ledger),
             "--subexp", "subexp1",
             "--date", "2026-05-23",
             "--expected-times", "02:00,08:00,14:00,18:00,22:00"],
            capture_output=True, text=True
        )
        report = json.loads(result.stdout)
        assert report["missed_fires"] == []
