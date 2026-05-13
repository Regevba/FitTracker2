"""Tests for `scripts/analytics-watch-server.py` — Phase 2.A.1 of
analytics-observability per docs/master-plan/analytics-master-plan-2026-05-13.md.

End-to-end shape: spin the server on a free port, POST an event, verify
(a) the POST returns 202 + sequence number, (b) the SSE /stream sees the
event, (c) /health reflects the counter.

The tests use only stdlib (`http.client`, `threading`, `socket`, `pytest`).
"""
from __future__ import annotations

import http.client
import importlib.util
import json
import socket
import sys
import threading
import time
from pathlib import Path

import pytest


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "analytics-watch-server.py"


def _import_server_module():
    """Load `analytics-watch-server.py` as a module (hyphen-safe via importlib)."""
    spec = importlib.util.spec_from_file_location("analytics_watch_server", SCRIPT_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _free_port() -> int:
    """Return an OS-assigned free TCP port (close socket before caller binds)."""
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


@pytest.fixture
def server():
    """Start the server on a free port; tear down on test exit."""
    mod = _import_server_module()
    # Reset module-level counters for test isolation
    mod._total_events_received = 0
    with mod._subscribers_lock:
        mod._subscribers.clear()
    mod._shutdown_event.clear()

    port = _free_port()
    srv = mod._make_server("127.0.0.1", port)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()

    # Wait briefly for /health to respond — confirms ready
    for _ in range(50):
        try:
            c = http.client.HTTPConnection("127.0.0.1", port, timeout=0.5)
            c.request("GET", "/health")
            r = c.getresponse()
            r.read()
            c.close()
            if r.status == 200:
                break
        except Exception:
            pass
        time.sleep(0.02)
    else:
        srv.shutdown()
        srv.server_close()
        pytest.fail("Server did not become healthy in 1s")

    yield ("127.0.0.1", port, mod, srv)
    srv.shutdown()
    srv.server_close()
    t.join(timeout=1.0)


def _post_event(host: str, port: int, event: dict) -> dict:
    body = json.dumps(event).encode("utf-8")
    c = http.client.HTTPConnection(host, port, timeout=2.0)
    c.request(
        "POST",
        "/event",
        body=body,
        headers={"Content-Type": "application/json", "Content-Length": str(len(body))},
    )
    r = c.getresponse()
    out = json.loads(r.read().decode("utf-8"))
    c.close()
    assert r.status == 202, f"Expected 202, got {r.status}: {out}"
    return out


def _get_health(host: str, port: int) -> dict:
    c = http.client.HTTPConnection(host, port, timeout=1.0)
    c.request("GET", "/health")
    r = c.getresponse()
    body = json.loads(r.read().decode("utf-8"))
    c.close()
    assert r.status == 200
    return body


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_health_endpoint_initially_empty(server):
    host, port, _mod, _srv = server
    h = _get_health(host, port)
    assert h["status"] == "ok"
    assert h["events_received"] == 0
    assert h["subscribers"] == 0


def test_post_event_increments_sequence(server):
    host, port, _mod, _srv = server
    r1 = _post_event(host, port, {"event_name": "test_event", "params": {"x": 1}})
    r2 = _post_event(host, port, {"event_name": "test_event_2"})
    assert r1["sequence"] == 1
    assert r2["sequence"] == 2
    h = _get_health(host, port)
    assert h["events_received"] == 2


def test_post_event_rejects_non_object(server):
    host, port, _mod, _srv = server
    c = http.client.HTTPConnection(host, port, timeout=1.0)
    body = b"[1, 2, 3]"
    c.request("POST", "/event", body=body, headers={"Content-Length": str(len(body))})
    r = c.getresponse()
    r.read()
    c.close()
    assert r.status == 400


def test_post_event_rejects_invalid_json(server):
    host, port, _mod, _srv = server
    c = http.client.HTTPConnection(host, port, timeout=1.0)
    body = b"this is not json"
    c.request("POST", "/event", body=body, headers={"Content-Length": str(len(body))})
    r = c.getresponse()
    r.read()
    c.close()
    assert r.status == 400


def test_sse_stream_receives_posted_event(server):
    """The end-to-end happy path: open a stream, POST an event, see it on stream."""
    host, port, _mod, _srv = server

    received: list[dict] = []
    stop = threading.Event()

    def _reader():
        c = http.client.HTTPConnection(host, port, timeout=5.0)
        c.request("GET", "/stream")
        r = c.getresponse()
        assert r.status == 200
        assert r.getheader("Content-Type", "").startswith("text/event-stream")
        # Read the SSE feed line-by-line until we get an event or stop
        while not stop.is_set():
            line = r.fp.readline().decode("utf-8")
            if not line:
                break
            if line.startswith("data: "):
                received.append(json.loads(line[6:].strip()))
                if len(received) >= 1:
                    break
        c.close()

    t = threading.Thread(target=_reader, daemon=True)
    t.start()
    # Give the reader time to register as subscriber
    time.sleep(0.15)
    # Verify the subscriber registered
    h = _get_health(host, port)
    assert h["subscribers"] >= 1

    _post_event(host, port, {"event_name": "stream_test", "params": {"value": 42}})

    t.join(timeout=2.0)
    stop.set()

    assert len(received) == 1
    ev = received[0]
    assert ev["event_name"] == "stream_test"
    assert ev["params"] == {"value": 42}
    assert ev["sequence"] == 1
    assert "received_at" in ev


def test_health_reports_active_subscriber_count(server):
    host, port, _mod, _srv = server
    stop = threading.Event()
    started = threading.Event()

    def _hold_stream():
        c = http.client.HTTPConnection(host, port, timeout=5.0)
        c.request("GET", "/stream")
        r = c.getresponse()
        started.set()
        # Hold connection until stop set
        while not stop.is_set():
            line = r.fp.readline()
            if not line:
                break
        c.close()

    t = threading.Thread(target=_hold_stream, daemon=True)
    t.start()
    started.wait(timeout=2.0)
    time.sleep(0.15)  # let subscriber register
    h = _get_health(host, port)
    assert h["subscribers"] >= 1, f"Expected at least 1 subscriber, got {h}"
    stop.set()


def test_unknown_endpoint_returns_404(server):
    host, port, _mod, _srv = server
    c = http.client.HTTPConnection(host, port, timeout=1.0)
    c.request("GET", "/nonexistent")
    r = c.getresponse()
    r.read()
    c.close()
    assert r.status == 404
