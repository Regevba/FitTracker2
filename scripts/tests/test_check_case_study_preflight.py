#!/usr/bin/env python3
"""Tests for the check_case_study_missing_fields function in scripts/check-case-study-preflight.py.

T12 / PR-4 of framework v7.7 Validity Closure.

Verifies:
  1. Post-2026-04-28 case study missing required frontmatter fields → REJECT.
  2. Pre-2026-04-28 case studies are exempt (forward-only rule).
  3. Post-2026-04-28 case study with all required fields → PASS.
  4. Missing fields are enumerated in the finding message.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Resolve scripts/ relative to this file so the import works regardless of cwd.
SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

import importlib.util

_spec = importlib.util.spec_from_file_location(
    "check_case_study_preflight",
    SCRIPTS_DIR / "check-case-study-preflight.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

check_case_study_missing_fields = _mod.check_case_study_missing_fields


def _finding_code(finding: dict) -> str:
    """Extract the code field from a finding dict."""
    return finding.get("code", "")


# ---------------------------------------------------------------------------
# T12: CASE_STUDY_MISSING_FIELDS — post-cutoff blocks
# ---------------------------------------------------------------------------

def test_case_study_missing_fields_blocks_post_cutoff(tmp_path):
    """Case study dated >= 2026-04-28 missing required fields → REJECT."""
    cs = tmp_path / "test-case-study.md"
    cs.write_text('''---
date_written: 2026-04-29
title: Test
---
# Test
''')
    findings = check_case_study_missing_fields(cs)
    codes = [_finding_code(f) for f in findings]
    assert "CASE_STUDY_MISSING_FIELDS" in codes, (
        f"Expected CASE_STUDY_MISSING_FIELDS for post-cutoff file missing required "
        f"fields. Got: {findings}"
    )


def test_case_study_missing_fields_passes_pre_cutoff(tmp_path):
    """Pre-2026-04-28 case studies are exempt (forward-only rule)."""
    cs = tmp_path / "old.md"
    cs.write_text('''---
date_written: 2026-04-15
title: Old
---
''')
    findings = check_case_study_missing_fields(cs)
    assert findings == [], (
        f"Expected no findings for pre-cutoff file. Got: {findings}"
    )


def test_case_study_missing_fields_passes_with_all_fields(tmp_path):
    """Post-cutoff case study with all required fields → PASS."""
    cs = tmp_path / "complete.md"
    cs.write_text('''---
date_written: 2026-04-29
work_type: Feature
dispatch_pattern: serial
success_metrics:
  primary: "X to Y"
kill_criteria:
  - "Z"
title: Complete
---
''')
    findings = check_case_study_missing_fields(cs)
    assert findings == [], (
        f"Expected no findings for complete post-cutoff file. Got: {findings}"
    )


def test_case_study_missing_fields_partial_required_listed(tmp_path):
    """Missing fields are enumerated in the finding message."""
    cs = tmp_path / "partial.md"
    cs.write_text('''---
date_written: 2026-04-29
work_type: Feature
title: Partial
---
''')  # missing: success_metrics, kill_criteria, dispatch_pattern
    findings = check_case_study_missing_fields(cs)
    assert len(findings) > 0, "Expected at least one finding for partial file"
    msg = str(findings)
    assert "success_metrics" in msg, f"Expected 'success_metrics' in findings message. Got: {msg}"
    assert "kill_criteria" in msg, f"Expected 'kill_criteria' in findings message. Got: {msg}"
    assert "dispatch_pattern" in msg, f"Expected 'dispatch_pattern' in findings message. Got: {msg}"


def test_case_study_missing_fields_no_frontmatter_exempt(tmp_path):
    """File with no YAML frontmatter at all → no finding (another check handles)."""
    cs = tmp_path / "no-fm.md"
    cs.write_text('''# Old Style Case Study

**Date written:** 2026-04-29

This case study has no YAML frontmatter.
''')
    findings = check_case_study_missing_fields(cs)
    # Files without YAML frontmatter are exempt from this check
    # (they predate the YAML format or lack date in frontmatter)
    assert findings == [], (
        f"Expected no findings for file without YAML frontmatter. Got: {findings}"
    )


def test_case_study_missing_fields_on_cutoff_date_triggers(tmp_path):
    """Case study dated exactly 2026-04-28 (the cutoff) is subject to the check."""
    cs = tmp_path / "cutoff.md"
    cs.write_text('''---
date_written: 2026-04-28
title: On cutoff
---
''')
    findings = check_case_study_missing_fields(cs)
    codes = [_finding_code(f) for f in findings]
    assert "CASE_STUDY_MISSING_FIELDS" in codes, (
        f"Expected CASE_STUDY_MISSING_FIELDS for file dated exactly on cutoff. Got: {findings}"
    )
