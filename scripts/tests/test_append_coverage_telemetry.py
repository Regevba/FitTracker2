"""Unit tests for scripts/append-coverage-telemetry.py (R9 coverage ledger).

Closes docs/master-plan/r9-track-b-30day-coverage-read-2026-07-04.md Follow-up #1.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "append-coverage-telemetry.py"

_COBERTURA = """<?xml version="1.0"?>
<coverage line-rate="0.84" branch-rate="0.72">
  <packages><package><classes>
    <class filename="app/auth/jwt_validator.py" line-rate="0.35"/>
    <class filename="app/services/cohort_service.py" line-rate="0.30"/>
    <class filename="app/services/insight_service.py" line-rate="1.0"/>
  </classes></package></packages>
</coverage>"""


def _load():
    spec = importlib.util.spec_from_file_location("append_cov", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


act = _load()


def _write_xml(tmp_path: Path) -> Path:
    xml = tmp_path / "coverage.xml"
    xml.write_text(_COBERTURA, encoding="utf-8")
    return xml


def test_parse_cobertura_totals_and_low_modules(tmp_path):
    body = act.parse_cobertura(_write_xml(tmp_path), low_threshold=0.60)
    assert body["line_rate"] == 0.84
    assert body["branch_rate"] == 0.72
    # only the two <0.60 modules, sorted ascending; 100% module excluded
    assert [m["module"] for m in body["per_module"]] == [
        "app/services/cohort_service.py",
        "app/auth/jwt_validator.py",
    ]


def test_append_writes_row(tmp_path):
    ledger = tmp_path / "ledger.jsonl"
    rc = act.main(["--xml", str(_write_xml(tmp_path)), "--ledger", str(ledger),
                   "--date", "2026-07-20", "--provenance", "test"])
    assert rc == 0
    rows = [json.loads(l) for l in ledger.read_text().splitlines() if l.strip()]
    assert len(rows) == 1
    assert rows[0]["date"] == "2026-07-20"
    assert rows[0]["surface"] == "python-ai-engine"
    assert rows[0]["schema_version"] == 1


def test_dedup_by_date_surface(tmp_path):
    ledger = tmp_path / "ledger.jsonl"
    args = ["--xml", str(_write_xml(tmp_path)), "--ledger", str(ledger),
            "--date", "2026-07-20"]
    act.main(args)
    act.main(args)  # same (date, surface) → no second row
    rows = [l for l in ledger.read_text().splitlines() if l.strip()]
    assert len(rows) == 1
    # a different surface DOES append
    act.main(args + ["--surface", "ios-slather"])
    rows = [l for l in ledger.read_text().splitlines() if l.strip()]
    assert len(rows) == 2


def test_missing_xml_is_fail_soft(tmp_path):
    ledger = tmp_path / "ledger.jsonl"
    rc = act.main(["--xml", str(tmp_path / "nope.xml"), "--ledger", str(ledger)])
    assert rc == 0  # never breaks the checkpoint
    assert not ledger.exists()


def test_fetch_ci_fail_soft_when_gh_unavailable(tmp_path, monkeypatch):
    # With no local xml and --fetch-ci, a failing/absent gh must still exit 0
    # and write nothing (never breaks the checkpoint).
    def _boom(*a, **k):
        raise FileNotFoundError("gh not found")
    monkeypatch.setattr(act.subprocess, "run", _boom)
    ledger = tmp_path / "ledger.jsonl"
    rc = act.main(["--xml", str(tmp_path / "nope.xml"), "--ledger", str(ledger),
                   "--fetch-ci"])
    assert rc == 0
    assert not ledger.exists()


def test_fetch_ci_uses_downloaded_xml_and_labels_provenance(tmp_path, monkeypatch):
    # Simulate a successful gh fetch by having fetch_latest_ci_coverage_xml
    # return a real coverage.xml; the row must be written with a '-ci-fetch'
    # provenance suffix.
    xml = _write_xml(tmp_path)
    monkeypatch.setattr(act, "fetch_latest_ci_coverage_xml", lambda d: xml)
    ledger = tmp_path / "ledger.jsonl"
    rc = act.main(["--xml", str(tmp_path / "absent.xml"), "--ledger", str(ledger),
                   "--fetch-ci", "--date", "2026-07-21", "--provenance", "checkpoint"])
    assert rc == 0
    rows = [json.loads(l) for l in ledger.read_text().splitlines() if l.strip()]
    assert len(rows) == 1
    assert rows[0]["provenance"] == "checkpoint-ci-fetch"
    assert rows[0]["line_rate"] == 0.84


def test_corrupt_ledger_line_tolerated(tmp_path):
    ledger = tmp_path / "ledger.jsonl"
    ledger.write_text("{not valid json\n", encoding="utf-8")
    rc = act.main(["--xml", str(_write_xml(tmp_path)), "--ledger", str(ledger),
                   "--date", "2026-07-21"])
    assert rc == 0
    # the good row still appends despite the corrupt pre-existing line
    assert any('"2026-07-21"' in l for l in ledger.read_text().splitlines())
