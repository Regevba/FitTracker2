"""Tests for DE-R14 integrity-check parallelization (memoized + ThreadPool
first_commit_date)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "integrity-check.py"
_spec = importlib.util.spec_from_file_location("integrity_check", _MOD)
ic = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ic)


def _reset_cache():
    ic._FCD_CACHE.clear()


def test_memoization_computes_once(monkeypatch):
    _reset_cache()
    calls = []
    monkeypatch.setattr(ic, "_compute_first_commit_date",
                        lambda p: calls.append(p) or "2026-01-01")
    p = Path("/x/a.md")
    assert ic.first_commit_date(p) == "2026-01-01"
    assert ic.first_commit_date(p) == "2026-01-01"  # cache hit
    assert len(calls) == 1  # computed only once


def test_none_result_is_cached(monkeypatch):
    _reset_cache()
    calls = []
    monkeypatch.setattr(ic, "_compute_first_commit_date",
                        lambda p: calls.append(p) or None)
    p = Path("/x/missing.md")
    assert ic.first_commit_date(p) is None
    assert ic.first_commit_date(p) is None
    assert len(calls) == 1  # None memoized (not recomputed)


def test_prefetch_serial_populates_cache(monkeypatch):
    _reset_cache()
    monkeypatch.setattr(ic, "_compute_first_commit_date", lambda p: f"d:{p.name}")
    paths = [Path(f"/x/{i}.md") for i in range(5)]
    ic.prefetch_first_commit_dates(paths, jobs=1)
    assert all(str(p) in ic._FCD_CACHE for p in paths)
    # subsequent lookups are pure cache hits (no recompute)
    monkeypatch.setattr(ic, "_compute_first_commit_date",
                        lambda p: (_ for _ in ()).throw(AssertionError("recomputed")))
    assert ic.first_commit_date(paths[0]) == "d:0.md"


def test_prefetch_parallel_matches_serial(monkeypatch):
    monkeypatch.setattr(ic, "_compute_first_commit_date", lambda p: f"d:{p.name}")
    paths = [Path(f"/x/{i}.md") for i in range(20)]
    _reset_cache()
    ic.prefetch_first_commit_dates(paths, jobs=1)
    serial = {str(p): ic._FCD_CACHE[str(p)] for p in paths}
    _reset_cache()
    ic.prefetch_first_commit_dates(paths, jobs=8)
    parallel = {str(p): ic._FCD_CACHE[str(p)] for p in paths}
    assert serial == parallel  # parallel result is deterministic + identical


def test_prefetch_skips_already_cached(monkeypatch):
    _reset_cache()
    ic._FCD_CACHE[str(Path("/x/0.md"))] = "cached"
    computed = []
    monkeypatch.setattr(ic, "_compute_first_commit_date",
                        lambda p: computed.append(p.name) or "new")
    ic.prefetch_first_commit_dates([Path("/x/0.md"), Path("/x/1.md")], jobs=1)
    assert "0.md" not in computed  # already-cached path skipped
    assert "1.md" in computed
