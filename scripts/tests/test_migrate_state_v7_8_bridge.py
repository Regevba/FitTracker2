"""Tests for scripts/migrate-state-v7-8-bridge.py.

Covers v7.8 schema bridge field migration (T16 — bridge design §8.4):
  - Idempotency: running twice is a no-op
  - Inserts agent_manifest after framework_version (or current_phase fallback)
  - Inserts _meta.deprecation_warnings at top-level
  - Skips files where both fields already exist
  - Errors on malformed JSON before mutation
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "migrate_state_v7_8_bridge",
    SCRIPTS_DIR / "migrate-state-v7-8-bridge.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
migrate_file = _mod.migrate_file
_add_agent_manifest = _mod._add_agent_manifest
_add_meta_deprecation_warnings = _mod._add_meta_deprecation_warnings


# ---------------------------------------------------------------------------
# T1 — agent_manifest insertion
# ---------------------------------------------------------------------------

def test_add_agent_manifest_after_framework_version():
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete",\n'
        '  "framework_version": "v7.7",\n'
        '  "work_type": "feature"\n'
        '}\n'
    )
    new_text, changed = _add_agent_manifest(text)
    assert changed is True
    data = json.loads(new_text)
    assert data["agent_manifest"] == {"reads": [], "writes": [], "shared_writes": []}
    # Insertion order: agent_manifest comes right after framework_version
    keys = list(data.keys())
    fv_idx = keys.index("framework_version")
    am_idx = keys.index("agent_manifest")
    assert am_idx == fv_idx + 1


def test_add_agent_manifest_falls_back_to_current_phase():
    """If framework_version missing, anchor on current_phase."""
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete",\n'
        '  "work_type": "feature"\n'
        '}\n'
    )
    new_text, changed = _add_agent_manifest(text)
    assert changed is True
    data = json.loads(new_text)
    assert "agent_manifest" in data


def test_add_agent_manifest_skips_when_present():
    """Idempotency: don't re-insert."""
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete",\n'
        '  "agent_manifest": {"reads": ["x"], "writes": [], "shared_writes": []}\n'
        '}\n'
    )
    new_text, changed = _add_agent_manifest(text)
    assert changed is False
    assert new_text == text


def test_add_agent_manifest_no_anchor_returns_unchanged():
    """If neither anchor exists, no-op."""
    text = '{"feature": "x"}\n'
    new_text, changed = _add_agent_manifest(text)
    assert changed is False


# ---------------------------------------------------------------------------
# T2 — _meta.deprecation_warnings insertion
# ---------------------------------------------------------------------------

def test_add_meta_appends_at_top_level():
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete"\n'
        '}\n'
    )
    new_text, changed = _add_meta_deprecation_warnings(text)
    assert changed is True
    data = json.loads(new_text)
    assert data["_meta"] == {"deprecation_warnings": []}


def test_add_meta_skips_when_present():
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "_meta": {"deprecation_warnings": ["something"]}\n'
        '}\n'
    )
    new_text, changed = _add_meta_deprecation_warnings(text)
    assert changed is False


def test_add_meta_handles_trailing_comma_correctly():
    """Top-level last field gets a trailing comma added before _meta."""
    text = (
        '{\n'
        '  "feature": "x",\n'
        '  "case_study": "docs/x.md"\n'  # no trailing comma
        '}\n'
    )
    new_text, changed = _add_meta_deprecation_warnings(text)
    assert changed is True
    # Parse must succeed
    data = json.loads(new_text)
    assert data["case_study"] == "docs/x.md"
    assert data["_meta"]["deprecation_warnings"] == []


# ---------------------------------------------------------------------------
# T3 — full file migration
# ---------------------------------------------------------------------------

def _write_state(tmp_path: Path, content: str) -> Path:
    p = tmp_path / "state.json"
    p.write_text(content)
    return p


def test_migrate_file_adds_both_fields(tmp_path):
    p = _write_state(tmp_path,
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete",\n'
        '  "framework_version": "v7.7",\n'
        '  "case_study": "docs/x.md"\n'
        '}\n'
    )
    rep = migrate_file(p)
    assert rep["agent_manifest_added"] is True
    assert rep["meta_added"] is True
    assert rep["error"] is None
    data = json.loads(p.read_text())
    assert "agent_manifest" in data
    assert "_meta" in data


def test_migrate_file_idempotent(tmp_path):
    """Running migrate_file twice is a no-op on the second run."""
    p = _write_state(tmp_path,
        '{\n'
        '  "feature": "x",\n'
        '  "current_phase": "complete"\n'
        '}\n'
    )
    rep1 = migrate_file(p)
    assert rep1["agent_manifest_added"] is True
    rep2 = migrate_file(p)
    assert rep2["agent_manifest_added"] is False
    assert rep2["meta_added"] is False


def test_migrate_file_dry_run_does_not_write(tmp_path):
    p = _write_state(tmp_path,
        '{\n  "feature": "x",\n  "current_phase": "complete"\n}\n'
    )
    original = p.read_text()
    rep = migrate_file(p, dry_run=True)
    assert rep["agent_manifest_added"] is True  # would have changed
    assert p.read_text() == original  # but didn't actually write


def test_migrate_file_invalid_json_returns_error(tmp_path):
    p = _write_state(tmp_path, '{"feature": broken')
    rep = migrate_file(p)
    assert rep["error"] is not None
    assert "invalid JSON" in rep["error"]
