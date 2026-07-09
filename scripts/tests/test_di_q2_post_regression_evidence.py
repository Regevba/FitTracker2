"""DI-Q2 (data-integrity-and-rollback §5) — post-regression forensic snapshot.

When the daily integrity checkpoint detects a regression it must capture a
SECOND, immutable `post-regression-evidence-<ts>/` snapshot in addition to
writing the regression flag. These tests cover:

  1. Structural guard — `capture_post_regression_evidence(...)` is invoked inside
     the `if regression:` branch of `_run_pipeline` (not the read-only `--ci`
     path), so a refactor can't silently drop the evidence capture.
  2. Behavioral — the helper reuses `write_snapshot`, writes a machine-readable
     `evidence.json` carrying the deltas, and re-runs the checksum pass so
     `evidence.json` is covered by CHECKSUMS.sha256.
  3. Failure-safety — a snapshot failure returns None and does not raise (the
     flag write must remain the load-bearing signal).
"""
from __future__ import annotations

import ast
import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
SCRIPT_PATH = SCRIPTS_DIR / "daily-integrity-checkpoint.py"

sys.path.insert(0, str(SCRIPTS_DIR))
_spec = importlib.util.spec_from_file_location("daily_integrity_checkpoint", SCRIPT_PATH)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]


# ---------------------------------------------------------------- structural

def _find_func(tree: ast.Module, name: str) -> ast.FunctionDef:
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name == name:
            return node
    raise AssertionError(f"function {name} not found")


def test_helper_exists():
    assert hasattr(_mod, "capture_post_regression_evidence"), (
        "DI-Q2 helper capture_post_regression_evidence must exist"
    )


def test_evidence_capture_lives_inside_regression_branch():
    """The evidence capture must be inside `if regression:` of `_run_pipeline`,
    so it fires only on a real regression and only in the snapshot-owning path."""
    tree = ast.parse(SCRIPT_PATH.read_text())
    pipeline = _find_func(tree, "_run_pipeline")

    def _calls_in_regression_if(node: ast.AST) -> bool:
        for n in ast.walk(node):
            if (isinstance(n, ast.If)
                    and isinstance(n.test, ast.Name) and n.test.id == "regression"):
                for inner in ast.walk(n):
                    if (isinstance(inner, ast.Call)
                            and isinstance(inner.func, ast.Name)
                            and inner.func.id == "capture_post_regression_evidence"):
                        return True
        return False

    assert _calls_in_regression_if(pipeline), (
        "capture_post_regression_evidence(...) must be called inside the "
        "`if regression:` branch of _run_pipeline"
    )


def test_ci_path_does_not_snapshot():
    """The read-only `--ci` path must NOT capture evidence (no on-disk writes)."""
    tree = ast.parse(SCRIPT_PATH.read_text())
    ci = _find_func(tree, "_run_ci_check")
    calls = {
        n.func.id for n in ast.walk(ci)
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
    }
    assert "capture_post_regression_evidence" not in calls, (
        "--ci path is read-only; it must not capture a forensic snapshot"
    )


# ---------------------------------------------------------------- behavioral

@pytest.fixture()
def _stub_snapshot(monkeypatch, tmp_path):
    """Redirect the evidence root to tmp and stub write_snapshot to a minimal
    real-ish snapshot (a dir with one payload file), so the helper's own
    checksum/manifest/evidence.json logic runs for real."""
    monkeypatch.setattr(_mod, "POST_REGRESSION_EVIDENCE_ROOT", tmp_path)

    def _fake_write_snapshot(target_dir: Path, make_outputs: dict, metrics: dict) -> bool:
        target_dir.mkdir(parents=True, exist_ok=True)
        (target_dir / "metrics.json").write_text(json.dumps(metrics))
        return True

    monkeypatch.setattr(_mod, "write_snapshot", _fake_write_snapshot)
    return tmp_path


def _fake_metrics() -> dict:
    # write_manifest reads a fixed set of metric keys — supply them all.
    return {
        "integrity_findings": 3, "integrity_advisory": 0, "doc_debt_open": 7,
        "completeness_blocking": 1, "completeness_advisory": 0,
        "features_total": 130, "features_post_v6": 96, "fully_adopted": 9,
        "adoption_pct_post_v6": 6.7,
        "timing_wall_time_pct_post_v6": 38.5, "per_phase_timing_pct_post_v6": 92.7,
        "cache_hits_pct_post_v6": 34.4, "cu_v2_pct_post_v6": 28.1,
        "gate_coverage_rows": 2000, "gate_coverage_distinct_gates": 28,
        "mechanism_c_session_events": 61,
    }


def test_evidence_snapshot_written(_stub_snapshot):
    logs: list[str] = []
    deltas = {"integrity_findings": 3, "fully_adopted": -2}
    evidence_dir = _mod.capture_post_regression_evidence(
        "2026-07-09", deltas, "2026-07-08",
        make_outputs={}, metrics=_fake_metrics(),
        ft2_git={"commit": "abc", "branch": "main", "dirty_files": 0},
        fs_git={"commit": "def", "branch": "main", "dirty_files": 0},
        hw=None, log=logs.append,
    )
    assert evidence_dir is not None
    assert evidence_dir.name.startswith("post-regression-evidence-")
    assert evidence_dir.parent == _stub_snapshot

    ev = json.loads((evidence_dir / "evidence.json").read_text())
    assert ev["trigger"] == "post-regression-evidence"
    assert ev["deltas"] == deltas
    assert ev["prev_date"] == "2026-07-08"

    # evidence.json must be covered by the checksum manifest (DI-Q3 verify path).
    checksums = (evidence_dir / "CHECKSUMS.sha256").read_text()
    assert "evidence.json" in checksums
    assert (evidence_dir / "MANIFEST.md").exists()
    assert "DI-Q2" in (evidence_dir / "MANIFEST.md").read_text()


def test_evidence_capture_failure_is_safe(monkeypatch, tmp_path):
    """A snapshot failure returns None and does not raise."""
    monkeypatch.setattr(_mod, "POST_REGRESSION_EVIDENCE_ROOT", tmp_path)
    monkeypatch.setattr(_mod, "write_snapshot", lambda *a, **k: False)
    logs: list[str] = []
    out = _mod.capture_post_regression_evidence(
        "2026-07-09", {"x": 1}, "2026-07-08", {}, _fake_metrics(),
        {}, {}, None, logs.append,
    )
    assert out is None
    assert any("FAILED" in line for line in logs)
