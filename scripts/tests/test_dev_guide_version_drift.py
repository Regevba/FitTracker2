#!/usr/bin/env python3
"""Unit tests for DEV_GUIDE_VERSION_DRIFT — cycle-time ADVISORY.

Cycle-time advisory in `scripts/integrity-check.py` (backlog 2026-05-24). Fires
when the LAST version token in a dev-guide H1 title diverges from the canonical
framework version (FRAMEWORK-FACTS.md). Two surfaces: the in-repo canonical
guide (always) + a best-effort fitme-story mirror (skipped when absent).

Cycle-time gates use the unit layer only (no try-repo fixture pair), per the
v8.x ready-now workplan. Ships advisory; +14d Mechanism A telemetry → promotion
decision.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "integrity_check", SCRIPTS_DIR / "integrity-check.py",
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

GATE = "DEV_GUIDE_VERSION_DRIFT"


def _wire(monkeypatch, tmp_path, h1, *, canonical="v7.10"):
    """Point the gate at a temp dev-guide + a canonical override; fitme-story
    mirror defaults to an absent path (cross-repo check skips)."""
    guide = tmp_path / "dev-guide.md"
    guide.write_text(h1 + "\n\nbody\n", encoding="utf-8")
    monkeypatch.setattr(_mod, "DEV_GUIDE_PATH", guide)
    monkeypatch.setenv("FRAMEWORK_VERSION_CANONICAL_OVERRIDE", canonical)
    monkeypatch.setattr(_mod, "_FITME_STORY_DEV_GUIDE", tmp_path / "absent" / "dev-guide.md")
    return guide


def test_fires_on_version_drift(monkeypatch, tmp_path):
    _wire(monkeypatch, tmp_path,
          "# PM Framework — Developer Guide (v1.0 → v7.9)", canonical="v7.10")
    findings = _mod.check_dev_guide_version_drift()
    assert len(findings) == 1
    f = findings[0]
    assert f["code"] == GATE
    assert f["severity"] == "ADVISORY"
    assert "v7.9" in f["message"] and "v7.10" in f["message"]


def test_no_fire_when_aligned(monkeypatch, tmp_path):
    _wire(monkeypatch, tmp_path,
          "# PM Framework — Developer Guide (v1.0 → v7.10)", canonical="v7.10")
    assert _mod.check_dev_guide_version_drift() == []


def test_skip_when_no_canonical(monkeypatch, tmp_path):
    """Fail-open: an unresolvable canonical version skips rather than fires."""
    guide = tmp_path / "dev-guide.md"
    guide.write_text("# Guide (v7.9)\n", encoding="utf-8")
    monkeypatch.setattr(_mod, "DEV_GUIDE_PATH", guide)
    monkeypatch.delenv("FRAMEWORK_VERSION_CANONICAL_OVERRIDE", raising=False)
    # REPO_ROOT with no FRAMEWORK-FACTS.md → canonical resolves to None.
    monkeypatch.setattr(_mod, "REPO_ROOT", tmp_path / "empty-root")
    assert _mod.check_dev_guide_version_drift() == []


def test_cross_repo_mirror_drift(monkeypatch, tmp_path):
    """In-repo aligned but the fitme-story mirror drifts → one mirror finding."""
    _wire(monkeypatch, tmp_path,
          "# PM Framework — Developer Guide (v1.0 → v7.10)", canonical="v7.10")
    web = tmp_path / "web-dev-guide.md"
    web.write_text("# FitMe Story — Developer Guide (v1.0 → v7.9)\n", encoding="utf-8")
    monkeypatch.setattr(_mod, "_FITME_STORY_DEV_GUIDE", web)
    findings = _mod.check_dev_guide_version_drift()
    assert len(findings) == 1
    assert "fitme-story" in findings[0]["message"].lower() \
        or "cross-repo" in findings[0]["message"].lower()


def test_coverage_emission(monkeypatch, tmp_path):
    _wire(monkeypatch, tmp_path,
          "# PM Framework — Developer Guide (v1.0 → v7.10)", canonical="v7.10")
    cov = _mod.GateCoverage(mode="cycle")
    _mod.check_dev_guide_version_drift(coverage=cov)
    assert GATE in cov.gates, "expected a Mechanism A coverage bucket for the gate"
