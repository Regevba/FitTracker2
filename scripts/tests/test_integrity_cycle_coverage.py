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


# 2026-06-17: four legacy advisories previously emitted NO cycle coverage, so
# the F17 index showed them stale and GATE_COVERAGE_ZERO would have false-flagged
# them. These pin the emission + the candidates == checked + skipped invariant.

def test_tier_tag_advisory_emits_coverage():
    cov = GateCoverage(mode="cycle")
    ic.check_tier_tags_advisory(coverage=cov)
    b = _balance(cov, "TIER_TAG_LIKELY_INCORRECT")
    assert b["candidates"] == 1 and b["checked"] == 1  # single aggregate run


def test_cache_hits_auto_inactive_emits_balanced_coverage():
    cov = GateCoverage(mode="cycle")
    ic.check_cache_hits_auto_instrumentation_inactive(coverage=cov)
    _balance(cov, "CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE")  # balance holds even if 0


def test_branch_isolation_historical_emits_balanced_coverage():
    cov = GateCoverage(mode="cycle")
    ic.check_branch_isolation_historical(coverage=cov)
    b = _balance(cov, "BRANCH_ISOLATION_HISTORICAL")
    assert b["candidates"] >= 1  # live corpus has feature state.json files


def test_phase_lie_emits_coverage_per_feature():
    cov = GateCoverage(mode="cycle")
    n = 0
    for d in sorted(ic.FEATURES_DIR.iterdir()):
        if d.is_dir():
            ic.audit_feature(d, coverage=cov)
            n += 1
    b = _balance(cov, "PHASE_LIE")
    assert b["candidates"] == n  # one candidate per feature dir scanned


def test_four_advisories_back_compat_no_coverage():
    # back-compat: the pre-instrumentation call shape (coverage=None) still works
    ic.check_tier_tags_advisory()
    ic.check_cache_hits_auto_instrumentation_inactive()
    ic.check_branch_isolation_historical()
    next_dir = next((d for d in ic.FEATURES_DIR.iterdir() if d.is_dir()), None)
    if next_dir:
        ic.audit_feature(next_dir)
