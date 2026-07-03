#!/usr/bin/env python3
"""FIT-163 (T15) — orphan-test + untested-symbol scanner (advisory).

Two directions, both advisory (never blocks a commit; surfaced weekly via
`.github/workflows/orphan-tests-weekly.yml`):

  1. ORPHAN TEST — a `*Tests.swift` file that references ZERO production
     symbols. Signal: its subject was renamed/deleted, or the file is pure
     scaffolding. High-value: a test that exercises nothing still "passes".

  2. UNTESTED SYMBOL — a *significant* production type (Service / Manager /
     Store / Engine / Orchestrator / Gateway / Adapter / Coordinator /
     ViewModel / Repository) that NO test file references. Coarser signal;
     scoped to logic-bearing types so the list stays actionable (SwiftUI
     Views and small value types are intentionally out of scope).

Symbol extraction is regex-based (no Swift toolchain needed), matching the
convention of the other repo scanners (check-pr-workflow-coverage.py, etc.).

Usage:
    python3 scripts/scan-orphan-tests.py            # human summary + JSON, exit 0
    python3 scripts/scan-orphan-tests.py --json      # JSON only
    python3 scripts/scan-orphan-tests.py --strict    # exit 1 if any finding
    python3 scripts/scan-orphan-tests.py \
        --prod-dir FitTracker --test-dir FitTrackerTests

Exit codes: 0 = clean OR advisory (default). 1 = findings AND --strict. 2 = usage.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Top-level nominal type declarations. `extension` does not declare a new type.
_DECL_RE = re.compile(
    r"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|final\s+|open\s+|"
    r"@\w+\s+)*"
    r"(?:class|struct|enum|protocol|actor)\s+([A-Z]\w*)",
    re.MULTILINE,
)

# Top-level (column-0, file-scope) global bindings + free functions. A test can
# exercise production through a global (e.g. `supabase`) or a free function
# without ever naming a type — those references must count so the orphan check
# doesn't false-positive. Anchored at line start with NO leading whitespace so
# nested/member declarations (which are indented) are excluded.
_GLOBAL_RE = re.compile(
    r"^(?:public\s+|internal\s+|private\s+|fileprivate\s+|@\w+\s+)*"
    r"(?:let|var|func)\s+([A-Za-z_]\w*)",
    re.MULTILINE,
)

# Logic-bearing type-name suffixes eligible for the untested-symbol direction.
_SIGNIFICANT_SUFFIXES = (
    "Service", "Manager", "Store", "Engine", "Orchestrator", "Gateway",
    "Adapter", "Coordinator", "ViewModel", "Repository", "Client", "Provider",
    "Builder", "Parser", "Validator", "Calculator", "Resolver", "Scheduler",
)

# Generated / non-source files excluded from the production symbol set.
_PROD_EXCLUDE_NAMES = {"DesignTokens.swift"}


def _rel(path: Path) -> str:
    """Repo-relative path when under REPO_ROOT; else a stable fallback (used by
    tmp_path fixtures in the unit tests, which live outside the repo)."""
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _is_historical(text: str) -> bool:
    """HISTORICAL v1 files are not in the build target — skip them."""
    head = text[:600]
    return "HISTORICAL —" in head or "HISTORICAL --" in head


def extract_prod_symbols(prod_dir: Path) -> dict[str, dict]:
    """Return {type_name: {"file": rel_path, "historical": bool}} for every
    declared production type.

    HISTORICAL v1 files are NOT excluded from the symbol universe: a HISTORICAL
    file can still define a type a *live* test references (e.g.
    NotificationPreferencesStore), and dropping it produces false-positive
    orphan-test findings. Instead each symbol carries a `historical` flag so
    the untested-symbol direction can skip superseded types (where a missing
    test is expected, not a regression)."""
    symbols: dict[str, dict] = {}
    for path in sorted(prod_dir.rglob("*.swift")):
        if path.name in _PROD_EXCLUDE_NAMES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        historical = _is_historical(text)
        rel = _rel(path)
        for m in _DECL_RE.finditer(text):
            name = m.group(1)
            # First declaration wins for path attribution; ignore re-decls.
            symbols.setdefault(name, {"file": rel, "historical": historical})
    return symbols


def extract_prod_globals(prod_dir: Path) -> set[str]:
    """Return the set of top-level global binding / free-function names."""
    names: set[str] = set()
    for path in sorted(prod_dir.rglob("*.swift")):
        if path.name in _PROD_EXCLUDE_NAMES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        names.update(_GLOBAL_RE.findall(text))
    return names


def _word_set(text: str) -> set[str]:
    """Identifier tokens in a source file (for fast membership tests)."""
    return set(re.findall(r"[A-Za-z_]\w*", text))


def scan(prod_dir: Path, test_dir: Path) -> dict:
    prod_symbols = extract_prod_symbols(prod_dir)
    # Orphan detection references the full production identifier universe:
    # declared types PLUS top-level globals / free functions.
    prod_names = set(prod_symbols) | extract_prod_globals(prod_dir)

    orphan_tests: list[str] = []
    # Track which production symbols any test references.
    referenced: set[str] = set()
    test_files = sorted(test_dir.rglob("*Tests.swift"))

    for path in test_files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        tokens = _word_set(text)
        hits = tokens & prod_names
        referenced |= hits
        if not hits:
            orphan_tests.append(_rel(path))

    # Untested significant symbols: logic-bearing types no test references.
    # HISTORICAL (superseded) types are excluded — a missing test there is
    # expected, not a regression.
    untested: list[dict] = []
    for name, meta in sorted(prod_symbols.items()):
        if name in referenced or meta["historical"]:
            continue
        if name.endswith(_SIGNIFICANT_SUFFIXES):
            untested.append({"symbol": name, "file": meta["file"]})

    return {
        "schema_version": 1,
        "prod_symbol_count": len(prod_symbols),
        "test_file_count": len(test_files),
        "orphan_tests": orphan_tests,
        "untested_significant_symbols": untested,
        "finding_count": len(orphan_tests) + len(untested),
    }


def render(result: dict) -> str:
    lines = ["Orphan-test scan (FIT-163 / T15 — advisory)", ""]
    lines.append(
        f"  production types: {result['prod_symbol_count']}  |  "
        f"test files: {result['test_file_count']}"
    )
    lines.append("")
    orphans = result["orphan_tests"]
    if orphans:
        lines.append(f"⚠ ORPHAN TESTS ({len(orphans)}) — reference no production symbol:")
        lines.extend(f"    - {p}" for p in orphans)
    else:
        lines.append("✓ No orphan tests — every *Tests.swift references ≥1 production symbol.")
    lines.append("")
    untested = result["untested_significant_symbols"]
    if untested:
        lines.append(
            f"⚠ UNTESTED SIGNIFICANT SYMBOLS ({len(untested)}) — "
            "logic-bearing types no test references:"
        )
        lines.extend(f"    - {u['symbol']}  ({u['file']})" for u in untested)
    else:
        lines.append("✓ Every significant production type is referenced by ≥1 test.")
    lines.append("")
    lines.append(f"Total advisory findings: {result['finding_count']}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Orphan-test + untested-symbol scanner (advisory).")
    ap.add_argument("--prod-dir", default="FitTracker", help="Production source dir (default: FitTracker)")
    ap.add_argument("--test-dir", default="FitTrackerTests", help="Test dir (default: FitTrackerTests)")
    ap.add_argument("--json", action="store_true", help="Emit JSON only")
    ap.add_argument("--strict", action="store_true", help="Exit 1 if any finding (default: advisory exit 0)")
    ap.add_argument("--output", help="Write JSON result to this path")
    args = ap.parse_args(argv)

    prod_dir = (REPO_ROOT / args.prod_dir).resolve()
    test_dir = (REPO_ROOT / args.test_dir).resolve()
    if not prod_dir.is_dir():
        print(f"error: prod dir not found: {prod_dir}", file=sys.stderr)
        return 2
    if not test_dir.is_dir():
        print(f"error: test dir not found: {test_dir}", file=sys.stderr)
        return 2

    result = scan(prod_dir, test_dir)

    if args.output:
        Path(args.output).write_text(json.dumps(result, indent=2) + "\n")

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(render(result))

    if args.strict and result["finding_count"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
