"""Shared pytest fixtures for `scripts/tests/`.

Introduced by feature `framework-f14-f15-dispatch-test-coverage` (PRD §4 OQ4).
Provides fixture contracts per integration-spec.md §3:
  - `tmp_gate_coverage_ledger` — isolated JSONL ledger with K3 teardown guard
  - `make_valid_state_json` — schema-validated state.json factory
  - `make_invalid_state_json` — gate-specific violation recipes
  - `tmp_pr_cache_file` — controllable-age PR cache fixture

Schema-drift fail-fast: `DEFAULT_VALID_STATE` is validated against the live
schema at import time. If the schema evolves and the baseline becomes
invalid, conftest import raises LOUD and every test in this directory
fails with a clear `schema-drift` reason. This is intentional — silent
fixture drift caused the v7.7 `cache_hits` keying-drift incident
(honesty-ledger FT2-FH-001).
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

import pytest


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
CANONICAL_GATE_COVERAGE_LEDGER = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"

# Lazy-load check-state-schema.py (filename contains hyphens → can't import normally).
sys.path.insert(0, str(SCRIPTS_DIR))
_css_spec = importlib.util.spec_from_file_location(
    "check_state_schema", SCRIPTS_DIR / "check-state-schema.py",
)
_check_state_schema = importlib.util.module_from_spec(_css_spec)
_css_spec.loader.exec_module(_check_state_schema)


# ─── Baseline: minimum-valid v7.9 state.json ───────────────────────────────
# Changes to this baseline = schema migration. Update with caution.
DEFAULT_VALID_STATE: dict[str, Any] = {
    "feature_name": "test-fixture-feature",
    "display_name": "Test fixture feature",
    "current_phase": "research",
    "created_at": "2026-05-22T00:00:00Z",
    "updated": "2026-05-22T00:00:00Z",
    "framework_version": "v7.9",
    "work_type": "feature",
    "work_subtype": "framework_feature",
    "state_owner": "ft2",
    "dispatch_pattern": "serial",
    "has_ui": False,
    "requires_analytics": False,
    "isolation_opt_out": False,
    "branch": "feature/test-fixture-feature",
    "case_study_type": "feature_case_study",
    "phases": {
        "research": {"status": "in_progress", "started_at": "2026-05-22T00:00:00Z"}
    },
    "tasks": [],
    "cache_hits": [
        {"timestamp": "2026-05-22T00:00:00Z", "cache_level": "L1", "skill": "test"}
    ],
    "transitions": [],
    "timing": {
        "phases": {
            "research": {"started_at": "2026-05-22T00:00:00Z"}
        }
    },
}


@dataclass
class State:
    """Wrapper around a fixture state.json: path on disk + content dict."""
    path: Path
    content: dict[str, Any]

    def write(self) -> "State":
        self.path.write_text(json.dumps(self.content, indent=2) + "\n")
        return self


# ─── Fixture: tmp_gate_coverage_ledger ─────────────────────────────────────


@pytest.fixture
def tmp_gate_coverage_ledger(tmp_path: Path):
    """Provides a tmp JSONL path for Mechanism A telemetry writes.

    K3 GUARD: records the canonical ledger's mtime at setup and asserts at
    teardown that it did NOT change during the test. Any test that
    accidentally writes to the canonical ledger fails LOUD here.

    Tests MUST monkey-patch `_check_state_schema.GATE_COVERAGE_LEDGER` to
    this returned path before invoking `_check_state_schema.main()`.
    """
    canonical = CANONICAL_GATE_COVERAGE_LEDGER
    canonical_mtime_at_setup = (
        canonical.stat().st_mtime if canonical.exists() else None
    )
    tmp_ledger = tmp_path / "gate-coverage.jsonl"
    yield tmp_ledger
    if canonical_mtime_at_setup is not None and canonical.exists():
        canonical_mtime_at_teardown = canonical.stat().st_mtime
        assert canonical_mtime_at_teardown == canonical_mtime_at_setup, (
            f"K3 VIOLATION: canonical {canonical} mtime changed during test "
            f"({canonical_mtime_at_setup} → {canonical_mtime_at_teardown}). "
            "This would contaminate the v7.9 calibration baseline. Revert."
        )


# ─── Fixture: make_valid_state_json ────────────────────────────────────────


@pytest.fixture
def make_valid_state_json(tmp_path: Path) -> Callable[..., State]:
    """Factory returning a function that builds a minimum-valid state.json.

    Usage:
        def test_foo(make_valid_state_json):
            state = make_valid_state_json(current_phase="prd")
            # state.path → tmp Path; state.content → dict
    """
    _validate_baseline_or_raise()

    def _factory(**overrides: Any) -> State:
        # Deep-merge overrides onto baseline so callers can override nested keys
        content = _deep_merge_dict(dict(DEFAULT_VALID_STATE), overrides)
        # Ensure a unique filename per call within the same test
        slug = content.get("feature_name", "test")
        idx = len(list(tmp_path.glob(f"{slug}-*-state.json")))
        path = tmp_path / f"{slug}-{idx}-state.json"
        state = State(path=path, content=content)
        state.write()
        return state

    return _factory


# ─── Fixture: make_invalid_state_json ──────────────────────────────────────


@pytest.fixture
def make_invalid_state_json(make_valid_state_json) -> Callable[[str], State]:
    """Factory: returns a state.json file engineered to FAIL a specific gate.

    Recipes (one per F14/F15 gate in scope):
      - STATE_NO_CASE_STUDY_LINK
      - CASE_STUDY_MISSING_FIELDS         [PENDING — T3]
      - CU_V2_INVALID                      [PENDING — T4]
      - CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT  [PENDING — T5]
      - PHASE_TRANSITION_NO_LOG            [PENDING — T6]
      - PHASE_TRANSITION_NO_TIMING         [PENDING — T7]
      - BRANCH_ISOLATION_HISTORICAL        [PENDING — T8] (cycle-time, integrity-check.py)
      - BRANCH_ISOLATION_LAUNCHD_DRIFT     [PENDING — T9] (cycle-time, integrity-check.py)
      - PR_CACHE_STALE                     [PENDING — T10] (uses tmp_pr_cache_file)
    """
    def _factory(violates: str) -> State:
        if violates == "STATE_NO_CASE_STUDY_LINK":
            # Recipe: current_phase=complete + no case_study link + no exempt tag.
            # case_study_type must NOT be in EXEMPT_CASE_STUDY_TYPES; the baseline
            # uses "feature_case_study" which is non-exempt by design.
            return make_valid_state_json(
                current_phase="complete",
                case_study=None,
                parent_case_study=None,
            )
        if violates == "CU_V2_INVALID":
            # Recipe: cu_v2 is a dict (to avoid crashing validate-cu-v2.py
            # which calls .get directly) but contains malformed factors
            # (non-dict). validate() returns "factors missing or not a dict".
            return make_valid_state_json(
                cu_v2={"factors": "not_a_dict_should_be_object"},
            )
        if violates == "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT":
            # Recipe: post-Mechanism-C feature (created_at >= 2026-05-02)
            # + current_phase=complete + cache_hits explicitly empty (key
            # present, len==0). Must also satisfy STATE_NO_CASE_STUDY_LINK
            # so we provide case_study so only the target gate fires.
            return make_valid_state_json(
                created_at="2026-05-15T00:00:00Z",
                current_phase="complete",
                cache_hits=[],  # empty list, not absent
                case_study="docs/case-studies/test-fixture-feature-case-study.md",
            )
        if violates == "PHASE_TRANSITION_NO_LOG":
            # Recipe: a phase change (current_phase != committed-HEAD value)
            # without a fresh log event. Tests pair this with monkey-patches
            # of _load_committed_state (returns prior phase) + _load_feature_log
            # (returns None) so the gate sees a transition without a log.
            return make_valid_state_json(
                current_phase="prd",
                phases={
                    "research": {"status": "approved"},
                    "prd": {"status": "in_progress"},
                },
                timing={
                    "phases": {
                        "research": {
                            "started_at": "2026-05-22T00:00:00Z",
                            "ended_at": "2026-05-22T01:00:00Z",
                        },
                        "prd": {"started_at": "2026-05-22T01:00:00Z"},
                    }
                },
            )
        if violates == "PHASE_TRANSITION_NO_TIMING":
            # Recipe: phase change + log event present (so LOG check passes)
            # but timing.phases.<new_phase>.started_at is MISSING.
            return make_valid_state_json(
                current_phase="prd",
                phases={
                    "research": {"status": "approved"},
                    "prd": {"status": "in_progress"},
                },
                # timing.phases.prd intentionally missing started_at
                timing={
                    "phases": {
                        "research": {
                            "started_at": "2026-05-22T00:00:00Z",
                            "ended_at": "2026-05-22T01:00:00Z",
                        },
                        # prd entry absent → started_at missing
                    }
                },
            )
        # Other recipes land in T3, T6-T10 per tasks.md
        raise NotImplementedError(
            f"Violation recipe for {violates!r} not yet implemented. "
            f"Pending tasks: T3 (CASE_STUDY_MISSING_FIELDS — different surface), "
            f"T6 (PHASE_TRANSITION_NO_LOG), T7 (PHASE_TRANSITION_NO_TIMING), "
            f"T8/T9 (cycle-time gates), T10 (PR_CACHE_STALE)."
        )

    return _factory


# ─── Fixture: tmp_pr_cache_file ────────────────────────────────────────────


@pytest.fixture
def tmp_pr_cache_file(tmp_path: Path):
    """Provides a controllable .cache/gh-pr-cache.json path.

    Helpers:
      .write_valid()        → writes a valid cache structure
      .age(hours)           → os.utime to N hours ago
    """
    cache_path = tmp_path / "gh-pr-cache.json"

    @dataclass
    class _PrCacheHandle:
        path: Path

        def write_valid(self) -> "_PrCacheHandle":
            self.path.write_text(json.dumps({
                "last_refreshed_at": "2026-05-22T00:00:00Z",
                "repos": {
                    "FitTracker2": {"prs": []},
                    "fitme-story": {"prs": []},
                },
            }, indent=2))
            return self

        def age(self, hours: float) -> "_PrCacheHandle":
            ts = time.time() - hours * 3600
            os.utime(self.path, (ts, ts))
            return self

    return _PrCacheHandle(path=cache_path)


# ─── Internal helpers ──────────────────────────────────────────────────────


def _deep_merge_dict(base: dict, overrides: dict) -> dict:
    """Recursive dict merge; overrides win. None values in overrides REMOVE
    the key from the result (lets recipes drop fields explicitly)."""
    result = dict(base)
    for k, v in overrides.items():
        if v is None:
            result.pop(k, None)
        elif isinstance(v, dict) and isinstance(result.get(k), dict):
            result[k] = _deep_merge_dict(result[k], v)
        else:
            result[k] = v
    return result


def _validate_baseline_or_raise() -> None:
    """Schema-drift fail-fast: assert DEFAULT_VALID_STATE passes the live
    schema. Called at first fixture use, not at module import, to avoid
    breaking pytest collection if the schema module itself can't load.

    Implementation note: there is no single `validate_schema()` entry
    point in `check-state-schema.py`; the schema is enforced by the suite
    of `check_*()` gate functions called by `main()`. Instead of calling
    every check, we run a representative cross-section:
      - `check_state_no_case_study_link(state)` — must NOT fire on baseline
      - `check_cu_v2_schema(state)` — must NOT fire (cu_v2 absent → skip)
    If a future schema migration breaks this cross-section, the conftest
    fails LOUD with the offending field.
    """
    state = dict(DEFAULT_VALID_STATE)
    errors: list[str] = []
    # Cross-section 1: linkage gate skips on non-complete phase
    findings = _check_state_schema.check_state_no_case_study_link(state)
    if findings:
        errors.append(
            f"DEFAULT_VALID_STATE unexpectedly fails STATE_NO_CASE_STUDY_LINK: "
            f"{findings}"
        )
    # Cross-section 2: cu_v2 schema skips when key absent
    findings = _check_state_schema.check_cu_v2_schema(state)
    if findings:
        errors.append(
            f"DEFAULT_VALID_STATE unexpectedly fails CU_V2_INVALID: {findings}"
        )
    if errors:
        raise RuntimeError(
            "FIXTURE SCHEMA DRIFT: DEFAULT_VALID_STATE no longer schema-valid. "
            "Update conftest.py::DEFAULT_VALID_STATE to reflect the live "
            "schema. Errors:\n  " + "\n  ".join(errors)
        )
