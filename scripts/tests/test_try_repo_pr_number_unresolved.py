"""F16 try-repo coverage note for PR_NUMBER_UNRESOLVED — documented structural skip.

PR_NUMBER_UNRESOLVED resolves `phases.merge.pr_number` against a live
`gh pr list --state all` call (`_load_pr_cache`), returning None — and skipping
the check with reason `gh_unavailable` — whenever `gh` is missing or
unauthenticated. The try-repo harness runs the REAL `.githooks/pre-commit` as a
subprocess with HOME scrubbed, so:

  1. `gh` is unauthenticated in that environment → `_load_pr_cache()` returns
     None → the gate always skips `gh_unavailable`, never reaching `checked()`.
  2. `_load_pr_cache` shells out inside the subprocess, so in-process
     monkeypatching (the technique the unit/function tests use) cannot reach it.

Exercising this gate deterministically would require either real `gh` auth
(network + non-deterministic corpus) or a fake `gh` on PATH returning a fixed
PR list — both out of scope for the hermetic try-repo layer. The gate's
resolve/skip logic IS covered at the unit/function layer via monkeypatched
`_load_pr_cache`. This mirrors the STATE_OWNER_LOCATION_MISMATCH documented
skip in test_try_repo_closure_gates.py.
"""
from __future__ import annotations

import pytest


@pytest.mark.skip(
    reason=(
        "PR_NUMBER_UNRESOLVED skips `gh_unavailable` in the hermetic try-repo "
        "harness (real pre-commit subprocess + scrubbed HOME → unauthenticated "
        "`gh` → `_load_pr_cache()` returns None). Not reachable without real gh "
        "auth or a fake-gh-on-PATH shim; covered at the unit/function layer via "
        "monkeypatched _load_pr_cache. See module docstring."
    )
)
def test_pr_number_unresolved_placeholder():
    """Placeholder for the structurally-skipped gate. See decorator reason."""
