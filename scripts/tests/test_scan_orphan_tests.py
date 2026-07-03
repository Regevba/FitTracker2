"""Unit tests for FIT-163 (T15) scripts/scan-orphan-tests.py.

Uses importlib.util because the source file has a hyphen in its name and
cannot be imported with `import scan-orphan-tests`. Fixtures build tiny Swift
trees under tmp_path so the scanner runs against controlled input.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIR))


def _load():
    spec = importlib.util.spec_from_file_location(
        "scan_orphan_tests", SCRIPTS_DIR / "scan-orphan-tests.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()


def _write(base: Path, rel: str, text: str) -> Path:
    p = base / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    return p


@pytest.fixture
def tree(tmp_path: Path):
    """Return (prod_dir, test_dir) factory helpers on a fresh tmp tree."""
    prod = tmp_path / "FitTracker"
    tests = tmp_path / "FitTrackerTests"
    prod.mkdir()
    tests.mkdir()
    return prod, tests


# ── extraction ───────────────────────────────────────────────────────────────

def test_extract_types_and_historical_flag(tree):
    prod, _ = tree
    _write(prod, "Services/FooService.swift", "final class FooService {}\n")
    _write(
        prod,
        "Views/OldView.swift",
        "// HISTORICAL — superseded 2026-01-01\nstruct OldView {}\n",
    )
    syms = mod.extract_prod_symbols(prod)
    assert syms["FooService"]["historical"] is False
    assert syms["OldView"]["historical"] is True


def test_extract_globals_column0_only(tree):
    prod, _ = tree
    _write(
        prod,
        "Services/Client.swift",
        "let supabase: X = makeIt()\n"
        "func topLevelHelper() {}\n"
        "struct Wrapper {\n    let nestedProp = 1\n    func member() {}\n}\n",
    )
    globals_ = mod.extract_prod_globals(prod)
    assert "supabase" in globals_
    assert "topLevelHelper" in globals_
    # Indented (member) declarations must NOT be treated as globals.
    assert "nestedProp" not in globals_
    assert "member" not in globals_


# ── orphan detection ─────────────────────────────────────────────────────────

def test_test_referencing_a_type_is_not_orphan(tree):
    prod, tests = tree
    _write(prod, "Services/FooService.swift", "class FooService {}\n")
    _write(tests, "FooServiceTests.swift", "@testable import FitTracker\nlet x = FooService()\n")
    r = mod.scan(prod, tests)
    assert r["orphan_tests"] == []


def test_test_referencing_nothing_is_orphan(tree):
    prod, tests = tree
    _write(prod, "Services/FooService.swift", "class FooService {}\n")
    _write(tests, "GhostTests.swift", "import XCTest\nfinal class GhostTests: XCTestCase {}\n")
    r = mod.scan(prod, tests)
    assert "FitTrackerTests/GhostTests.swift".split("/")[-1] in r["orphan_tests"][0]


def test_test_referencing_only_a_global_is_not_orphan(tree):
    prod, tests = tree
    _write(prod, "Services/Client.swift", "let supabase: X = makeIt()\n")
    _write(tests, "SupabaseClientTests.swift", "import XCTest\nXCTAssertNotNil(supabase)\n")
    r = mod.scan(prod, tests)
    assert r["orphan_tests"] == []


def test_test_referencing_symbol_in_historical_file_is_not_orphan(tree):
    prod, tests = tree
    _write(
        prod,
        "Services/LegacyStore.swift",
        "// HISTORICAL — superseded\nfinal class LegacyPreferencesStore {}\n",
    )
    _write(tests, "LegacyTests.swift", "let s = LegacyPreferencesStore()\n")
    r = mod.scan(prod, tests)
    assert r["orphan_tests"] == []


# ── untested-symbol direction ────────────────────────────────────────────────

def test_untested_significant_symbol_listed(tree):
    prod, tests = tree
    _write(prod, "Services/LonelyService.swift", "class LonelyService {}\n")
    _write(prod, "Services/UsedService.swift", "class UsedService {}\n")
    _write(tests, "UsedServiceTests.swift", "let u = UsedService()\n")
    r = mod.scan(prod, tests)
    names = {u["symbol"] for u in r["untested_significant_symbols"]}
    assert "LonelyService" in names
    assert "UsedService" not in names


def test_untested_excludes_non_significant_and_historical(tree):
    prod, tests = tree
    # Non-significant name (no logic-bearing suffix) → not listed.
    _write(prod, "Models/Widget.swift", "struct Widget {}\n")
    # HISTORICAL significant type → excluded even though untested.
    _write(
        prod,
        "Services/OldService.swift",
        "// HISTORICAL — superseded\nclass OldService {}\n",
    )
    _write(tests, "AnchorTests.swift", "let w = Widget()\n")  # keep this test non-orphan
    r = mod.scan(prod, tests)
    names = {u["symbol"] for u in r["untested_significant_symbols"]}
    assert "Widget" not in names
    assert "OldService" not in names


# ── CLI / exit codes ─────────────────────────────────────────────────────────

def test_strict_exit_code_on_findings(tree, capsys):
    prod, tests = tree
    _write(prod, "A.swift", "class A {}\n")
    _write(tests, "GhostTests.swift", "final class GhostTests {}\n")
    rc = mod.main(["--prod-dir", str(prod), "--test-dir", str(tests), "--strict"])
    assert rc == 1


def test_advisory_exit_zero_by_default(tree):
    prod, tests = tree
    _write(prod, "A.swift", "class A {}\n")
    _write(tests, "GhostTests.swift", "final class GhostTests {}\n")
    rc = mod.main(["--prod-dir", str(prod), "--test-dir", str(tests)])
    assert rc == 0


def test_missing_dir_returns_usage_error(tmp_path):
    rc = mod.main(["--prod-dir", str(tmp_path / "nope"), "--test-dir", str(tmp_path)])
    assert rc == 2
