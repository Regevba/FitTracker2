#!/usr/bin/env python3
"""Dispatch tests for cycle-time advisory gates in `scripts/integrity-check.py`.

Covers T8 + T9 of feature `framework-f14-f15-dispatch-test-coverage`
(integration-spec §2.2 surface S2). Both gates are CYCLE-TIME ADVISORY:
`integrity-check.py::main()` exits 0 even when findings exist; assertion
shape is therefore "check function returns non-empty findings list" +
"main() runs to completion without raising / non-zero exit".

Pattern follows the PR #317 prototype (see
`test_branch_isolation_and_closure_completeness.py::test_main_runs_mode_b_…`)
adapted for `integrity-check.py` instead of `check-state-schema.py`.
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
    "integrity_check", SCRIPTS_DIR / "integrity-check.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


# ─── Helpers ─────────────────────────────────────────────────────────────


def _make_feature_state(
    features_dir: Path,
    feature_name: str,
    *,
    created_at: str = "2026-05-15T00:00:00Z",
    isolation_opt_out: bool = False,
    case_study_type: str | None = None,
    extra: dict | None = None,
) -> Path:
    """Write a minimal state.json at <features_dir>/<feature_name>/state.json
    sufficient to exercise the advisory check functions."""
    feat_dir = features_dir / feature_name
    feat_dir.mkdir(parents=True, exist_ok=True)
    content: dict = {
        "feature_name": feature_name,
        "current_phase": "complete",
        "created_at": created_at,
        "isolation_opt_out": isolation_opt_out,
        "phases": {},
    }
    if case_study_type is not None:
        content["case_study_type"] = case_study_type
    if extra:
        content.update(extra)
    state_path = feat_dir / "state.json"
    state_path.write_text(json.dumps(content, indent=2) + "\n")
    return state_path


# ─── T8: BRANCH_ISOLATION_HISTORICAL dispatch test ─────────────────────────


def test_main_dispatch_branch_isolation_historical(monkeypatch, tmp_path, capsys):
    """T8 — end-to-end dispatch coverage for `BRANCH_ISOLATION_HISTORICAL`.

    Exercises the gate through TWO paths to lift dispatch coverage:

    1. Direct call to `check_branch_isolation_historical()` — assert the
       function returns a non-empty findings list when given a state.json
       that satisfies all trigger conditions (forward-only after-ship-date,
       no opt-out, no merge PR, non-exempt case_study_type) AND `git log`
       reports no feature/* or chore/* branches.

    2. End-to-end `main()` invocation with controlled REPO_ROOT — assert
       `main()` runs to completion and does NOT raise SystemExit with a
       non-zero code (advisory gates must not block).

    Note: `check_branch_isolation_historical` reads
    `REPO_ROOT / ".claude" / "features"` locally (line 557), so we
    monkey-patch the module-level `REPO_ROOT` to point at a tmp dir.
    `subprocess.check_output` is also patched to return empty so the
    "on_feature_branch" detection fails predictably (no git repo in tmp).
    """
    # Stand up tmp .claude/features/<feat>/state.json
    tmp_repo = tmp_path / "repo"
    features_dir = tmp_repo / ".claude" / "features"
    features_dir.mkdir(parents=True)
    _make_feature_state(
        features_dir,
        "ft-test-feature",
        created_at="2026-05-15T00:00:00Z",
    )

    # Patch module globals: REPO_ROOT is what the check functions read
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_repo)
    monkeypatch.setattr(_mod, "FEATURES_DIR", features_dir)
    monkeypatch.setattr(_mod, "CASE_STUDIES_DIR", tmp_repo / "docs" / "case-studies")

    # Force `git log --source` + `git log --format=%s` to return empty so
    # neither the ref-walk nor the conventional-commit fallback finds a
    # feature/* or chore/* branch. The gate then emits the advisory.
    def _empty_check_output(cmd, **kw):
        return ""

    monkeypatch.setattr(_mod.subprocess, "check_output", _empty_check_output)

    # ─── Path 1: direct check function call ──
    findings = _mod.check_branch_isolation_historical()
    assert isinstance(findings, list), "check fn must return list"
    assert len(findings) >= 1, (
        f"Expected ADVISORY finding for ft-test-feature; got: {findings}"
    )
    codes = {f["code"] for f in findings}
    assert "BRANCH_ISOLATION_HISTORICAL" in codes, (
        f"Expected BRANCH_ISOLATION_HISTORICAL in finding codes; got: {codes}"
    )
    severities = {f["severity"] for f in findings}
    assert severities == {"ADVISORY"}, (
        f"Gate must emit ADVISORY-only; got severities: {severities}"
    )

    # ─── Path 2: end-to-end main() dispatch ──
    monkeypatch.setattr(sys, "argv", ["integrity-check.py"])
    # main() returns None when no --findings-only/--snapshot/--strict;
    # it may also sys.exit(0) on the --compare-to path which we don't trigger.
    try:
        rc = _mod.main()
    except SystemExit as e:
        # Advisory gates must not exit non-zero. Accept exit code 0 or None.
        assert e.code in (0, None), (
            f"Advisory gate must not block; main() exited with code={e.code}"
        )
        rc = e.code
    assert rc in (0, None), f"main() returned unexpected rc={rc}"
    # Sanity check: stdout mentions the advisory finding count
    out = capsys.readouterr().out
    assert "advisory" in out.lower() or "Findings:" in out, (
        f"main() output missing expected sections; got: {out[:500]}"
    )


# ─── T9: BRANCH_ISOLATION_LAUNCHD_DRIFT dispatch test ──────────────────────


@pytest.mark.skipif(
    sys.platform != "darwin",
    reason="BRANCH_ISOLATION_LAUNCHD_DRIFT is macOS-only (scans ~/Library/LaunchAgents)",
)
def test_main_dispatch_branch_isolation_launchd_drift(monkeypatch, tmp_path):
    """T9 — dispatch coverage for `BRANCH_ISOLATION_LAUNCHD_DRIFT`.

    macOS-only advisory. The gate scans `~/Library/LaunchAgents/*.plist`
    for jobs whose ProgramArguments reference a `.claude/features/<feat>`
    path while their WorkingDirectory does NOT start with the expected
    `state.json::worktree_path`.

    Test strategy — two paths to maximise dispatch coverage:

    1. Smoke: assert the check function is callable + returns a list with
       no contrived inputs (whatever the real LaunchAgents dir contains).
       This proves the gate's dispatch path is exercised on every cycle
       run on macOS — the closure we need for F14/F15.

    2. Triggered: monkey-patch `Path.home()` AND `REPO_ROOT` so the gate
       sees (a) a synthetic plist that references a feature dir with a
       mismatched WorkingDirectory, and (b) the corresponding state.json
       with `worktree_path`. Assert at least one ADVISORY finding emerges.

    Constraint: fully simulating launchd in a test is high-effort; the
    triggered path is a focused write-and-scan that exercises every line
    of the gate's body without spawning a real launchd job.
    """
    # ─── Path 1: smoke (real environment) ──
    findings_smoke = _mod.check_branch_isolation_launchd_drift()
    assert isinstance(findings_smoke, list), (
        "check fn must return list (possibly empty) on real LaunchAgents scan"
    )

    # ─── Path 2: triggered ──
    # Stand up tmp HOME with a synthetic plist + tmp REPO_ROOT with a
    # state.json declaring worktree_path that DOESN'T match the plist's
    # WorkingDirectory. The gate must flag the mismatch.
    tmp_home = tmp_path / "home"
    launchagents = tmp_home / "Library" / "LaunchAgents"
    launchagents.mkdir(parents=True)

    tmp_repo = tmp_path / "repo"
    features_dir = tmp_repo / ".claude" / "features"
    features_dir.mkdir(parents=True)
    feature_name = "ft-launchd-test-feature"
    expected_worktree = "/expected/worktree/path"
    _make_feature_state(
        features_dir,
        feature_name,
        extra={"worktree_path": expected_worktree},
    )

    # Synthetic plist: ProgramArguments references the feature dir but
    # WorkingDirectory is intentionally divergent. Use plistlib to write.
    import plistlib
    plist_path = launchagents / "com.fittracker.test.plist"
    plist_content = {
        "Label": "com.fittracker.test",
        "ProgramArguments": [
            "/usr/bin/python3",
            f"/some/script.py",
            f"--features-dir=.claude/features/{feature_name}",
        ],
        "WorkingDirectory": "/wrong/working/directory",
    }
    with open(plist_path, "wb") as f:
        plistlib.dump(plist_content, f)

    # Patch module globals + Path.home so the gate sees our synthetic env
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_repo)
    monkeypatch.setattr(_mod.Path, "home", classmethod(lambda cls: tmp_home))

    findings_triggered = _mod.check_branch_isolation_launchd_drift()
    assert isinstance(findings_triggered, list)
    assert len(findings_triggered) >= 1, (
        f"Expected ADVISORY finding for plist drift; got: {findings_triggered}"
    )
    codes = {f["code"] for f in findings_triggered}
    assert "BRANCH_ISOLATION_LAUNCHD_DRIFT" in codes, (
        f"Expected BRANCH_ISOLATION_LAUNCHD_DRIFT in codes; got: {codes}"
    )
    severities = {f["severity"] for f in findings_triggered}
    assert severities == {"ADVISORY"}, (
        f"Gate must emit ADVISORY-only; got severities: {severities}"
    )


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
