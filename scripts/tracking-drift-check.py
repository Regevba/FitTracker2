#!/usr/bin/env python3
"""tracking-drift-check — surface rows that claim OPEN but evidence says SHIPPED.

Closes the `TRACKING_DRIFT_OPEN_BUT_SHIPPED` class documented in
docs/product/backlog.md (Dev-Env track, 2026-05-24): planning rows
(backlog checkboxes, RICE table rows, cadence-ledger rows) that sit marked
`[ ]` / un-struck for days-to-weeks while their evidence is already on disk.
Concrete instances at filing time: R6, UX-UU1/C9, UX-UU2/C10, C5.

Two deliberately-narrow signals (kill criterion: 0 false positives):

  Signal 1 — SELF-CONTRADICTION (HIGH confidence)
    An open checkbox line (`- [ ]`, not struck) whose own text carries an
    explicit ship marker: a ✅ emoji, or an uppercase SHIPPED / CLOSED token,
    or a `**SHIPPED`/`**Closed` bold marker. The line contradicts itself.

  Signal 2 — STATE CROSS-REF (MEDIUM confidence)
    An un-struck RICE/markdown table row OR open checkbox whose bolded item
    name maps to a `.claude/features/<slug>/state.json` with
    current_phase == complete. To avoid noise we require the slug to have
    >=2 significant (len>=4) words and ALL of them to appear in the row, and
    we skip rows carrying explicit future-work language (Phase 2, deferred
    to, follow-up, PR-2, gated on, post-launch, behavioral learning, ...).

Advisory only: always exits 0. `--json <path>` writes structured findings.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"

# Files scanned by default. Each is a planning surface where open/shipped drift
# has been empirically observed.
DEFAULT_SCAN_FILES = [
    "docs/product/backlog.md",
    ".claude/shared/must-have-cadence-followups.md",
    ".claude/shared/v7-9-1-candidates.md",
]

# Signal 1: explicit ship markers (case-sensitive where noted to avoid the
# noisy lowercase "deps shipped" describing-a-dependency pattern).
SHIP_MARKERS = ("✅", "SHIPPED", "CLOSED", "**Closed", "**Shipped", "DONE 20")

# Future-work phrases — if present, the row legitimately stays open even when a
# sibling/parent feature is complete. Lower-cased substring match. Deliberately
# specific (e.g. "deferred to" not bare "deferred") to avoid suppressing real
# drift whose paragraph happens to mention a deferral elsewhere.
FUTURE_WORK_PHRASES = (
    "phase 2", "deferred to", "deferred until", "follow-up", "followup",
    "next pass", "post-launch", "post launch", "gated on", "pr-2",
    "behavioral learning", "not yet started", "blocked on", "aspirational",
    "re-eval", "when convenient", "unblock", "re-activate", "reactivate",
    "↔",  # integration-of-two-systems row: named feature is the counterparty
)

# Section headings under which rows are already reconciled — never flag inside.
DONE_SECTION_TOKENS = ("done", "shipped", "moved to")

OPEN_CHECKBOX_RE = re.compile(r"^\s*[-*]\s*\[ \]\s")
STRIKE_RE = re.compile(r"~~")
SECTION_RE = re.compile(r"^#{2,4}\s+(.*)$")
# Markdown table data row whose first non-empty cell is a RICE-style number.
TABLE_RICE_ROW_RE = re.compile(r"^\|\s*([0-9]+(?:\.[0-9]+)?)\s*\|")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
PARENS_RE = re.compile(r"\([^)]*\)")


def complete_feature_slugs() -> dict[str, list[str]]:
    """Map each complete-feature slug -> its significant (len>=4) words."""
    out: dict[str, list[str]] = {}
    if not FEATURES_DIR.is_dir():
        return out
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        try:
            d = json.loads(state_path.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        if d.get("current_phase") != "complete":
            continue
        slug = state_path.parent.name
        words = [w for w in slug.split("-") if len(w) >= 4]
        if len(words) >= 2:  # single-word slugs are too generic to match safely
            out[slug] = words
    return out


def _has_future_work_language(low: str) -> bool:
    return any(p in low for p in FUTURE_WORK_PHRASES)


def scan_file(path: Path, slugs: dict[str, list[str]]) -> list[dict]:
    findings: list[dict] = []
    try:
        lines = path.read_text().splitlines()
    except OSError:
        return findings
    rel = str(path.relative_to(REPO_ROOT))
    in_done_section = False
    for i, line in enumerate(lines, start=1):
        sec = SECTION_RE.match(line)
        if sec:
            heading = sec.group(1).lower()
            in_done_section = any(t in heading for t in DONE_SECTION_TOKENS)
            continue
        if in_done_section:
            continue  # rows here are the shipped record, not open claims
        if STRIKE_RE.search(line):
            continue  # already reconciled (struck through)
        low = line.lower()

        is_open_checkbox = bool(OPEN_CHECKBOX_RE.match(line))
        is_rice_row = bool(TABLE_RICE_ROW_RE.match(line))

        # First bold span is the row's TITLE (status markers there describe the
        # row itself; markers buried later usually reference a different item).
        first_bold = BOLD_RE.search(line)
        title = first_bold.group(1) if first_bold else ""

        # Signal 1 — self-contradiction: open checkbox whose TITLE says shipped.
        if is_open_checkbox and any(m in title for m in SHIP_MARKERS):
            findings.append({
                "file": rel, "line": i, "severity": "ADVISORY",
                "code": "TRACKING_DRIFT_OPEN_BUT_SHIPPED",
                "signal": "self_contradiction",
                "message": (f"{rel}:{i} open checkbox `[ ]` but its title carries "
                            f"a ship marker — reconcile to `[x]`/strike-through."),
                "excerpt": line.strip()[:160],
            })
            continue

        # Signal 2 — state cross-ref on un-struck RICE rows / open checkboxes.
        if not (is_rice_row or is_open_checkbox):
            continue
        if _has_future_work_language(low):
            continue
        if not title:
            continue
        # Match against the title with parentheticals (which carry "parent: X"
        # and work-type notes) stripped, so a complete PARENT doesn't flag an
        # open child enhancement.
        title_core = PARENS_RE.sub(" ", title).lower()
        bold_norm = re.sub(r"[^a-z0-9 ]", " ", title_core)
        for slug, words in slugs.items():
            if all(re.search(rf"\b{re.escape(w)}\b", bold_norm) for w in words):
                findings.append({
                    "file": rel, "line": i, "severity": "ADVISORY",
                    "code": "TRACKING_DRIFT_OPEN_BUT_SHIPPED",
                    "signal": "state_complete_cross_ref",
                    "feature": slug,
                    "message": (f"{rel}:{i} un-struck row names "
                                f"`{slug}` whose state.json is complete — "
                                f"reconcile the row."),
                    "excerpt": line.strip()[:160],
                })
                break
    return findings


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--json", help="Write structured findings to this path")
    p.add_argument("--files", nargs="*", help="Override scan file list")
    p.add_argument("--quiet", action="store_true")
    args = p.parse_args()

    slugs = complete_feature_slugs()
    scan_files = args.files or DEFAULT_SCAN_FILES
    findings: list[dict] = []
    for f in scan_files:
        fp = REPO_ROOT / f
        if fp.is_file():
            findings.extend(scan_file(fp, slugs))

    if args.json:
        Path(args.json).write_text(json.dumps(
            {"findings": findings, "count": len(findings)}, indent=2) + "\n")

    if not args.quiet:
        if not findings:
            print("✅ No tracking drift — all open rows lack ship evidence.")
        else:
            print(f"{len(findings)} tracking-drift advisory finding(s):\n")
            for fnd in findings:
                print(f"  [{fnd['signal']}] {fnd['message']}")
                print(f"      → {fnd['excerpt']}")
    return 0  # advisory: never blocks


if __name__ == "__main__":
    raise SystemExit(main())
