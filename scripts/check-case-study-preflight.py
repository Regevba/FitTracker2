#!/usr/bin/env python3
"""
Pre-commit checks for case study .md files. Closes Class B → Class A for the
two case-study-related defenses that previously fired only on the 72h cycle.

Checks (added 2026-04-25 as part of v7.6 Mechanical Enforcement):

1. **BROKEN_PR_CITATION (write-time)** — staged case-study .md files containing
   `PR #NNN` or `/pull/NNN` citations must resolve via `gh pr view`. The same
   check runs every 72h via the integrity cycle; this is the write-time
   sibling. Skipped gracefully if `gh` is unavailable.

2. **CASE_STUDY_MISSING_TIER_TAGS (write-time)** — staged case-study .md files
   with `Date written:` on or after 2026-04-21 (the data-quality-tiers
   convention's introduction date) must contain at least one T1/T2/T3 tier
   tag. Forward-only; pre-convention case studies are exempt.

Exempt files:
- `case-study-template.md`, `README.md`, `data-quality-tiers.md`
- Anything under `docs/case-studies/meta-analysis/` (those discuss citations
  and tier labels rather than make them).

Usage:
    scripts/check-case-study-preflight.py                # validate all eligible case studies
    scripts/check-case-study-preflight.py <path>...      # validate specific files
    scripts/check-case-study-preflight.py --staged       # validate git-staged case study .md files

Exit codes:
    0  all validated files pass all checks
    1  one or more files violate a check (message on stderr)
    2  usage error or missing file

Bypass (emergency only): `git commit --no-verify`. The 72h cycle still
catches anything introduced via bypass.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CASE_STUDIES_DIR = REPO_ROOT / "docs" / "case-studies"

EXEMPT_NAMES = {
    "README.md",
    "case-study-template.md",
    "normalization-framework.md",
    "fittracker-evolution-walkthrough.md",
    "pm-workflow-evolution-v1-to-v4.md",
    "pm-workflow-skill.md",
    "data-quality-tiers.md",
}

# Data-quality-tiers convention shipped 2026-04-21 (Gemini audit Tier 2.3).
# Forward-only by policy: case studies dated before this date are exempt.
TIER_CONVENTION_DATE = "2026-04-21"

# Same regex shape as integrity-check.py (kept in sync intentionally).
_PR_CITATION_PAT = re.compile(
    r'(?:[Pp][Rr]\s*#?|github\.com/[^/\s]+/[^/\s]+/pull/)(\d+)'
)
_DATE_WRITTEN_PAT = re.compile(
    r"(?im)^\*\*Date written:\*\*\s*(\d{4}-\d{2}-\d{2})|^>\s*\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})"
)
_TIER_TAG_PAT = re.compile(r"\bT[123]\b[\s—:.\)\(]")


_PR_CACHE: set[int] | None = None
_PR_CACHE_LOADED: bool = False


def _load_pr_cache() -> set[int] | None:
    """Single `gh pr list` call, cached for the script's lifetime. Graceful
    degradation: returns None if gh is unavailable, and the BROKEN_PR_CITATION
    check is skipped rather than failing the hook."""
    global _PR_CACHE, _PR_CACHE_LOADED
    if _PR_CACHE_LOADED:
        return _PR_CACHE
    _PR_CACHE_LOADED = True
    try:
        out = subprocess.check_output(
            ["gh", "pr", "list", "--state", "all", "--limit", "500",
             "--json", "number"],
            text=True, stderr=subprocess.DEVNULL,
        )
        _PR_CACHE = {p["number"] for p in json.loads(out)}
    except (subprocess.CalledProcessError, FileNotFoundError,
            json.JSONDecodeError):
        _PR_CACHE = None
    return _PR_CACHE


def _is_exempt(path: Path) -> bool:
    """Return True if the file should be skipped entirely."""
    if path.name in EXEMPT_NAMES:
        return True
    try:
        rel = path.resolve().relative_to(CASE_STUDIES_DIR)
    except ValueError:
        return True  # Outside case-studies dir
    if "meta-analysis" in rel.parts:
        return True
    return False


def validate_file(path: Path) -> list[str]:
    """Return human-readable violation messages for one case study file."""
    errors: list[str] = []
    if not path.exists():
        errors.append(f"{path}: does not exist")
        return errors
    if _is_exempt(path):
        return errors
    try:
        text = path.read_text()
    except Exception as e:
        errors.append(f"{path}: cannot read ({e})")
        return errors

    # Check 1c: BROKEN_PR_CITATION at write-time
    cited = {int(m.group(1)) for m in _PR_CITATION_PAT.finditer(text)}
    if cited:
        pr_cache = _load_pr_cache()
        if pr_cache is not None:
            broken = sorted(n for n in cited if n not in pr_cache)
            for n in broken:
                errors.append(
                    f"{path}: cites PR #{n} which does not resolve on GitHub. "
                    f"Verify the number, fix the citation, or use issue-citation "
                    f"syntax (`issue #{n}`, `repo#{n}`) if it's an issue not a PR."
                )

    # Check 1d: CASE_STUDY_MISSING_TIER_TAGS at write-time
    date_match = _DATE_WRITTEN_PAT.search(text)
    if date_match:
        date_written = date_match.group(1) or date_match.group(2)
        if date_written and date_written >= TIER_CONVENTION_DATE:
            if not _TIER_TAG_PAT.search(text):
                errors.append(
                    f"{path}: dated {date_written} (>= {TIER_CONVENTION_DATE}) "
                    f"but contains no T1/T2/T3 tier tag. Add at least one tier "
                    f"label (T1=Instrumented, T2=Declared, T3=Narrative) per "
                    f"`docs/case-studies/data-quality-tiers.md`. Forward-only "
                    f"policy: this rule applies to case studies written on or "
                    f"after {TIER_CONVENTION_DATE}."
                )
    return errors


def collect_staged_case_studies() -> list[Path]:
    """Return list of staged case-study .md paths under docs/case-studies/."""
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    paths = []
    for line in out.splitlines():
        if not line:
            continue
        if line.startswith("docs/case-studies/") and line.endswith(".md"):
            p = REPO_ROOT / line
            if p.exists():
                paths.append(p)
    return paths


def collect_all_case_studies() -> list[Path]:
    if not CASE_STUDIES_DIR.exists():
        return []
    return sorted(p for p in CASE_STUDIES_DIR.rglob("*.md"))


def main() -> int:
    args = sys.argv[1:]
    if args == ["--staged"]:
        files = collect_staged_case_studies()
        mode = "staged"
    elif not args:
        files = collect_all_case_studies()
        mode = "all"
    else:
        files = [Path(a).resolve() for a in args]
        mode = "explicit"

    # Filter exempt files for cleaner output.
    eligible = [f for f in files if not _is_exempt(f)]

    if not eligible:
        print(f"No eligible case study .md files to validate (mode={mode}).")
        return 0

    all_errors: list[str] = []
    for p in eligible:
        all_errors.extend(validate_file(p))

    if all_errors:
        print(f"✗ CASE_STUDY: {len(all_errors)} violation(s) "
              f"(mode={mode}, files scanned={len(eligible)})",
              file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    pr_note = ""
    if _PR_CACHE is not None:
        pr_note = f" (PR-resolution: {len(_PR_CACHE)} known PRs)"
    elif _PR_CACHE_LOADED:
        pr_note = " (PR-resolution skipped — gh unavailable)"
    print(f"✓ All {len(eligible)} case study files pass all checks "
          f"(mode={mode}){pr_note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
