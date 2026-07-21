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

3. **CASE_STUDY_MISSING_FIELDS (write-time)** — staged case-study .md files
   using YAML frontmatter and dated on or after 2026-04-28 must have
   work_type, success_metrics, kill_criteria, and dispatch_pattern fields.
   Forward-only; pre-convention case studies are exempt. Only applies to
   files with YAML frontmatter (the new standard for post-v7.7 case studies).

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
import os
import re
import subprocess
import sys
from pathlib import Path


# `REPO_ROOT_OVERRIDE` env var redirects all repo-relative path resolution
# to a different root — required by the F16 try-repo harness. Production
# never sets this; fallback is canonical `<file>/../..`.
# See .claude/features/f16-try-repo-harness/prd.md §3.5 Q6.
_REPO_ROOT_OVERRIDE = os.environ.get("REPO_ROOT_OVERRIDE")
if _REPO_ROOT_OVERRIDE:
    REPO_ROOT = Path(_REPO_ROOT_OVERRIDE).resolve()
else:
    REPO_ROOT = Path(__file__).resolve().parent.parent
CASE_STUDIES_DIR = REPO_ROOT / "docs" / "case-studies"

# Mechanism A (v7.8 §4.1): per-gate coverage tracking. This is the SECOND
# pre-commit gate host (distinct from check-state-schema.py); its lone gate
# CASE_STUDY_MISSING_FIELDS was the last live gate not emitting coverage — so
# it was invisible to the F17 gate-last-fired index + GATE_COVERAGE_ZERO.
# Instrumented 2026-07-21 to close that telemetry blind spot.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_coverage import GateCoverage  # noqa: E402

GATE_COVERAGE_LEDGER = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"

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

# CASE_STUDY_MISSING_FIELDS cutoff: case studies dated >= this date must carry
# all four required frontmatter fields. Forward-only rule introduced v7.7.
FIELDS_CUTOFF_DATE = "2026-04-28"
REQUIRED_FRONTMATTER_FIELDS = ["work_type", "success_metrics", "kill_criteria", "dispatch_pattern"]

# Same regex shape as integrity-check.py (kept in sync intentionally).
# v7.8.3 D-3: updated to 3-alternation form for cross-repo cite routing.
#
# Groups:
#   group(1)        — FT2 default form:       PR #N  or  PR#N
#   group(2)+3      — cross-repo short form:  [fitme-story#42]  (brackets required
#                     to avoid false positives on "PRs #96", "issue #140", etc.)
#   group(4)+5+6    — URL form:               github.com/owner/repo/pull/N
_PR_CITATION_PAT = re.compile(
    r"(?:[Pp][Rr]\s*#(\d+))"                              # group 1: FT2 default
    r"|(?:\[([\w-]+)\s*#(\d+)\])(?!\()"                   # groups 2+3: cross-repo short (brackets, NOT markdown link)
    r"|(?:github\.com/([\w-]+)/([\w-]+)/pull/(\d+))"     # groups 4+5+6: URL form
)

# Whitelist mapping repo short names → full "owner/repo" identifiers.
# Used by resolve_pr_cite() to route cross-repo short-form cites.
REPO_MAP: dict[str, str] = {
    "fitme-story": "Regevba/fitme-story",
    "FitTracker2": "Regevba/FitTracker2",
    "ft2": "Regevba/FitTracker2",
}
_DATE_WRITTEN_PAT = re.compile(
    r"(?im)^\*\*Date written:\*\*\s*(\d{4}-\d{2}-\d{2})|^>\s*\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})"
)
_TIER_TAG_PAT = re.compile(r"\bT[123]\b[\s—:.\)\(]")
_YAML_FM_PAT = re.compile(r"^---\n(.*?\n)---\n", re.DOTALL)


def parse_frontmatter(path: Path) -> dict | None:
    """Parse YAML frontmatter from a .md file.

    Returns a dict of frontmatter keys/values if the file starts with ---,
    or None if it has no YAML frontmatter. Uses a simple key-value parser
    that handles:
      - scalar: ``key: value``
      - null: ``key:`` (returns empty string)
      - list: subsequent lines starting with ``  - item``
      - nested scalar: ``key:\n  sub: value`` (returns dict)

    This avoids a PyYAML dependency while handling the frontmatter shapes
    used in this repo's case studies.
    """
    try:
        text = path.read_text()
    except Exception:
        return None

    m = _YAML_FM_PAT.match(text)
    if not m:
        return None

    fm_text = m.group(1)
    result: dict = {}
    current_key: str | None = None
    current_list: list | None = None
    current_sub: dict | None = None

    for line in fm_text.splitlines():
        # Top-level key: value
        top_kv = re.match(r'^(\w[\w_-]*):\s*(.*)', line)
        if top_kv:
            if current_key and current_list is not None:
                result[current_key] = current_list
            elif current_key and current_sub is not None:
                result[current_key] = current_sub
            current_key = top_kv.group(1)
            value = top_kv.group(2).strip()
            if value:
                result[current_key] = value
                current_list = None
                current_sub = None
            else:
                # Could be a list or nested dict — will be decided by next lines
                result[current_key] = None
                current_list = None
                current_sub = None
        elif current_key and re.match(r'^\s+-\s+(.*)', line):
            # List item
            item = re.match(r'^\s+-\s+(.*)', line).group(1).strip()
            if current_list is None:
                current_list = []
                result[current_key] = current_list
            current_list.append(item)
        elif current_key and re.match(r'^\s+(\w[\w_-]*):\s*(.*)', line):
            # Nested key
            sub_m = re.match(r'^\s+(\w[\w_-]*):\s*(.*)', line)
            if current_sub is None:
                current_sub = {}
                result[current_key] = current_sub
            current_sub[sub_m.group(1)] = sub_m.group(2).strip()

    return result


def check_case_study_missing_fields(
    path: Path, *, coverage: "GateCoverage | None" = None
) -> list[dict]:
    """Reject case studies using YAML frontmatter dated >= 2026-04-28 that
    are missing required frontmatter fields.

    Returns a list of finding dicts (empty list = no findings / pass).
    Only applies to files with YAML frontmatter; Markdown-body-only case
    studies (pre-v7.7 format) are exempt from this check.

    Code: CASE_STUDY_MISSING_FIELDS
    """
    GATE = "CASE_STUDY_MISSING_FIELDS"
    if coverage is not None:
        coverage.candidate(GATE)

    fm = parse_frontmatter(path)
    if fm is None:
        # No YAML frontmatter — exempt from this check
        if coverage is not None:
            coverage.skip(GATE, "no_frontmatter")
        return []

    date_written = str(fm.get("date_written", "")).strip()
    if not date_written or date_written < FIELDS_CUTOFF_DATE:
        if coverage is not None:
            coverage.skip(GATE, "pre_cutoff")
        return []  # Forward-only: pre-cutoff files are exempt

    if coverage is not None:
        coverage.checked(GATE)
    missing = [f for f in REQUIRED_FRONTMATTER_FIELDS if f not in fm or fm[f] is None]
    if not missing:
        return []

    return [{
        "code": "CASE_STUDY_MISSING_FIELDS",
        "file": str(path),
        "message": (
            f"Case study dated {date_written} (>= {FIELDS_CUTOFF_DATE}) missing "
            f"required frontmatter fields: {missing}. "
            f"Add work_type (Feature/Enhancement/Fix/Chore), success_metrics, "
            f"kill_criteria, and dispatch_pattern (serial/parallel/mixed)."
        ),
        "severity": "failure",
    }]


_PR_CACHE: dict | None = None
_PR_CACHE_LOADED: bool = False


def _load_pr_cache() -> dict | None:
    """Load multi-repo cached PR data; refresh via refresh-pr-cache.py if stale.

    v7.8.3 D-3 morph: was set[int] | None (FT2-only); now returns the
    multi-repo dict shape matching .cache/gh-pr-cache.json:
      {"schema_version": 1, "last_refreshed_at": "...",
       "repos": {"Regevba/FitTracker2": {open,merged,closed}, ...}}

    Returns None if gh is unavailable AND no stale cache exists — caller
    skips the BROKEN_PR_CITATION check gracefully (never block a commit on
    missing network access).
    """
    global _PR_CACHE, _PR_CACHE_LOADED
    if _PR_CACHE_LOADED:
        return _PR_CACHE
    _PR_CACHE_LOADED = True

    cache_file = REPO_ROOT / ".cache" / "gh-pr-cache.json"
    if not cache_file.exists():
        # Try to refresh via the Task 1.1 refresh script.
        refresh_script = Path(__file__).parent / "refresh-pr-cache.py"
        if refresh_script.exists():
            try:
                subprocess.run(
                    [sys.executable, str(refresh_script)],
                    check=False, timeout=60,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                )
            except Exception:
                pass

    if not cache_file.exists():
        _PR_CACHE = None
        return _PR_CACHE

    try:
        _PR_CACHE = json.loads(cache_file.read_text())
    except Exception as e:
        print(f"WARN: PR cache load failed: {e}", file=sys.stderr)
        _PR_CACHE = None
    return _PR_CACHE


def resolve_pr_cite(match: re.Match, cache: dict | None) -> str | None:
    """Resolve a single _PR_CITATION_PAT match against the multi-repo PR cache.

    Returns None if the cite is valid (PR found in cache).
    Returns a human-readable error string if the cite is broken or unresolvable.
    Returns None when cache is None (gh unavailable — caller skips gracefully).

    Routing logic:
      group(1)    → FT2 default       → repo "Regevba/FitTracker2"
      group(2+3)  → cross-repo short  → REPO_MAP lookup → full repo name
      group(4+6)  → URL form          → "{group4}/{group5}" as full repo name
    """
    if cache is None:
        return None  # gh unavailable; caller already noted this, skip gracefully

    if match.group(1):
        repo = "Regevba/FitTracker2"
        pr_num = int(match.group(1))
    elif match.group(2):
        repo_short = match.group(2)
        repo = REPO_MAP.get(repo_short)
        if repo is None:
            return (
                f"BROKEN_PR_CITATION: unknown repo short name '{repo_short}' — "
                f"valid names: {sorted(REPO_MAP.keys())}. "
                f"Add to REPO_MAP in check-case-study-preflight.py if intentional."
            )
        pr_num = int(match.group(3))
    elif match.group(4):
        repo = f"{match.group(4)}/{match.group(5)}"
        pr_num = int(match.group(6))
    else:
        return None  # no group matched — regex logic error; skip silently

    repos = cache.get("repos", {})
    if repo not in repos:
        return (
            f"BROKEN_PR_CITATION: no cache entry for repo '{repo}'. "
            f"Run scripts/refresh-pr-cache.py to rebuild, or add repo to REPO_MAP."
        )

    repo_cache = repos[repo]
    all_prs = (
        repo_cache.get("open", [])
        + repo_cache.get("merged", [])
        + repo_cache.get("closed", [])
    )
    if not any(pr["number"] == pr_num for pr in all_prs):
        refreshed_at = cache.get("last_refreshed_at", "unknown")
        return (
            f"BROKEN_PR_CITATION: PR #{pr_num} not found in {repo} "
            f"(cache last refreshed {refreshed_at}). "
            f"Verify the number or run scripts/refresh-pr-cache.py to refresh."
        )

    return None


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


def validate_file(path: Path, *, coverage: "GateCoverage | None" = None) -> list[str]:
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

    # Check 1c: BROKEN_PR_CITATION at write-time (v7.8.3 D-3: multi-repo routing)
    pr_cache = _load_pr_cache()
    for m in _PR_CITATION_PAT.finditer(text):
        finding = resolve_pr_cite(m, pr_cache)
        if finding is not None:
            errors.append(f"{path}: {finding}")

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

    # Check 1e: CASE_STUDY_MISSING_FIELDS at write-time (v7.7, forward-only >= 2026-04-28)
    for finding in check_case_study_missing_fields(path, coverage=coverage):
        errors.append(
            f"{path}: [{finding['code']}] {finding['message']}"
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

    coverage = GateCoverage(mode=mode)
    all_errors: list[str] = []
    for p in eligible:
        all_errors.extend(validate_file(p, coverage=coverage))

    # Mechanism A: flush per-gate coverage so CASE_STUDY_MISSING_FIELDS is
    # visible to the F17 gate-last-fired index + GATE_COVERAGE_ZERO (closes the
    # 2026-07-21 telemetry blind spot). Fires on both success and failure paths
    # below. Tests opt out via GATE_COVERAGE_LEDGER_DISABLED=1. Fail-soft on IO.
    if os.environ.get("GATE_COVERAGE_LEDGER_DISABLED") != "1":
        try:
            coverage.write_jsonl(GATE_COVERAGE_LEDGER)
        except OSError:
            pass

    if all_errors:
        print(f"✗ CASE_STUDY: {len(all_errors)} violation(s) "
              f"(mode={mode}, files scanned={len(eligible)})",
              file=sys.stderr)
        for err in all_errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    pr_note = ""
    if _PR_CACHE is not None:
        # Count total PRs across all repos in the multi-repo cache.
        total_prs = sum(
            len(r.get("open", [])) + len(r.get("merged", [])) + len(r.get("closed", []))
            for r in _PR_CACHE.get("repos", {}).values()
        )
        repos_str = ", ".join(_PR_CACHE.get("repos", {}).keys())
        pr_note = f" (PR-resolution: {total_prs} PRs across [{repos_str}])"
    elif _PR_CACHE_LOADED:
        pr_note = " (PR-resolution skipped — gh unavailable)"
    print(f"✓ All {len(eligible)} case study files pass all checks "
          f"(mode={mode}){pr_note}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
