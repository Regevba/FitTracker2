"""Unit tests for scripts/figma-mirror-staleness.py (Gap D advisory).

Covers:
  * code_token_keys() flattens tokens.json to the 80 slash-named keys the
    Figma code-mirror collection (985:2) uses (borderRadius -> radius rename;
    typography/shadow/motion excluded).
  * main() reports "no drift" when snapshot == code keys (exit 0).
  * main() reports added/removed token drift (still exit 0 — advisory).
  * main() reports staleness when the snapshot is older than the horizon.
  * --update-snapshot rewrites the snapshot from current code keys.
  * a Mechanism A coverage row is emitted to the ledger.
  * missing snapshot is handled (advisory skip, exit 0).
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))


def _load_module(tmp_tokens: Path, tmp_snapshot: Path, tmp_ledger: Path):
    """Load figma-mirror-staleness.py with its module-level paths redirected to tmp."""
    spec = importlib.util.spec_from_file_location(
        "figma_mirror_staleness", SCRIPTS_DIR / "figma-mirror-staleness.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.TOKENS = tmp_tokens
    mod.SNAPSHOT = tmp_snapshot
    mod.COVERAGE_LEDGER = tmp_ledger
    return mod


MINI_TOKENS = {
    "$schema": "x",
    "comment": "ignored",
    "color": {
        "brand": {"primary": {"value": "#FA8F40", "type": "color"}},
        "status": {"success": {"value": "#34C759", "type": "color"}},
    },
    "spacing": {"large": {"value": "24", "type": "spacing"}},
    "borderRadius": {"card": {"value": "16", "type": "borderRadius"}},
    "opacity": {"disabled": {"value": 0.15, "type": "opacity"}},
    "size": {"ctaHeight": {"value": 52, "type": "dimension"}},
    "layout": {"chartHeight": {"value": 158, "type": "dimension"}},
    # excluded categories:
    "typography": {"hero": {"value": "x", "type": "typography"}},
    "shadow": {"card": {"color": {"value": "x", "type": "color"}}},
    "motion": {"x": {"value": {"easing": "easeOut", "duration": 0.2}, "type": "motion"}},
}
EXPECTED_KEYS = {
    "brand/primary", "status/success", "spacing/large", "radius/card",
    "opacity/disabled", "size/ctaHeight", "layout/chartHeight",
}


@pytest.fixture
def env(tmp_path):
    tokens = tmp_path / "tokens.json"
    tokens.write_text(json.dumps(MINI_TOKENS))
    snapshot = tmp_path / "snapshot.json"
    ledger = tmp_path / "gate-coverage.jsonl"
    mod = _load_module(tokens, snapshot, ledger)
    return mod, tokens, snapshot, ledger


def test_code_token_keys_flattening_and_exclusions(env):
    mod, *_ = env
    assert mod.code_token_keys() == EXPECTED_KEYS  # borderRadius->radius; typo/shadow/motion excluded


def test_no_drift_when_snapshot_matches(env, capsys):
    mod, _t, snapshot, ledger = env
    snapshot.write_text(json.dumps({"audited_at": "2026-06-18", "ios": {"token_keys": sorted(EXPECTED_KEYS)}}))
    rc = mod.main_with_args(["--today", "2026-06-18"]) if hasattr(mod, "main_with_args") else _run(mod, ["--today", "2026-06-18"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "no drift" in out
    assert ledger.exists()  # coverage emitted
    row = json.loads(ledger.read_text().strip().splitlines()[-1])
    assert row["gate"] == "FIGMA_MIRROR_STALENESS" and row["checked"] == 1


def test_added_in_code_flagged(env, capsys):
    mod, _t, snapshot, _l = env
    short = sorted(EXPECTED_KEYS - {"brand/primary"})
    snapshot.write_text(json.dumps({"audited_at": "2026-06-18", "ios": {"token_keys": short}}))
    rc = _run(mod, ["--today", "2026-06-18"])
    out = capsys.readouterr().out
    assert rc == 0  # advisory
    assert "NOT in mirror" in out and "brand/primary" in out


def test_removed_in_code_flagged(env, capsys):
    mod, _t, snapshot, _l = env
    extra = sorted(EXPECTED_KEYS | {"brand/ghost"})
    snapshot.write_text(json.dumps({"audited_at": "2026-06-18", "ios": {"token_keys": extra}}))
    rc = _run(mod, ["--today", "2026-06-18"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "NOT in code" in out and "brand/ghost" in out


def test_staleness_horizon(env, capsys):
    mod, _t, snapshot, _l = env
    snapshot.write_text(json.dumps({"audited_at": "2026-01-01", "ios": {"token_keys": sorted(EXPECTED_KEYS)}}))
    rc = _run(mod, ["--today", "2026-06-18", "--horizon-days", "90"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "days old" in out


def test_update_snapshot(env, capsys):
    mod, _t, snapshot, _l = env
    rc = _run(mod, ["--update-snapshot", "--today", "2026-06-18"])
    assert rc == 0
    written = json.loads(snapshot.read_text())
    assert set(written["ios"]["token_keys"]) == EXPECTED_KEYS
    assert written["audited_at"] == "2026-06-18"


def test_missing_snapshot_is_advisory_skip(env, capsys):
    mod, _t, _s, ledger = env  # snapshot file not written
    rc = _run(mod, [])
    out = capsys.readouterr().out
    assert rc == 0 and "no mirror snapshot" in out
    row = json.loads(ledger.read_text().strip().splitlines()[-1])
    assert row["skipped"] == 1 and "no_snapshot" in row["skip_reasons"]


def _run(mod, argv):
    """Invoke main() with a patched argv."""
    old = sys.argv
    sys.argv = ["figma-mirror-staleness.py", *argv]
    try:
        return mod.main()
    finally:
        sys.argv = old
