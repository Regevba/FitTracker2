#!/usr/bin/env python3
"""`/analytics watch` CLI — tail the local analytics mirror SSE stream.

Phase 2.A.2 of `analytics-observability` per
docs/master-plan/analytics-master-plan-2026-05-13.md §6.1.

Connects to the SSE endpoint of `scripts/analytics-watch-server.py`
(default http://127.0.0.1:8765/stream) and prints every event as it
arrives. Designed for use while the iOS Simulator or fitme-story dev
server runs locally with `DEBUG_ANALYTICS=1` env flag set.

USAGE
-----
    python3 scripts/analytics-watch.py
    python3 scripts/analytics-watch.py --filter home_action_tap
    python3 scripts/analytics-watch.py --server http://localhost:9999
    python3 scripts/analytics-watch.py --raw

OPTIONS
-------
    --server URL        SSE server URL (default: http://127.0.0.1:8765)
    --filter PATTERN    Only print events whose `event_name` or `name`
                        contains PATTERN (substring match, case-sensitive).
                        Pass multiple --filter flags to OR them together.
    --raw               Print raw JSON dicts (no pretty-printing or colors).
    --no-color          Disable ANSI color output (auto-detected from TTY).
    --since N           Skip the first N seconds of events (useful for
                        ignoring connection-time replays — not implemented
                        in the bounded-queue v1 server; reserved for future).

Ctrl-C exits cleanly.
"""
from __future__ import annotations

import argparse
import http.client
import json
import signal
import sys
import urllib.parse
from typing import Any


def _is_tty() -> bool:
    return sys.stdout.isatty()


def _color(name: str, use_color: bool) -> tuple[str, str]:
    """Return (start, end) ANSI codes for `name` or empty strings if disabled."""
    if not use_color:
        return "", ""
    codes = {
        "dim": "\033[2m",
        "bold": "\033[1m",
        "cyan": "\033[36m",
        "green": "\033[32m",
        "yellow": "\033[33m",
        "magenta": "\033[35m",
        "red": "\033[31m",
    }
    return codes.get(name, ""), "\033[0m" if name in codes else ""


def _format_event(event: dict[str, Any], use_color: bool) -> str:
    """Format an event dict as a single human-readable line."""
    dim_s, dim_e = _color("dim", use_color)
    cyan_s, cyan_e = _color("cyan", use_color)
    green_s, green_e = _color("green", use_color)
    yellow_s, yellow_e = _color("yellow", use_color)

    seq = event.get("sequence", "?")
    received_at = event.get("received_at", "")[:19]  # YYYY-MM-DDTHH:MM:SS
    name = event.get("event_name") or event.get("name") or "<unnamed>"
    params = event.get("params") or event.get("parameters") or {}

    head = (
        f"{dim_s}[{received_at} #{seq}]{dim_e} "
        f"{cyan_s}{name}{cyan_e}"
    )
    if params:
        kv = " ".join(
            f"{green_s}{k}{green_e}={yellow_s}{json.dumps(v, default=str)}{yellow_e}"
            for k, v in params.items()
        )
        return f"{head} {kv}"
    return head


def _match_filters(event: dict[str, Any], patterns: list[str]) -> bool:
    """True iff no patterns OR event name contains any pattern."""
    if not patterns:
        return True
    name = (event.get("event_name") or event.get("name") or "").lower()
    return any(p.lower() in name for p in patterns)


def _stream(host: str, port: int, path: str, filters: list[str], raw: bool, use_color: bool) -> int:
    """Open SSE connection, read events forever, print matching ones.

    Returns exit code (0 normal, 1 on connection error).
    """
    try:
        conn = http.client.HTTPConnection(host, port, timeout=None)
        conn.request("GET", path)
        resp = conn.getresponse()
    except (ConnectionRefusedError, OSError) as exc:
        sys.stderr.write(
            f"error: cannot connect to http://{host}:{port}{path} — {exc}\n"
            f"hint: start the server first:\n"
            f"  python3 scripts/analytics-watch-server.py\n"
        )
        return 1

    if resp.status != 200:
        sys.stderr.write(f"error: server returned HTTP {resp.status}\n")
        return 1

    ctype = resp.getheader("Content-Type", "")
    if "text/event-stream" not in ctype:
        sys.stderr.write(f"error: expected text/event-stream, got '{ctype}'\n")
        return 1

    # Banner
    sys.stderr.write(
        f"watching events at http://{host}:{port}{path} (filters: {filters or 'none'})\n"
        f"press Ctrl-C to stop\n"
    )

    try:
        while True:
            line = resp.fp.readline()
            if not line:
                sys.stderr.write("\nserver closed the connection\n")
                return 0
            line = line.decode("utf-8", errors="replace").rstrip("\n")
            if not line.startswith("data: "):
                continue
            try:
                event = json.loads(line[6:])
            except json.JSONDecodeError as exc:
                sys.stderr.write(f"warn: bad event payload: {exc}\n")
                continue
            if not isinstance(event, dict):
                continue
            if not _match_filters(event, filters):
                continue
            if raw:
                print(json.dumps(event, default=str))
            else:
                print(_format_event(event, use_color))
            sys.stdout.flush()
    except KeyboardInterrupt:
        sys.stderr.write("\nstopped.\n")
        return 0
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="`/analytics watch` — tail the local analytics mirror SSE stream"
    )
    parser.add_argument(
        "--server",
        default="http://127.0.0.1:8765",
        help="SSE server URL (default: http://127.0.0.1:8765)",
    )
    parser.add_argument(
        "--filter",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Only print events whose name contains PATTERN. Repeatable (OR semantics).",
    )
    parser.add_argument("--raw", action="store_true", help="Print raw JSON")
    parser.add_argument("--no-color", action="store_true", help="Disable ANSI colors")
    args = parser.parse_args(argv)

    u = urllib.parse.urlparse(args.server)
    if u.scheme not in ("http", ""):
        sys.stderr.write(f"error: only http:// is supported, got '{args.server}'\n")
        return 1
    host = u.hostname or "127.0.0.1"
    port = u.port or 8765
    path = "/stream"

    use_color = (not args.no_color) and _is_tty()

    # Don't crash on broken pipe (e.g., piping to `head`)
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    return _stream(host, port, path, args.filter, args.raw, use_color)


if __name__ == "__main__":
    sys.exit(main())
