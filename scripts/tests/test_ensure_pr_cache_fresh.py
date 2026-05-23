#!/usr/bin/env python3
"""Dispatch test for the `PR_CACHE_STALE` gate in `scripts/ensure-pr-cache-fresh.py`.

T10 of feature `framework-f14-f15-dispatch-test-coverage` (Phase 4).
Surface S3 per integration-spec.md §2.3.

This script is the v7.8.4 PR-cache freshness gate. Unlike the
`check-state-schema.py` family (Surface S1), it does **not** emit a
Mechanism A coverage row to `.claude/logs/gate-coverage.jsonl`. The
signal that the gate fired is:

  1. The string `PR_CACHE_STALE:` printed to stderr; AND
  2. An attempt to invoke `scripts/refresh-pr-cache.py` via subprocess.

The exit code depends on the *refresh outcome*, not on whether the gate
detected staleness:

  - rc=0 if the cache was fresh OR the refresh subprocess succeeded
  - rc=1 if the cache was stale and the refresh subprocess failed

This test forces the refresh subprocess to fail so the assertion is
deterministic regardless of whether `gh` CLI + network are available in
the test environment. Both observed behaviors are documented in the test
docstring.

Per integration-spec §2.3 the `cache_age_seconds()` helper reads the
`last_refreshed_at` field from the cache JSON content, NOT the file
mtime. The conftest `tmp_pr_cache_file.age(hours)` fixture only adjusts
mtime, which the script ignores — so this test writes its own cache
JSON with a stale `last_refreshed_at` timestamp instead of relying on
the `.age()` helper.
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


# Resolve scripts/ relative to this file so the import works regardless of cwd.
SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

# Filename has a hyphen so we can't `import` it directly — use importlib.
_spec = importlib.util.spec_from_file_location(
    "ensure_pr_cache_fresh",
    SCRIPTS_DIR / "ensure-pr-cache-fresh.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)


# Canonical gate emission key — mirrors stderr prefix in
# `scripts/ensure-pr-cache-fresh.py` lines 152/167/176. Locking the
# string here defends against future rename drift (same pattern as
# CACHE_HITS_GATE_KEY in test_check_state_schema.py).
PR_CACHE_STALE_GATE_KEY = "PR_CACHE_STALE"


def test_main_dispatch_pr_cache_stale(tmp_path, monkeypatch, capsys):
    """T10 — PR_CACHE_STALE dispatch test.

    Recipe (per integration-spec §2.3):
      - Write a valid cache JSON with `last_refreshed_at` 25h ago
        (1h past the 24h default freshness threshold)
      - Monkey-patch `_mod.CACHE_PATH` to the tmp file
      - Monkey-patch `_mod.subprocess.run` to raise CalledProcessError so
        the refresh path deterministically fails (otherwise the result
        would depend on whether `gh` CLI is configured in the test env)
      - Drive `_mod.main()` with the canonical argv

    Observed behavior (documented per task instructions):
      - With refresh forced to FAIL: rc=1, stderr contains
        "PR_CACHE_STALE: cache age 25.0h > threshold 24.0h. Refreshing…"
        and "PR_CACHE_STALE: refresh failed (...)".
      - With refresh allowed to succeed (gh available in env): rc=0,
        stderr still contains the "PR_CACHE_STALE: ... Refreshing…"
        prefix. The stderr prefix is the canonical gate signal; the
        exit code reflects refresh outcome only.

    Asserting on the stderr prefix (not rc) is the contract: the gate
    DETECTED staleness regardless of whether refresh succeeded.
    """
    # ── Build a cache JSON with last_refreshed_at = now - 25h ──────────
    cache_file = tmp_path / "gh-pr-cache.json"
    stale_ts = (datetime.now(timezone.utc) - timedelta(hours=25)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    cache_file.write_text(
        json.dumps(
            {
                "last_refreshed_at": stale_ts,
                "repos": {
                    "Regevba/FitTracker2": {"open": [{"number": 1}]},
                    "Regevba/fitme-story": {"open": [{"number": 2}]},
                },
            },
            indent=2,
        )
    )

    # ── Route the script's CACHE_PATH to our tmp file ──────────────────
    monkeypatch.setattr(_mod, "CACHE_PATH", cache_file)

    # ── Force the refresh subprocess to fail deterministically ─────────
    # This isolates the test from whether `gh` CLI is configured in the
    # local/CI environment. The gate still fires (PR_CACHE_STALE stderr)
    # regardless of refresh outcome.
    def _fake_run(*args, **kwargs):
        raise subprocess.CalledProcessError(
            returncode=1,
            cmd=args[0] if args else "refresh-pr-cache.py",
            stderr="simulated refresh failure (test injection)",
        )

    monkeypatch.setattr(_mod.subprocess, "run", _fake_run)

    # ── Drive main() end-to-end ────────────────────────────────────────
    monkeypatch.setattr(
        sys,
        "argv",
        ["ensure-pr-cache-fresh.py", "--max-age-hours", "24", "--quiet"],
    )
    rc = _mod.main()

    # ── Assert: refresh-failed path returns rc=1 ───────────────────────
    # When refresh fails, the script returns 1 (script lines 165-173).
    # This is the deterministic exit code under our monkey-patch.
    assert rc == 1, (
        f"Expected rc=1 on stale + refresh-failed path; got rc={rc}. "
        "Either the gate's refresh-failure branch regressed, or the "
        "monkey-patch failed to inject the CalledProcessError."
    )

    # ── Assert: gate emitted PR_CACHE_STALE to stderr ──────────────────
    # The stderr prefix is the canonical "the gate fired" signal — it
    # appears in BOTH the refresh-succeeded (rc=0) and refresh-failed
    # (rc=1) paths. See script lines 152, 167, 176.
    captured = capsys.readouterr()
    assert PR_CACHE_STALE_GATE_KEY in captured.err, (
        f"Expected {PR_CACHE_STALE_GATE_KEY!r} in stderr; got: "
        f"{captured.err!r}"
    )
    # Also assert the staleness reason was reported (defends against a
    # future change that silently drops the age delta from the message).
    assert "25.0h > threshold 24.0h" in captured.err, (
        f"Expected stale-age reason in stderr; got: {captured.err!r}"
    )
