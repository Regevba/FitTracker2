#!/usr/bin/env python3
"""Local analytics mirror — Server-Sent Events sink for FitMe iOS + fitme-story web.

Phase 2.A.1 of `analytics-observability` per
docs/master-plan/analytics-master-plan-2026-05-13.md §6.

PURPOSE
-------
While the iOS app (or fitme-story dev server) runs locally with the
`DEBUG_ANALYTICS=1` env flag set, every analytics event the app fires
is teed to this server in addition to the production path (FirebaseAnalytics
or window.gtag). The `/analytics watch` CLI connects to the SSE stream and
prints events in real time, eliminating the round-trip through GA4 Realtime
for dev iteration.

ARCHITECTURE
------------
HTTP server on localhost:8765 (configurable via --port). Three endpoints:

    POST /event       — Receive a single analytics event (JSON body)
    GET  /stream      — Server-Sent Events stream of all events
    GET  /health      — Health JSON: {status, events_received, subscribers}

Each event is a JSON dict; we add a server-side `received_at` timestamp.

USAGE
-----
    python3 scripts/analytics-watch-server.py [--port 8765] [--bind 127.0.0.1]

The server is INTENDED FOR LOCAL DEVELOPMENT ONLY. It does not authenticate
clients, does not enforce HTTPS, and binds to loopback by default. Never
expose to the public internet.

WHY NOT WEBSOCKETS
------------------
The `websockets` package is not in stdlib. SSE gives real-time push using
only stdlib `http.server`. iOS has native SSE support via URLSession with
`text/event-stream`; browsers have `EventSource`. Plain HTTP POST for the
event ingress keeps client code trivially small.

NOT PRODUCTION CODE
-------------------
This server runs in the operator's local dev environment only. Events still
go to GA4 in production via FirebaseAnalyticsAdapter / window.gtag — the
mirror is a passive tee, not a replacement.
"""
from __future__ import annotations

import argparse
import http.server
import json
import queue
import signal
import sys
import threading
import time
from datetime import datetime, timezone
from typing import Any


# Global state. Single-process server; concurrency via threading.
_event_lock = threading.Lock()
_total_events_received = 0
_subscribers: list[queue.Queue[dict[str, Any]]] = []
_subscribers_lock = threading.Lock()
_shutdown_event = threading.Event()


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _broadcast(event: dict[str, Any]) -> None:
    """Push a received event to every active SSE subscriber queue."""
    with _subscribers_lock:
        # Iterate over a copy so disconnects mid-loop don't break iteration
        for q in list(_subscribers):
            try:
                q.put_nowait(event)
            except queue.Full:
                # Slow subscriber — drop the event for this subscriber rather
                # than block all others.
                pass


class _Handler(http.server.BaseHTTPRequestHandler):
    # Reduce default access-log noise; we'll print our own concise lines.
    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        return

    # ------------------------------------------------------------------
    def do_GET(self) -> None:  # noqa: N802  (BaseHTTPRequestHandler API)
        if self.path == "/health":
            return self._handle_health()
        if self.path == "/stream":
            return self._handle_stream()
        self.send_error(404, "Not Found")

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/event":
            return self._handle_event_post()
        self.send_error(404, "Not Found")

    # ------------------------------------------------------------------
    def _handle_health(self) -> None:
        with _subscribers_lock:
            sub_count = len(_subscribers)
        payload = json.dumps({
            "status": "ok",
            "events_received": _total_events_received,
            "subscribers": sub_count,
            "server_time_utc": _iso_now(),
        }).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    # ------------------------------------------------------------------
    def _handle_event_post(self) -> None:
        global _total_events_received
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > 64 * 1024:
            self.send_error(400, "Content-Length missing or > 64 KiB")
            return
        try:
            body = self.rfile.read(length).decode("utf-8")
            event = json.loads(body)
            if not isinstance(event, dict):
                raise ValueError("Event payload must be a JSON object")
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            self.send_error(400, f"Invalid JSON body: {exc}")
            return

        event.setdefault("received_at", _iso_now())
        with _event_lock:
            _total_events_received += 1
            event["sequence"] = _total_events_received
        _broadcast(event)

        body_out = json.dumps({"ok": True, "sequence": event["sequence"]}).encode("utf-8")
        self.send_response(202)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body_out)))
        self.end_headers()
        self.wfile.write(body_out)

    # ------------------------------------------------------------------
    def _handle_stream(self) -> None:
        """Server-Sent Events stream. Holds the connection open until either
        the client disconnects or the server is shut down."""
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        # Allow `EventSource` from any localhost origin
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        q: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=1024)
        with _subscribers_lock:
            _subscribers.append(q)

        # Initial comment-line so EventSource immediately sees data and opens
        # the stream. SSE clients ignore lines starting with ":".
        try:
            self.wfile.write(b": connected\n\n")
            self.wfile.flush()

            while not _shutdown_event.is_set():
                try:
                    event = q.get(timeout=15.0)
                except queue.Empty:
                    # Periodic heartbeat so middleboxes don't close idle conns
                    try:
                        self.wfile.write(b": heartbeat\n\n")
                        self.wfile.flush()
                    except (BrokenPipeError, ConnectionResetError):
                        return
                    continue

                data = json.dumps(event, default=str)
                try:
                    self.wfile.write(f"data: {data}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError):
                    return
        finally:
            with _subscribers_lock:
                if q in _subscribers:
                    _subscribers.remove(q)


class _ThreadingServer(http.server.ThreadingHTTPServer):
    daemon_threads = True


def _make_server(bind: str, port: int) -> _ThreadingServer:
    return _ThreadingServer((bind, port), _Handler)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Local analytics mirror SSE sink — Phase 2.A.1 (analytics-observability)"
    )
    parser.add_argument("--port", type=int, default=8765, help="TCP port (default: 8765)")
    parser.add_argument("--bind", default="127.0.0.1", help="Bind address (default: 127.0.0.1)")
    parser.add_argument("--quiet", action="store_true", help="Suppress startup banner")
    args = parser.parse_args(argv)

    try:
        server = _make_server(args.bind, args.port)
    except OSError as exc:
        sys.stderr.write(f"error: cannot bind to {args.bind}:{args.port} — {exc}\n")
        return 1

    if not args.quiet:
        sys.stderr.write(
            f"analytics-watch-server listening on http://{args.bind}:{args.port}\n"
            f"  POST /event   — submit a JSON event\n"
            f"  GET  /stream  — SSE stream of events\n"
            f"  GET  /health  — health JSON\n"
            f"press Ctrl-C to stop\n"
        )

    def _on_signal(_signum: int, _frame: Any) -> None:
        _shutdown_event.set()
        # Schedule shutdown on a separate thread; shutdown() must not be called
        # from a handler running inside the server's own thread.
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)

    try:
        server.serve_forever()
    finally:
        server.server_close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
