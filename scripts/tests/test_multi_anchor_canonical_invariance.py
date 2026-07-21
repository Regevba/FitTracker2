"""Canonical-anchor invariance guard (FT2-FH-004 lesson).

The multi-anchor tool was revived 2026-07-21 after the 2026-07-07 backup-path move
stranded it. The revival re-registered the 2026-06-10 telemetry-backfill anchor as
TREND CONTEXT. This test enforces the load-bearing invariant that must survive that
change and any future anchor addition:

  Adding anchors to the registry must NEVER change which anchor gates the regression
  verdict. 2026-05-14 stays canonical, non-superseding; newer anchors are advisory
  trend context only. This is the exact failure class that motivated FT2-FH-004 (a
  non-compliant DEFAULT_BASELINE bump that had to be reverted in PR #701).

These tests take NO dependency on backup files existing on disk — they assert on the
registry/config surface + the gating logic, so they pass in CI where the anchors are
absent.
"""
from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load(name: str, rel: str):
    src = REPO_ROOT / rel
    spec = importlib.util.spec_from_file_location(name, src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def mod():
    return _load("integrity_multi_anchor", "scripts/integrity-multi-anchor.py")


def test_canonical_label_is_2026_05_14(mod):
    assert mod.CANONICAL_ANCHOR == "2026-05-14-platform"


def test_exactly_one_registry_entry_is_canonical(mod):
    labels = [label for label, _ in mod.ANCHOR_REGISTRY]
    assert labels.count(mod.CANONICAL_ANCHOR) == 1, (
        f"canonical label must appear exactly once in the registry; labels={labels}")


def test_new_anchors_are_trend_context_not_canonical(mod):
    # The 06-10 anchor added at revival must be present AND must not be canonical.
    labels = [label for label, _ in mod.ANCHOR_REGISTRY]
    assert "2026-06-10-telemetry-backfill" in labels
    assert "2026-06-10-telemetry-backfill" != mod.CANONICAL_ANCHOR


def test_only_canonical_anchor_gates_the_verdict(mod, monkeypatch, capsys):
    """Adding a trend anchor whose cohort REGRESSES must NOT produce a gating regression;
    only the canonical anchor's REAL_REGRESSIONs land in report['regressions']."""
    # Build three in-memory anchors: a trend anchor that REGRESSES on the cohort vs live,
    # the canonical anchor that is FLAT vs live, and live. Only the canonical verdict may
    # gate — so the trend regression must NOT appear in report['regressions'].
    trend = {"f0": {"cache_hits": True}, "f1": {"cache_hits": True}}       # 2 adopted → drops to 1 in live
    canonical = {"f0": {"cache_hits": True}, "f1": {"cache_hits": False}}  # 1 adopted → matches live (flat)
    live = {"f0": {"cache_hits": True}, "f1": {"cache_hits": False}}       # 1 adopted

    def fake_load_anchor(label, cands, instrumented_only=False):
        table = {"trend-regresses": trend, mod.CANONICAL_ANCHOR: canonical, "live": live}
        return (label, table[label], "mem") if label in table else None

    monkeypatch.setattr(mod, "ANCHOR_REGISTRY", [
        ("trend-regresses", []),
        (mod.CANONICAL_ANCHOR, []),
    ])
    monkeypatch.setattr(mod, "LIVE", ("live", []))
    monkeypatch.setattr(mod, "load_anchor", fake_load_anchor)
    monkeypatch.setattr(sys, "argv", ["integrity-multi-anchor.py"])

    rc = mod.main()
    out = capsys.readouterr().out
    # The trend anchor regresses on the cohort, but it is NOT canonical → must not gate.
    assert rc == 0
    assert "No REAL regressions vs canonical anchor" in out


def test_too_few_anchors_is_loud_and_nonzero(mod, monkeypatch, capsys):
    """The <2-anchor guard must return 3 (config error) and warn on stderr — never a
    silent exit-0 that reads as 'no regression'."""
    monkeypatch.setattr(mod, "ANCHOR_REGISTRY", [
        (mod.CANONICAL_ANCHOR, [Path("/nonexistent/measurement-adoption.json")]),
    ])
    monkeypatch.setattr(mod, "LIVE", ("live", [Path("/nonexistent/live.json")]))
    monkeypatch.setattr(sys, "argv", ["integrity-multi-anchor.py"])

    rc = mod.main()
    err = capsys.readouterr().err
    assert rc == 3
    assert "MULTI-ANCHOR UNAVAILABLE" in err


def test_integrity_diff_default_baseline_still_points_at_2026_05_14():
    """Guard against a non-compliant DEFAULT_BASELINE re-bump (the FT2-FH-004 incident).
    integrity-diff must keep resolving the 2026-05-14 leaf, never a newer anchor dir."""
    diff = _load("integrity_diff", "scripts/integrity-diff.py")
    leaf = str(diff._BASELINE_LEAF)
    assert "2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14" in leaf
    # candidates must be dual-root (Developer consolidated + Documents legacy fallback)
    cand_str = " ".join(str(p) for p in diff._BASELINE_CANDIDATES)
    assert "Developer/FitMe/backups" in cand_str and "Documents" in cand_str


def test_backup_roots_are_dual_path(mod):
    """Both revived tools must resolve anchors across the consolidated + legacy roots."""
    roots = " ".join(str(r) for r in mod._BACKUP_ROOTS)
    assert re.search(r"Developer/FitMe/backups/FitTracker2-backups", roots)
    assert re.search(r"Documents/FitTracker2-backups", roots)
