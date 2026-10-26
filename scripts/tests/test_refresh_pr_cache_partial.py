#!/usr/bin/env python3
"""Partial-failure behavior of scripts/refresh-pr-cache.py (2026-10-26).

A failed fetch for one repo must carry that repo forward from the previous
cache (not drop it), keep the previous refresh timestamp, and exit 1.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "refresh-pr-cache.py"


def _load():
    spec = importlib.util.spec_from_file_location("refresh_pr_cache", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


FT2 = "Regevba/FitTracker2"
FS = "Regevba/fitme-story"
OLD_TS = "2026-10-25T04:00:00Z"


def _prev_cache(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({
        "schema_version": 1,
        "last_refreshed_at": OLD_TS,
        "repos": {
            FT2: {"open": [], "merged": [{"number": 1, "title": "old", "state": "MERGED"}], "closed": []},
            FS: {"open": [], "merged": [], "closed": []},
        },
    }))


def test_failed_repo_is_carried_forward_and_exits_1(tmp_path, monkeypatch):
    mod = _load()
    cache = tmp_path / ".cache" / "gh-pr-cache.json"
    _prev_cache(cache)
    monkeypatch.setattr(mod, "CACHE_FILE", cache)
    fresh = {"open": [{"number": 9, "title": "new", "state": "OPEN"}], "merged": [], "closed": []}
    monkeypatch.setattr(mod, "fetch_repo_prs", lambda repo: None if repo == FT2 else fresh)

    assert mod.main() == 1
    out = json.loads(cache.read_text())
    assert out["repos"][FT2]["merged"][0]["number"] == 1  # carried forward
    assert out["repos"][FS] == fresh
    assert out["last_refreshed_at"] == OLD_TS  # not marked fresh


def test_full_success_refreshes_timestamp_and_exits_0(tmp_path, monkeypatch):
    mod = _load()
    cache = tmp_path / ".cache" / "gh-pr-cache.json"
    _prev_cache(cache)
    monkeypatch.setattr(mod, "CACHE_FILE", cache)
    fresh = {"open": [], "merged": [], "closed": []}
    monkeypatch.setattr(mod, "fetch_repo_prs", lambda repo: fresh)

    assert mod.main() == 0
    out = json.loads(cache.read_text())
    assert set(out["repos"]) == {FT2, FS}
    assert out["last_refreshed_at"] != OLD_TS


def test_all_fail_without_previous_cache_exits_1_and_writes_nothing(tmp_path, monkeypatch):
    mod = _load()
    cache = tmp_path / ".cache" / "gh-pr-cache.json"
    monkeypatch.setattr(mod, "CACHE_FILE", cache)
    monkeypatch.setattr(mod, "fetch_repo_prs", lambda repo: None)

    assert mod.main() == 1
    assert not cache.exists()
