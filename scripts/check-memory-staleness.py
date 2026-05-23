#!/usr/bin/env python3
"""
scripts/check-memory-staleness.py — readout for auto-memory staleness.

Closes cadence-followups §C11 (Option C, 2026-05-17 session). The
auto-memory system at $HOME/.claude/projects/-Volumes-DevSSD-FitTracker2/
memory/ accumulates topic files over time. This script surfaces:

  1. MEMORY.md size — warns over 24 KB (soft limit; entries past line 200
     get truncated when loaded into a new session).
  2. Index entries pointing at files that DON'T exist (broken refs).
  3. Topic files on disk that AREN'T indexed in MEMORY.md (orphans).
  4. Index entries that exceed 200 chars on a single line (truncation risk).

Exit codes:
  0 — no findings
  1 — at least one warning (does not fail CI by default)

Override:
  CHECK_MEMORY_STRICT=1 → exit 1 on any finding (default is 0 on
                          warnings; preserves session continuity).
  CHECK_MEMORY_DIR=<path> → override the default memory dir for testing.

Usage:
  python3 scripts/check-memory-staleness.py
  make memory-check  # equivalent
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

# ─── config ───────────────────────────────────────────────────────────
DEFAULT_MEMORY_DIR = (
    Path.home() / ".claude" / "projects" / "-Volumes-DevSSD-FitTracker2" / "memory"
)
MEMORY_DIR = Path(os.environ.get("CHECK_MEMORY_DIR", DEFAULT_MEMORY_DIR))
INDEX_FILE = MEMORY_DIR / "MEMORY.md"

SIZE_WARN_KB = 24
SIZE_ERROR_KB = 32
LINE_WARN_CHARS = 200

STRICT = os.environ.get("CHECK_MEMORY_STRICT") == "1"

# Regex for index entries: matches `- [Title](file.md) — ...`
ENTRY_RE = re.compile(r"^\s*-\s+\[[^\]]+\]\(([^)]+\.md)\)")


def main() -> int:
    findings: list[str] = []

    if not INDEX_FILE.exists():
        print(f"ℹ no MEMORY.md at {INDEX_FILE} — nothing to check")
        return 0

    raw = INDEX_FILE.read_bytes()
    size_kb = len(raw) / 1024

    # ─── Check 1: size ─────────────────────────────────────────────
    if size_kb > SIZE_ERROR_KB:
        findings.append(
            f"❌ MEMORY.md is {size_kb:.1f} KB (over {SIZE_ERROR_KB} KB hard threshold) — entries past ~200 lines truncate at session load"
        )
    elif size_kb > SIZE_WARN_KB:
        findings.append(
            f"⚠ MEMORY.md is {size_kb:.1f} KB (over {SIZE_WARN_KB} KB soft limit) — consider trimming or moving detail into topic files"
        )

    # ─── Check 2 + 3: index ↔ filesystem consistency ──────────────
    indexed_files: set[str] = set()
    long_lines: list[tuple[int, int, str]] = []  # (line_no, char_count, title)
    for line_no, line in enumerate(raw.decode("utf-8").splitlines(), start=1):
        m = ENTRY_RE.match(line)
        if not m:
            continue
        ref = m.group(1)
        indexed_files.add(ref)
        if len(line) > LINE_WARN_CHARS:
            title_match = re.search(r"\[([^\]]+)\]", line)
            title = title_match.group(1)[:40] if title_match else "(unknown)"
            long_lines.append((line_no, len(line), title))

    on_disk = {
        p.name for p in MEMORY_DIR.glob("*.md") if p.name != "MEMORY.md"
    }

    missing_refs = indexed_files - on_disk
    orphan_files = on_disk - indexed_files

    if missing_refs:
        findings.append(
            f"❌ {len(missing_refs)} index entries reference files that don't exist on disk:"
        )
        for f in sorted(missing_refs)[:10]:
            findings.append(f"     - {f}")
        if len(missing_refs) > 10:
            findings.append(f"     ... and {len(missing_refs) - 10} more")

    if orphan_files:
        findings.append(
            f"⚠ {len(orphan_files)} topic files on disk but NOT indexed in MEMORY.md (orphans):"
        )
        for f in sorted(orphan_files)[:10]:
            findings.append(f"     - {f}")
        if len(orphan_files) > 10:
            findings.append(f"     ... and {len(orphan_files) - 10} more")

    # ─── Check 4: long lines (truncation risk) ────────────────────
    if long_lines:
        findings.append(
            f"⚠ {len(long_lines)} index entries exceed {LINE_WARN_CHARS} chars (move detail into topic files):"
        )
        for line_no, chars, title in long_lines[:5]:
            findings.append(f"     - line {line_no} ({chars} chars): {title}…")
        if len(long_lines) > 5:
            findings.append(f"     ... and {len(long_lines) - 5} more")

    # ─── output ────────────────────────────────────────────────────
    if not findings:
        print(f"✓ MEMORY.md staleness check passed")
        print(f"   size: {size_kb:.1f} KB / {SIZE_WARN_KB} KB soft limit")
        print(f"   indexed entries: {len(indexed_files)}")
        print(f"   topic files on disk: {len(on_disk)}")
        return 0

    print("MEMORY.md staleness findings:")
    print(f"  size: {size_kb:.1f} KB | indexed: {len(indexed_files)} | on disk: {len(on_disk)}")
    print()
    for f in findings:
        print(f"  {f}")
    print()
    print(f"  Reference: {INDEX_FILE}")
    print(f"  Quick fixes: trim long lines into topic files, prune orphans, repair broken refs")
    print(f"  Disable: set CHECK_MEMORY_STRICT=0 (default) — warnings don't fail CI")

    # Has any ❌ (error)?
    has_error = any(f.startswith("❌") for f in findings)
    if STRICT or has_error:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
