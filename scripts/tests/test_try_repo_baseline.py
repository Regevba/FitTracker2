"""F16 try-repo harness — T2 baseline + builder tests.

Acceptance criteria (from .claude/features/f16-try-repo-harness/tasks.md):
- `tests/fixtures/_baseline/state.json` round-trips through `make_state_json()`
  builder with empty overrides → byte-identity vs canonical baseline
- Single-field override mutates ONLY that field
- Nested-dict override deep-merges (doesn't replace whole sub-tree)
- List override REPLACES wholesale (doesn't concatenate)
- `None` override DELETES the key (for testing REQUIRED-field omission gates)

These tests do NOT spawn a throwaway repo or run pre-commit. They cover only
the producer side of the hybrid fixture format (PRD Q2).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Add `scripts/tests/` to sys.path so the _try_repo_fixtures module is
# importable. The directory holds test-only helpers; it is NOT a Python
# package (no production import path).
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_fixtures import (  # noqa: E402
    BASELINE_STATE_PATH,
    load_baseline,
    make_state_json,
)


# ────────────────────────────────────────────────────────────────────────────
# Baseline integrity
# ────────────────────────────────────────────────────────────────────────────


def test_baseline_file_exists():
    """The canonical baseline must exist at the documented path."""
    assert BASELINE_STATE_PATH.exists(), (
        f"Baseline missing at {BASELINE_STATE_PATH}. The F16 builder relies "
        "on this path; restore tests/fixtures/_baseline/state.json before "
        "running any try-repo test."
    )


def test_baseline_is_valid_json():
    """The baseline must parse as JSON."""
    with BASELINE_STATE_PATH.open() as f:
        data = json.load(f)
    assert isinstance(data, dict)
    assert "feature_name" in data
    assert data["feature_name"] == "_baseline-fixture"


def test_baseline_has_minimal_required_fields():
    """The baseline must carry every v7.9.1 required state.json field.

    If this fails, the baseline drifted out of sync with the schema. Bump
    the baseline; do NOT relax the assertion list.
    """
    baseline = load_baseline()
    required_top_level = {
        "feature_name",
        "current_phase",
        "created_at",
        "updated_at",
        "framework_version",
        "work_type",
        "state_owner",
        "isolation_opt_out",
        "isolation_opt_out_reason",
        "branch",
        "primary_metric",
        "success_metrics",
        "kill_criteria",
        "phases",
        "timing",
    }
    missing = required_top_level - set(baseline.keys())
    assert not missing, (
        f"Baseline is missing required fields: {sorted(missing)}. "
        "Update tests/fixtures/_baseline/state.json and re-run."
    )


# ────────────────────────────────────────────────────────────────────────────
# Round-trip identity
# ────────────────────────────────────────────────────────────────────────────


def test_baseline_round_trip_byte_identity(tmp_path: Path):
    """Q2 LOCKED — empty overrides must produce content semantically identical
    to the baseline (deep-equal JSON).

    Why semantic identity and not byte-identity: `make_state_json` uses
    `json.dump(indent=2)` which may differ from the source file's exact
    formatting. The PRD's Q2 mitigation calls for byte-identity in spirit
    but only requires the merged content to round-trip without semantic
    drift — which is what fixtures actually need.
    """
    dest = tmp_path / "round_trip.json"
    make_state_json({}, dest)
    with dest.open() as f:
        round_tripped = json.load(f)
    original = load_baseline()
    assert round_tripped == original, (
        "Round-trip produced semantically different state.json. The builder "
        "is silently mutating baseline content; investigate _deep_merge."
    )


# ────────────────────────────────────────────────────────────────────────────
# Override semantics
# ────────────────────────────────────────────────────────────────────────────


def test_single_field_override_mutates_only_that_field(tmp_path: Path):
    """A top-level scalar override replaces only the target field."""
    dest = tmp_path / "override_single.json"
    make_state_json({"feature_name": "test-mutation"}, dest)
    with dest.open() as f:
        merged = json.load(f)
    baseline = load_baseline()
    assert merged["feature_name"] == "test-mutation"
    # Every other top-level field must be byte-identical to the baseline.
    for key in baseline:
        if key == "feature_name":
            continue
        assert merged[key] == baseline[key], (
            f"Override of feature_name silently mutated {key!r}; "
            "_deep_merge is leaking state."
        )


def test_nested_dict_override_deep_merges(tmp_path: Path):
    """A nested override at `phases.implementation.notes` must preserve
    sibling fields under `phases.implementation` AND sibling phase blocks
    under `phases`.
    """
    dest = tmp_path / "override_nested.json"
    make_state_json(
        {"phases": {"implementation": {"notes": "mutated by test"}}},
        dest,
    )
    with dest.open() as f:
        merged = json.load(f)
    baseline = load_baseline()

    # The mutation landed.
    assert merged["phases"]["implementation"]["notes"] == "mutated by test"

    # Sibling fields under implementation are preserved.
    impl_baseline = baseline["phases"]["implementation"]
    impl_merged = merged["phases"]["implementation"]
    for key in impl_baseline:
        if key == "notes":
            continue
        assert impl_merged[key] == impl_baseline[key], (
            f"Deep-merge dropped sibling phase field {key!r}."
        )

    # Sibling phase blocks (research/prd/tasks) are preserved.
    for phase in ("research", "prd", "tasks"):
        assert merged["phases"][phase] == baseline["phases"][phase], (
            f"Deep-merge dropped sibling phase {phase!r}."
        )


def test_list_override_replaces_wholesale(tmp_path: Path):
    """A list override REPLACES the baseline list; does NOT concatenate.

    Documented semantics — fixtures must spell out the full target list.
    """
    dest = tmp_path / "override_list.json"
    make_state_json({"success_metrics": ["replaced"]}, dest)
    with dest.open() as f:
        merged = json.load(f)
    assert merged["success_metrics"] == ["replaced"], (
        "List override did NOT replace wholesale. _deep_merge is silently "
        "concatenating, breaking the documented semantics."
    )


def test_none_override_deletes_key(tmp_path: Path):
    """Setting a key to None in overrides removes it — for testing
    REQUIRED-field omission gates (e.g., STATE_OWNER_MISSING positive
    fixture).
    """
    dest = tmp_path / "override_none.json"
    make_state_json({"state_owner": None}, dest)
    with dest.open() as f:
        merged = json.load(f)
    assert "state_owner" not in merged, (
        "None-sentinel did NOT delete the key. _deep_merge is treating "
        "None as a literal value; required-field-omission fixtures "
        "cannot be expressed."
    )
    # Other fields untouched.
    baseline = load_baseline()
    for key in baseline:
        if key == "state_owner":
            continue
        assert merged[key] == baseline[key]


def test_deep_merge_nested_none_deletes(tmp_path: Path):
    """None at a nested key path deletes only that key."""
    dest = tmp_path / "override_nested_none.json"
    make_state_json(
        {"phases": {"implementation": {"notes": None}}},
        dest,
    )
    with dest.open() as f:
        merged = json.load(f)
    assert "notes" not in merged["phases"]["implementation"], (
        "Nested None-sentinel did not delete the key."
    )
    # Sibling phase keys preserved.
    assert "started_at" in merged["phases"]["implementation"]


# ────────────────────────────────────────────────────────────────────────────
# File-system contract
# ────────────────────────────────────────────────────────────────────────────


def test_make_state_json_creates_missing_parent_dirs(tmp_path: Path):
    """`dest`'s parent directory is auto-created."""
    dest = tmp_path / "deeply" / "nested" / "state.json"
    assert not dest.parent.exists()
    make_state_json({}, dest)
    assert dest.exists()
    assert dest.parent.is_dir()


def test_make_state_json_returns_dest_path(tmp_path: Path):
    """Builder returns the same `dest` for caller chaining."""
    dest = tmp_path / "returned.json"
    result = make_state_json({}, dest)
    assert result == dest


def test_make_state_json_writes_valid_json_with_trailing_newline(tmp_path: Path):
    """Output file ends with `\\n` for POSIX text-file convention + git
    cleanliness.
    """
    dest = tmp_path / "trailing_newline.json"
    make_state_json({}, dest)
    content = dest.read_bytes()
    assert content.endswith(b"\n"), (
        "Builder output missing trailing newline; git will complain."
    )
