#!/usr/bin/env python3
"""Tests for the check_cache_hits_empty_post_v6 function in scripts/check-state-schema.py.

T3 / PR-1 of framework v7.7 Validity Closure.

Verifies:
  1. Post-v6 + complete + empty cache_hits[] → CACHE_HITS_EMPTY_POST_V6 finding.
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


# ---------------------------------------------------------------------------
# T3.1 — Post-v6 + complete + empty cache_hits → REJECT
# ---------------------------------------------------------------------------

def test_cache_hits_empty_post_v6_blocks_when_complete():
    """current_phase=complete + post-v6 + cache_hits=[] → REJECT."""
    state = {
        "feature_name": "test-feature",
        "current_phase": "complete",
        "created_at": "2026-04-20T00:00:00Z",  # post-v6 ship date 2026-04-16
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert any(f["code"] == "CACHE_HITS_EMPTY_POST_V6" for f in findings), (
        f"Expected CACHE_HITS_EMPTY_POST_V6 finding for post-v6 complete feature "
        f"with empty cache_hits[]. Got: {findings}"
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
        f"Pre-v6 feature must not trigger CACHE_HITS_EMPTY_POST_V6. Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T3.3 — Post-v6 but not yet complete → still allowed
# ---------------------------------------------------------------------------

def test_cache_hits_empty_post_v6_passes_non_complete():
    """Post-v6 but not complete → empty array still allowed."""
    state = {
        "feature_name": "wip",
        "current_phase": "implementation",
        "created_at": "2026-04-20T00:00:00Z",
        "cache_hits": []
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == [], (
        f"In-progress post-v6 feature must not trigger CACHE_HITS_EMPTY_POST_V6. "
        f"Got: {findings}"
    )


# ---------------------------------------------------------------------------
# T3.4 — Happy path: post-v6 + complete + non-empty cache_hits → PASS
# ---------------------------------------------------------------------------

def test_cache_hits_post_v6_complete_with_entries_passes():
    """Post-v6 + complete + cache_hits non-empty → PASS (the happy path)."""
    state = {
        "feature_name": "ok",
        "current_phase": "complete",
        "created_at": "2026-04-20T00:00:00Z",
        "cache_hits": [{"key": "x", "layer": "L1", "ts": "2026-04-27T00:00:00Z"}]
    }
    findings = check_cache_hits_empty_post_v6(state)
    assert findings == [], (
        f"Post-v6 complete feature with non-empty cache_hits must not trigger "
        f"CACHE_HITS_EMPTY_POST_V6. Got: {findings}"
    )
