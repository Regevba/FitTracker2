"""Unit tests for scripts/backfill-platforms-tested.py.

Covers the pure derive_platforms_tested heuristic + the textual key insertion
(valid-JSON guarantee + anchor handling).
"""
import importlib.util
import json
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))

_spec = importlib.util.spec_from_file_location(
    "backfill_platforms_tested", SCRIPTS_DIR / "backfill-platforms-tested.py")
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

derive = _mod.derive_platforms_tested
insert = _mod._insert_keys


def test_framework_meta_chore_exempt():
    pt, prov = derive({"work_type": "chore", "feature_name": "x"})
    assert pt == {} and prov == "exempt:framework_meta"


def test_framework_feature_exempt():
    pt, prov = derive({"work_subtype": "framework_feature", "feature_name": "x"})
    assert pt == {} and prov == "exempt:framework_meta"


def test_ios_inferred_from_has_ui():
    pt, prov = derive({"work_type": "Feature", "has_ui": True, "feature_name": "x"})
    assert pt["ios"] is True and prov.startswith("backfill-heuristic-2026")


def test_ios_inferred_from_keyword():
    pt, prov = derive({"work_type": "Feature",
                       "scope_summary": "SwiftUI view in FitTracker/Views"})
    assert pt["ios"] is True


def test_web_inferred():
    pt, _ = derive({"work_type": "Feature",
                    "scope_summary": "fitme-story control-room Next.js page"})
    assert pt["web"] is True


def test_ai_inferred():
    pt, _ = derive({"work_type": "Feature",
                    "scope_summary": "AIOrchestrator cohort recommendation"})
    assert pt["ai"] is True


def test_low_confidence_when_no_signal():
    pt, prov = derive({"work_type": "Feature", "feature_name": "mystery",
                       "scope_summary": "does a thing"})
    assert prov == "backfill-heuristic-low-confidence"
    assert all(v is False for v in pt.values())


def test_insert_produces_valid_json():
    original = '{\n  "feature_name": "x",\n  "current_phase": "complete",\n  "k": 1\n}\n'
    out = insert(original, {"ios": True, "web": False, "backend": False, "ai": False},
                 "backfill-heuristic-2026-06-07")
    parsed = json.loads(out)
    assert parsed["platforms_tested"]["ios"] is True
    assert parsed["platforms_tested_provenance"] == "backfill-heuristic-2026-06-07"
    assert parsed["feature_name"] == "x" and parsed["k"] == 1


def test_insert_returns_none_without_anchor():
    assert insert('{"feature_name": "x"}', {}, "p") is None
