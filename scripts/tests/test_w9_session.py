"""Tests for scripts/w9_session.py — W9 session-identity + intent helpers.

Fixes the session-id keying bug (feature fix/w9-session-id-keying): Claude Code
delivers the session id on hook STDIN JSON (`session_id`), NOT as a
CLAUDE_SESSION_ID env var. The prior code read only the env var, so it always
fell back to the constant "default", which (a) permanently suppressed the
once-per-session concurrency check across sessions and (b) made the drift
detector share one branch baseline across every session.

Run: python3 -m pytest scripts/tests/test_w9_session.py -q
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1]


def _load():
    spec = importlib.util.spec_from_file_location("w9_session", SCRIPTS / "w9_session.py")
    mod = importlib.util.module_from_spec(spec)
    import sys
    sys.modules["w9_session"] = mod
    spec.loader.exec_module(mod)
    return mod


# ── session_id resolution order ─────────────────────────────────────────────

def test_session_id_prefers_env(monkeypatch):
    monkeypatch.setenv("CLAUDE_SESSION_ID", "env-sess")
    m = _load()
    assert m.session_id(payload={"session_id": "payload-sess"}) == "env-sess"


def test_session_id_reads_payload_when_env_unset(monkeypatch):
    monkeypatch.delenv("CLAUDE_SESSION_ID", raising=False)
    m = _load()
    assert m.session_id(payload={"session_id": "abc123"}) == "abc123"


def test_session_id_reads_stdin_text_json(monkeypatch):
    monkeypatch.delenv("CLAUDE_SESSION_ID", raising=False)
    m = _load()
    assert m.session_id(stdin_text='{"session_id": "from-stdin"}') == "from-stdin"


def test_session_id_falls_back_to_default(monkeypatch):
    monkeypatch.delenv("CLAUDE_SESSION_ID", raising=False)
    m = _load()
    assert m.session_id(payload={}) == "default"
    assert m.session_id(stdin_text="not json at all") == "default"


def test_session_id_payload_missing_field_is_default(monkeypatch):
    monkeypatch.delenv("CLAUDE_SESSION_ID", raising=False)
    m = _load()
    assert m.session_id(payload={"tool_name": "Bash"}) == "default"


# ── branch-switch intent detection (drift false-positive suppression) ───────

@pytest.mark.parametrize("cmd", [
    "git checkout main",
    "git checkout -b feature/x",
    "git switch main",
    "git switch -c foo",
    "git worktree add ../wt feature/x",
    "cd /repo && git checkout main",
])
def test_command_indicates_branch_switch_true(cmd):
    m = _load()
    assert m.command_indicates_branch_switch(cmd) is True


@pytest.mark.parametrize("cmd", [
    "git status",
    "git commit -m x",
    "git log --oneline",
    "echo git checkout",            # not a real git invocation token-wise
    "",
    None,
])
def test_command_indicates_branch_switch_false(cmd):
    m = _load()
    assert m.command_indicates_branch_switch(cmd) is False


# ── payload parsing ─────────────────────────────────────────────────────────

def test_hook_payload_parses_json():
    m = _load()
    assert m.hook_payload('{"a": 1}') == {"a": 1}


def test_hook_payload_bad_json_is_empty_dict():
    m = _load()
    assert m.hook_payload("nope") == {}
    assert m.hook_payload("") == {}


def test_command_from_payload_extracts_command():
    m = _load()
    p = {"tool_input": {"command": "git checkout main"}}
    assert m.command_from_payload(p) == "git checkout main"


def test_command_from_payload_missing_is_none():
    m = _load()
    assert m.command_from_payload({"tool_input": {}}) is None
    assert m.command_from_payload({}) is None
    assert m.command_from_payload("not a dict") is None
