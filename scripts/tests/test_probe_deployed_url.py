"""Unit tests for scripts/probe-deployed-url.sh (F-DEPLOYED-URL-PROBE).

Spawns a local http.server in a thread, then invokes the shell script as a
subprocess against http://localhost:<port>/<path> with each assertion flag
permutation. Verifies exit codes + stderr messages.

Test-only dep: stdlib http.server + threading. No external network.
"""
from __future__ import annotations

import http.server
import socketserver
import subprocess
import threading
import time
from pathlib import Path

import pytest


SCRIPT = Path(__file__).resolve().parents[1] / "probe-deployed-url.sh"


class _Server(socketserver.TCPServer):
    allow_reuse_address = True


class _Handler(http.server.BaseHTTPRequestHandler):
    """Tiny test server. Responds based on URL path:
        /ok-html             → 200, text/html, "hello world"
        /ok-xml              → 200, application/xml, "<rss/>"
        /robots-with-sitemap → 200, text/plain, "User-agent: *\nSitemap: ..."
        /robots-no-sitemap   → 200, text/plain, "User-agent: *\nDisallow: /"
        /not-found           → 404
        /with-newline-token  → 200, text/plain, "id=ABC%0Atrailing"
        /clean-token         → 200, text/plain, "id=ABC"
    """

    def do_GET(self):  # noqa: N802
        path = self.path
        if path == "/ok-html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"<html><body>hello world</body></html>")
        elif path == "/ok-xml":
            self.send_response(200)
            self.send_header("Content-Type", "application/xml")
            self.end_headers()
            self.wfile.write(b"<?xml version='1.0'?><rss/>")
        elif path == "/robots-with-sitemap":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"User-agent: *\nSitemap: http://example.com/sitemap.xml\n")
        elif path == "/robots-no-sitemap":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"User-agent: *\nDisallow: /\n")
        elif path == "/not-found":
            self.send_response(404)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"<html>not found</html>")
        elif path == "/with-newline-token":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"id=ABC%0Atrailing")
        elif path == "/clean-token":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"id=ABC")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args, **kwargs):  # silence test output
        pass


@pytest.fixture(scope="module")
def test_server():
    server = _Server(("127.0.0.1", 0), _Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.1)  # let server come up
    yield f"http://127.0.0.1:{port}"
    server.shutdown()
    server.server_close()


def _run(url: str, *extra_args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(SCRIPT), url, *extra_args],
        capture_output=True, text=True, timeout=30,
    )


def test_usage_error_no_args():
    r = subprocess.run([str(SCRIPT)], capture_output=True, text=True)
    assert r.returncode == 2
    assert "Usage" in r.stderr


def test_status_200_pass(test_server):
    r = _run(f"{test_server}/ok-html", "--status", "200")
    assert r.returncode == 0, r.stderr
    assert "OK:" in r.stdout


def test_status_mismatch_fail(test_server):
    r = _run(f"{test_server}/not-found", "--status", "200")
    assert r.returncode == 1
    assert "FAIL" in r.stderr
    assert "404" in r.stderr


def test_content_type_pass(test_server):
    r = _run(f"{test_server}/ok-xml", "--status", "200", "--content-type", "xml")
    assert r.returncode == 0, r.stderr


def test_content_type_mismatch_fail(test_server):
    r = _run(f"{test_server}/ok-html", "--status", "200", "--content-type", "xml")
    assert r.returncode == 1
    assert "content-type mismatch" in r.stderr


def test_body_contains_pass(test_server):
    r = _run(
        f"{test_server}/robots-with-sitemap",
        "--status", "200",
        "--body-contains", "Sitemap:",
    )
    assert r.returncode == 0, r.stderr


def test_body_contains_fail(test_server):
    r = _run(
        f"{test_server}/robots-no-sitemap",
        "--status", "200",
        "--body-contains", "Sitemap:",
    )
    assert r.returncode == 1
    assert "does not contain" in r.stderr


def test_body_not_contains_pass_clean_token(test_server):
    """W19 reproducer: clean token has no %0A → pass."""
    r = _run(
        f"{test_server}/clean-token",
        "--status", "200",
        "--body-not-contains", "%0A",
    )
    assert r.returncode == 0, r.stderr


def test_body_not_contains_fail_on_newline_corruption(test_server):
    """W19 class: encoded newline in body → fail."""
    r = _run(
        f"{test_server}/with-newline-token",
        "--status", "200",
        "--body-not-contains", "%0A",
    )
    assert r.returncode == 1
    assert "contains forbidden text" in r.stderr


def test_compound_assertions_pass(test_server):
    r = _run(
        f"{test_server}/robots-with-sitemap",
        "--status", "200",
        "--content-type", "text/plain",
        "--body-contains", "Sitemap:",
        "--body-not-contains", "%0A",
    )
    assert r.returncode == 0, r.stderr


def test_unknown_option_usage_error(test_server):
    r = _run(f"{test_server}/ok-html", "--bogus", "foo")
    assert r.returncode == 2


def test_curl_error_unreachable_host():
    """Unreachable host (port 1) → curl error → exit 3."""
    r = _run("http://127.0.0.1:1/never", "--status", "200")
    assert r.returncode == 3
    assert "curl failed" in r.stderr
