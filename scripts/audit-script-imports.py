#!/usr/bin/env python3
"""
audit-script-imports.py — R23 from 2026-05-19 dev-env audit.

Surveys every Python file in scripts/ for third-party imports (i.e.
not stdlib + not local module). Emits a report categorizing scripts as:

  CORE (stdlib + local only)  — airgapped-operation safe; no vendoring needed
  RESEARCH (third-party)      — needs a venv / requirements.txt; cannot run
                                offline-airgapped without pre-prepared deps

Use case: decide whether scripts/ deserves a `vendor/` directory or
whether we just ensure dependencies are documented + installable. R23
recommended this be a survey, not a code change.

Read-only. Emits report to stdout.

Linear: FIT-189
Plan: docs/research/2026-05-19-dev-env-audit-stability-and-scale.md (R23)
"""
from __future__ import annotations

import ast
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
LOCAL_MODULES = {"flock_writer", "gate_coverage"}  # local helpers in scripts/


def scan_imports(path: Path) -> set[str]:
    """Return the set of top-level module names imported by path."""
    try:
        tree = ast.parse(path.read_text())
    except (SyntaxError, UnicodeDecodeError):
        return set()
    out: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                out.add(alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom) and node.module:
            out.add(node.module.split(".")[0])
    return out


def main() -> int:
    stdlib = set(sys.stdlib_module_names)
    files = sorted(SCRIPTS_DIR.glob("*.py"))

    core: list[tuple[Path, set[str]]] = []
    research: list[tuple[Path, set[str]]] = []

    for path in files:
        imports = scan_imports(path)
        third_party = imports - stdlib - LOCAL_MODULES - {"__future__"}
        if third_party:
            research.append((path, third_party))
        else:
            core.append((path, imports))

    print(f"=== scripts/ third-party import audit ({len(files)} .py files) ===")
    print()
    print(f"CORE (stdlib + local only)      : {len(core)} files")
    print(f"RESEARCH (third-party imports)  : {len(research)} files")
    print()
    print("--- CORE scripts (airgapped-operation safe) ---")
    for path, _ in core:
        print(f"  ✓ {path.name}")
    print()
    print("--- RESEARCH scripts (need venv / deps pre-installed) ---")
    if not research:
        print("  (none)")
    for path, third_party in research:
        print(f"  · {path.name}")
        for dep in sorted(third_party):
            print(f"      - {dep}")
    print()
    if research:
        all_deps = sorted({d for _, ds in research for d in ds})
        print(f"Aggregate third-party deps: {len(all_deps)}")
        print(f"  {', '.join(all_deps)}")
        print()
    print("Recommendation: keep stdlib-only for core operational scripts")
    print("(all R1–R20 scripts, daily-checkpoint, integrity-check, preflight,")
    print("etc). Research scripts continue to use their own venv (typically")
    print("ai-engine/.venv or .build/ai-venv). No `vendor/` directory needed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
