"""Unit tests for v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fixes (b) + (c).

Covers:
  - ensure-pr-cache-fresh.py: _is_cron_context + _write_failure_flag
  - integrity-check.py:       pr_cache_refresh_failed_recently (fresh/stale/missing)
  - daily-integrity-checkpoint.py: precheck_cron_context exit-78 path

These tests use importlib.util because the source files have hyphens in
their names and cannot be imported with `import ensure-pr-cache-fresh`.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import time
from pathlib import Path
from unittest.mock import patch

import pytest


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))


def _load(filename: str, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, SCRIPTS_DIR / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def ensure_fresh_module():
    return _load("ensure-pr-cache-fresh.py", "ensure_pr_cache_fresh")


@pytest.fixture
def integrity_check_module():
    return _load("integrity-check.py", "integrity_check")


@pytest.fixture
def daily_checkpoint_module():
    return _load("daily-integrity-checkpoint.py", "daily_integrity_checkpoint")


@pytest.fixture
def clean_cron_env(monkeypatch):
    """Strip every cron-context env var so tests start from a known interactive baseline."""
    for var in ("LAUNCHD_LABEL", "CRON_CONTEXT", "XPC_SERVICE_NAME"):
        monkeypatch.delenv(var, raising=False)


# ---------------------------------------------------------------------------
# Sub-fix (b): _is_cron_context detection
# ---------------------------------------------------------------------------

def test_is_cron_context_interactive_default(ensure_fresh_module, clean_cron_env):
    """No env vars set → not cron context (interactive)."""
    assert ensure_fresh_module._is_cron_context() is False


def test_is_cron_context_launchd_label_set(ensure_fresh_module, clean_cron_env, monkeypatch):
    """LAUNCHD_LABEL set by launchd → cron context."""
    monkeypatch.setenv("LAUNCHD_LABEL", "com.fittracker.daily")
    assert ensure_fresh_module._is_cron_context() is True


def test_is_cron_context_manual_override(ensure_fresh_module, clean_cron_env, monkeypatch):
    """CRON_CONTEXT=1 manual override → cron context."""
    monkeypatch.setenv("CRON_CONTEXT", "1")
    assert ensure_fresh_module._is_cron_context() is True


def test_is_cron_context_xpc_pattern_match(ensure_fresh_module, clean_cron_env, monkeypatch):
    """XPC_SERVICE_NAME containing 'fittracker' + 'daily' → cron context."""
    monkeypatch.setenv("XPC_SERVICE_NAME", "com.fittracker.daily-checkpoint")
    assert ensure_fresh_module._is_cron_context() is True


def test_is_cron_context_unrelated_xpc_ignored(ensure_fresh_module, clean_cron_env, monkeypatch):
    """Unrelated XPC service (e.g., Spotlight) is NOT misidentified as cron."""
    monkeypatch.setenv("XPC_SERVICE_NAME", "com.apple.spotlight")
    assert ensure_fresh_module._is_cron_context() is False


# ---------------------------------------------------------------------------
# Sub-fix (b): _write_failure_flag writes well-formed JSON
# ---------------------------------------------------------------------------

def test_write_failure_flag_writes_json_payload(ensure_fresh_module, tmp_path, monkeypatch):
    """Flag file is JSON with required keys (ts, reason, context)."""
    flag = tmp_path / "pr-cache-refresh-failed.flag"
    monkeypatch.setattr(ensure_fresh_module, "REFRESH_FAILED_FLAG", flag)
    monkeypatch.setenv("LAUNCHD_LABEL", "com.fittracker.daily")

    ensure_fresh_module._write_failure_flag("subprocess exited 1: gh missing")

    assert flag.exists()
    payload = json.loads(flag.read_text())
    assert "ts" in payload
    assert payload["reason"].startswith("subprocess exited 1")
    assert payload["context"] == "launchd"


def test_write_failure_flag_caps_reason_length(ensure_fresh_module, tmp_path, monkeypatch):
    """Long failure reasons are truncated so the flag file stays small."""
    flag = tmp_path / "pr-cache-refresh-failed.flag"
    monkeypatch.setattr(ensure_fresh_module, "REFRESH_FAILED_FLAG", flag)
    huge_reason = "x" * 2000

    ensure_fresh_module._write_failure_flag(huge_reason)

    payload = json.loads(flag.read_text())
    assert len(payload["reason"]) <= 500


def test_write_failure_flag_oserror_is_swallowed(ensure_fresh_module, tmp_path, monkeypatch):
    """If we can't write the flag, we DO NOT crash the caller."""
    bad_path = tmp_path / "no-such-dir" / "nested" / "flag"
    monkeypatch.setattr(ensure_fresh_module, "REFRESH_FAILED_FLAG", bad_path)
    # Patch out mkdir so the directory cannot be created, simulating perms err.
    with patch.object(Path, "mkdir", side_effect=OSError("perms")):
        ensure_fresh_module._write_failure_flag("anything")  # must not raise


# ---------------------------------------------------------------------------
# Sub-fix (b): integrity-check reads the flag (fresh / stale / missing)
# ---------------------------------------------------------------------------

def test_flag_missing_returns_false(integrity_check_module, tmp_path, monkeypatch):
    """No flag file → skip_pr_gates = False."""
    monkeypatch.setattr(
        integrity_check_module, "REFRESH_FAILED_FLAG", tmp_path / "nope.flag"
    )
    skip, payload = integrity_check_module.pr_cache_refresh_failed_recently()
    assert skip is False
    assert payload is None


def test_flag_fresh_returns_true(integrity_check_module, tmp_path, monkeypatch):
    """Fresh flag (now-ish ts) → skip_pr_gates = True."""
    flag = tmp_path / "pr-cache-refresh-failed.flag"
    flag.write_text(json.dumps({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "reason": "test",
        "context": "launchd",
    }))
    monkeypatch.setattr(integrity_check_module, "REFRESH_FAILED_FLAG", flag)

    skip, payload = integrity_check_module.pr_cache_refresh_failed_recently()
    assert skip is True
    assert payload["context"] == "launchd"


def test_flag_stale_returns_false(integrity_check_module, tmp_path, monkeypatch):
    """Flag with ts >1h old → skip = False (kill criterion #3 enforcement)."""
    flag = tmp_path / "pr-cache-refresh-failed.flag"
    flag.write_text(json.dumps({
        "ts": "2020-01-01T00:00:00Z",
        "reason": "ancient",
        "context": "launchd",
    }))
    monkeypatch.setattr(integrity_check_module, "REFRESH_FAILED_FLAG", flag)

    skip, payload = integrity_check_module.pr_cache_refresh_failed_recently()
    assert skip is False
    # Payload still returned for diagnostics, but skip is False.


def test_flag_malformed_json_ignored(integrity_check_module, tmp_path, monkeypatch):
    """Malformed JSON → skip = False, no crash."""
    flag = tmp_path / "pr-cache-refresh-failed.flag"
    flag.write_text("{not valid json")
    monkeypatch.setattr(integrity_check_module, "REFRESH_FAILED_FLAG", flag)

    skip, payload = integrity_check_module.pr_cache_refresh_failed_recently()
    assert skip is False
    assert payload is None


# ---------------------------------------------------------------------------
# Sub-fix (c): precheck_cron_context exit-78 paths
# ---------------------------------------------------------------------------

def test_precheck_interactive_returns_none(daily_checkpoint_module, clean_cron_env):
    """Interactive session → no pre-check (returns None)."""
    assert daily_checkpoint_module.precheck_cron_context() is None


def test_precheck_cron_no_gh_returns_78(daily_checkpoint_module, clean_cron_env, monkeypatch):
    """Cron context + gh missing → exit 78."""
    monkeypatch.setenv("LAUNCHD_LABEL", "com.fittracker.daily")
    with patch("shutil.which", return_value=None):
        assert daily_checkpoint_module.precheck_cron_context() == 78


def test_precheck_cron_auth_fail_returns_78(daily_checkpoint_module, clean_cron_env, monkeypatch):
    """Cron context + gh present + auth-fail → exit 78."""
    monkeypatch.setenv("LAUNCHD_LABEL", "com.fittracker.daily")
    with patch("shutil.which", return_value="/opt/homebrew/bin/gh"):
        monkeypatch.setattr(
            daily_checkpoint_module, "run", lambda *a, **kw: (1, "Not logged in"),
        )
        assert daily_checkpoint_module.precheck_cron_context() == 78


def test_precheck_cron_auth_ok_returns_none(daily_checkpoint_module, clean_cron_env, monkeypatch):
    """Cron context + gh present + auth OK → None (proceed)."""
    monkeypatch.setenv("LAUNCHD_LABEL", "com.fittracker.daily")
    with patch("shutil.which", return_value="/opt/homebrew/bin/gh"):
        monkeypatch.setattr(
            daily_checkpoint_module, "run", lambda *a, **kw: (0, "Logged in as Regevba"),
        )
        assert daily_checkpoint_module.precheck_cron_context() is None
