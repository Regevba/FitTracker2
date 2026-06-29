"""Tests for GA4_MCP_DISCONNECTED (AN-1B.2, analytics-master-plan §8.3)."""
from __future__ import annotations

import importlib.util
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "check-state-schema.py"
_spec = importlib.util.spec_from_file_location("check_state_schema", _MOD)
css = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(css)

ANALYTICS_FILE = css.ANALYTICS_PROVIDER_PATH


def _clear_env(monkeypatch):
    monkeypatch.delenv("GA4_PROPERTY_ID", raising=False)
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)


def test_skip_when_no_analytics_files(monkeypatch):
    _clear_env(monkeypatch)
    assert css.check_ga4_mcp_connectivity(["scripts/foo.py", "docs/x.md"]) == []


def test_disconnected_fires_advisory_when_env_unset(monkeypatch):
    _clear_env(monkeypatch)
    f = css.check_ga4_mcp_connectivity([ANALYTICS_FILE])
    assert len(f) == 1
    assert f[0]["code"] == "GA4_MCP_DISCONNECTED"
    assert f[0]["advisory"] is True  # advisory-only by design
    assert "GA4_PROPERTY_ID unset" in f[0]["reasons"]


def test_taxonomy_csv_is_analytics_affecting(monkeypatch):
    _clear_env(monkeypatch)
    assert len(css.check_ga4_mcp_connectivity([css.ANALYTICS_TAXONOMY_CSV])) == 1


def test_connected_no_finding(monkeypatch, tmp_path):
    creds = tmp_path / "sa.json"
    creds.write_text("{}")
    monkeypatch.setenv("GA4_PROPERTY_ID", "properties/123456")
    monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", str(creds))
    assert css.check_ga4_mcp_connectivity([ANALYTICS_FILE]) == []


def test_creds_file_missing_fires(monkeypatch):
    monkeypatch.setenv("GA4_PROPERTY_ID", "properties/123456")
    monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", "/nonexistent/sa.json")
    f = css.check_ga4_mcp_connectivity([ANALYTICS_FILE])
    assert len(f) == 1
    assert any("file missing" in r for r in f[0]["reasons"])


def test_never_blocks_advisory_always_true(monkeypatch):
    _clear_env(monkeypatch)
    f = css.check_ga4_mcp_connectivity([ANALYTICS_FILE])
    # advisory must always be True — the gate never routes to errors[]
    assert f and f[0]["advisory"] is True
