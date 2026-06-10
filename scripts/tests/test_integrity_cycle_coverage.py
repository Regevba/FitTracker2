"""v7.10 — the three cycle-time checks must emit Mechanism A coverage.

Before v7.10, BROKEN_PR_CITATION / CASE_STUDY_MISSING_TIER_TAGS /
PATTERN_SKILL_UNMAPPED ran without emitting any coverage row, so the F17 index
and GATE_COVERAGE_ZERO meta-check were blind to them. These tests pin the
emission + the candidates == checked + skipped balance invariant.
"""
import importlib.util
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_SCRIPTS))
from gate_coverage import GateCoverage  # noqa: E402

_SPEC = importlib.util.spec_from_file_location("integrity_check", _SCRIPTS / "integrity-check.py")
ic = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(ic)


def _balance(cov, gate):
    b = cov.gates[gate]
    assert b["candidates"] == b["checked"] + b["skipped"], (
        f"{gate}: candidates {b['candidates']} != checked {b['checked']} + skipped {b['skipped']}")
    return b


def test_tier_tags_emits_balanced_coverage():
    cov = GateCoverage(mode="cycle")
    ic.audit_case_study_tier_tags(coverage=cov)
    b = _balance(cov, "CASE_STUDY_MISSING_TIER_TAGS")
    assert b["candidates"] >= 1  # live corpus has case studies


def test_pattern_skill_emits_coverage():
    cov = GateCoverage(mode="cycle")
    ic.check_pattern_skill_unmapped(coverage=cov)
    b = cov.gates["PATTERN_SKILL_UNMAPPED"]
    assert b["candidates"] >= 1
    assert b["candidates"] == b["checked"]  # every pattern id is evaluated


def test_citations_emits_balanced_coverage_with_cache():
    cov = GateCoverage(mode="cycle")
    # minimal non-None cache so the function runs the scan loop
    ic.audit_case_study_citations({"repos": {}}, coverage=cov)
    b = _balance(cov, "BROKEN_PR_CITATION")
    assert b["candidates"] >= 1


def test_citations_no_cache_emits_skip():
    cov = GateCoverage(mode="cycle")
    ic.audit_case_study_citations(None, coverage=cov)
    b = cov.gates["BROKEN_PR_CITATION"]
    assert b["skipped"] == 1 and b["checked"] == 0


def test_coverage_optional_no_crash_when_absent():
    # back-compat: all three run with coverage=None (the pre-v7.10 call shape)
    ic.audit_case_study_tier_tags()
    ic.check_pattern_skill_unmapped()
    ic.audit_case_study_citations(None)
