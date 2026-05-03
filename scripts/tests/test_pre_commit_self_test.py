"""Tests for scripts/pre-commit-self-test.py (v7.8 Mechanism D)."""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


def _load_module():
    """Load the pre-commit-self-test script as a module despite its hyphen-name."""
    repo_root = Path(__file__).resolve().parents[2]
    src = repo_root / "scripts" / "pre-commit-self-test.py"
    spec = importlib.util.spec_from_file_location("pre_commit_self_test", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["pre_commit_self_test"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load_module()


def test_extract_declared_gates_picks_up_uppercase_identifiers(mod):
    text = """#!/usr/bin/env bash
# Pre-commit hook
#
#   v7.5 (shipped):
#     - SCHEMA_DRIFT (legacy `phase` key)
#     - PR_NUMBER_UNRESOLVED (something)
#
set -euo pipefail
"""
    declared = mod.extract_declared_gates(text)
    assert "SCHEMA_DRIFT" in declared
    assert "PR_NUMBER_UNRESOLVED" in declared


def test_extract_declared_gates_skips_noise_words(mod):
    text = """#!/usr/bin/env bash
# IMPORTANT: this is a hook
# WARNING: do not bypass
# - SCHEMA_DRIFT (real gate)
"""
    declared = mod.extract_declared_gates(text)
    assert "SCHEMA_DRIFT" in declared
    assert "IMPORTANT" not in declared
    assert "WARNING" not in declared


def test_extract_declared_gates_handles_backticks_and_asterisks(mod):
    text = """#
# - **`SCHEMA_DRIFT`** — note
# - `BROKEN_PR_CITATION` (formatted)
#
set -euo pipefail
"""
    declared = mod.extract_declared_gates(text)
    assert "SCHEMA_DRIFT" in declared
    assert "BROKEN_PR_CITATION" in declared


def test_extract_declared_gates_stops_at_first_non_comment_line(mod):
    text = """#
# - REAL_GATE one
#
set -euo pipefail
# - LATER_GATE post-set should be ignored
"""
    declared = mod.extract_declared_gates(text)
    assert "REAL_GATE" in declared
    assert "LATER_GATE" not in declared


def test_extract_implemented_gates_finds_code_literals(mod):
    text = '''
        findings.append({"code": "STATE_NO_CASE_STUDY_LINK", "msg": "..."})
        findings.append({"code":"CU_V2_INVALID","msg":"..."})
    '''
    impl = mod.extract_implemented_gates(text)
    assert "STATE_NO_CASE_STUDY_LINK" in impl
    assert "CU_V2_INVALID" in impl


def test_extract_inline_drift_codes_detects_inline_messages(mod):
    text = '''
        errors.append(f"{path}: uses legacy `phase` key — canonical is current_phase")
        errors.append(f"{path}: PHASE_TRANSITION_NO_LOG — but `.claude/logs/...` event missing")
    '''
    inline = mod.extract_inline_drift_codes(text)
    assert "SCHEMA_DRIFT" in inline
    assert "PHASE_TRANSITION_NO_LOG" in inline


def test_extract_inline_drift_codes_detects_case_study_gates(mod):
    text = '''
        errors.append(f"{path}: cites PR #{n} which does not resolve on GitHub.")
        errors.append(f"{path}: dated ... but contains no T1/T2/T3 tier tag.")
    '''
    inline = mod.extract_inline_drift_codes(text)
    assert "BROKEN_PR_CITATION" in inline
    assert "CASE_STUDY_MISSING_TIER_TAGS" in inline


def test_main_passes_on_real_repo(mod, monkeypatch):
    """Real-repo end-to-end: the project's actual hook + checkers must agree."""
    monkeypatch.setattr(sys, "argv", ["pre-commit-self-test.py"])
    rc = mod.main()
    assert rc == 0
