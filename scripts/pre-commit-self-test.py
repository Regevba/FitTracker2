#!/usr/bin/env python3
"""Pre-commit hook header self-audit (v7.8 Mechanism D).

Asserts that every gate the `.githooks/pre-commit` HEADER claims to
enforce is actually IMPLEMENTED in `scripts/check-state-schema.py` (or
`scripts/check-case-study-preflight.py`). Catches header-vs-code drift
silently introduced when a new gate ships without its header line, OR
when a header line is left behind after a gate is removed.

Per docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md
§4.4. Pattern: gitleaks self-test, pre-commit.com `repo-rev` validation.

Detection:
  - Declared gates: extracted from the pre-commit hook header via regex
    on `^#\\s*-?\\s*([A-Z_]+)`. Skips lines that don't look like a gate
    name (uppercase + underscore + ≥6 chars).
  - Implemented gates: extracted from `"code": "NAME"` literals AND
    `errors.append(f"...{path}: uses legacy ...")` patterns in the two
    schema-check scripts.

Exit codes:
  0  declared == implemented (or differences are explainable: e.g.
     check-case-study-preflight.py owns BROKEN_PR_CITATION which the
     hook header lists under v7.6).
  1  drift detected; report on stdout.

This is a development-time check. The hook itself does not invoke this
script — it would slow every commit. Instead, `make pre-commit-self-test`
runs it manually + `make verify-local` runs it as part of the verify
pass + the per-PR pm-framework/pr-integrity check runs it.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK_FILE = REPO_ROOT / ".githooks" / "pre-commit"
SCHEMA_CHECKER = REPO_ROOT / "scripts" / "check-state-schema.py"
CASE_STUDY_CHECKER = REPO_ROOT / "scripts" / "check-case-study-preflight.py"

# Gates listed in the header but implemented elsewhere — accepted as
# documentation pointers. Add entries here if a gate is intentionally
# referenced in the hook header but lives in a non-checked file
# (e.g. a tool the hook invokes indirectly).
ACCEPTED_HEADER_REFERENCES = {
    # Cycle-time-only gates that the header references for context but
    # don't fire in pre-commit (they fire in scripts/integrity-check.py).
    "PHASE_LIE", "TASK_LIE", "NO_CS_LINK", "V2_FILE_MISSING",
    "PARTIAL_SHIP_TERMINAL", "NO_STATE", "INVALID_JSON", "NO_PHASE",
    "TIER_TAG_LIKELY_INCORRECT", "CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE",
    "GATE_COVERAGE_ZERO",
}

GATE_NAME_RE = re.compile(r"^#\s*-?\s*\*?\*?\s*`?([A-Z][A-Z0-9_]{4,})`?\b")
CODE_LITERAL_RE = re.compile(r'"code":\s*"([A-Z_][A-Z0-9_]{4,})"')


def extract_declared_gates(text: str) -> set[str]:
    """Pull gate names from comment lines in the hook header.

    The hook header is the contiguous block of comment lines (and blank
    lines between them) at the top of the file. We stop at the first
    non-comment, non-empty line — typically `set -euo pipefail`.
    """
    gates: set[str] = set()
    for line in text.split("\n"):
        if not line.startswith("#"):
            if line.strip():
                break
            continue
        m = GATE_NAME_RE.match(line)
        if m:
            name = m.group(1)
            # Filter out non-gate words that match the regex shape.
            if name not in {"IMPORTANT", "WARNING", "TODO", "FIXME", "NOTE"}:
                gates.add(name)
    return gates


def extract_implemented_gates(text: str) -> set[str]:
    """Pull gate codes from `"code": "NAME"` literals in checker source."""
    return set(CODE_LITERAL_RE.findall(text))


def extract_inline_drift_codes(text: str) -> set[str]:
    """Detect gates implemented as inline error messages (no `"code": "..."`).

    The `validate_file` function in check-state-schema.py uses inline
    error messages for SCHEMA_DRIFT (legacy `phase` key) and
    SCHEMA_DRIFT (legacy `created` key) — these don't appear as
    `"code": ...` literals but the header references them.
    """
    inline_codes: set[str] = set()
    if "uses legacy `phase` key" in text or 'uses legacy `phase`' in text:
        inline_codes.add("SCHEMA_DRIFT")
    if "uses legacy `created` key" in text or "uses legacy `created`" in text:
        inline_codes.add("SCHEMA_DRIFT")  # same code; v7.7 fix layer
    if "FRAMEWORK_VERSION_FORMAT" in text or "is not in canonical" in text:
        inline_codes.add("FRAMEWORK_VERSION_FORMAT")
    if "PR_NUMBER_UNRESOLVED" in text or "does not resolve on GitHub" in text:
        inline_codes.add("PR_NUMBER_UNRESOLVED")
    if "PHASE_TRANSITION_NO_LOG" in text or "but `.claude/logs/" in text:
        inline_codes.add("PHASE_TRANSITION_NO_LOG")
    if "PHASE_TRANSITION_NO_TIMING" in text or "started_at` is missing" in text:
        inline_codes.add("PHASE_TRANSITION_NO_TIMING")
    # Case-study preflight gates (no `"code": "..."` literals — emitted as
    # plain errors.append(f"...") with descriptive messages).
    if "BROKEN_PR_CITATION" in text or "cites PR #" in text and "does not resolve" in text:
        inline_codes.add("BROKEN_PR_CITATION")
    if "CASE_STUDY_MISSING_TIER_TAGS" in text or "no T1/T2/T3 tier tag" in text:
        inline_codes.add("CASE_STUDY_MISSING_TIER_TAGS")
    return inline_codes


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--quiet", action="store_true", help="suppress success message")
    args = ap.parse_args()

    if not HOOK_FILE.exists():
        print(f"ERROR: hook file missing: {HOOK_FILE}", file=sys.stderr)
        return 1
    if not SCHEMA_CHECKER.exists():
        print(f"ERROR: schema checker missing: {SCHEMA_CHECKER}", file=sys.stderr)
        return 1

    declared = extract_declared_gates(HOOK_FILE.read_text())

    schema_text = SCHEMA_CHECKER.read_text()
    case_study_text = CASE_STUDY_CHECKER.read_text() if CASE_STUDY_CHECKER.exists() else ""

    implemented = (
        extract_implemented_gates(schema_text)
        | extract_implemented_gates(case_study_text)
        | extract_inline_drift_codes(schema_text)
        | extract_inline_drift_codes(case_study_text)
    )

    # Declared but not implemented (header drift on the "extra claim" side).
    missing = declared - implemented - ACCEPTED_HEADER_REFERENCES
    # Implemented but not declared (header drift on the "missing claim" side).
    undeclared = implemented - declared - ACCEPTED_HEADER_REFERENCES

    drift = bool(missing or undeclared)

    if drift:
        print("✗ pre-commit-self-test: header drift detected", file=sys.stderr)
        if missing:
            print(f"  Declared in hook header but NOT implemented:", file=sys.stderr)
            for g in sorted(missing):
                print(f"    - {g}", file=sys.stderr)
        if undeclared:
            print(f"  Implemented but NOT declared in hook header:", file=sys.stderr)
            for g in sorted(undeclared):
                print(f"    - {g}", file=sys.stderr)
        print("", file=sys.stderr)
        print(
            f"  Fix: edit {HOOK_FILE.relative_to(REPO_ROOT)} "
            f"to declare/remove the listed gates.",
            file=sys.stderr,
        )
        return 1

    if not args.quiet:
        print(
            f"✓ pre-commit-self-test: {len(declared)} declared gates "
            f"all implemented + {len(implemented)} implemented gates all "
            f"declared (or accepted-reference)."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
