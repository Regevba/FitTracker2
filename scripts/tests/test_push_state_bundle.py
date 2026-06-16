"""Tests for scripts/push-state-bundle.py — the UCC live-feed Phase 2 assembler.

Focus on the public-blob safety contract: only allow-listed shared files ship,
PII ledgers (agent-leases.json) are excluded, feature/jsonl keys match exactly
what the fitme-story consumer (data-source.ts) requests, and the output is
valid round-trippable JSON.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

# Load the hyphenated module by path.
_MOD_PATH = Path(__file__).resolve().parent.parent / "push-state-bundle.py"
_spec = importlib.util.spec_from_file_location("push_state_bundle", _MOD_PATH)
psb = importlib.util.module_from_spec(_spec)
assert _spec and _spec.loader
_spec.loader.exec_module(psb)


def _make_claude_tree(tmp_path: Path) -> Path:
    """Build a minimal .claude/ tree with allow-listed + PII + feature + log files."""
    claude = tmp_path / ".claude"
    shared = claude / "shared"
    shared.mkdir(parents=True)
    # Allow-listed shared files
    (shared / "framework-manifest.json").write_text(json.dumps({"v": "7.10"}))
    (shared / "external-sync-status.json").write_text(json.dumps({"version": "1.1"}))
    (shared / "documentation-debt.json").write_text(json.dumps({"open": 7}))
    (shared / "measurement-adoption.json").write_text(json.dumps({"pct": 6.7}))
    # PII / non-allow-listed shared files — MUST NOT ship
    (shared / "agent-leases.json").write_text(json.dumps({"operator": "regev@example.com"}))
    (shared / "preflight-cache.json").write_text(json.dumps({"path": "/Users/secret"}))
    # A malformed allow-listed file — should skip cleanly
    (shared / "feature-registry.json").write_text("{not json")
    # Features
    feats = claude / "features"
    (feats / "garmin-health-connection").mkdir(parents=True)
    (feats / "garmin-health-connection" / "state.json").write_text(
        json.dumps({"feature": "garmin-health-connection", "current_phase": "complete"})
    )
    (feats / "ucc").mkdir(parents=True)
    (feats / "ucc" / "state.json").write_text(json.dumps({"feature": "ucc", "current_phase": "complete"}))
    # Gate-coverage log
    logs = claude / "logs"
    logs.mkdir()
    (logs / "gate-coverage.jsonl").write_text('{"gate":"A"}\n{"gate":"B"}\n')
    return claude


def _build(tmp_path: Path) -> dict:
    claude = _make_claude_tree(tmp_path)
    return psb.build_bundle(claude, commit_sha="abc1234", generated_at="2026-06-16T00:00:00Z")


def test_envelope_fields(tmp_path):
    b = _build(tmp_path)
    assert b["schema_version"] == 1
    assert b["commit_sha"] == "abc1234"
    assert b["generated_at"] == "2026-06-16T00:00:00Z"
    assert isinstance(b["files"], dict)


def test_allowlisted_shared_included(tmp_path):
    files = _build(tmp_path)["files"]
    assert files["shared/framework-manifest.json"] == {"v": "7.10"}
    assert files["shared/external-sync-status.json"] == {"version": "1.1"}
    assert files["shared/documentation-debt.json"] == {"open": 7}


def test_pii_and_nonallowlisted_excluded(tmp_path):
    """The load-bearing safety check: PII / non-allow-listed shared files never ship."""
    files = _build(tmp_path)["files"]
    assert "shared/agent-leases.json" not in files
    assert "shared/preflight-cache.json" not in files


def test_malformed_allowlisted_skipped(tmp_path):
    files = _build(tmp_path)["files"]
    assert "shared/feature-registry.json" not in files  # malformed -> skipped


def test_features_keyed_by_slug(tmp_path):
    files = _build(tmp_path)["files"]
    assert files["features/garmin-health-connection.json"]["current_phase"] == "complete"
    assert files["features/ucc.json"]["feature"] == "ucc"
    feature_keys = [k for k in files if k.startswith("features/")]
    assert len(feature_keys) == 2


def test_gate_coverage_is_raw_text_under_expected_key(tmp_path):
    files = _build(tmp_path)["files"]
    val = files["integrity/gate-coverage-ft2.jsonl"]
    assert isinstance(val, str)  # raw text, not parsed
    assert '"gate":"A"' in val and val.endswith("\n")


def test_output_is_valid_json(tmp_path):
    b = _build(tmp_path)
    assert json.loads(json.dumps(b)) == b  # round-trips


def test_missing_optional_membrane_status_skips(tmp_path):
    # membrane-status.json is in the allow-list but absent here — no crash, no key.
    files = _build(tmp_path)["files"]
    assert "shared/membrane-status.json" not in files


def test_empty_claude_dir_yields_empty_files(tmp_path):
    empty = tmp_path / ".claude"
    empty.mkdir()
    b = psb.build_bundle(empty, commit_sha="x", generated_at="t")
    assert b["files"] == {}
