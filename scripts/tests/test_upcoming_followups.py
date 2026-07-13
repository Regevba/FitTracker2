"""Regression tests for daily-integrity-checkpoint upcoming_followups parser.

Covers the 2026-07-13 fix: `**~YYYY-MM-DD**` approximate dates must surface,
firm `**YYYY-MM-DD**` dates keep working, struck-through `~~Bxx~~` rows stay
excluded, and out-of-window rows are dropped.
"""
import datetime as dt
import importlib.util
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
_spec = importlib.util.spec_from_file_location(
    "dc", REPO / "scripts" / "daily-integrity-checkpoint.py"
)
dc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dc)

TODAY = dt.date(2026, 7, 13)


def _run(tmp_path, body, monkeypatch, lookahead=14):
    f = tmp_path / "followups.md"
    f.write_text(body)
    monkeypatch.setattr(dc, "FOLLOWUPS_FILE", f)
    return {r["id"]: r for r in dc.upcoming_followups(TODAY, lookahead_days=lookahead)}


def test_firm_date_surfaces(tmp_path, monkeypatch):
    body = "| B1 | **2026-07-20** | do a thing | operator | src |\n"
    rows = _run(tmp_path, body, monkeypatch)
    assert "B1" in rows and rows["B1"]["days_away"] == 7


def test_approximate_date_surfaces(tmp_path, monkeypatch):
    # The bug: `**~2026-07-23**` was skipped by the `**20` prefilter + digit-anchored regex.
    body = "| B17 | **~2026-07-23** | schema-diff review | operator | src |\n"
    rows = _run(tmp_path, body, monkeypatch)
    assert "B17" in rows and rows["B17"]["days_away"] == 10


def test_struck_through_excluded(tmp_path, monkeypatch):
    # Struck rows use ~~id~~ / ~~date~~ and often bold **EXECUTED 2026-07-13** text —
    # must NOT match (the id/date cells aren't `| Bxx | **date**`).
    body = "| ~~B16~~ | ~~2026-07-13~~ | ~~review~~ **EXECUTED 2026-07-13** done | operator | src |\n"
    rows = _run(tmp_path, body, monkeypatch)
    assert rows == {}


def test_out_of_window_dropped(tmp_path, monkeypatch):
    body = (
        "| B19 | **2026-08-10** | soak verdict | operator | src |\n"
        "| B20 | **~2026-10-11** | rotate PAT | operator | src |\n"
    )
    rows = _run(tmp_path, body, monkeypatch)
    assert rows == {}  # both > 14 days away


def test_mixed_block(tmp_path, monkeypatch):
    body = (
        "| ~~B16~~ | ~~2026-07-13~~ | ~~done~~ | operator | src |\n"
        "| B17 | **~2026-07-23** | review | operator | src |\n"
        "| B18 | **ASAP (blocks B19)** | provision PAT | operator | src |\n"
        "| B19 | **2026-08-10** | verdict | operator | src |\n"
    )
    rows = _run(tmp_path, body, monkeypatch)
    assert set(rows) == {"B17"}  # B16 struck, B18 no date, B19 out of window
