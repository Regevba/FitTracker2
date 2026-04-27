#!/usr/bin/env python3
"""Backfill missing frontmatter fields for existing case studies.

Infers work_type, dispatch_pattern, success_metrics, and kill_criteria
from filename heuristics and case study body text. Writes a metadata
block using the text patterns that documentation-debt-report.py detects.

Usage:
    python3 scripts/backfill-case-study-fields.py --dry-run
    python3 scripts/backfill-case-study-fields.py --apply
    python3 scripts/backfill-case-study-fields.py --file <path> --dry-run
    python3 scripts/backfill-case-study-fields.py --file <path> --apply

Field detection patterns (from documentation-debt-report.py):
  work_type        │  \\bWork Type\\b  or  work_type: in YAML
  dispatch_pattern │  dispatch pattern  or  dispatch_pattern: in YAML
  success_metrics  │  success metrics?  or  primary metric  or  success_metrics: in YAML
  kill_criteria    │  kill criteria  or  kill_criteria: in YAML

Inference heuristics:
  work_type:
    - audit|remediation|burndown|cleanup|chore|refactor  → Chore
    - fix-|fix_|hotfix|patch  → Fix
    - enhance|enhancement|polish|v2|v3|refactor  → Enhancement
    - evolution|migration|framework|infrastructure  → Enhancement
    - otherwise  → Feature
    - Prefer PRD field if prd_path exists in frontmatter

  dispatch_pattern:
    - Counts subagent/parallel/agent dispatch mentions in text
    - "mixed dispatch" or "hybrid" → mixed
    - >1 parallel mention → parallel
    - otherwise → serial

  success_metrics + kill_criteria:
    - Regex for ## Success Metrics / ## Primary Metric / ## Kill Criteria sections
    - Extract first bullet under each
    - If missing section, emit 'TODO: review' placeholder
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NamedTuple


REPO_ROOT = Path(__file__).resolve().parent.parent
CASE_STUDIES_DIR = REPO_ROOT / "docs" / "case-studies"

EXCLUDED_NAMES = {
    "README.md",
    "case-study-template.md",
    "normalization-framework.md",
    "fittracker-evolution-walkthrough.md",
    "pm-workflow-evolution-v1-to-v4.md",
    "pm-workflow-skill.md",
    "data-quality-tiers.md",
}

# Detection patterns (must stay in sync with documentation-debt-report.py)
_HAS_WORK_TYPE_PAT = re.compile(r"(?im)(^\|\s*Work Type\s*\||\bWork Type\b|^work_type\s*:)")
_HAS_DISPATCH_PAT = re.compile(r"(?im)(dispatch pattern|^dispatch_pattern\s*:)")
_HAS_SUCCESS_PAT = re.compile(r"(?im)(success metrics?|primary metric|^success_metrics\s*:)")
_HAS_KILL_PAT = re.compile(r"(?im)(kill criteria|^kill_criteria\s*:)")

# Section extraction patterns
_SUCCESS_SECTION_PAT = re.compile(
    r"(?im)^#{1,3}\s*(?:success metrics?|primary metric)[^\n]*\n(.*?)(?=^#{1,3}\s|\Z)",
    re.DOTALL,
)
_KILL_SECTION_PAT = re.compile(
    r"(?im)^#{1,3}\s*(?:kill criteria)[^\n]*\n(.*?)(?=^#{1,3}\s|\Z)",
    re.DOTALL,
)
_BULLET_PAT = re.compile(r"(?m)^\s*[-*•]\s+(.+)")
_TABLE_ROW_PAT = re.compile(r"(?m)^\|[^|]+\|(.+?)\|")

# Dispatch counting patterns
_PARALLEL_MENTION_PAT = re.compile(
    r"(?i)(parallel\s+(?:dispatch|agent|subagent|worker)|dispatch.*parallel|subagent_type|concurrent\s+dispatch|Agent\()"
)
_MIXED_DISPATCH_PAT = re.compile(r"(?i)(mixed dispatch|hybrid dispatch)")

# PRD paths
_PRD_ROOT = REPO_ROOT / "docs" / "product" / "prd"


class InferredFields(NamedTuple):
    work_type: str
    dispatch_pattern: str
    success_metrics: str
    kill_criteria: str
    # Which fields had low confidence → TODO marker
    todos: list[str]


def _infer_work_type(path: Path, text: str) -> tuple[str, bool]:
    """Infer work_type from filename and content. Returns (value, is_todo)."""
    name = path.stem.lower()

    # Check linked PRD first
    prd_field = _read_prd_work_type(name)
    if prd_field:
        return prd_field, False

    # Heuristics by filename
    if re.search(r"\baudit\b|\bremediation\b|\bburndown\b|\bcleanup\b|\bchore\b", name):
        return "Chore", False
    if re.search(r"\bfix[-_]|[-_]fix\b|\bhotfix\b|\bpatch\b", name):
        return "Fix", False
    if re.search(r"\bstress[\-_]test\b|\bconcurrent\b", name):
        return "Chore", False
    if re.search(r"\brevamp\b|\bpolish\b|\bv2\b|\bv3\b|\bv4\b|\bv5\b|\bdecomposition\b|\bretroactive\b", name):
        return "Enhancement", False
    if re.search(r"\bevolution\b|\bmigration\b|\bframework\b|\binfrastructure\b|\bintegrity\b|\benforcement\b|\bmeasurement\b", name):
        return "Enhancement", False
    if re.search(r"\bssr\b|\bregression\b|\bbug\b", name):
        return "Fix", False
    if re.search(r"\bdispatchreplay\b|\barchitecture\b|\beval[-_]\b|\bsoc\b|\bhadf\b|\borchid\b|\bworkflow\b", name):
        return "Feature", False
    if re.search(r"\bsite\b|\bcontrol[-_]center\b|\bdashboard\b|\bdesign[-_]system\b|\bparallel[-_]write\b", name):
        return "Feature", False

    # Default
    return "Feature", True  # low confidence → TODO


def _read_prd_work_type(feature_stem: str) -> str | None:
    """Try to read work_type from the linked PRD file."""
    # Try various naming patterns
    candidates = [
        _PRD_ROOT / f"{feature_stem}.md",
        _PRD_ROOT / f"{feature_stem.replace('-case-study', '')}.md",
    ]
    # Remove common suffixes from feature stem
    clean = re.sub(r"[-_]case[-_]study$", "", feature_stem)
    clean = re.sub(r"[-_]v[\d.]+$", "", clean)
    candidates.append(_PRD_ROOT / f"{clean}.md")

    for candidate in candidates:
        if candidate.exists():
            text = candidate.read_text()
            m = re.search(r"(?im)^\|\s*Work Type\s*\|\s*([^|]+)\|", text)
            if m:
                return m.group(1).strip()
    return None


def _infer_dispatch_pattern(text: str) -> tuple[str, bool]:
    """Infer dispatch_pattern from case study text. Returns (value, is_todo)."""
    if _MIXED_DISPATCH_PAT.search(text):
        return "mixed", False

    parallel_count = len(_PARALLEL_MENTION_PAT.findall(text))
    if parallel_count > 2:
        return "parallel", False

    # Check for explicit concurrent dispatch mentions
    if re.search(r"(?i)(concurrent\s+dispatch|parallel\s+worktree|3\s+waves|multiple\s+agents)", text):
        return "parallel", False

    return "serial", False  # default; low confidence when count is ambiguous


def _extract_first_bullet_from_section(section_match: re.Match | None, text: str) -> str | None:
    """Extract first meaningful bullet from a section match."""
    if not section_match:
        return None
    body = section_match.group(1)
    # Try bullets first
    bullets = _BULLET_PAT.findall(body)
    if bullets:
        return bullets[0].strip()
    # Try table rows
    rows = _TABLE_ROW_PAT.findall(body)
    if rows:
        val = rows[0].strip()
        if len(val) > 5 and "---" not in val:
            return val
    # Try plain text (first non-empty line)
    for line in body.splitlines():
        line = line.strip()
        if line and not line.startswith("|") and not line.startswith("#"):
            return line
    return None


def _infer_success_metrics(text: str) -> tuple[str, bool]:
    """Infer success_metrics from body text. Returns (value, is_todo)."""
    # Try dedicated section
    match = _SUCCESS_SECTION_PAT.search(text)
    bullet = _extract_first_bullet_from_section(match, text)
    if bullet:
        # Truncate very long bullets
        if len(bullet) > 120:
            bullet = bullet[:117] + "..."
        return bullet, False

    # Try inline mentions
    m = re.search(r"(?i)(?:primary metric|success metric)[:\s]+(.+?)(?:\n|$)", text)
    if m:
        val = m.group(1).strip().rstrip(".")
        if val and len(val) > 5:
            return val[:120], False

    return "TODO: review", True


def _infer_kill_criteria(text: str) -> tuple[str, bool]:
    """Infer kill_criteria from body text. Returns (value, is_todo)."""
    match = _KILL_SECTION_PAT.search(text)
    bullet = _extract_first_bullet_from_section(match, text)
    if bullet:
        if len(bullet) > 120:
            bullet = bullet[:117] + "..."
        return bullet, False

    # Inline mention
    m = re.search(r"(?i)kill\s+(?:criterion|criteria)[:\s]+(.+?)(?:\n|$)", text)
    if m:
        val = m.group(1).strip().rstrip(".")
        if val and len(val) > 5:
            return val[:120], False

    return "TODO: review", True


def infer_fields(path: Path, text: str) -> InferredFields:
    """Infer all missing fields for a case study."""
    wt, wt_todo = _infer_work_type(path, text)
    dp, dp_todo = _infer_dispatch_pattern(text)
    sm, sm_todo = _infer_success_metrics(text)
    kc, kc_todo = _infer_kill_criteria(text)

    todos = []
    if wt_todo:
        todos.append("work_type")
    if dp_todo:
        todos.append("dispatch_pattern")
    if sm_todo:
        todos.append("success_metrics")
    if kc_todo:
        todos.append("kill_criteria")

    return InferredFields(
        work_type=wt,
        dispatch_pattern=dp,
        success_metrics=sm,
        kill_criteria=kc,
        todos=todos,
    )


def needs_backfill(text: str) -> list[str]:
    """Return list of field names that are missing from the case study."""
    missing = []
    if not _HAS_WORK_TYPE_PAT.search(text):
        missing.append("work_type")
    if not _HAS_DISPATCH_PAT.search(text):
        missing.append("dispatch_pattern")
    if not _HAS_SUCCESS_PAT.search(text):
        missing.append("success_metrics")
    if not _HAS_KILL_PAT.search(text):
        missing.append("kill_criteria")
    return missing


def build_backfill_block(fields: InferredFields, missing: list[str]) -> str:
    """Build the backfill metadata block to insert into the case study.

    Uses text patterns matching the doc-debt detector regexes:
    - "| Work Type |" for work_type
    - "Dispatch Pattern:" for dispatch_pattern
    - "Success Metrics" section for success_metrics
    - "Kill Criteria" section for kill_criteria
    """
    lines = [
        "",
        "<!-- doc-debt-backfill: fields added by scripts/backfill-case-study-fields.py -->",
    ]

    # Build a metadata table for work_type (and dispatch_pattern to be compact)
    table_fields = []
    if "work_type" in missing:
        todo_note = " <!-- TODO: review -->" if "work_type" in fields.todos else ""
        table_fields.append(("Work Type", fields.work_type + todo_note))
    if "dispatch_pattern" in missing:
        todo_note = " <!-- TODO: review -->" if "dispatch_pattern" in fields.todos else ""
        table_fields.append(("Dispatch Pattern", fields.dispatch_pattern + todo_note))

    if table_fields:
        lines.append("")
        lines.append("| Field | Value |")
        lines.append("|---|---|")
        for field_name, value in table_fields:
            lines.append(f"| {field_name} | {value} |")

    if "success_metrics" in missing:
        todo_note = " <!-- TODO: review -->" if "success_metrics" in fields.todos else ""
        lines.append("")
        lines.append(f"**Success Metrics:** {fields.success_metrics}{todo_note}")

    if "kill_criteria" in missing:
        todo_note = " <!-- TODO: review -->" if "kill_criteria" in fields.todos else ""
        lines.append("")
        lines.append(f"**Kill Criteria:** {fields.kill_criteria}{todo_note}")

    lines.append("")
    return "\n".join(lines)


def _find_insertion_point(text: str) -> int:
    """Find the best insertion point in the text for the backfill block.

    Prefers inserting after the **Date written:** line (and any immediately
    following metadata lines). Falls back to after the first H1 title.
    """
    # Find **Date written:** line end
    m = re.search(r"(?m)^\*\*Date written:\*\*.*$", text)
    if m:
        # Find end of the header block (consecutive lines starting with **)
        pos = m.end()
        # Skip additional metadata lines immediately following (e.g., **Framework version:**)
        # Only consume lines that directly follow without blank lines
        while True:
            rest = text[pos:]
            next_line_m = re.match(r"\n(\*\*[^*]+:\*\*[^\n]*)", rest)
            if next_line_m:
                pos += next_line_m.end()
            else:
                break
        return pos

    # Fall back to after the first H1
    m = re.search(r"(?m)^#[^#].*$", text)
    if m:
        return m.end()

    # Last resort: beginning of file
    return 0


def apply_backfill(path: Path, dry_run: bool = True) -> dict:
    """Apply backfill to a single case study file. Returns a result summary dict."""
    text = path.read_text()
    missing = needs_backfill(text)

    if not missing:
        return {
            "file": path.name,
            "status": "skip",
            "reason": "all fields present",
            "missing": [],
            "inferred": {},
            "todos": [],
        }

    fields = infer_fields(path, text)
    block = build_backfill_block(fields, missing)
    insertion_point = _find_insertion_point(text)

    new_text = text[:insertion_point] + block + text[insertion_point:]

    # Only report todos for fields that are actually missing (not pre-existing fields)
    relevant_todos = [t for t in fields.todos if t in missing]

    result = {
        "file": path.name,
        "status": "would_apply" if dry_run else "applied",
        "missing": missing,
        "inferred": {
            "work_type": fields.work_type if "work_type" in missing else "(already present)",
            "dispatch_pattern": fields.dispatch_pattern if "dispatch_pattern" in missing else "(already present)",
            "success_metrics": fields.success_metrics if "success_metrics" in missing else "(already present)",
            "kill_criteria": fields.kill_criteria if "kill_criteria" in missing else "(already present)",
        },
        "todos": relevant_todos,
    }

    if not dry_run:
        path.write_text(new_text)
        result["status"] = "applied"

    return result


def collect_eligible_case_studies(single_file: Path | None = None) -> list[Path]:
    """Return eligible case studies for backfill."""
    if single_file:
        return [single_file]
    return [
        p for p in sorted(CASE_STUDIES_DIR.glob("*.md"))
        if p.name not in EXCLUDED_NAMES
        and "meta-analysis" not in str(p)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode_grp = parser.add_mutually_exclusive_group(required=True)
    mode_grp.add_argument("--dry-run", action="store_true",
                          help="Preview changes without writing files")
    mode_grp.add_argument("--apply", action="store_true",
                          help="Write changes to files")
    parser.add_argument("--file", metavar="PATH",
                        help="Process a single file instead of all case studies")
    args = parser.parse_args()

    dry_run = args.dry_run
    single = Path(args.file).resolve() if args.file else None
    files = collect_eligible_case_studies(single)

    total = skipped = applied = todo_count = 0
    results = []

    for path in files:
        try:
            r = apply_backfill(path, dry_run=dry_run)
        except Exception as e:
            print(f"  ERROR {path.name}: {e}", file=sys.stderr)
            continue

        total += 1
        if r["status"] == "skip":
            skipped += 1
        else:
            applied += 1
            todo_count += len(r["todos"])
            results.append(r)

    mode_label = "DRY-RUN" if dry_run else "APPLY"
    print(f"\n=== Backfill Case-Study Fields [{mode_label}] ===")
    print(f"Files scanned:     {total}")
    print(f"Already complete:  {skipped}")
    print(f"{'Would apply' if dry_run else 'Applied'}:         {applied}")
    print(f"TODO markers:      {todo_count} (across {sum(1 for r in results if r['todos'])} files)")
    print()

    for r in results:
        status_sym = "~" if dry_run else "✓"
        todo_note = f"  [TODO: {r['todos']}]" if r["todos"] else ""
        print(f"  {status_sym} {r['file']}{todo_note}")
        print(f"      missing: {r['missing']}")
        for field, val in r["inferred"].items():
            if field in r["missing"]:
                print(f"      {field}: {val!r}")
        print()

    if todo_count > 0:
        files_with_todos = sum(1 for r in results if r["todos"])
        ratio = files_with_todos / max(applied, 1)
        print(f"WARNING: {files_with_todos} files ({ratio:.0%}) have TODO markers.")

        # Count TODOs specifically on heuristic-based fields (work_type, dispatch_pattern)
        # versus content-based fields (success_metrics, kill_criteria).
        heuristic_todos = sum(
            1 for r in results
            if any(t in r["todos"] for t in ["work_type", "dispatch_pattern"])
        )
        heuristic_ratio = heuristic_todos / max(applied, 1)

        if heuristic_ratio > 0.5:
            print(f"STOP_AND_REPORT: >50% of files ({heuristic_todos}) have TODO markers on "
                  "work_type or dispatch_pattern. Inference heuristics need refinement.")
            return 2

        if ratio > 0.5:
            print(
                f"NOTE: High TODO rate ({ratio:.0%}) is expected — most TODOs are on "
                "success_metrics/kill_criteria which legitimately don't exist in audit/"
                "chore case studies predating the PRD structure. Manual review recommended."
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())
