#!/usr/bin/env python3
"""W9 session-identity + intent helpers (feature fix/w9-session-id-keying).

WHY THIS EXISTS
---------------
Claude Code delivers the session id to hooks on **STDIN JSON** (the `session_id`
field of the hook payload), NOT as a `CLAUDE_SESSION_ID` environment variable.

The original W9 hooks (`check-branch-drift.py`, `w9_concurrency_check.py`) read
only `os.environ["CLAUDE_SESSION_ID"]` and fell back to the constant `"default"`.
Because the env var is never set in practice, every session shared the SAME
`"default"` key. Two failures followed:

  1. Phase 2 — the once-per-session marker `default-w9-concurrency.done` was
     written once and then suppressed the concurrency check FOREVER across all
     later sessions. The Phase-2 calibration gathered ZERO valid telemetry.
  2. Phase 1 — the drift detector shared one `default-branch.txt` baseline, so
     it could not distinguish "I deliberately ran `git checkout`" from "another
     session flipped my HEAD" → the 45 logged "drift" rows were near-100%
     false positives from intentional branch switches.

This module centralizes (a) resolving the real session id from the hook payload
and (b) recognizing when a branch change was caused by THIS session's own
command (so the drift detector can suppress the false positive).
"""
from __future__ import annotations

import json
import os
import re
import sys

# A branch change is "intentional" when the command that just ran is itself a
# branch-switching git invocation. Matched per shell segment so `echo git
# checkout` (git not at a command boundary) does NOT count.
_SWITCH_RE = re.compile(r"^git\s+(?:checkout|switch|worktree\s+add)\b")
_SEGMENT_SPLIT = re.compile(r"&&|\|\||[;|\n]")


def session_id(payload: dict | None = None, *, stdin_text: str | None = None) -> str:
    """Resolve the current session id.

    Resolution order:
      1. CLAUDE_SESSION_ID env var (explicit override; used by tests + manual runs)
      2. the hook payload's `session_id` field (the real Claude Code source)
      3. "default" (last-resort; only when no id is discoverable)
    """
    env = os.environ.get("CLAUDE_SESSION_ID")
    if env:
        return env

    data = payload
    if data is None:
        if stdin_text is None:
            stdin_text = read_stdin_nonblocking()
        data = hook_payload(stdin_text) if stdin_text else {}

    if isinstance(data, dict):
        sid = data.get("session_id")
        if sid:
            return str(sid)
    return "default"


def command_indicates_branch_switch(command: str | None) -> bool:
    """True if `command` is (or chains to) a branch-switching git invocation.

    Used to suppress drift false positives: if the command that just ran was a
    `git checkout` / `git switch` / `git worktree add`, then a branch change is
    EXPECTED, not a concurrent-session collision.
    """
    if not command:
        return False
    for seg in _SEGMENT_SPLIT.split(command):
        if _SWITCH_RE.match(seg.strip()):
            return True
    return False


def hook_payload(stdin_text: str | None = None) -> dict:
    """Parse the hook payload dict from stdin JSON. {} on any failure."""
    if stdin_text is None:
        stdin_text = read_stdin_nonblocking()
    if not stdin_text:
        return {}
    try:
        data = json.loads(stdin_text)
    except (ValueError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def command_from_payload(payload: dict | None) -> str | None:
    """Extract `tool_input.command` from a hook payload, or None."""
    if not isinstance(payload, dict):
        return None
    ti = payload.get("tool_input")
    if isinstance(ti, dict):
        return ti.get("command")
    return None


def read_stdin_nonblocking() -> str | None:
    """Read stdin only if data is already available; never block.

    Hooks receive their JSON payload on stdin, but the same scripts are also run
    in tests / manually with no stdin. A blocking read would hang those. We use
    a zero-timeout select so an absent stdin degrades to None instead of hanging.
    """
    try:
        if sys.stdin is None or sys.stdin.closed:
            return None
        import select
        ready, _, _ = select.select([sys.stdin], [], [], 0)
        if not ready:
            return None
        return sys.stdin.read()
    except Exception:
        return None
