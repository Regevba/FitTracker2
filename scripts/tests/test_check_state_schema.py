#!/usr/bin/env python3
"""Tests for the check_cache_hits_empty_post_v6 function in scripts/check-state-schema.py.

T3 / PR-1 of framework v7.7 Validity Closure.

Verifies:
  1. Post-v6 + complete + empty cache_hits[] → CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT
     finding (legacy name: CACHE_HITS_EMPTY_POST_V6, renamed in v7.8.3 — the
     Python function name is preserved; the emission key was renamed).
  2. Pre-v6 features are exempt (empty cache_hits OK at any phase).
  3. Post-v6 but not yet complete → empty cache_hits still allowed.
  4. Post-v6 + complete + non-empty cache_hits → no finding (happy path).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Resolve scripts/ relative to this file so the import works regardless of cwd.
SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

# Import the function under test. The name must exist in check-state-schema.py;
# the failing-test step expects NameError/ImportError if it doesn't yet.
# We import from the module as "check_state_schema" (hyphens not valid in Python
# module names, so we use importlib).
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "check_state_schema",
    SCRIPTS_DIR / "check-state-schema.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

check_cache_hits_empty_post_v6 = _mod.check_cache_hits_empty_post_v6
check_cu_v2_schema = _mod.check_cu_v2_schema
validate_file = _mod.validate_file

# Canonical gate key — mirrors `scripts/check-state-schema.py:308`.
# The Python function name `check_cache_hits_empty_post_v6` retains its
# legacy name (pre-v7.8.3 rename); the EMISSION key is canonical. Using
# a module-level constant locks the invariant against future rename drift,
# mirroring the pattern adopted in `test_gate_coverage.py:169` (PR #320).
CACHE_HITS_GATE_KEY = "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT"


# ---------------------------------------------------------------------------
# T3.1 — Post-v6 + complete + empty cache_hits → REJECT
# ---------------------------------------------------------------------------

def test_cache_hits_empty_post_v6_blocks_when_complete():
    """current_phase=complete + post-Mechanism-C + cache_hits=[] → REJECT.

    Post-v6 (2026-04-16) is necessary but not sufficient — the date must
    also be ≥ MECHANISM_C_SHIP_DATE (2026-05-02). Features whose lifecycle
    predates Mechanism C (the PostToolUse:Read auto-instrumentation) are
    exempt: empty cache_hits[] then means "no instrumentation existed,"
    not "instrumentation failed to fire." Per PR #173 (v7.8 PR-1).
    """
    state = {
        "feature_name": "test-feature",
        "current_phase": "complete",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C (2026-05-02)
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert any(f["code"] == CACHE_HITS_GATE_KEY for f in findings), (
        f"Expected {CACHE_HITS_GATE_KEY} finding for post-Mechanism-C "
        f"complete feature with empty cache_hits[]. Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T3.2 — Pre-v6 feature is exempt
# ---------------------------------------------------------------------------

def test_cache_hits_empty_post_v6_passes_pre_v6():
    """Pre-v6 features are exempt — empty cache_hits OK."""
    state = {
        "feature_name": "old",
        "current_phase": "complete",
        "created_at": "2026-04-15T00:00:00Z",  # pre-v6 ship date (2026-04-16)
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == [], (
        f"Pre-v6 feature must not trigger {CACHE_HITS_GATE_KEY}. Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T3.3 — Post-v6 but not yet complete → still allowed
# ---------------------------------------------------------------------------

def test_cache_hits_empty_post_v6_passes_non_complete():
    """Post-Mechanism-C but not complete → empty array still allowed."""
    state = {
        "feature_name": "wip",
        "current_phase": "implementation",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == [], (
        f"In-progress post-v6 feature must not trigger {CACHE_HITS_GATE_KEY}. "
        f"Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T3.4 — Happy path: post-v6 + complete + non-empty cache_hits → PASS
# ---------------------------------------------------------------------------

def test_cache_hits_post_v6_complete_with_entries_passes():
    """Post-Mechanism-C + complete + cache_hits non-empty → PASS (happy path)."""
    state = {
        "feature_name": "ok",
        "current_phase": "complete",
        "created_at": "2026-05-03T00:00:00Z",  # post-Mechanism-C
        "cache_hits": [{"key": "x", "layer": "L1", "ts": "2026-05-03T00:00:00Z"}]
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == [], (
        f"Post-v6 complete feature with non-empty cache_hits must not trigger "
        f"{CACHE_HITS_GATE_KEY}. Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T7 — check_cu_v2_schema wiring tests
# ---------------------------------------------------------------------------

def test_check_cu_v2_schema_passes_valid():
    """Valid cu_v2 → no findings."""
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 0.5,
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5,
            },
            "total": 2.0,
            "tier_class": "B_medium",
        }
    }
    findings = check_cu_v2_schema(state)
    assert findings == [], (
        f"Valid cu_v2 must not trigger any findings. Got: {findings}"
    )


def test_check_cu_v2_schema_blocks_invalid():
    """Factor out of [0,1] → CU_V2_INVALID finding."""
    state = {
        "cu_v2": {
            "factors": {
                "complexity": 99.0,  # out of [0,1]
                "blast_radius": 0.5,
                "novelty": 0.5,
                "verification_difficulty": 0.5,
            },
            "total": 100.0,
            "tier_class": "A_high",
        }
    }
    findings = check_cu_v2_schema(state)
    assert any("CU_V2_INVALID" in str(f) for f in findings), (
        f"Expected CU_V2_INVALID finding for out-of-range factor. Got: {findings}"
    )


def test_check_cu_v2_schema_passes_pre_v6_no_field():
    """Pre-v6 state without cu_v2 key → exempt, no findings."""
    state = {"feature_name": "old"}
    findings = check_cu_v2_schema(state)
    assert findings == [], (
        f"Pre-v6 state without cu_v2 must not trigger any findings. Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T11 — check_state_no_case_study_link tests
# ---------------------------------------------------------------------------

check_state_no_case_study_link = _mod.check_state_no_case_study_link


def test_state_no_case_study_link_blocks_when_complete():
    """current_phase=complete + missing case_study + missing exempt tag → REJECT."""
    state = {
        "feature_name": "test",
        "current_phase": "complete"
    }
    findings = check_state_no_case_study_link(state)
    assert any(f["code"] == "STATE_NO_CASE_STUDY_LINK" for f in findings), (
        f"Expected STATE_NO_CASE_STUDY_LINK for complete feature without link "
        f"or exempt tag. Got: {findings}"
    )


def test_state_no_case_study_link_passes_with_link():
    state = {
        "feature_name": "test",
        "current_phase": "complete",
        "case_study": "docs/case-studies/x.md"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == [], (
        f"Complete feature with case_study link must not trigger "
        f"STATE_NO_CASE_STUDY_LINK. Got: {findings}"
    )


def test_state_no_case_study_link_passes_with_parent_link():
    """parent_case_study is an accepted alternative to direct case_study."""
    state = {
        "feature_name": "test",
        "current_phase": "complete",
        "parent_case_study": "docs/case-studies/parent.md"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == [], (
        f"Complete feature with parent_case_study link must not trigger "
        f"STATE_NO_CASE_STUDY_LINK. Got: {findings}"
    )


def test_state_no_case_study_link_passes_with_exempt():
    for tag in ("no_case_study_required", "pre_pm_workflow_backfill", "roundup", "framework_meta_retroactive"):
        state = {
            "feature_name": "test",
            "current_phase": "complete",
            "case_study_type": tag
        }
        findings = check_state_no_case_study_link(state)
        assert findings == [], (
            f"exempt tag {tag} should pass STATE_NO_CASE_STUDY_LINK. Got: {findings}"
        )


def test_state_no_case_study_link_passes_pre_complete():
    state = {
        "feature_name": "test",
        "current_phase": "implementation"
    }
    findings = check_state_no_case_study_link(state)
    assert findings == [], (
        f"Non-complete feature must not trigger STATE_NO_CASE_STUDY_LINK. "
        f"Got: {findings}"
    )


# ---------------------------------------------------------------------------
# F-4b — SCHEMA_DRIFT for legacy `created` key (added 2026-05-01)
# Surfaced by 2026-04-30 audit: 43 of 46 state.json used `created` while gate
# read `created_at` → 0% effective coverage. These tests use validate_file
# (not a separate check function) because the check is inline in validate_file
# matching the pattern of the existing legacy-`phase` SCHEMA_DRIFT check.
# ---------------------------------------------------------------------------

def _write_tmp_state(tmp_path, payload: dict):
    p = tmp_path / "state.json"
    import json
    p.write_text(json.dumps(payload))
    return p


def test_schema_drift_created_blocks_legacy_key(tmp_path):
    """`created` without `created_at` → REJECT (matches legacy-phase pattern)."""
    p = _write_tmp_state(tmp_path, {
        "feature_name": "test",
        "created": "2026-04-20T00:00:00Z",
    })
    errors = validate_file(p, enforce_transition=False)
    assert any("legacy `created` key" in e for e in errors), (
        f"Expected legacy-`created` SCHEMA_DRIFT finding. Got: {errors}"
    )


def test_schema_drift_created_passes_canonical(tmp_path):
    """`created_at` only → PASS."""
    p = _write_tmp_state(tmp_path, {
        "feature_name": "test",
        "created_at": "2026-04-20T00:00:00Z",
    })
    errors = validate_file(p, enforce_transition=False)
    assert not any("legacy `created` key" in e for e in errors), (
        f"Canonical `created_at` must not trigger SCHEMA_DRIFT. Got: {errors}"
    )


def test_schema_drift_created_passes_when_both_present(tmp_path):
    """Both keys → PASS the SCHEMA_DRIFT check (presence of `created_at` satisfies).

    Rationale: matches the legacy-`phase` pattern, which also passes when
    both `phase` and `current_phase` are present. Migration tools may produce
    a transient both-keys state; downstream consumers read `created_at`.
    """
    p = _write_tmp_state(tmp_path, {
        "feature_name": "test",
        "created": "2026-04-20T00:00:00Z",
        "created_at": "2026-04-20T00:00:00Z",
    })
    errors = validate_file(p, enforce_transition=False)
    assert not any("legacy `created` key" in e for e in errors), (
        f"Both-keys state must not trigger SCHEMA_DRIFT. Got: {errors}"
    )


# ---------------------------------------------------------------------------
# F-5 — FRAMEWORK_VERSION_FORMAT (added 2026-05-01)
# Surfaced by 2026-04-30 audit: 6 of 46 state.json had unprefixed numeric
# values ("7.6", "6.0"). Format-only check; absence is allowed pending
# backfill PR.
# ---------------------------------------------------------------------------

    # Match on the FRAMEWORK_VERSION_FORMAT error's unique phrase. Avoids substring
# coincidences where (a) the pytest tmp dir path contains "framework_version" and
# (b) the STATE_OWNER_MISSING error's "FT2-canonical features" contains "canonical",
# which together can produce false matches if the assertion is loose. The phrase
# below is unique to the FRAMEWORK_VERSION_FORMAT emit site at check-state-schema.py:680.
_FW_VERSION_FORMAT_PHRASE = "is not in canonical"


def test_framework_version_format_blocks_unprefixed_numeric(tmp_path):
    p = _write_tmp_state(tmp_path, {
        "feature_name": "test",
        "state_owner": "ft2",
        "framework_version": "7.6",
    })
    errors = validate_file(p, enforce_transition=False)
    assert any(_FW_VERSION_FORMAT_PHRASE in e for e in errors), (
        f"Expected FRAMEWORK_VERSION_FORMAT finding for unprefixed '7.6'. "
        f"Got: {errors}"
    )


def test_framework_version_format_passes_canonical_v_prefix(tmp_path):
    for valid in ["v7.7", "v6.0", "v1.0", "v10.20", "v7.7.1", "pre-v5.0"]:
        p = _write_tmp_state(tmp_path, {
            "feature_name": "test",
            "state_owner": "ft2",
            "framework_version": valid,
        })
        errors = validate_file(p, enforce_transition=False)
        assert not any(_FW_VERSION_FORMAT_PHRASE in e for e in errors), (
            f"Canonical {valid!r} must pass FRAMEWORK_VERSION_FORMAT. "
            f"Got: {errors}"
        )


def test_framework_version_format_passes_when_absent(tmp_path):
    """Absence allowed pending backfill PR — only format is enforced."""
    p = _write_tmp_state(tmp_path, {
        "feature_name": "test",
        "state_owner": "ft2",
    })
    errors = validate_file(p, enforce_transition=False)
    assert not any(_FW_VERSION_FORMAT_PHRASE in e for e in errors), (
        f"Absent framework_version must not trigger format check. Got: {errors}"
    )


def test_framework_version_format_blocks_garbage_strings(tmp_path):
    for invalid in ["7", "v7", "version-7.6", "7.6-beta", "latest", ""]:
        p = _write_tmp_state(tmp_path, {
            "feature_name": "test",
            "state_owner": "ft2",
            "framework_version": invalid,
        })
        errors = validate_file(p, enforce_transition=False)
        assert any(_FW_VERSION_FORMAT_PHRASE in e for e in errors), (
            f"Invalid {invalid!r} must trigger FRAMEWORK_VERSION_FORMAT. "
            f"Got: {errors}"
        )


# ────────────────────────────────────────────────────────────────────────────
# F14/F15 dispatch tests — per-gate test_main_dispatch_<gate>() coverage
# Feature: framework-f14-f15-dispatch-test-coverage (Phase 4 implementation).
# Pattern proven by PR #317 (BRANCH_ISOLATION_VIOLATION Mode B prototype).
# Each test invokes main() end-to-end with monkey-patched IO helpers and
# asserts both the rejection path AND Mechanism A row emission.
# ────────────────────────────────────────────────────────────────────────────


def test_main_dispatch_state_no_case_study_link(
    tmp_gate_coverage_ledger,
    make_invalid_state_json,
    monkeypatch,
):
    """T2 — pilot dispatch test. Validates the monkey-patch pattern shape
    by exercising STATE_NO_CASE_STUDY_LINK end-to-end via main().

    The gate fires when:
      - current_phase = "complete"
      - case_study + parent_case_study fields both absent
      - case_study_type not in EXEMPT_CASE_STUDY_TYPES
    """
    import json as _json

    # Build a state.json crafted to FAIL the gate.
    invalid_state = make_invalid_state_json("STATE_NO_CASE_STUDY_LINK")

    # Monkey-patch IO helpers so main() sees our synthetic state file.
    monkeypatch.setattr(
        _mod, "collect_staged_state_files", lambda: [invalid_state.path]
    )
    monkeypatch.setattr(
        _mod, "collect_all_staged_files", lambda: [str(invalid_state.path)]
    )
    # Mechanism A: route ledger writes to the tmp path (K3 guard).
    monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", "--staged"])

    # Drive main() end-to-end.
    rc = _mod.main()

    # STATE_NO_CASE_STUDY_LINK is enforced → rc must be non-zero.
    assert rc != 0, (
        f"STATE_NO_CASE_STUDY_LINK failed to fire on invalid state.json; rc={rc}. "
        "Either the gate has regressed OR the violation recipe is no longer valid."
    )

    # Mechanism A: ledger must exist and contain a row for our gate.
    assert tmp_gate_coverage_ledger.exists(), (
        "Coverage ledger missing — main() bypassed Mechanism A telemetry. "
        "This is the silent-pass class that F14 closes."
    )
    rows = [
        _json.loads(line)
        for line in tmp_gate_coverage_ledger.read_text().splitlines()
        if line.strip()
    ]
    matching = [r for r in rows if r.get("gate") == "STATE_NO_CASE_STUDY_LINK"]
    assert len(matching) >= 1, (
        f"STATE_NO_CASE_STUDY_LINK did not emit a candidate row to "
        f"gate-coverage.jsonl; got gates: {[r.get('gate') for r in rows]}"
    )
    assert matching[0].get("candidates", 0) > 0, (
        f"STATE_NO_CASE_STUDY_LINK row has zero candidates: {matching[0]}"
    )


def test_main_dispatch_cu_v2_invalid(
    tmp_gate_coverage_ledger,
    make_invalid_state_json,
    monkeypatch,
):
    """T4 — CU_V2_INVALID dispatch test. Gate fires when state.cu_v2 has a
    malformed shape that validate-cu-v2.py rejects."""
    import json as _json

    invalid_state = make_invalid_state_json("CU_V2_INVALID")

    monkeypatch.setattr(
        _mod, "collect_staged_state_files", lambda: [invalid_state.path]
    )
    monkeypatch.setattr(
        _mod, "collect_all_staged_files", lambda: [str(invalid_state.path)]
    )
    monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", "--staged"])

    rc = _mod.main()

    # Enforced gate → non-zero rc.
    assert rc != 0, f"CU_V2_INVALID failed to fire on malformed cu_v2; rc={rc}"

    assert tmp_gate_coverage_ledger.exists()
    rows = [
        _json.loads(line)
        for line in tmp_gate_coverage_ledger.read_text().splitlines()
        if line.strip()
    ]
    matching = [r for r in rows if r.get("gate") == "CU_V2_INVALID"]
    assert len(matching) >= 1, (
        f"CU_V2_INVALID did not emit a candidate row; got: "
        f"{[r.get('gate') for r in rows]}"
    )
    assert matching[0].get("candidates", 0) > 0


def test_main_dispatch_cache_hits_auto_instrumentation_drift(
    tmp_gate_coverage_ledger,
    make_invalid_state_json,
    monkeypatch,
):
    """T5 — CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT dispatch test. Gate fires
    when a post-Mechanism-C feature (created_at >= 2026-05-02) reaches
    current_phase=complete with empty cache_hits[]. This is the gate whose
    keying-drift incident (honesty-ledger FT2-FH-001) motivated F14."""
    import json as _json

    invalid_state = make_invalid_state_json("CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT")

    monkeypatch.setattr(
        _mod, "collect_staged_state_files", lambda: [invalid_state.path]
    )
    monkeypatch.setattr(
        _mod, "collect_all_staged_files", lambda: [str(invalid_state.path)]
    )
    monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", "--staged"])

    rc = _mod.main()

    # Enforced post-v7.8.3 → non-zero rc.
    assert rc != 0, (
        f"CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT failed to fire; rc={rc}. "
        "Check that the recipe's created_at is past MECHANISM_C_SHIP_DATE."
    )

    assert tmp_gate_coverage_ledger.exists()
    rows = [
        _json.loads(line)
        for line in tmp_gate_coverage_ledger.read_text().splitlines()
        if line.strip()
    ]
    matching = [r for r in rows if r.get("gate") == "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT"]
    assert len(matching) >= 1, (
        f"CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT did not emit a candidate row; "
        f"got: {[r.get('gate') for r in rows]}"
    )
    assert matching[0].get("candidates", 0) > 0


def test_main_dispatch_phase_transition_no_log(
    tmp_gate_coverage_ledger,
    make_invalid_state_json,
    monkeypatch,
):
    """T6 — PHASE_TRANSITION_NO_LOG dispatch test.

    Highest-risk F15 gate (guards most-frequent state mutation). Fires when:
      - enforce_transition=True (--staged mode)
      - committed (HEAD) current_phase != in-file current_phase
      - .claude/logs/<feature>.log.json missing OR no recent matching event

    We mock _feature_slug_from_path to return a known slug, _load_committed_state
    to return a state with the OLD phase, and _load_feature_log to return None.
    """
    import json as _json

    invalid_state = make_invalid_state_json("PHASE_TRANSITION_NO_LOG")

    # Tell the dispatcher this file belongs to a known feature slug
    monkeypatch.setattr(
        _mod, "_feature_slug_from_path", lambda p: "test-no-log-feature"
    )
    # Simulate HEAD: this feature exists in HEAD with current_phase=research,
    # so the in-file change to "prd" registers as a phase transition.
    monkeypatch.setattr(
        _mod,
        "_load_committed_state",
        lambda p: {"current_phase": "research"},
    )
    # Simulate: no log file exists for this feature → LOG check fails
    monkeypatch.setattr(_mod, "_load_feature_log", lambda slug: None)

    monkeypatch.setattr(
        _mod, "collect_staged_state_files", lambda: [invalid_state.path]
    )
    monkeypatch.setattr(
        _mod, "collect_all_staged_files", lambda: [str(invalid_state.path)]
    )
    monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", "--staged"])

    rc = _mod.main()

    assert rc != 0, f"PHASE_TRANSITION_NO_LOG failed to fire; rc={rc}"

    assert tmp_gate_coverage_ledger.exists()
    rows = [
        _json.loads(line)
        for line in tmp_gate_coverage_ledger.read_text().splitlines()
        if line.strip()
    ]
    matching = [r for r in rows if r.get("gate") == "PHASE_TRANSITION_NO_LOG"]
    assert len(matching) >= 1, (
        f"PHASE_TRANSITION_NO_LOG did not emit a candidate row; got: "
        f"{[r.get('gate') for r in rows]}"
    )
    assert matching[0].get("candidates", 0) > 0


def test_main_dispatch_phase_transition_no_timing(
    tmp_gate_coverage_ledger,
    make_invalid_state_json,
    monkeypatch,
):
    """T7 — PHASE_TRANSITION_NO_TIMING dispatch test.

    Fires when:
      - enforce_transition=True
      - phase changed vs HEAD
      - timing.phases.<new_phase>.started_at missing OR
      - timing.phases.<old_phase>.ended_at missing (when old_phase exists)

    We provide a fresh log event (to pass LOG check) but omit the new
    phase's timing entry.
    """
    import json as _json
    import datetime as _dt

    invalid_state = make_invalid_state_json("PHASE_TRANSITION_NO_TIMING")

    monkeypatch.setattr(
        _mod, "_feature_slug_from_path", lambda p: "test-no-timing-feature"
    )
    monkeypatch.setattr(
        _mod,
        "_load_committed_state",
        lambda p: {"current_phase": "research"},
    )
    # LOG check needs to PASS so we isolate TIMING. Provide a fresh log
    # event for the new phase.
    now_iso = _dt.datetime.now(_dt.timezone.utc).isoformat().replace("+00:00", "Z")
    monkeypatch.setattr(
        _mod,
        "_load_feature_log",
        lambda slug: {
            "events": [
                {
                    "event_type": "phase_started",
                    "phase": "prd",
                    "timestamp": now_iso,
                }
            ]
        },
    )

    monkeypatch.setattr(
        _mod, "collect_staged_state_files", lambda: [invalid_state.path]
    )
    monkeypatch.setattr(
        _mod, "collect_all_staged_files", lambda: [str(invalid_state.path)]
    )
    monkeypatch.setattr(_mod, "GATE_COVERAGE_LEDGER", tmp_gate_coverage_ledger)
    monkeypatch.setattr(sys, "argv", ["check-state-schema.py", "--staged"])

    rc = _mod.main()

    assert rc != 0, f"PHASE_TRANSITION_NO_TIMING failed to fire; rc={rc}"

    assert tmp_gate_coverage_ledger.exists()
    rows = [
        _json.loads(line)
        for line in tmp_gate_coverage_ledger.read_text().splitlines()
        if line.strip()
    ]
    matching = [r for r in rows if r.get("gate") == "PHASE_TRANSITION_NO_TIMING"]
    assert len(matching) >= 1, (
        f"PHASE_TRANSITION_NO_TIMING did not emit a candidate row; got: "
        f"{[r.get('gate') for r in rows]}"
    )
    assert matching[0].get("candidates", 0) > 0
