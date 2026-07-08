"""Unit + dispatch tests for the F4 FRAMEWORK_VERSION_STALE advisory gate.

Layer 1 (unit): version-tuple parsing, canonical resolution priority, each skip
reason, the stale/healthy comparison, and the two exemptions.
Layer 2 (dispatch): monkeypatched committed-state so the gate reaches a real
transition; asserts Mechanism A coverage emits (candidate + checked/skip) and
that a stale state produces an advisory finding, not an error.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "check_state_schema", SCRIPTS_DIR / "check-state-schema.py"
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

from gate_coverage import GateCoverage  # noqa: E402

GATE = "FRAMEWORK_VERSION_STALE"
FEATURES_DIR = _mod.FEATURES_DIR


def _path(slug: str = "_unit-fixture") -> Path:
    return FEATURES_DIR / slug / "state.json"


def _base_state(**over) -> dict:
    s = {
        "current_phase": "implementation",
        "framework_version": "v7.5",
        "state_owner": "ft2",
    }
    s.update(over)
    return s


# ── Layer 1: version parsing ────────────────────────────────────────────────


@pytest.mark.parametrize("raw,expected", [
    ("v7.9.1", (7, 9, 1, 1)),
    ("v7.10", (7, 10, 0, 1)),
    ("v8.0", (8, 0, 0, 1)),
    ("pre-v7.0", (7, 0, 0, 0)),
    ("pre-v5.0", (5, 0, 0, 0)),
])
def test_parse_framework_version_ok(raw, expected):
    assert _mod._parse_framework_version(raw) == expected


@pytest.mark.parametrize("raw", ["7.9", "v7", "", "garbage", None, "7.10.0"])
def test_parse_framework_version_rejects(raw):
    assert _mod._parse_framework_version(raw) is None


def test_version_ordering():
    pv = _mod._parse_framework_version
    assert pv("v7.9.1") < pv("v7.10")          # minor 9 < 10 (not lexical)
    assert pv("pre-v7.0") < pv("v7.0")          # pre sorts before release
    assert pv("v7.10") < pv("v8.0")
    assert not (pv("v7.10") < pv("v7.10"))      # equal is not stale


# ── Layer 1: canonical resolution priority ──────────────────────────────────


def test_canonical_override_wins(monkeypatch):
    monkeypatch.setattr(_mod, "_FRAMEWORK_VERSION_CANONICAL_OVERRIDE", "v9.9")
    assert _mod._canonical_framework_version() == "v9.9"


def test_canonical_falls_back_to_framework_facts(monkeypatch):
    monkeypatch.setattr(_mod, "_FRAMEWORK_VERSION_CANONICAL_OVERRIDE", None)
    # Real FRAMEWORK-FACTS.md under REPO_ROOT resolves to the current version.
    assert _mod._canonical_framework_version() is not None


def test_canonical_unknown_when_facts_missing(monkeypatch, tmp_path):
    monkeypatch.setattr(_mod, "_FRAMEWORK_VERSION_CANONICAL_OVERRIDE", None)
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)  # no docs/FRAMEWORK-FACTS.md
    assert _mod._canonical_framework_version() is None


# ── Layer 2: gate dispatch + skip reasons ───────────────────────────────────


def _run(state, monkeypatch, *, committed=None, canonical="v7.10",
         enforce_transition=True):
    """Run the gate with a controlled committed HEAD + canonical version."""
    monkeypatch.setattr(_mod, "_FRAMEWORK_VERSION_CANONICAL_OVERRIDE", canonical)
    monkeypatch.setattr(_mod, "_load_committed_state", lambda p: committed)
    cov = GateCoverage()
    findings = _mod.check_framework_version_stale(
        state, _path(), coverage=cov, enforce_transition=enforce_transition
    )
    return findings, cov.gates.get(GATE, {})


def test_fires_on_stale_with_transition(monkeypatch):
    findings, stats = _run(_base_state(framework_version="v7.5"), monkeypatch,
                           committed=None)  # None HEAD => transition
    assert len(findings) == 1
    f = findings[0]
    assert f["code"] == GATE
    # ENFORCED 2026-07-08 (cadence F4): flag flipped to False, so the finding
    # is now blocking (advisory=False). Was True during the advisory window.
    assert f["advisory"] is False
    assert f["recorded"] == "v7.5"
    assert f["canonical"] == "v7.10"
    assert stats["checked"] == 1


def test_healthy_when_version_current(monkeypatch):
    findings, stats = _run(_base_state(framework_version="v7.10"), monkeypatch,
                           committed=None)
    assert findings == []          # reached comparison, no finding
    assert stats["checked"] == 1   # candidate counted as checked, not skipped


def test_healthy_when_version_newer(monkeypatch):
    findings, _ = _run(_base_state(framework_version="v8.0"), monkeypatch,
                       committed=None)
    assert findings == []


def test_skip_no_phase_change(monkeypatch):
    state = _base_state(framework_version="v7.5", current_phase="implementation")
    findings, stats = _run(state, monkeypatch,
                           committed={"current_phase": "implementation"})
    assert findings == []
    assert stats["skip_reasons"].get("no_phase_change") == 1


def test_skip_not_staged_mode(monkeypatch):
    findings, stats = _run(_base_state(), monkeypatch, enforce_transition=False)
    assert findings == []
    assert stats["skip_reasons"].get("not_staged_mode") == 1


def test_skip_field_absent(monkeypatch):
    state = _base_state()
    del state["framework_version"]
    findings, stats = _run(state, monkeypatch, committed=None)
    assert findings == []
    assert stats["skip_reasons"].get("field_absent") == 1


def test_skip_malformed_version(monkeypatch):
    findings, stats = _run(_base_state(framework_version="7.5"), monkeypatch,
                           committed=None)
    assert findings == []
    assert stats["skip_reasons"].get("malformed_version") == 1


def test_skip_canonical_unknown(monkeypatch, tmp_path):
    # canonical=None disables the override AND tmp_path REPO_ROOT has no
    # docs/FRAMEWORK-FACTS.md, so neither resolution source returns a version.
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path)
    findings, stats = _run(_base_state(), monkeypatch, committed=None,
                           canonical=None)
    assert findings == []
    assert stats["skip_reasons"].get("canonical_version_unknown") == 1


def test_skip_reverse_sync_mirror(monkeypatch):
    state = _base_state(framework_version="v7.5",
                        state_owner_sync_origin="fitme-story-reverse")
    findings, stats = _run(state, monkeypatch, committed=None)
    assert findings == []
    assert stats["skip_reasons"].get("reverse_sync_mirror") == 1


def test_skip_explicit_exempt(monkeypatch):
    state = _base_state(framework_version="v7.5",
                        framework_version_stale_exempt=True)
    findings, stats = _run(state, monkeypatch, committed=None)
    assert findings == []
    assert stats["skip_reasons"].get("explicit_exempt") == 1


def test_advisory_finding_is_not_an_error(monkeypatch):
    """In advisory mode the finding carries advisory=True so validate_file
    routes it to stderr, never to errors[]."""
    monkeypatch.setattr(_mod, "FRAMEWORK_VERSION_STALE_ADVISORY_MODE", True)
    findings, _ = _run(_base_state(framework_version="v7.5"), monkeypatch,
                       committed=None)
    assert findings and all(f["advisory"] for f in findings)
