#!/usr/bin/env python3
"""Unit + dispatch tests for F3 — DEPENDENCY_GRAPH_CYCLE.

Cycle-time ADVISORY in `scripts/integrity-check.py`. Builds a directed
dependency graph from scheduled_after.predecessor + parent_feature and flags
cycles, self-loops, and dangling references. See
`.claude/features/f3-dependency-graph-cycle-check/calibration-artifacts.md`.
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

GATE = "DEPENDENCY_GRAPH_CYCLE"


def _make(features_dir: Path, name: str, **fields) -> None:
    d = features_dir / name
    d.mkdir(parents=True, exist_ok=True)
    content = {"feature_name": name, "current_phase": "complete"}
    content.update(fields)
    (d / "state.json").write_text(json.dumps(content, indent=2) + "\n")


def _wire(monkeypatch, tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    features_dir = repo / ".claude" / "features"
    features_dir.mkdir(parents=True)
    (repo / "docs" / "case-studies").mkdir(parents=True)
    monkeypatch.setattr(_mod, "REPO_ROOT", repo)
    monkeypatch.setattr(_mod, "FEATURES_DIR", features_dir)
    monkeypatch.setattr(_mod, "CASE_STUDIES_DIR", repo / "docs" / "case-studies")
    return features_dir


def _codes(findings, feature=None):
    return [f for f in findings
            if f["code"] == GATE and (feature is None or f["feature"] == feature)]


# ─── Fire: cycle / self-loop / dangling ───────────────────────────────────


def test_two_node_cycle_fires_once(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "a", scheduled_after={"predecessor": "b"})
    _make(fd, "b", parent_feature="a")
    findings = _mod.check_dependency_graph_cycles()
    cyc = [f for f in findings if "cycle detected" in f["message"]]
    assert len(cyc) == 1, f"expected exactly one cycle finding, got {cyc}"
    assert {f["severity"] for f in findings} == {"ADVISORY"}


def test_three_node_cycle(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "a", scheduled_after={"predecessor": "b"})
    _make(fd, "b", scheduled_after={"predecessor": "c"})
    _make(fd, "c", scheduled_after={"predecessor": "a"})
    findings = _mod.check_dependency_graph_cycles()
    cyc = [f for f in findings if "cycle detected" in f["message"]]
    assert len(cyc) == 1


def test_self_loop(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "solo", parent_feature="solo")
    findings = _mod.check_dependency_graph_cycles()
    assert any("itself" in f["message"] for f in _codes(findings, "solo"))


def test_dangling_reference(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "child", parent_feature="ghost-parent")
    findings = _mod.check_dependency_graph_cycles()
    msgs = [f["message"] for f in _codes(findings, "child")]
    assert msgs and "dangling" in msgs[0] and "ghost-parent" in msgs[0]


def test_string_form_scheduled_after_dangling(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "x", scheduled_after="missing-pred")  # bare-string form
    findings = _mod.check_dependency_graph_cycles()
    assert any("missing-pred" in f["message"] for f in _codes(findings, "x"))


# ─── No-fire: clean graph / free-text depends_on / no edges ───────────────


def test_clean_dag_no_findings(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "base")
    _make(fd, "mid", parent_feature="base")
    _make(fd, "leaf", scheduled_after={"predecessor": "mid"})
    findings = _mod.check_dependency_graph_cycles()
    assert _codes(findings) == []


def test_depends_on_freetext_not_an_edge(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    # depends_on holds prose, not feature names — must NOT be parsed as edges.
    _make(fd, "feat", depends_on=[
        "PR #158 — six lifecycle analytics events (MERGED 2026-04-30; ready)",
        "Existing Supabase cohort_stats table + increment RPC",
    ])
    findings = _mod.check_dependency_graph_cycles()
    assert _codes(findings) == [], (
        "depends_on free-text must not produce dangling findings"
    )


def test_feature_with_no_edges_not_candidate(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "lonely")
    cov = _mod.GateCoverage(mode="cycle")
    _mod.check_dependency_graph_cycles(coverage=cov)
    assert GATE not in cov.gates or cov.gates[GATE]["candidates"] == 0


# ─── Coverage + graceful degradation ──────────────────────────────────────


def test_coverage_emission(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "base")
    _make(fd, "mid", parent_feature="base")
    cov = _mod.GateCoverage(mode="cycle")
    _mod.check_dependency_graph_cycles(coverage=cov)
    assert GATE in cov.gates
    assert cov.gates[GATE]["candidates"] >= 1  # mid has an edge
    assert cov.gates[GATE]["checked"] >= 1


def test_graceful_when_features_dir_missing(monkeypatch, tmp_path):
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path / "repo")
    monkeypatch.setattr(_mod, "FEATURES_DIR", tmp_path / "repo" / ".claude" / "features")
    cov = _mod.GateCoverage(mode="cycle")
    findings = _mod.check_dependency_graph_cycles(coverage=cov)
    assert findings == []
    assert cov.gates[GATE]["skip_reasons"].get("features_dir_missing") == 1


def test_invalid_json_skipped(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "ok", parent_feature="base")
    _make(fd, "base")
    bad = fd / "broken"
    bad.mkdir()
    (bad / "state.json").write_text("{ not valid json")
    findings = _mod.check_dependency_graph_cycles()  # must not raise
    assert isinstance(findings, list)


# ─── Dispatch: wired into build_snapshot() ────────────────────────────────


def test_dispatch_via_build_snapshot(monkeypatch, tmp_path):
    fd = _wire(monkeypatch, tmp_path)
    _make(fd, "a", scheduled_after={"predecessor": "b"})
    _make(fd, "b", scheduled_after={"predecessor": "a"})

    def _empty_check_output(cmd, **kw):
        return ""
    monkeypatch.setattr(_mod.subprocess, "check_output", _empty_check_output)
    monkeypatch.setattr(sys, "argv", ["integrity-check.py"])
    monkeypatch.setenv("GATE_COVERAGE_LEDGER_DISABLED", "1")

    snap = _mod.build_snapshot("manual")
    codes = {f["code"] for f in snap["findings"]}
    assert GATE in codes
    fires = [f for f in snap["findings"] if f["code"] == GATE]
    assert all(f["severity"] == "ADVISORY" for f in fires)
