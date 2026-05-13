"""Tests for `scripts/analytics-watch.py` — Phase 2.A.2 of analytics-observability.

The watcher CLI connects to the live SSE server and prints events. These tests
spin the real server up, run the watcher as a subprocess, and assert on stdout.
"""
from __future__ import annotations

import http.client
import importlib.util
import json
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

import pytest


SCRIPTS = Path(__file__).resolve().parents[1]
SERVER_PATH = SCRIPTS / "analytics-watch-server.py"
WATCH_PATH = SCRIPTS / "analytics-watch.py"


def _import_server():
    spec = importlib.util.spec_from_file_location("analytics_watch_server", SERVER_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _import_watch():
    spec = importlib.util.spec_from_file_location("analytics_watch", WATCH_PATH)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


@pytest.fixture
def server():
    mod = _import_server()
    mod._total_events_received = 0
    with mod._subscribers_lock:
        mod._subscribers.clear()
    mod._shutdown_event.clear()

    port = _free_port()
    srv = mod._make_server("127.0.0.1", port)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()

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
        pytest.fail("Server did not become healthy")

    yield ("127.0.0.1", port)
    srv.shutdown()
    srv.server_close()
    t.join(timeout=1.0)


def _post(host: str, port: int, payload: dict) -> dict:
    body = json.dumps(payload).encode()
    c = http.client.HTTPConnection(host, port, timeout=2.0)
    c.request("POST", "/event", body=body, headers={"Content-Length": str(len(body))})
    r = c.getresponse()
    out = json.loads(r.read())
    c.close()
    return out


# ---------------------------------------------------------------------------
# Pure-function tests (no subprocess)
# ---------------------------------------------------------------------------


def test_match_filters_empty_passes_all():
    mod = _import_watch()
    assert mod._match_filters({"event_name": "home_action_tap"}, []) is True


def test_match_filters_substring_match():
    mod = _import_watch()
    e = {"event_name": "home_action_tap"}
    assert mod._match_filters(e, ["home_"]) is True
    assert mod._match_filters(e, ["action"]) is True
    assert mod._match_filters(e, ["nutrition"]) is False


def test_match_filters_or_semantics():
    mod = _import_watch()
    e = {"event_name": "home_action_tap"}
    assert mod._match_filters(e, ["nutrition", "home_"]) is True


def test_match_filters_case_insensitive():
    mod = _import_watch()
    e = {"event_name": "Home_Action_Tap"}
    assert mod._match_filters(e, ["HOME_"]) is True


def test_format_event_includes_name_and_params():
    mod = _import_watch()
    e = {
        "sequence": 7,
        "received_at": "2026-05-13T18:30:00",
        "event_name": "home_action_tap",
        "params": {"action_type": "start_workout"},
    }
    out = mod._format_event(e, use_color=False)
    assert "home_action_tap" in out
    assert "action_type" in out
    assert "start_workout" in out
    assert "#7" in out


def test_format_event_no_params():
    mod = _import_watch()
    e = {"sequence": 1, "received_at": "2026-05-13T18:30:00", "event_name": "foo"}
    out = mod._format_event(e, use_color=False)
    assert "foo" in out


def test_format_event_strips_color_when_disabled():
    mod = _import_watch()
    e = {"sequence": 1, "received_at": "2026-05-13T18:30:00", "event_name": "x"}
    out = mod._format_event(e, use_color=False)
    assert "\033[" not in out


# ---------------------------------------------------------------------------
# Integration tests: real server + watcher subprocess
# ---------------------------------------------------------------------------


def _run_watch_until_event_seen(host: str, port: int, args: list[str], event_payload: dict) -> tuple[int, str, str]:
    """Start the watcher in a subprocess, POST one event, return its output.

    Reads stdout reactively in a thread so Python stdout buffering doesn't
    swallow events when the subprocess is terminated.
    """
    # `-u` forces unbuffered stdout — critical when stdout is a pipe rather
    # than a TTY (Python block-buffers PIPE by default).
    proc = subprocess.Popen(
        [sys.executable, "-u", str(WATCH_PATH), "--server", f"http://{host}:{port}", "--no-color"] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    out_lines: list[str] = []
    err_lines: list[str] = []
    stop = threading.Event()

    def _drain(pipe, sink):
        try:
            for line in pipe:
                sink.append(line)
                if stop.is_set():
                    break
        except Exception:
            pass

    t_out = threading.Thread(target=_drain, args=(proc.stdout, out_lines), daemon=True)
    t_err = threading.Thread(target=_drain, args=(proc.stderr, err_lines), daemon=True)
    t_out.start()
    t_err.start()

    # Wait for the watcher to subscribe (banner line in err) AND for the
    # server to register the subscriber (visible via /health)
    for _ in range(60):
        if any("watching events" in l for l in err_lines):
            try:
                c = http.client.HTTPConnection(host, port, timeout=1.0)
                c.request("GET", "/health")
                r = c.getresponse()
                health = json.loads(r.read())
                c.close()
                if health.get("subscribers", 0) >= 1:
                    break
            except Exception:
                pass
        time.sleep(0.05)

    # Small grace period after subscriber registers so the SSE handler is
    # blocked on its queue.get() rather than mid-handshake
    time.sleep(0.1)

    # Now POST and wait for output to arrive
    _post(host, port, event_payload)
    for _ in range(60):
        if out_lines:
            break
        time.sleep(0.05)

    stop.set()
    proc.terminate()
    try:
        proc.wait(timeout=2.0)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=1.0)
    t_out.join(timeout=1.0)
    t_err.join(timeout=1.0)
    return proc.returncode, "".join(out_lines), "".join(err_lines)


def test_watch_prints_unfiltered_event(server):
    host, port = server
    rc, out, err = _run_watch_until_event_seen(
        host, port, [], {"event_name": "stream_test", "params": {"v": 1}}
    )
    assert "stream_test" in out, f"out={out!r} err={err!r}"
    assert "watching events" in err  # banner goes to stderr


def test_watch_filter_includes_matching_event(server):
    host, port = server
    rc, out, err = _run_watch_until_event_seen(
        host, port, ["--filter", "stream"], {"event_name": "stream_test"}
    )
    assert "stream_test" in out


def test_watch_filter_excludes_non_matching_event(server):
    host, port = server
    rc, out, err = _run_watch_until_event_seen(
        host, port, ["--filter", "nutrition"], {"event_name": "home_event"}
    )
    assert "home_event" not in out


def test_watch_raw_mode_emits_json(server):
    host, port = server
    rc, out, err = _run_watch_until_event_seen(
        host, port, ["--raw"], {"event_name": "raw_test", "params": {"k": "v"}}
    )
    # In raw mode, stdout should contain a parseable JSON line
    lines = [l for l in out.splitlines() if l.strip().startswith("{")]
    assert lines, f"expected JSON in stdout; got out={out!r}"
    decoded = json.loads(lines[0])
    assert decoded["event_name"] == "raw_test"
    assert decoded["params"] == {"k": "v"}


def test_watch_reports_connection_error_with_hint():
    """Pointing at a non-existent server should exit non-zero with a hint."""
    # Use a port that's almost certainly not in use
    proc = subprocess.run(
        [sys.executable, str(WATCH_PATH), "--server", "http://127.0.0.1:1", "--no-color"],
        capture_output=True,
        text=True,
        timeout=5,
    )
    assert proc.returncode == 1
    assert "cannot connect" in proc.stderr
    assert "start the server first" in proc.stderr
