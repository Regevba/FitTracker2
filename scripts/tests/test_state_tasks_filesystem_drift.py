#!/usr/bin/env python3
"""Unit + dispatch tests for F1 — STATE_TASKS_FILESYSTEM_DRIFT.

Cycle-time ADVISORY in `scripts/integrity-check.py`. The gate fires for a
feature that is `complete` with an empty `tasks[]` ledger yet shows shipped
artifacts (case study / related_prs / merge PR) and is post-task-discipline
and not framework-meta. See
`.claude/features/f1-state-tasks-filesystem-drift/calibration-artifacts.md`.

Test layers per the v8.x ready-now workplan §3 (cycle-time gates use the
unit + dispatch layers; no try-repo fixture pair).
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "integrity_check", SCRIPTS_DIR / "integrity-check.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

GATE = "STATE_TASKS_FILESYSTEM_DRIFT"


# ─── Helpers ─────────────────────────────────────────────────────────────


def _make_feature(
    features_dir: Path,
    name: str,
    *,
    current_phase: str = "complete",
    created_at: str = "2026-05-15T00:00:00Z",
    tasks=None,
    extra: dict | None = None,
) -> Path:
    feat_dir = features_dir / name
    feat_dir.mkdir(parents=True, exist_ok=True)
    content: dict = {
        "feature_name": name,
        "current_phase": current_phase,
        "created_at": created_at,
        "tasks": tasks if tasks is not None else [],
    }
    if extra:
        content.update(extra)
    p = feat_dir / "state.json"
    p.write_text(json.dumps(content, indent=2) + "\n")
    return p


def _wire(monkeypatch, tmp_repo: Path):
    features_dir = tmp_repo / ".claude" / "features"
    features_dir.mkdir(parents=True, exist_ok=True)
    cs_dir = tmp_repo / "docs" / "case-studies"
    cs_dir.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_repo)
    monkeypatch.setattr(_mod, "FEATURES_DIR", features_dir)
    monkeypatch.setattr(_mod, "CASE_STUDIES_DIR", cs_dir)
    return features_dir, cs_dir


def _add_case_study(cs_dir: Path, name: str):
    (cs_dir / f"{name}-case-study.md").write_text("# case study\n")


# ─── Unit: fire conditions ────────────────────────────────────────────────


def test_fires_on_complete_empty_tasks_with_case_study(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "drifted-feat")
    _add_case_study(cs, "drifted-feat")
    findings = _mod.check_state_tasks_filesystem_drift()
    codes = {f["code"] for f in findings}
    assert GATE in codes
    assert {f["severity"] for f in findings} == {"ADVISORY"}
    assert any(f["feature"] == "drifted-feat" for f in findings)


def test_fires_on_related_prs_artifact(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "feat-prs",
                  extra={"related_prs": [123]})
    findings = _mod.check_state_tasks_filesystem_drift()
    assert any(f["feature"] == "feat-prs" for f in findings)


def test_fires_on_merge_pr_artifact(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "feat-merge",
                  extra={"phases": {"merge": {"pr_number": 999}}})
    findings = _mod.check_state_tasks_filesystem_drift()
    msgs = [f["message"] for f in findings if f["feature"] == "feat-merge"]
    assert msgs and "#999" in msgs[0]


# ─── Unit: skip conditions ────────────────────────────────────────────────


def test_skip_when_tasks_populated(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "has-tasks",
                  tasks=[{"id": "T1", "status": "done"}])
    _add_case_study(cs, "has-tasks")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "has-tasks" for f in findings)


def test_skip_when_not_complete(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "in-prog",
                  current_phase="implementation")
    _add_case_study(cs, "in-prog")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "in-prog" for f in findings)


def test_skip_pre_task_discipline(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "old-feat",
                  created_at="2026-04-01T00:00:00Z")
    _add_case_study(cs, "old-feat")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "old-feat" for f in findings)


def test_skip_framework_meta_by_name(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "framework-v9-9-thing")
    _add_case_study(cs, "framework-v9-9-thing")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "framework-v9-9-thing" for f in findings)


def test_skip_framework_meta_by_subtype(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "some-infra",
                  extra={"work_subtype": "framework_feature"})
    _add_case_study(cs, "some-infra")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "some-infra" for f in findings)


def test_skip_exempt_case_study_type(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "roundup-feat",
                  extra={"case_study_type": "roundup"})
    _add_case_study(cs, "roundup-feat")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "roundup-feat" for f in findings)


def test_skip_no_shipped_artifact(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _wire(monkeypatch, repo)
    # complete + empty tasks + post-discipline + non-meta, but NO artifact
    _make_feature(repo / ".claude" / "features", "thin-feat")
    findings = _mod.check_state_tasks_filesystem_drift()
    assert not any(f["feature"] == "thin-feat" for f in findings)


# ─── Coverage emission (Mechanism A) ──────────────────────────────────────


def test_coverage_emission(monkeypatch, tmp_path):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "drift-a")
    _add_case_study(cs, "drift-a")
    _make_feature(repo / ".claude" / "features", "old-skip",
                  created_at="2026-04-01T00:00:00Z")
    cov = _mod.GateCoverage(mode="cycle")
    findings = _mod.check_state_tasks_filesystem_drift(coverage=cov)
    assert GATE in cov.gates, "expected coverage bucket for the gate"
    stats = cov.gates[GATE]
    assert stats["candidates"] >= 2  # drift-a + old-skip both candidates
    assert stats["checked"] >= 1     # drift-a checked
    assert stats["skip_reasons"].get("pre_task_discipline", 0) >= 1  # old-skip
    assert any(f["feature"] == "drift-a" for f in findings)


def test_graceful_when_features_dir_missing(monkeypatch, tmp_path):
    repo = tmp_path / "repo"  # no .claude/features
    monkeypatch.setattr(_mod, "REPO_ROOT", repo)
    monkeypatch.setattr(_mod, "FEATURES_DIR", repo / ".claude" / "features")
    cov = _mod.GateCoverage(mode="cycle")
    findings = _mod.check_state_tasks_filesystem_drift(coverage=cov)
    assert findings == []


# ─── Dispatch: wired into main() advisory_findings ────────────────────────


def test_dispatch_via_main(monkeypatch, tmp_path, capsys):
    repo = tmp_path / "repo"
    _, cs = _wire(monkeypatch, repo)
    _make_feature(repo / ".claude" / "features", "drift-dispatch")
    _add_case_study(cs, "drift-dispatch")

    def _empty_check_output(cmd, **kw):
        return ""
    monkeypatch.setattr(_mod.subprocess, "check_output", _empty_check_output)
    monkeypatch.setattr(sys, "argv", ["integrity-check.py"])
    # Don't pollute the real gate-coverage ledger from the test.
    monkeypatch.setenv("GATE_COVERAGE_LEDGER_DISABLED", "1")

    snap = _mod.build_snapshot("manual")
    codes = {f["code"] for f in snap["findings"]}
    assert GATE in codes, f"gate not dispatched via build_snapshot; codes={codes}"
    # Advisory must not inflate the gating finding_count.
    fire = [f for f in snap["findings"]
            if f["code"] == GATE and f["feature"] == "drift-dispatch"]
    assert fire and fire[0]["severity"] == "ADVISORY"
