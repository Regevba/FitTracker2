"""Tests for scripts/ops-digest.py (FIT-205 / F23).

Focus on the pure/deterministic logic — verdict severity ordering, cadence
window filtering (incl. struck-through rows), ISO-date parsing, and text
rendering — plus a fail-soft smoke that the digest builds even when producers
are unavailable. Subprocess-backed sections are exercised via the real repo in
the smoke test only (best-effort, never asserted on live values).
"""

import importlib.util
import json
from datetime import date
from pathlib import Path

_MOD_PATH = Path(__file__).resolve().parent.parent / "ops-digest.py"
_spec = importlib.util.spec_from_file_location("ops_digest", _MOD_PATH)
ops = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ops)


def test_max_verdict_severity_ordering():
    assert ops._max_verdict("ok", "warn") == "warn"
    assert ops._max_verdict("warn", "fail") == "fail"
    assert ops._max_verdict("fail", "ok") == "fail"
    assert ops._max_verdict("ok", "unknown") == "unknown"
    assert ops._max_verdict("warn", "unknown") == "warn"  # warn outranks unknown
    assert ops._max_verdict("ok", "ok") == "ok"


def test_parse_iso_date():
    assert ops._parse_iso_date("2026-07-23") == date(2026, 7, 23)
    assert ops._parse_iso_date("| B17 | **2026-07-23** | review") == date(2026, 7, 23)
    assert ops._parse_iso_date("no date here") is None
    assert ops._parse_iso_date("2026-13-40") is None  # invalid month/day


def test_cadence_window_filters_by_days(tmp_path, monkeypatch):
    shared = tmp_path / ".claude" / "shared"
    shared.mkdir(parents=True)
    (shared / "must-have-cadence-followups.md").write_text(
        "| ID | Date | What |\n"
        "|---|---|---|\n"
        "| B_soon | 2026-07-20 | due in 2 days |\n"
        "| B_far | 2026-09-01 | outside window |\n"
        "| B_past | 2026-07-01 | already past |\n"
        "| ~~B_done~~ | 2026-07-19 | struck through, skip |\n"
    )
    monkeypatch.setattr(ops, "SHARED", shared)
    out = ops.section_cadence(window_days=14, today=date(2026, 7, 18))
    ids = [u["id"] for u in out["upcoming"]]
    assert ids == ["B_soon"]  # only the in-window, non-struck, non-past row
    assert out["upcoming"][0]["in_days"] == 2
    assert out["verdict"] == "ok"


def test_cadence_missing_file_is_unknown(tmp_path, monkeypatch):
    monkeypatch.setattr(ops, "SHARED", tmp_path / "does-not-exist")
    out = ops.section_cadence(window_days=14, today=date(2026, 7, 18))
    assert out["verdict"] == "unknown"
    assert out["upcoming"] == []


def test_telemetry_reads_ledger(tmp_path, monkeypatch):
    shared = tmp_path / "shared"
    shared.mkdir(parents=True)
    (shared / "measurement-adoption.json").write_text(
        json.dumps({"fully_adopted": 9, "post_v6_count": 97, "tier_1_1_status": "partial"})
    )
    monkeypatch.setattr(ops, "SHARED", shared)
    out = ops.section_telemetry()
    assert out["verdict"] == "ok"
    assert out["adoption"]["fully_adopted"] == 9
    assert out["adoption"]["post_v6"] == 97


def test_telemetry_reads_summary_nested_schema(tmp_path, monkeypatch):
    """Pin the real schema 1.0 shape (counts under `summary`) — pattern #24."""
    shared = tmp_path / "shared"
    shared.mkdir(parents=True)
    (shared / "measurement-adoption.json").write_text(json.dumps({
        "updated": "2026-07-18T19:45:24Z",
        "summary": {"fully_adopted": 9, "features_post_v6": 97, "tier_1_1_status": "partial"},
    }))
    monkeypatch.setattr(ops, "SHARED", shared)
    out = ops.section_telemetry()
    assert out["verdict"] == "ok"
    assert out["adoption"]["fully_adopted"] == 9
    assert out["adoption"]["post_v6"] == 97
    assert out["adoption"]["status"] == "partial"


def test_telemetry_missing_ledger_is_unknown(tmp_path, monkeypatch):
    monkeypatch.setattr(ops, "SHARED", tmp_path / "nope")
    out = ops.section_telemetry()
    assert out["verdict"] == "unknown"


def test_render_text_contains_overall_and_sections():
    digest = {
        "generated_at": "2026-07-18T10:00:00+00:00",
        "head": "abc1234", "branch": "main", "window_days": 14,
        "overall_verdict": "ok",
        "sections": {
            "deploy_ci": {"verdict": "ok", "recent_merges": [
                {"pr": 914, "subject": "docs: ssd"}], "bot_pr_health": "ok"},
            "integrity": {"verdict": "ok", "overall": "PASS", "layers": []},
            "telemetry": {"verdict": "ok", "adoption": {
                "fully_adopted": 9, "post_v6": 97, "status": "partial"}},
            "cadence": {"verdict": "ok", "upcoming": [
                {"id": "B17", "due": "2026-07-23", "in_days": 5, "what": "review"}]},
        },
    }
    txt = ops.render_text(digest)
    assert "OVERALL: OK" in txt
    assert "#914" in txt
    assert "B17" in txt
    assert "10-layer sweep: PASS" in txt


def test_render_text_overall_fail_prompts_attention():
    digest = {
        "generated_at": "2026-07-18T10:00:00+00:00", "head": "x", "branch": "main",
        "window_days": 14, "overall_verdict": "fail",
        "sections": {
            "deploy_ci": {"verdict": "ok", "recent_merges": [], "bot_pr_health": "ok"},
            "integrity": {"verdict": "fail", "overall": "FAIL", "layers": [
                {"status": "FAIL", "layer": "Framework integrity", "detail": "3 findings"}]},
            "telemetry": {"verdict": "ok", "adoption": {}},
            "cadence": {"verdict": "ok", "upcoming": []},
        },
    }
    txt = ops.render_text(digest)
    assert "OVERALL: FAIL" in txt
    assert "see flagged sections" in txt
    assert "FAIL Framework integrity — 3 findings" in txt


def test_build_digest_is_fail_soft(tmp_path, monkeypatch):
    """Even if every producer errors, the digest still assembles with a verdict."""
    monkeypatch.setattr(ops, "_run", lambda *a, **k: (124, "__error__: simulated"))
    monkeypatch.setattr(ops, "SHARED", tmp_path / "empty")
    digest = ops.build_digest(window_days=14, today=date(2026, 7, 18))
    assert digest["overall_verdict"] in ops.SEVERITY
    assert set(digest["sections"]) == {"deploy_ci", "integrity", "telemetry", "cadence"}
