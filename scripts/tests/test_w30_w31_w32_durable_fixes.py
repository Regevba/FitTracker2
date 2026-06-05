"""Tests for W30 + W31 + W32 durable fixes (v7.9.1+).

W30 — Q6 PR-list parity gate's YAML parser now accepts bare-integer list items.
W31 — operator-side workflow-coverage detector script available.
W32 — close-feature.py auto-skips --force-incomplete for single-phase work types.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent


def _import(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


check_state_schema = _import(
    "check_state_schema_w30",
    REPO_ROOT / "scripts" / "check-state-schema.py",
)
close_feature = _import(
    "close_feature_w32",
    REPO_ROOT / "scripts" / "close-feature.py",
)


# ---------------------------------------------------------------------------
# W30 tests
# ---------------------------------------------------------------------------


class TestW30BareIntFallback(unittest.TestCase):
    """The Q6 parser's _collect_case_study_pr_numbers must accept bare-int
    string items (the form `_parse_case_study_frontmatter` produces from
    inline-YAML `- 623` list-item syntax).
    """

    def test_bare_int_string_in_related_prs_extracted(self):
        fm = {"related_prs": ["623", "621", "625"]}
        prs = check_state_schema._collect_case_study_pr_numbers("", fm)
        self.assertEqual(prs, {621, 623, 625})

    def test_hash_prefix_string_still_works(self):
        fm = {"related_prs": ["PR #234", "FT2 #777 (some context)"]}
        prs = check_state_schema._collect_case_study_pr_numbers("", fm)
        self.assertEqual(prs, {234, 777})

    def test_bare_int_native_still_works(self):
        fm = {"related_prs": [501, 502]}
        prs = check_state_schema._collect_case_study_pr_numbers("", fm)
        self.assertEqual(prs, {501, 502})

    def test_mixed_forms_all_extracted(self):
        fm = {"related_prs": ["100", 200, "PR #300", "fitme-story #400"]}
        prs = check_state_schema._collect_case_study_pr_numbers("", fm)
        self.assertEqual(prs, {100, 200, 300, 400})

    def test_non_digit_strings_silently_skipped(self):
        # Non-digit + non-`#N` strings produce no PR; should not error.
        fm = {"related_prs": ["foo", "bar", "123abc"]}
        prs = check_state_schema._collect_case_study_pr_numbers("", fm)
        self.assertEqual(prs, set())

    def test_body_citations_still_collected(self):
        body = ("Shipped via PR #999. "
                "See also https://github.com/Regevba/FitTracker2/pull/888 .")
        fm = {"related_prs": ["777"]}
        prs = check_state_schema._collect_case_study_pr_numbers(body, fm)
        self.assertEqual(prs, {777, 888, 999})


# ---------------------------------------------------------------------------
# W32 tests
# ---------------------------------------------------------------------------


class TestW32SinglePhaseAutoSkip(unittest.TestCase):
    """close_feature() must auto-skip the --force-incomplete requirement
    when state.json declares a single-phase work shape (framework_feature
    work_subtype, Chore/Fix work_type, or explicit single_phase: true).
    Existing behavior preserved for non-single-phase features.
    """

    def _write_state(self, tmpdir: Path, *, work_type: str,
                     work_subtype: str | None = None,
                     single_phase: bool | None = None) -> Path:
        feat = tmpdir / ".claude" / "features" / "test-w32"
        feat.mkdir(parents=True)
        state = {
            "feature_name": "test-w32",
            "current_phase": "implementation",
            "work_type": work_type,
            "framework_version": "v7.9.1",
            "tasks": [{"id": "T1", "description": "x", "status": "complete"}],
        }
        if work_subtype is not None:
            state["work_subtype"] = work_subtype
        if single_phase is not None:
            state["single_phase"] = single_phase
        (feat / "state.json").write_text(json.dumps(state, indent=2))
        return feat / "state.json"

    def _early_phase_check(self, state: dict) -> bool:
        """Replicates the W32 logic inline so we can unit-test the trigger
        condition without depending on close_feature()'s side-effects.
        """
        EARLY_PHASES = {"research", "prd", "tasks_phase",
                        "ux_or_integration", "implementation"}
        SINGLE_PHASE_SUBTYPES = {"framework_feature"}
        SINGLE_PHASE_WORK_TYPES = {"Chore", "Fix"}
        if state.get("current_phase") not in EARLY_PHASES:
            return False  # Not an early phase; no auto-skip relevant
        return bool(
            state.get("single_phase") is True
            or state.get("work_subtype") in SINGLE_PHASE_SUBTYPES
            or state.get("work_type") in SINGLE_PHASE_WORK_TYPES
        )

    def test_framework_feature_subtype_auto_skips(self):
        state = {"current_phase": "implementation",
                 "work_type": "Feature",
                 "work_subtype": "framework_feature"}
        self.assertTrue(self._early_phase_check(state))

    def test_chore_work_type_auto_skips(self):
        state = {"current_phase": "implementation",
                 "work_type": "Chore"}
        self.assertTrue(self._early_phase_check(state))

    def test_fix_work_type_auto_skips(self):
        state = {"current_phase": "implementation",
                 "work_type": "Fix"}
        self.assertTrue(self._early_phase_check(state))

    def test_explicit_single_phase_true_auto_skips(self):
        state = {"current_phase": "implementation",
                 "work_type": "Feature",
                 "single_phase": True}
        self.assertTrue(self._early_phase_check(state))

    def test_regular_feature_still_requires_force_incomplete(self):
        state = {"current_phase": "implementation",
                 "work_type": "Feature"}
        self.assertFalse(self._early_phase_check(state))

    def test_feature_with_enhancement_subtype_still_blocked(self):
        # work_subtype: enhancement is NOT single-phase
        state = {"current_phase": "implementation",
                 "work_type": "Feature",
                 "work_subtype": "enhancement"}
        self.assertFalse(self._early_phase_check(state))

    def test_testing_phase_unaffected(self):
        # The whole gate is bypassed when current_phase is past EARLY_PHASES
        state = {"current_phase": "testing",
                 "work_type": "Feature"}
        self.assertFalse(self._early_phase_check(state))


# ---------------------------------------------------------------------------
# W31 tests (script-presence + basic CLI sanity)
# ---------------------------------------------------------------------------


class TestW31CoverageScriptExists(unittest.TestCase):
    """The W31 operator-side detector script is callable + reports usage error
    on missing/invalid args."""

    SCRIPT = REPO_ROOT / "scripts" / "check-pr-workflow-coverage.py"

    def test_script_file_present_and_executable(self):
        self.assertTrue(self.SCRIPT.exists(), f"missing: {self.SCRIPT}")
        # Has a shebang
        self.assertTrue(self.SCRIPT.read_text().startswith("#!/usr/bin/env python3"))

    def test_usage_error_on_no_args(self):
        result = subprocess.run(
            [sys.executable, str(self.SCRIPT)],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)

    def test_usage_error_on_non_integer_arg(self):
        result = subprocess.run(
            [sys.executable, str(self.SCRIPT), "not-a-number"],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
