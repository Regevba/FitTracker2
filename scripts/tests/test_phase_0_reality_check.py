"""F2 — Tests for phase-0-reality-check.py.

Covers:
- Missing state.json
- Empty task list
- All-done tasks (no advisories)
- Pending task with 2+ keyword matches in git subjects → advisory
- Pending task with 2+ matches in merged PR titles → advisory
- Pending task with task-ID mention in Tier 2.2 log → advisory
- Noise tokens filtered out (won't false-positive on common words)
- Done task with matches → no advisory (status filter)
- File-system contract for output
"""

from __future__ import annotations

import json
import sys
import importlib.util
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "phase-0-reality-check.py"


_spec = importlib.util.spec_from_file_location(
    "phase_0_reality_check", SCRIPT_PATH
)
assert _spec is not None and _spec.loader is not None
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


# ────────────────────────────────────────────────────────────────────────────
# Keyword extraction
# ────────────────────────────────────────────────────────────────────────────


def test_extract_keywords_filters_noise():
    """Common noise words drop out."""
    kw = _mod._extract_keywords(
        "Test the feature for the framework using the scripts above"
    )
    # All of "Test", "the", "feature", "for", "framework", "scripts", "above"
    # are noise per the NOISE_TOKENS set.
    assert kw == [] or all(t.lower() not in _mod.NOISE_TOKENS for t in kw)


def test_extract_keywords_returns_distinct_in_order():
    """Distinct tokens preserved in insertion order."""
    kw = _mod._extract_keywords(
        "Implement backfill_cu_v2 across backfill_cu_v2 sites"
    )
    assert "backfill_cu_v2" in kw
    # Only once despite appearing twice
    assert kw.count("backfill_cu_v2") == 1


def test_extract_keywords_respects_min_len():
    """Tokens shorter than min_len are excluded."""
    kw = _mod._extract_keywords("ab CDE FGHIJ", min_len=5)
    assert "ab" not in kw
    assert "CDE" not in kw
    assert "FGHIJ" in kw


def test_extract_keywords_non_string_input_returns_empty():
    assert _mod._extract_keywords(None) == []
    assert _mod._extract_keywords(42) == []


# ────────────────────────────────────────────────────────────────────────────
# Per-task checks
# ────────────────────────────────────────────────────────────────────────────


def test_pending_task_with_git_matches_gets_advisory():
    """Threshold is ≥2 EVIDENCE ITEMS across all sources (not 2 keyword hits
    within a single item). Two matching commits → advisory.
    """
    task = {
        "id": "T1",
        "status": "pending",
        "description": "Implement BRANCH_ISOLATION_VIOLATION Mode C check",
    }
    git_subjects = [
        ("aaaaaaaa", "feat(gates): BRANCH_ISOLATION_VIOLATION Mode C — added"),
        ("bbbbbbbb", "feat(tests): BRANCH_ISOLATION_VIOLATION Mode C fixture pair"),
    ]
    result = _mod.check_task(task, git_subjects, [], [])
    assert result["advisory"] == "this task may already be done"
    assert len(result["evidence"]["git_commits"]) == 2


def test_pending_task_with_pr_matches_gets_advisory():
    """Two matching PRs trip the threshold. Description needs ≥2 distinct
    keywords that survive noise filtering AND match the PR titles."""
    task = {
        "id": "T1",
        "status": "pending",
        "description": "Implement REPO_ROOT_OVERRIDE environment variable for try-repo harness",
    }
    prs = [
        {
            "repo": "Regevba/FitTracker2",
            "number": 611,
            "title": "fix(gates): REPO_ROOT_OVERRIDE for try-repo harness path-redirect",
        },
        {
            "repo": "Regevba/FitTracker2",
            "number": 612,
            "title": "feat: REPO_ROOT_OVERRIDE wired into try-repo harness scaffold",
        },
    ]
    result = _mod.check_task(task, [], prs, [])
    assert result["advisory"] == "this task may already be done"
    assert len(result["evidence"]["merged_prs"]) == 2


def test_pending_task_with_log_event_id_match_gets_advisory():
    """Multiple matching log events trip the threshold."""
    task = {"id": "T3", "status": "pending", "description": "Wire CI workflow"}
    log_events = [
        {
            "event_type": "implementation",
            "summary": "T3 shipped — CI workflow wired up",
            "timestamp": "2026-06-04T10:00:00Z",
        },
        {
            "event_type": "implementation",
            "summary": "T3 follow-up CI workflow polish",
            "timestamp": "2026-06-04T11:00:00Z",
        },
    ]
    result = _mod.check_task(task, [], [], log_events)
    assert result["advisory"] == "this task may already be done"
    assert len(result["evidence"]["log_events"]) == 2


def test_mixed_evidence_across_sources_trips_threshold():
    """1 git + 1 PR = 2 total evidence items → advisory."""
    task = {
        "id": "T1",
        "status": "pending",
        "description": "Implement BRANCH_ISOLATION_VIOLATION Mode C check",
    }
    git_subjects = [
        ("aaaaaaaa", "feat(gates): BRANCH_ISOLATION_VIOLATION Mode C — added"),
    ]
    prs = [
        {
            "repo": "Regevba/FitTracker2",
            "number": 1,
            "title": "BRANCH_ISOLATION_VIOLATION Mode C tests added",
        }
    ]
    result = _mod.check_task(task, git_subjects, prs, [])
    assert result["advisory"] == "this task may already be done"
    assert result["match_score"] == 2


def test_done_task_never_gets_advisory_even_with_matches():
    """Status filter — done tasks are never flagged."""
    task = {
        "id": "T1",
        "status": "done",
        "description": "Build the REPO_ROOT_OVERRIDE feature",
    }
    prs = [
        {
            "repo": "Regevba/FitTracker2",
            "number": 611,
            "title": "REPO_ROOT_OVERRIDE feature added",
        }
    ]
    result = _mod.check_task(task, [], prs, [])
    assert result["advisory"] is None


def test_single_keyword_match_does_not_trigger_advisory():
    """Requires ≥2 distinct keyword hits to avoid noise."""
    task = {
        "id": "T1",
        "status": "pending",
        "description": "Implement REPO_ROOT_OVERRIDE",
    }
    prs = [
        {
            "repo": "Regevba/FitTracker2",
            "number": 1,
            "title": "Some unrelated PR about REPO_ROOT_OVERRIDE",
        }
    ]
    result = _mod.check_task(task, [], prs, [])
    # Only 1 keyword match — score may be 1, no advisory threshold breach
    assert result["match_score"] <= 1
    assert result["advisory"] is None


# ────────────────────────────────────────────────────────────────────────────
# End-to-end: reality_check on a real feature dir layout
# ────────────────────────────────────────────────────────────────────────────


def test_missing_state_json_raises():
    with pytest.raises(FileNotFoundError):
        _mod.reality_check("does-not-exist-feature")


def test_empty_tasks_returns_zero_findings(tmp_path: Path, monkeypatch):
    """Build a synthetic feature dir + override REPO_ROOT to point at it."""
    feature_dir = tmp_path / ".claude" / "features" / "test-feature"
    feature_dir.mkdir(parents=True)
    state = {"feature_name": "test-feature", "tasks": []}
    (feature_dir / "state.json").write_text(json.dumps(state))
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)

    report = _mod.reality_check("test-feature")
    assert report["task_count"] == 0
    assert report["flagged_count"] == 0
    assert report["findings"] == []


def test_report_metadata_fields(tmp_path: Path, monkeypatch):
    feature_dir = tmp_path / ".claude" / "features" / "f"
    feature_dir.mkdir(parents=True)
    (feature_dir / "state.json").write_text(json.dumps({"tasks": []}))
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)

    report = _mod.reality_check("f", window_days=14)
    assert report["schema_version"] == 1
    assert report["feature"] == "f"
    assert report["window_days"] == 14
    assert "checked_at" in report


# ────────────────────────────────────────────────────────────────────────────
# Resilience
# ────────────────────────────────────────────────────────────────────────────


def test_malformed_log_file_handled_gracefully(
    tmp_path: Path, monkeypatch
):
    """A corrupt feature log file does not crash the script."""
    log_dir = tmp_path / ".claude" / "logs"
    log_dir.mkdir(parents=True)
    (log_dir / "broken.log.json").write_text("not valid json {")
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)

    # Should return empty list rather than raise
    events = _mod._recent_log_events("broken", window_days=30)
    assert events == []


def test_missing_pr_cache_handled_gracefully(
    tmp_path: Path, monkeypatch
):
    """Missing PR cache returns empty list, no crash."""
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)
    prs = _mod._recent_merged_prs(window_days=30)
    assert prs == []


def test_tasks_field_not_list_handled(tmp_path: Path, monkeypatch):
    """state.json where tasks is a dict or missing — should not crash."""
    feature_dir = tmp_path / ".claude" / "features" / "f"
    feature_dir.mkdir(parents=True)
    (feature_dir / "state.json").write_text(json.dumps({"tasks": "weird"}))
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)

    report = _mod.reality_check("f")
    assert report["task_count"] == 0
