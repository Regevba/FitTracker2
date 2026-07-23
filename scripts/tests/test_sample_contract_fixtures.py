"""Unit tests for scripts/sample-contract-fixtures.py.

Covers the drift-detection core (_missing_keys), jsonl/json-glob readers, the
cross-repo mirror provenance resolution, and the --check freshness gate with an
injected `now` (no Date.now reliance).
"""
import importlib.util
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "sample_contract_fixtures", SCRIPTS_DIR / "sample-contract-fixtures.py")
scf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(scf)


def test_missing_keys_detects_drift():
    # Consumer expects event.ts but producer emits timestamp → drift caught.
    records = [{"timestamp": "x", "gate": "G"}]
    assert scf._missing_keys(records, ["ts"]) == ["ts"]
    assert scf._missing_keys(records, ["timestamp"]) == []


def test_missing_keys_empty_records_returns_all():
    assert scf._missing_keys([], ["a", "b"]) == ["a", "b"]


def test_missing_keys_key_present_in_any_record_passes():
    records = [{"a": 1}, {"b": 2}]
    assert scf._missing_keys(records, ["a", "b"]) == []


def test_read_jsonl_last_n(tmp_path):
    f = tmp_path / "x.jsonl"
    f.write_text("".join(json.dumps({"i": i}) + "\n" for i in range(20)))
    out = scf._read_jsonl(f, 3)
    assert [r["i"] for r in out] == [17, 18, 19]


def test_read_jsonl_skips_malformed(tmp_path):
    f = tmp_path / "x.jsonl"
    f.write_text('{"ok": 1}\nnot json\n{"ok": 2}\n')
    out = scf._read_jsonl(f, 10)
    assert [r["ok"] for r in out] == [1, 2]


def test_sample_source_local_is_canonical():
    c = {"producer_repo": "FitTracker2", "producer_path": ".claude/logs/x.jsonl"}
    path, prov = scf._sample_source(c)
    assert prov == "canonical"


def test_sample_source_cross_repo_uses_mirror():
    c = {"producer_repo": "fitme-story", "local_mirror": ".claude/logs/m.jsonl"}
    path, prov = scf._sample_source(c)
    assert prov == "mirror" and path.name == "m.jsonl"


def test_sample_source_cross_repo_no_mirror_unavailable():
    c = {"producer_repo": "fitme-story"}
    path, prov = scf._sample_source(c)
    assert path is None and prov == "unavailable"


def test_check_flags_stale_fixture(tmp_path, monkeypatch):
    # Build a tiny manifest + a stale fixture, assert --check fails.
    sample_dir = tmp_path / "fix"
    sample_dir.mkdir()
    (sample_dir / "c.jsonl").write_text('{"k": 1}\n')
    (sample_dir / "c.meta.json").write_text(json.dumps({
        "sampled_at": (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()}))
    monkeypatch.setattr(scf, "REPO_ROOT", tmp_path)
    manifest = {"sample_dir": "fix", "max_age_days": 7,
                "contracts": [{"name": "c", "producer_repo": "FitTracker2", "required_keys": ["k"]}]}
    assert scf.check(manifest, now=datetime.now(timezone.utc)) == 1


def test_check_passes_fresh_complete_fixture(tmp_path, monkeypatch):
    sample_dir = tmp_path / "fix"
    sample_dir.mkdir()
    (sample_dir / "c.jsonl").write_text('{"k": 1}\n')
    (sample_dir / "c.meta.json").write_text(json.dumps({
        "sampled_at": datetime.now(timezone.utc).isoformat()}))
    monkeypatch.setattr(scf, "REPO_ROOT", tmp_path)
    manifest = {"sample_dir": "fix", "max_age_days": 7,
                "contracts": [{"name": "c", "producer_repo": "FitTracker2", "required_keys": ["k"]}]}
    assert scf.check(manifest, now=datetime.now(timezone.utc)) == 0


def test_check_flags_missing_required_key(tmp_path, monkeypatch):
    sample_dir = tmp_path / "fix"
    sample_dir.mkdir()
    (sample_dir / "c.jsonl").write_text('{"other": 1}\n')
    (sample_dir / "c.meta.json").write_text(json.dumps({
        "sampled_at": datetime.now(timezone.utc).isoformat()}))
    monkeypatch.setattr(scf, "REPO_ROOT", tmp_path)
    manifest = {"sample_dir": "fix", "max_age_days": 7,
                "contracts": [{"name": "c", "producer_repo": "FitTracker2", "required_keys": ["k"]}]}
    assert scf.check(manifest, now=datetime.now(timezone.utc)) == 1


# --- gate-coverage ledger resolution (worktree telemetry-loss reader half) ---
# Regression guard for the 2026-07-23 fix: #934 redirected the gate-coverage
# ledger WRITER to the git common worktree, but this sampler (a READER) still
# resolved REPO_ROOT-relative, so every worktree-isolated run reported
# "source unavailable" and failed the contract re-sample. Same reader/writer
# mismatch class as observed-pattern #24.

def test_gate_coverage_source_resolves_to_common_worktree(monkeypatch, tmp_path):
    main_root = tmp_path / "main"
    (main_root / ".claude" / "logs").mkdir(parents=True)
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(main_root))

    contract = {"producer_repo": "FitTracker2",
                "producer_path": ".claude/logs/gate-coverage.jsonl"}
    src, provenance = scf._sample_source(contract)

    assert provenance == "canonical"
    # Resolved against the override (common worktree), NOT the linked worktree.
    assert src == main_root / ".claude" / "logs" / "gate-coverage.jsonl"


def test_non_ledger_local_producer_stays_repo_root_relative(monkeypatch, tmp_path):
    # Only the gitignored ledger is redirected; ordinary tracked producers must
    # still resolve against the worktree's own REPO_ROOT.
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(tmp_path / "elsewhere"))
    monkeypatch.setattr(scf, "REPO_ROOT", tmp_path / "wt")

    contract = {"producer_repo": "FitTracker2",
                "producer_path": ".claude/shared/contract-manifest.json"}
    src, provenance = scf._sample_source(contract)

    assert provenance == "canonical"
    assert src == tmp_path / "wt" / ".claude" / "shared" / "contract-manifest.json"
