"""Unit tests for scripts/mutation-summary.py (F18 version-proof cache reader).

These build a throwaway sqlite db mirroring mutmut's `.mutmut-cache` schema and
assert the summary math — so the reader stays correct independent of any mutmut /
peewee version installed (the whole point of bypassing mutmut's own readers).
"""
from __future__ import annotations

import importlib.util
import sqlite3
from pathlib import Path

_MOD_PATH = Path(__file__).resolve().parents[1] / "mutation-summary.py"
_spec = importlib.util.spec_from_file_location("mutation_summary", _MOD_PATH)
ms = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ms)  # type: ignore[union-attr]


def _make_cache(tmp_path, statuses: dict[str, int], files: int = 2) -> Path:
    """Create a minimal .mutmut-cache with the given status -> count distribution."""
    db = tmp_path / ".mutmut-cache"
    con = sqlite3.connect(str(db))
    con.execute("CREATE TABLE SourceFile (id INTEGER PRIMARY KEY, filename TEXT, hash TEXT)")
    con.execute("CREATE TABLE Line (id INTEGER PRIMARY KEY, sourcefile INTEGER, line TEXT, line_number INTEGER)")
    con.execute("CREATE TABLE Mutant (id INTEGER PRIMARY KEY, line INTEGER, [index] INTEGER, tested_against_hash TEXT, status TEXT)")
    for i in range(files):
        con.execute("INSERT INTO SourceFile (filename, hash) VALUES (?, ?)", (f"f{i}.py", "h"))
    for status, n in statuses.items():
        for _ in range(n):
            con.execute("INSERT INTO Mutant (line, [index], status) VALUES (1, 0, ?)", (status,))
    con.commit()
    con.close()
    return db


def test_score_and_buckets(tmp_path):
    db = _make_cache(tmp_path, {"ok_killed": 8, "bad_timeout": 2, "bad_survived": 5, "untested": 100})
    s = ms.summarize(db)
    assert s["total_mutants"] == 115
    assert s["source_files"] == 2
    assert s["killed"] == 10          # ok_killed + bad_timeout
    assert s["survived"] == 5
    assert s["untested"] == 100
    assert s["tested"] == 15
    assert s["mutation_score"] == round(10 / 15, 4)


def test_no_tested_mutants_score_none(tmp_path):
    db = _make_cache(tmp_path, {"untested": 50})
    s = ms.summarize(db)
    assert s["tested"] == 0
    assert s["mutation_score"] is None


def test_suspicious_and_skipped_not_scored(tmp_path):
    db = _make_cache(tmp_path, {"ok_killed": 4, "bad_survived": 0, "ok_suspicious": 3, "skipped": 7})
    s = ms.summarize(db)
    assert s["suspicious"] == 3
    assert s["skipped"] == 7
    assert s["tested"] == 4          # suspicious + skipped excluded from tested
    assert s["mutation_score"] == 1.0


def test_missing_cache_is_graceful(tmp_path):
    s = ms.summarize(tmp_path / "does-not-exist")
    assert s["total"] == 0
    assert "error" in s
    assert "mutation-summary:" in ms.render(s)


def test_render_contains_survivor_label(tmp_path):
    db = _make_cache(tmp_path, {"ok_killed": 1, "bad_survived": 2})
    out = ms.render(ms.summarize(db))
    assert "survived:   2" in out
    assert "mutation score" in out
