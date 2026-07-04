"""FIT-183 (R17) — tests for daily-integrity-checkpoint.py::state_sync_health_probe.

The probe is best-effort I/O — it must NEVER raise, and it must correctly
classify 200/503/404/network-error responses. urllib is mocked; no network.
"""
from __future__ import annotations

import importlib.util
import io
import json
import urllib.error
from pathlib import Path
from unittest.mock import patch

SCRIPTS_DIR = Path(__file__).resolve().parents[1]


def _load():
    spec = importlib.util.spec_from_file_location(
        "daily_checkpoint", SCRIPTS_DIR / "daily-integrity-checkpoint.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()


class _FakeResp:
    def __init__(self, body: bytes, status: int = 200):
        self._body = body
        self.status = status

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def test_healthy_200():
    body = json.dumps({"healthy": True, "reason": "ok", "age_minutes": 30,
                       "ft2_state_count": 113, "gate_coverage_lines": 4024}).encode()
    with patch("urllib.request.urlopen", return_value=_FakeResp(body, 200)):
        r = mod.state_sync_health_probe(url="https://example.test/health")
    assert r["reachable"] is True
    assert r["http_status"] == 200
    assert r["healthy"] is True
    assert r["age_minutes"] == 30


def test_stale_503_carries_reason_body():
    body = json.dumps({"healthy": False, "reason": "stale", "age_minutes": 500}).encode()
    err = urllib.error.HTTPError("u", 503, "Service Unavailable", {}, io.BytesIO(body))
    with patch("urllib.request.urlopen", side_effect=err):
        r = mod.state_sync_health_probe(url="https://example.test/health")
    assert r["reachable"] is True
    assert r["http_status"] == 503
    assert r["healthy"] is False
    assert r["reason"] == "stale"


def test_404_not_deployed_has_no_health_key():
    err = urllib.error.HTTPError("u", 404, "Not Found", {}, io.BytesIO(b"not json"))
    with patch("urllib.request.urlopen", side_effect=err):
        r = mod.state_sync_health_probe(url="https://example.test/health")
    assert r["reachable"] is True
    assert r["http_status"] == 404
    assert "healthy" not in r  # render treats this as best-effort, not an alert


def test_network_error_is_unreachable_not_raised():
    with patch("urllib.request.urlopen", side_effect=OSError("connection refused")):
        r = mod.state_sync_health_probe(url="https://example.test/health")
    assert r["reachable"] is False
    assert "error" in r
    assert "OSError" in r["error"]
