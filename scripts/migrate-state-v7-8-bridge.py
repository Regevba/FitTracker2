#!/usr/bin/env python3
"""Idempotent migration: populate v7.8 schema bridge fields on every state.json.

Per docs/superpowers/specs/2026-05-02-framework-v7-8-and-v7-9-bridge-design.md
§4.7 + §8.4. Adds two advisory bridge fields to every
`.claude/features/*/state.json`:

  agent_manifest:
    reads: []          # paths the agent reads (populated by /pm-workflow during phase transitions)
    writes: []         # paths the agent writes
    shared_writes: []  # paths shared with other agents — registered with merge_strategy

  _meta:
    deprecation_warnings: []  # populated on read by check-state-schema.py when stale fields detected (OpenAPI Sunset / RFC 8594 pattern)

Idempotent: skips fields that already exist. Safe to re-run.

v7.8 ships these fields populated as empty arrays; no enforcement gate
consumes them yet. v7.9 flips:
  - pre-commit validates `staged_paths ⊆ agent_manifest.writes` (Mechanism G)
  - `_meta.deprecation_warnings` non-empty → SCHEMA_LEGACY_FIELD failure code

Why text-based insertion (not json.dump round-trip):
  - json.dump rewrites the entire file with normalized formatting, producing
    noisy diffs that obscure the actual change.
  - Text-based insertion at a known anchor produces clean 1-2 line diffs.
  - Pattern carried over from PR #185 + #186 (framework_version backfill).

Anchor logic:
  - agent_manifest inserts after `framework_version` line, OR after
    `current_phase` line if framework_version absent. Same indentation.
  - _meta inserts at top-level just before the closing brace.

Usage:
  python3 scripts/migrate-state-v7-8-bridge.py             # all 47 features
  python3 scripts/migrate-state-v7-8-bridge.py --dry-run   # report only
  python3 scripts/migrate-state-v7-8-bridge.py <path>      # single file

Returns 0 on success; non-zero if any file fails to parse after migration.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"

ANCHOR_FRAMEWORK_VERSION = re.compile(r'^(\s*)"framework_version":', re.MULTILINE)
ANCHOR_CURRENT_PHASE = re.compile(r'^(\s*)"current_phase":', re.MULTILINE)


def _add_agent_manifest(text: str) -> tuple[str, bool]:
    """Insert `agent_manifest` block. Return (new_text, changed).

    Handles two cases:
      a) Anchor line ends with a comma (typical — anchor is not the last
         top-level field): insert the new field right after, with its own
         trailing comma.
      b) Anchor line has no trailing comma (anchor IS the last field):
         add a comma to the anchor line first, then insert the new field
         WITHOUT a trailing comma (it's now the last field). Edge case
         only on minimal state.json files; real repo files always fall
         into (a).
    """
    if '"agent_manifest"' in text:
        return text, False

    anchor = ANCHOR_FRAMEWORK_VERSION.search(text) or ANCHOR_CURRENT_PHASE.search(text)
    if anchor is None:
        return text, False

    indent = anchor.group(1)
    line_end_idx = text.index("\n", anchor.end())

    # Inspect the anchor line content (from line start to newline).
    line_start_idx = text.rfind("\n", 0, anchor.start()) + 1
    anchor_line = text[line_start_idx:line_end_idx]
    has_trailing_comma = anchor_line.rstrip().endswith(",")

    block_lines = [
        f'{indent}"agent_manifest": {{',
        f'{indent}  "reads": [],',
        f'{indent}  "writes": [],',
        f'{indent}  "shared_writes": []',
        f'{indent}}}',
    ]

    if has_trailing_comma:
        # Case (a): insert after the anchor's newline; new block ends with ",\n".
        block = "\n".join(block_lines) + ",\n"
        return text[:line_end_idx + 1] + block + text[line_end_idx + 1:], True
    else:
        # Case (b): anchor was last. Add a comma to it, then insert new block
        # without a trailing comma (it becomes the new last field).
        prefix = text[:line_end_idx].rstrip() + ","
        block = "\n".join(block_lines)
        return prefix + "\n" + block + text[line_end_idx:], True


def _add_meta_deprecation_warnings(text: str) -> tuple[str, bool]:
    """Insert `_meta.deprecation_warnings` block at top level.

    Strategy: find the LAST top-level closing brace `^}` and insert
    `_meta` block before its preceding line. We assume the file ends with
    `}\n` and the prior top-level field has a trailing comma (the migration
    pass adds the comma if needed).
    """
    if '"_meta"' in text:
        return text, False

    # Parse to confirm valid JSON before mutating, and to detect the last
    # top-level key (so we can append `_meta` cleanly).
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return text, False
    if not isinstance(data, dict):
        return text, False

    # Find the closing brace at the start of a line (matches the file-final `}`)
    closing_brace_match = re.search(r"^\}\s*$", text, re.MULTILINE)
    if closing_brace_match is None:
        return text, False
    close_idx = closing_brace_match.start()

    # The line before the closing brace is the last top-level value's last line.
    # We need to ensure that line ends with a comma (it usually doesn't if it's
    # the last top-level field). Find the last non-blank character before close_idx.
    head = text[:close_idx].rstrip()
    if not head.endswith(","):
        # Add a trailing comma to the previous last field.
        head_with_comma = head + ","
    else:
        head_with_comma = head

    block = (
        '\n  "_meta": {\n'
        '    "deprecation_warnings": []\n'
        '  }\n'
    )

    new_text = head_with_comma + block + text[close_idx:]
    # Verify parse still works.
    try:
        json.loads(new_text)
    except json.JSONDecodeError:
        return text, False
    return new_text, True


def migrate_file(path: Path, dry_run: bool = False) -> dict:
    """Apply both bridge-field additions. Return change report."""
    report = {"path": str(path), "agent_manifest_added": False, "meta_added": False, "error": None}
    try:
        text = path.read_text()
    except OSError as exc:
        report["error"] = f"read failed: {exc}"
        return report

    # Validate JSON before mutating.
    try:
        json.loads(text)
    except json.JSONDecodeError as exc:
        report["error"] = f"invalid JSON before migration: {exc}"
        return report

    new_text, manifest_added = _add_agent_manifest(text)
    new_text, meta_added = _add_meta_deprecation_warnings(new_text)

    report["agent_manifest_added"] = manifest_added
    report["meta_added"] = meta_added

    if not (manifest_added or meta_added):
        return report

    # Validate JSON after migration.
    try:
        json.loads(new_text)
    except json.JSONDecodeError as exc:
        report["error"] = f"invalid JSON after migration: {exc}"
        return report

    if not dry_run:
        path.write_text(new_text)
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("paths", nargs="*", help="state.json files (default: all under .claude/features/)")
    ap.add_argument("--dry-run", action="store_true", help="report changes without writing")
    args = ap.parse_args()

    if args.paths:
        files = [Path(p).resolve() for p in args.paths]
    else:
        files = sorted(FEATURES_DIR.glob("*/state.json"))

    if not files:
        print("No state.json files found.", file=sys.stderr)
        return 0

    n_manifest = n_meta = n_error = n_skipped = 0
    for f in files:
        rep = migrate_file(f, dry_run=args.dry_run)
        if rep["error"]:
            print(f"ERROR {f.name}: {rep['error']}", file=sys.stderr)
            n_error += 1
            continue
        if rep["agent_manifest_added"] or rep["meta_added"]:
            tags = []
            if rep["agent_manifest_added"]:
                tags.append("agent_manifest")
                n_manifest += 1
            if rep["meta_added"]:
                tags.append("_meta")
                n_meta += 1
            print(f"  + {f.parent.name}: {', '.join(tags)}")
        else:
            n_skipped += 1

    prefix = "DRY-RUN " if args.dry_run else ""
    print(
        f"\n{prefix}Migrated {len(files) - n_error - n_skipped} of {len(files)} "
        f"(agent_manifest: +{n_manifest}, _meta: +{n_meta}, "
        f"already-present: {n_skipped}, errors: {n_error})"
    )
    return 0 if n_error == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
