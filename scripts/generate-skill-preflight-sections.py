#!/usr/bin/env python3
"""
Regenerate the pattern-preflight block inside each skill's SKILL.md
(v7.9.1 pattern↔skill overlay).

Each of the 12 `.claude/skills/<skill>/SKILL.md` files has an
"Observed Patterns" preflight section. This script replaces that section's
BODY (everything between the section heading and the next `## ` heading) with
a deterministically-generated block delimited by:

    <!-- BEGIN pattern-preflight (generated) -->
    ...
    <!-- END pattern-preflight -->

The generated body carries:
  - corrected catalog counts (23 gate + 28 workflow = 51) — fixes the stale
    "9 workflow patterns" text some SKILL.md files still carry
  - a table of THIS skill's mapped patterns (id | title | blocker | remediation)
  - the activation line pointing at `make skill-preflight SKILL=<skill>`

The section HEADING line is left untouched (so matching is stable across runs).
Running twice produces NO diff (idempotent).

Usage
-----
  python3 scripts/generate-skill-preflight-sections.py            # write
  python3 scripts/generate-skill-preflight-sections.py --check    # dry-run, exit 1 if any file would change
  make gen-skill-preflight
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MAP_PATH = REPO_ROOT / ".claude" / "shared" / "pattern-skill-map.json"
SKILLS_DIR = REPO_ROOT / ".claude" / "skills"

SKILLS = (
    "pm-workflow", "dev", "qa", "design", "ops", "release",
    "marketing", "analytics", "cx", "research", "ux", "brainstorm-pm",
)

BEGIN = "<!-- BEGIN pattern-preflight (generated) -->"
END = "<!-- END pattern-preflight -->"


def pattern_sort_key(pid: str) -> tuple[int, int]:
    """Sort gates #1..#23 first, then workflow W1..W28."""
    if pid.startswith("#"):
        return (0, int(pid[1:]))
    return (1, int(pid[1:]))


def build_block(skill: str, patterns: list[dict]) -> str:
    mine = sorted([p for p in patterns if skill in p["skills"]],
                  key=lambda p: pattern_sort_key(p["id"]))
    n_mech = sum(1 for p in mine if p["detector"] != "manual")

    lines = [BEGIN]
    lines.append(
        "The [pattern↔skill map](../../shared/pattern-skill-map.json) tracks "
        "**51 work-blocking patterns** (23 gate-firing patterns + 28 workflow "
        "patterns) drawn from the [Observed Patterns Catalog]"
        "(../../integrity/observed-patterns.md) (`make observed-patterns`). The "
        f"patterns below are the ones mapped to `/{skill}` work — probe the "
        "mechanized ones, checklist the rest:"
    )
    lines.append("")
    lines.append("| ID | Pattern | Blocker | Remediation |")
    lines.append("|---|---|---|---|")
    for p in mine:
        blk = "yes" if p["blocker"] else "no"
        det = "" if p["detector"] == "manual" else " *(probed)*"
        title = p["title"].replace("|", "\\|")
        rem = p["remediation"].replace("|", "\\|")
        lines.append(f"| `{p['id']}` | {title}{det} | {blk} | {rem} |")
    lines.append("")
    lines.append(
        f"At activation run `make skill-preflight SKILL={skill}` — probes the "
        f"{n_mech} mechanized blockers for this work type; clear any before proceeding."
    )
    lines.append("")
    lines.append(
        "**Mandatory** (CLAUDE.md §v7.8.5): any novel pattern surfaced this "
        "session MUST be appended to [`observed-patterns.md`]"
        "(../../integrity/observed-patterns.md) before the feature closes — "
        "then re-run `make gen-skill-preflight`."
    )
    lines.append(END)
    return "\n".join(lines)


def find_section_bounds(md_lines: list[str]) -> tuple[int, int] | None:
    """Return (heading_idx, next_heading_idx) for the Observed-Patterns section."""
    heading = None
    for i, line in enumerate(md_lines):
        if line.startswith("## ") and "observed pattern" in line.lower():
            heading = i
            break
    if heading is None:
        return None
    nxt = len(md_lines)
    for j in range(heading + 1, len(md_lines)):
        if md_lines[j].startswith("## "):
            nxt = j
            break
    return heading, nxt


def regen_file(path: Path, skill: str, patterns: list[dict]) -> str | None:
    """Return new file content (or None if no section found)."""
    text = path.read_text()
    md_lines = text.split("\n")
    bounds = find_section_bounds(md_lines)
    if bounds is None:
        return None
    heading, nxt = bounds
    block = build_block(skill, patterns)

    # Rebuild: heading line, blank, block, blank, then the next-heading onward.
    new_lines = md_lines[: heading + 1] + ["", *block.split("\n"), ""] + md_lines[nxt:]
    return "\n".join(new_lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="dry-run: exit 1 if any SKILL.md would change")
    args = ap.parse_args()

    patterns = json.loads(MAP_PATH.read_text())
    changed, missing = [], []

    for skill in SKILLS:
        md = SKILLS_DIR / skill / "SKILL.md"
        if not md.exists():
            missing.append(skill)
            continue
        new_content = regen_file(md, skill, patterns)
        if new_content is None:
            missing.append(f"{skill} (no Observed-Patterns section)")
            continue
        if new_content != md.read_text():
            changed.append(skill)
            if not args.check:
                md.write_text(new_content)

    if missing:
        print("WARNING: section not found for: " + ", ".join(missing), file=sys.stderr)

    if args.check:
        if changed:
            print("Would change: " + ", ".join(changed))
            return 1
        print("All 12 SKILL.md preflight sections up to date (no diff).")
        return 0

    print(f"Regenerated {len(changed)} SKILL.md section(s): "
          + (", ".join(changed) if changed else "(none — already current)"))
    return 2 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
