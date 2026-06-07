"""Unit tests for the T14 platforms_tested parity sub-check in
scripts/check-state-schema.py (check_platforms_tested + _platforms_tested_exempt).

Covers shape validation, the non-empty-at-complete requirement, the Q2
framework-meta exemption, advisory-mode tagging, and Mechanism A coverage
emission. The check reads `git show :path` for the committed phase; tests pass
a path not tracked in git so `_load_committed_state` returns None (old_phase
None ≠ complete), exercising the transition path cleanly.
"""
import importlib.util
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "check_state_schema", SCRIPTS_DIR / "check-state-schema.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

check_platforms_tested = _mod.check_platforms_tested
_platforms_tested_exempt = _mod._platforms_tested_exempt
GateCoverage = _mod.GateCoverage

FAKE = Path("/tmp/nonexistent-feature/state.json")  # not in git → committed None


def _violations(findings):
    return {f["violation"] for f in findings}


# ── Shape validation ──────────────────────────────────────────────────────

def test_valid_shape_no_finding():
    state = {"current_phase": "research",
             "platforms_tested": {"ios": True, "web": False, "backend": False, "ai": False}}
    assert check_platforms_tested(state, FAKE, enforce_transition=False) == []


def test_non_dict_shape_flagged():
    state = {"current_phase": "research", "platforms_tested": ["ios"]}
    f = check_platforms_tested(state, FAKE, enforce_transition=False)
    assert "malformed_shape" in _violations(f)


def test_bad_key_and_nonbool_value_flagged():
    state = {"current_phase": "research",
             "platforms_tested": {"android": True, "ios": "yes"}}
    f = check_platforms_tested(state, FAKE, enforce_transition=False)
    assert "malformed_shape" in _violations(f)


def test_non_string_provenance_flagged():
    state = {"current_phase": "research",
             "platforms_tested": {"ios": True}, "platforms_tested_provenance": 5}
    f = check_platforms_tested(state, FAKE, enforce_transition=False)
    assert "malformed_provenance" in _violations(f)


# ── Non-empty-at-complete requirement ─────────────────────────────────────

def test_complete_empty_platforms_flagged():
    state = {"current_phase": "complete", "work_type": "Feature",
             "platforms_tested": {"ios": False, "web": False, "backend": False, "ai": False}}
    f = check_platforms_tested(state, FAKE, enforce_transition=True)
    assert "platforms_tested_empty" in _violations(f)


def test_complete_missing_field_flagged():
    state = {"current_phase": "complete", "work_type": "Feature"}
    f = check_platforms_tested(state, FAKE, enforce_transition=True)
    assert "platforms_tested_empty" in _violations(f)


def test_complete_non_empty_passes():
    state = {"current_phase": "complete", "work_type": "Feature",
             "platforms_tested": {"ios": True, "web": False, "backend": False, "ai": False}}
    assert check_platforms_tested(state, FAKE, enforce_transition=True) == []


def test_non_complete_phase_not_flagged():
    state = {"current_phase": "tasks_phase", "work_type": "Feature"}
    assert check_platforms_tested(state, FAKE, enforce_transition=True) == []


# ── Q2 framework-meta exemption ───────────────────────────────────────────

def test_chore_exempt_at_complete():
    state = {"current_phase": "complete", "work_type": "chore"}
    assert check_platforms_tested(state, FAKE, enforce_transition=True) == []


def test_framework_feature_exempt_at_complete():
    state = {"current_phase": "complete", "work_type": "Feature",
             "work_subtype": "framework_feature"}
    assert check_platforms_tested(state, FAKE, enforce_transition=True) == []


def test_provenance_exempt_at_complete():
    state = {"current_phase": "complete", "work_type": "Feature",
             "platforms_tested_provenance": "exempt:framework_meta"}
    assert check_platforms_tested(state, FAKE, enforce_transition=True) == []


def test_exempt_helper():
    assert _platforms_tested_exempt({"work_type": "chore"})
    assert _platforms_tested_exempt({"work_subtype": "framework_feature"})
    assert _platforms_tested_exempt({"platforms_tested_provenance": "exempt:x"})
    assert _platforms_tested_exempt({"work_type": "Feature"}) is None


# ── Advisory tagging + Mechanism A coverage ───────────────────────────────

def test_all_findings_are_advisory():
    state = {"current_phase": "complete", "work_type": "Feature",
             "platforms_tested": {"ios": False}}
    f = check_platforms_tested(state, FAKE, enforce_transition=True)
    assert f and all(x["advisory"] is True for x in f)


def test_coverage_checked_on_real_evaluation():
    cov = GateCoverage(mode="staged")
    state = {"current_phase": "complete", "work_type": "Feature",
             "platforms_tested": {"ios": True}}
    check_platforms_tested(state, FAKE, coverage=cov, enforce_transition=True)
    b = cov.gates["PLATFORMS_TESTED"]
    assert b["candidates"] == 1 and b["checked"] == 1


def test_coverage_skip_records_exempt_reason():
    cov = GateCoverage(mode="staged")
    state = {"current_phase": "complete", "work_subtype": "framework_feature"}
    check_platforms_tested(state, FAKE, coverage=cov, enforce_transition=True)
    b = cov.gates["PLATFORMS_TESTED"]
    assert b["skipped"] == 1
    assert "exempt_work_subtype_framework_feature" in b["skip_reasons"]
