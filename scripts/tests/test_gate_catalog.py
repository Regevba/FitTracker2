"""
Unit tests for scripts/gate-catalog.py (T16 / TC-T16).

Covers: enumeration completeness, required-field shape, tier derivation
(fixture == try-repo authority, no over-crediting from try_repo test-file
mentions), orphan-fixture detection, and the committed catalog staying in
sync with the live derivation (the `--check` contract).
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "gate-catalog.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("gate_catalog", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


gc = _load_module()


def test_enumeration_counts():
    cat = gc.build_catalog()
    by_stage = cat["summary"]["by_stage"]
    # 21 write-time (incl. CASE_STUDY_MISSING_FIELDS in check-case-study-preflight.py)
    # + 9 cycle-time + 2 W9 hooks + 1 standalone = 33.
    assert by_stage == {
        "cycle-time": 9,
        "hook": 2,
        "standalone": 1,
        "write-time": 21,
    }, by_stage
    assert cat["gate_count"] == 33


def test_every_gate_has_required_fields():
    cat = gc.build_catalog()
    for gid, e in cat["gates"].items():
        for field in ("stage", "source", "enforcement", "description", "tier", "test_files"):
            assert field in e, f"{gid} missing {field}"
        assert e["stage"] in {"write-time", "cycle-time", "hook", "standalone"}, gid
        assert e["tier"] in {"none", "unit", "dispatch", "try-repo"}, gid


def test_fixture_is_the_only_try_repo_signal():
    """A gate with its own fixture dir is try-repo; a gate merely *mentioned*
    inside another gate's try_repo test file (no fixture) must NOT be
    over-credited to try-repo."""
    cat = gc.build_catalog()["gates"]
    # FEATURE_CLOSURE_COMPLETENESS has a fixture dir -> try-repo.
    assert cat["FEATURE_CLOSURE_COMPLETENESS"]["tier"] == "try-repo"
    assert cat["FEATURE_CLOSURE_COMPLETENESS"]["fixture_path"] is not None
    # PLATFORMS_TESTED has NO fixture dir; it appears in another gate's
    # try_repo test via shared baseline state -> must be unit, not try-repo.
    assert cat["PLATFORMS_TESTED"]["fixture_path"] is None
    assert cat["PLATFORMS_TESTED"]["tier"] == "unit"


def test_case_study_missing_fields_is_cataloged():
    """The gate that FRAMEWORK-FACTS's check-state-schema.py-scoped count
    missed — proves the catalog spans both pre-commit gate hosts."""
    cat = gc.build_catalog()["gates"]
    e = cat["CASE_STUDY_MISSING_FIELDS"]
    assert e["source"] == "scripts/check-case-study-preflight.py"
    assert e["stage"] == "write-time"
    assert e["tier"] == "try-repo"  # has both fixture + dispatch test


def test_write_time_gap_signal():
    """The T1 GATE_TEST_MISSING precursor: write-time gates lacking a try-repo
    fixture are surfaced explicitly."""
    cat = gc.build_catalog()
    gap = cat["summary"]["write_time_without_try_repo"]
    assert set(gap) == {
        "CSV_TAXONOMY_DRIFT",
        "GA4_MCP_DISCONNECTED",
        "PLATFORMS_TESTED",
        "PR_NUMBER_UNRESOLVED",
    }, gap
    # every listed gap gate really is write-time and really lacks a fixture
    for gid in gap:
        assert cat["gates"][gid]["stage"] == "write-time"
        assert cat["gates"][gid]["fixture_path"] is None


def test_no_orphan_fixtures():
    """Every try-repo fixture on disk is claimed by exactly one catalog gate."""
    assert gc.orphan_fixtures() == []


def test_committed_catalog_matches_live_derivation():
    """The committed .claude/shared/gate-catalog.json must equal a fresh build
    (this is what `gate-catalog.py --check` enforces in CI)."""
    committed = json.loads(gc.CATALOG_PATH.read_text(encoding="utf-8"))
    assert committed == gc.build_catalog(), (
        "gate-catalog.json is stale — run `make gate-catalog` and commit."
    )
