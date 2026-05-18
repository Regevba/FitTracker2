#!/usr/bin/env python3
"""Lint the two audit prompts for placeholders + required sections.

Usage:
    python3 scripts/audit/check_prompts.py
    (or: make audit-prompts-self-check)
"""
from __future__ import annotations
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent.parent

PLACEHOLDER_PATTERNS = [r"\bTODO\b", r"\bFIXME\b", r"<placeholder>"]
# Note: "TBD" appears legitimately in 01-extraction-prompt.md for Audit #4 scope.
# Suppress TBD detection there; flag it elsewhere.

EXTRACTION_REQUIRED_SECTIONS = ["How to run", "Profile selection table"]
AUDITOR_REQUIRED_SECTIONS = [
    "Hard constraints",
    "Phase 1",
    "Phase 2",
    "Phase 3",
    "Refusal template",
]


@dataclass
class CheckResult:
    passed: bool
    failures: list[str] = field(default_factory=list)


def _check_placeholders(content: str, path: str, allow_tbd: bool = False) -> list[str]:
    failures = []
    patterns = list(PLACEHOLDER_PATTERNS)
    if not allow_tbd:
        patterns.append(r"\bTBD\b")
    for pattern in patterns:
        if re.search(pattern, content):
            failures.append(f"{path}: contains forbidden token matching /{pattern}/")
    return failures


def _check_sections(content: str, required: list[str], path: str) -> list[str]:
    failures = []
    for section in required:
        if section not in content:
            failures.append(f"{path}: missing required section '{section}'")
    return failures


def check_prompts(repo_root: Path = REPO_ROOT) -> CheckResult:
    prompts_dir = repo_root / "docs" / "audits" / "prompts"
    extraction = prompts_dir / "01-extraction-prompt.md"
    auditor = prompts_dir / "02-auditor-prompt.md"

    failures: list[str] = []
    if not extraction.exists():
        failures.append(f"missing file: {extraction}")
    if not auditor.exists():
        failures.append(f"missing file: {auditor}")
    if failures:
        return CheckResult(passed=False, failures=failures)

    extraction_text = extraction.read_text()
    auditor_text = auditor.read_text()

    failures.extend(_check_placeholders(extraction_text, str(extraction), allow_tbd=True))
    failures.extend(_check_placeholders(auditor_text, str(auditor), allow_tbd=False))
    failures.extend(_check_sections(extraction_text, EXTRACTION_REQUIRED_SECTIONS, str(extraction)))
    failures.extend(_check_sections(auditor_text, AUDITOR_REQUIRED_SECTIONS, str(auditor)))

    return CheckResult(passed=not failures, failures=failures)


def main() -> int:
    result = check_prompts()
    if result.passed:
        print("OK — audit prompts pass self-check.")
        return 0
    print("FAIL — audit prompts have issues:")
    for f in result.failures:
        print(f"  - {f}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
