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


# ────────────────────────────────────────────────────────────────────────────
# F14 dispatch test — exercises main() end-to-end for CASE_STUDY_MISSING_FIELDS.
# Feature: framework-f14-f15-dispatch-test-coverage (Phase 4 T3).
# ────────────────────────────────────────────────────────────────────────────


def test_main_dispatch_case_study_missing_fields(tmp_path, monkeypatch):
    """T3 — CASE_STUDY_MISSING_FIELDS dispatch test on the
    check-case-study-preflight.py surface (S4 — missed in integration-spec §1).

    Honest finding (worth a backlog ticket): unlike the check-state-schema.py
    gates, this script does NOT emit Mechanism A `gate-coverage.jsonl` rows.
    F14's premise (per PRD §5) is that gates with internal-function tests
    but no dispatch test are at risk of silent-pass — this gate adds a
    SECOND class of risk: no Mechanism A coverage emission at all. We
    assert rc != 0 as the dispatch signal; coverage-emission verification
    is deferred to a follow-up backlog item (see T12 — open a
    `check-case-study-preflight Mechanism A coverage` ticket).

    Recipe: tmp .md with frontmatter dated >= cutoff missing REQUIRED fields.
    Monkey-patch `_is_exempt` so the tmp file (outside CASE_STUDIES_DIR)
    is treated as eligible.
    """
    invalid_case_study = tmp_path / "fake-feature-case-study.md"
    invalid_case_study.write_text("""---
date_written: 2026-05-22
title: Fake feature
---

# Fake feature case study body
""")
    # Missing: work_type, success_metrics, kill_criteria, dispatch_pattern

    monkeypatch.setattr(_mod, "_is_exempt", lambda p: False)
    monkeypatch.setattr(
        _mod, "collect_staged_case_studies", lambda: [invalid_case_study]
    )
    monkeypatch.setattr(sys, "argv", ["check-case-study-preflight.py", "--staged"])

    rc = _mod.main()

    assert rc != 0, (
        f"CASE_STUDY_MISSING_FIELDS failed to fire via main() dispatch; rc={rc}. "
        "Either the gate has regressed OR the recipe no longer matches the "
        "REQUIRED_FRONTMATTER_FIELDS list."
    )


# ---------------------------------------------------------------------------
# Mechanism A coverage instrumentation (2026-07-21 — closes the telemetry
# blind spot: CASE_STUDY_MISSING_FIELDS was the last live gate not emitting
# gate-coverage.jsonl rows, so it was invisible to the F17 index +
# GATE_COVERAGE_ZERO).
# ---------------------------------------------------------------------------

def test_missing_fields_emits_gate_coverage(tmp_path):
    """The gate records candidate/checked/skip on the shared GateCoverage
    tracker: 1 post-cutoff-missing file → checked; 1 pre-cutoff + 1
    no-frontmatter → skipped with distinct reasons."""
    checked_file = tmp_path / "checked.md"
    checked_file.write_text("---\ndate_written: 2026-04-29\ntitle: T\n---\n")
    pre_cutoff = tmp_path / "old.md"
    pre_cutoff.write_text("---\ndate_written: 2026-04-15\ntitle: Old\n---\n")
    no_fm = tmp_path / "plain.md"
    no_fm.write_text("# Just a markdown body, no frontmatter\n")

    cov = _mod.GateCoverage(mode="explicit")
    for f in (checked_file, pre_cutoff, no_fm):
        _mod.check_case_study_missing_fields(f, coverage=cov)

    ledger = tmp_path / "gc.jsonl"
    cov.write_jsonl(ledger)
    import json
    row = json.loads(ledger.read_text().splitlines()[0])
    assert row["gate"] == "CASE_STUDY_MISSING_FIELDS"
    assert row["candidates"] == 3
    assert row["checked"] == 1
    assert row["skipped"] == 2
    assert row["skip_reasons"] == {"no_frontmatter": 1, "pre_cutoff": 1}


def test_missing_fields_coverage_optional_no_behavior_change(tmp_path):
    """Passing no coverage tracker must not change findings (back-compat)."""
    cs = tmp_path / "cs.md"
    cs.write_text("---\ndate_written: 2026-04-29\ntitle: T\n---\n")
    assert _finding_code(check_case_study_missing_fields(cs)[0]) == "CASE_STUDY_MISSING_FIELDS"
