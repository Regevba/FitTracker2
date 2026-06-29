"""Tests for scripts/migrate-state-schema.py (DE-R18 / FIT-184)."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "migrate-state-schema.py"
_spec = importlib.util.spec_from_file_location("migrate_state_schema", _MOD)
ms = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ms)


def test_current_version_absent_is_zero():
    assert ms.current_version({}) == 0
    assert ms.current_version({"schema_version": "x"}) == 0  # non-int → 0


def test_current_version_reads_int():
    assert ms.current_version({"schema_version": 1}) == 1


def test_migrate_stamps_current_from_absent():
    state, start, end = ms.migrate_state({"current_phase": "complete"})
    assert start == 0
    assert end == ms.CURRENT_SCHEMA_VERSION
    assert state["schema_version"] == ms.CURRENT_SCHEMA_VERSION


def test_migrate_idempotent_at_current():
    s = {"schema_version": ms.CURRENT_SCHEMA_VERSION, "x": 1}
    state, start, end = ms.migrate_state(dict(s))
    assert start == end == ms.CURRENT_SCHEMA_VERSION
    assert state["x"] == 1


def test_migrate_unknown_path_raises(monkeypatch):
    # Pretend current is 5 but no steps beyond 1 exist → must raise.
    monkeypatch.setattr(ms, "CURRENT_SCHEMA_VERSION", 5)
    try:
        ms.migrate_state({})
        assert False, "expected RuntimeError"
    except RuntimeError as e:
        assert "no migration step" in str(e)


def test_registry_is_contiguous_to_current():
    # Every version below CURRENT must have an outgoing step (no gaps).
    froms = {s[0] for s in ms.MIGRATIONS}
    for v in range(ms.CURRENT_SCHEMA_VERSION):
        assert v in froms, f"missing migration step from v{v}"


def test_main_execute_backfills(tmp_path, monkeypatch):
    feats = tmp_path / ".claude" / "features"
    (feats / "alpha").mkdir(parents=True)
    (feats / "beta").mkdir(parents=True)
    (feats / "alpha" / "state.json").write_text(json.dumps({"current_phase": "complete"}))
    (feats / "beta" / "state.json").write_text(
        json.dumps({"current_phase": "implementation", "schema_version": ms.CURRENT_SCHEMA_VERSION}))
    monkeypatch.setattr(ms, "FEATURES_DIR", feats)

    # dry-run writes nothing
    assert ms.main(["--quiet"]) == 0
    assert "schema_version" not in json.loads((feats / "alpha" / "state.json").read_text())

    # execute backfills alpha, leaves beta untouched
    assert ms.main(["--execute", "--quiet"]) == 0
    assert json.loads((feats / "alpha" / "state.json").read_text())["schema_version"] == ms.CURRENT_SCHEMA_VERSION
    assert json.loads((feats / "beta" / "state.json").read_text())["schema_version"] == ms.CURRENT_SCHEMA_VERSION


def test_main_missing_dir_exits_2(tmp_path, monkeypatch):
    monkeypatch.setattr(ms, "FEATURES_DIR", tmp_path / "nope")
    assert ms.main([]) == 2
