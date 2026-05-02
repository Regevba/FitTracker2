#!/usr/bin/env python3
"""
v7.8 Mechanism C entry point: PostToolUse:Read auto-instrumentation.

Reads a Claude Code hook tool-payload JSON from stdin (per the documented
PostToolUse contract: tool_name + tool_input + tool_use_id + session_id +
cwd). For Read tool calls, appends a structured event to the per-session
events ledger at .claude/logs/_session-<session_id>.events.jsonl.

v7.8 advisory mode: this script writes ONLY the session ledger. It does NOT
write to state.json::cache_hits[]; the gate CACHE_HITS_EMPTY_POST_V6 is
exempt from features whose created_at predates MECHANISM_C_SHIP_DATE
(2026-05-02), so the v7.8 ship is non-blocking. The v7.7 silent-pass on
the gate's `created_at` field is also fixed in this PR via a dual-read
fallback to the legacy `created` field.

v7.9 promotion: this script will additionally call scripts/log-cache-hit.py
on Reads matching the v7.9 hit definition (path-already-read-this-session),
and CACHE_HITS_EMPTY_POST_V6 will be promoted from "non-empty" to
"≥N hits where N is calibrated from the v7.8 measurement window."

Fail-soft contract: any error is swallowed to a stderr line and the script
exits 0. Per Claude Code hook semantics, a non-zero PostToolUse exit does
not break the tool call, but exit 0 keeps the agent's debug log clean.

References:
  - docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md §4.3
  - docs/research/2026-05-02-framework-mechanism-c-cache-hits-auto-instrumentation-research.md §1, §6
  - issue #140 (cache_hits writer-path)
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOGS_DIR = REPO_ROOT / ".claude" / "logs"
ACTIVE_FEATURE_LOCKFILE = REPO_ROOT / ".claude" / "active-feature"


def _resolve_active_feature() -> str:
    """Resolve the active feature for attribution.

    Order: $FT2_ACTIVE_FEATURE env var > .claude/active-feature lockfile > "".
    The two-layer model is borrowed from W3C Baggage / Sentry Scope (set context
    once at session entry; read at write time). v7.8 populates only the
    lockfile; the env var is reserved for v7.9's session propagation.
    """
    env = os.environ.get("FT2_ACTIVE_FEATURE", "").strip()
    if env:
        return env
    if ACTIVE_FEATURE_LOCKFILE.exists():
        try:
            return ACTIVE_FEATURE_LOCKFILE.read_text(encoding="utf-8").strip()
        except OSError:
            pass
    return ""


def main() -> int:
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return 0
        payload = json.loads(raw)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"observe-cache-hit: failed to parse payload: {exc}",
              file=sys.stderr)
        return 0  # fail-soft

    if payload.get("tool_name") != "Read":
        return 0

    session_id = payload.get("session_id") or "unknown"
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path", "")
    if not file_path:
        return 0

    try:
        LOGS_DIR.mkdir(parents=True, exist_ok=True)
        ledger_path = LOGS_DIR / f"_session-{session_id}.events.jsonl"
        event = {
            "timestamp": datetime.now(timezone.utc)
                                 .isoformat(timespec="seconds")
                                 .replace("+00:00", "Z"),
            "tool_name": "Read",
            "tool_use_id": payload.get("tool_use_id", ""),
            "file_path": file_path,
            "session_id": session_id,
            "active_feature": _resolve_active_feature(),
        }
        with open(ledger_path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(event, separators=(",", ":")) + "\n")
    except OSError as exc:
        print(f"observe-cache-hit: ledger append failed: {exc}",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
