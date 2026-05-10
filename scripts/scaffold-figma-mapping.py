#!/usr/bin/env python3
"""
scaffold-figma-mapping.py — auto-generate iOS Code Connect template files
from a feature's state.json::figma_node_ids block.

Reads .claude/features/<feature>/state.json, finds the figma_node_ids
dict, and for each Figma node entry generates a matching .figma.swift
template file alongside the corresponding SwiftUI View struct.

Coalesces multiple Figma nodes that map to the same View into ONE
.figma.swift file with multiple FigmaConnect structs (one per state
variant — e.g., populated + empty).

Idempotent: skips if the .figma.swift file already exists (use --force
to overwrite). Emits a report grouped by status.

Usage:
  python3 scripts/scaffold-figma-mapping.py <feature-name>
  python3 scripts/scaffold-figma-mapping.py <feature-name> --dry-run
  python3 scripts/scaffold-figma-mapping.py <feature-name> --force
  python3 scripts/scaffold-figma-mapping.py --help

Companion: scripts/scaffold-figma-mapping.mjs in the fitme-story repo
does the equivalent for React (.figma.tsx).

Source-of-truth design library (default): FitTracker-Design-System-Library
file key 0Ai7s3fCFqR5JXDW8JvgmD. Override via state.json:
  "figma_node_ids": {
    "library_file_key": "<key>",
    "library_file_name": "<file slug>",
    "<node-name>": "<X:Y>",
    ...
  }

Manual override: add `code_mapping` block to bypass the View-name
heuristic for nodes whose Figma key doesn't match a Swift struct:
  "figma_node_ids": {
    "day_assignment_editor": "921:2",
    "training_tab_active_plan_badge": "922:2",
    "code_mapping": {
      "day_assignment_editor": "ImportPreviewView",
      "training_tab_active_plan_badge": "TrainingPlanView"
    }
  }

Exit codes:
  0  All Figma nodes either scaffolded or skipped (file exists).
  1  Argument parse error or feature directory not found.
  2  At least one Figma node could not be mapped to a Swift View
     (warning emitted; operator must hand-author or add code_mapping).
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Iterable

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
VIEWS_DIR = REPO_ROOT / "FitTracker" / "Views"
DESIGN_SYSTEM_DIR = REPO_ROOT / "FitTracker" / "DesignSystem"

DEFAULT_LIBRARY_FILE_KEY = "0Ai7s3fCFqR5JXDW8JvgmD"
DEFAULT_LIBRARY_FILE_NAME = "FitTracker-Design-System-Library"

# Reserved keys in figma_node_ids that aren't Figma node references
RESERVED_KEYS = {
    "library_file_key",
    "library_file_name",
    "library_file_url",
    "code_mapping",
    "page",
    "section",
    "page_title_section",
}

# State qualifier suffixes that may appear on figma_node_ids keys
STATE_QUALIFIER_SUFFIXES = [
    "_populated_active",
    "_populated",
    "_empty",
    "_loading",
    "_error",
    "_editor",
    "_states",
    "_banner",
    "_sheet",
    "_screen",
    "_view",
]


def snake_to_pascal(s: str) -> str:
    return "".join(p.capitalize() for p in s.split("_"))


def candidate_view_names(node_key: str) -> Iterable[str]:
    """Yield candidate Swift View struct names to look up for a given key."""
    base = snake_to_pascal(node_key)
    yield base
    yield base + "View"
    yield base + "Screen"
    yield base + "Row"
    for suffix in STATE_QUALIFIER_SUFFIXES:
        if node_key.endswith(suffix):
            stripped = node_key[: -len(suffix)]
            stripped_base = snake_to_pascal(stripped)
            yield stripped_base
            yield stripped_base + "View"
            yield stripped_base + "Screen"
            yield stripped_base + "Row"


def find_view_file(struct_name: str) -> Path | None:
    """Search FitTracker/Views/**/*.swift + DesignSystem/*.swift for
    `struct <Name>: View {` and return the first match."""
    pattern = re.compile(rf"^struct\s+{re.escape(struct_name)}\s*:\s*View\b")
    for search_dir in (VIEWS_DIR, DESIGN_SYSTEM_DIR):
        if not search_dir.exists():
            continue
        for swift_file in search_dir.rglob("*.swift"):
            if swift_file.name.endswith(".figma.swift"):
                continue
            try:
                with swift_file.open() as f:
                    for line in f:
                        if pattern.match(line.strip()):
                            return swift_file
            except (OSError, UnicodeDecodeError):
                continue
    return None


def normalize_node_id(raw: str) -> str:
    return str(raw).replace(":", "-")


def figma_url_for(file_key: str, file_name: str, node_id: str) -> str:
    return f"https://www.figma.com/design/{file_key}/{file_name}?node-id={node_id}"


def state_qualifier_suffix(node_key: str) -> str:
    """If node_key ends in a state qualifier (populated, empty, etc.),
    return a PascalCase suffix to disambiguate FigmaConnect struct names."""
    m = re.search(r"_(populated_active|populated|empty|loading|error|editor)$", node_key)
    return "_" + snake_to_pascal(m.group(1)) if m else ""


def file_template(view_struct: str, connections: list[tuple[str, str]]) -> str:
    """Render a .figma.swift file containing one or more FigmaConnect structs.

    `connections` is a list of (struct_suffix, node_url) tuples.
    """
    structs = []
    for suffix, node_url in connections:
        connect_name = f"{view_struct}{suffix}_FigmaConnect"
        structs.append(
            f"struct {connect_name}: FigmaConnect {{\n"
            f"    let component = {view_struct}.self\n"
            f"    let figmaNodeUrl: String =\n"
            f'        "{node_url}"\n'
            f"\n"
            f"    var body: some View {{\n"
            f"        {view_struct}()\n"
            f"    }}\n"
            f"}}"
        )
    body = "\n\n".join(structs)
    return (
        f"// Figma Code Connect template — auto-scaffolded by\n"
        f"// scripts/scaffold-figma-mapping.py. Operator may adjust each\n"
        f"// `body` example to render a more realistic preview.\n"
        f"\n"
        f"#if canImport(Figma)\n"
        f"import Figma\n"
        f"import SwiftUI\n"
        f"\n"
        f"{body}\n"
        f"#endif\n"
    )


def report_row(status: str, node_key: str, node_id: str, target: str = "") -> str:
    badge = {
        "scaffolded": "✓",
        "skipped": "·",
        "unmapped": "!",
        "skipped-reserved": "·",
    }.get(status, "?")
    label = {
        "scaffolded": "wrote",
        "skipped": "exists",
        "unmapped": "no view found",
        "skipped-reserved": "reserved key",
    }.get(status, status)
    return f"  {badge} {node_key:35s} {node_id:10s} {label:18s} {target}"


def main() -> int:
    p = argparse.ArgumentParser(
        description="Auto-generate iOS Code Connect .figma.swift templates"
        " from <feature>/state.json::figma_node_ids."
    )
    p.add_argument("feature", help="feature folder name under .claude/features/")
    p.add_argument("--dry-run", action="store_true",
                   help="report what would be scaffolded without writing files")
    p.add_argument("--force", action="store_true",
                   help="overwrite existing .figma.swift files")
    args = p.parse_args()

    state_path = FEATURES_DIR / args.feature / "state.json"
    if not state_path.exists():
        print(f"ERROR: state.json not found at {state_path}", file=sys.stderr)
        return 1
    try:
        with state_path.open() as f:
            state = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"ERROR: cannot parse {state_path}: {e}", file=sys.stderr)
        return 1

    figma_node_ids = state.get("figma_node_ids") or {}
    if not figma_node_ids:
        print(f"NOTE: no figma_node_ids in {state_path}; nothing to scaffold")
        return 0

    file_key = figma_node_ids.get("library_file_key", DEFAULT_LIBRARY_FILE_KEY)
    file_name = figma_node_ids.get("library_file_name", DEFAULT_LIBRARY_FILE_NAME)
    code_mapping = figma_node_ids.get("code_mapping") or {}

    # First pass: resolve each node entry to (view_struct, view_file, suffix, node_url)
    rows: list[tuple[str, str, str, str]] = []
    coalesced: dict[Path, tuple[str, list[tuple[str, str]]]] = {}
    unmapped_count = 0

    for node_key, node_value in figma_node_ids.items():
        if node_key in RESERVED_KEYS or not isinstance(node_value, str):
            rows.append(("skipped-reserved", node_key, str(node_value or ""), ""))
            continue

        node_id = normalize_node_id(node_value)
        node_url = figma_url_for(file_key, file_name, node_id)

        # Resolve View struct: explicit code_mapping wins; else heuristic
        view_struct: str | None = code_mapping.get(node_key)
        view_file: Path | None = None
        if view_struct:
            view_file = find_view_file(view_struct)
        else:
            for candidate in candidate_view_names(node_key):
                found = find_view_file(candidate)
                if found is not None:
                    view_file = found
                    view_struct = candidate
                    break

        if view_file is None or view_struct is None:
            rows.append(("unmapped", node_key, node_id, ""))
            unmapped_count += 1
            continue

        out_path = view_file.parent / f"{view_struct}.figma.swift"
        target = str(out_path.relative_to(REPO_ROOT))
        suffix = state_qualifier_suffix(node_key)

        # Coalesce by output path (multiple states per View)
        if out_path not in coalesced:
            coalesced[out_path] = (view_struct, [])
        coalesced[out_path][1].append((suffix, node_url))
        rows.append(("scaffolded", node_key, node_id, target))

    # Second pass: write files (one per coalesced path)
    written = 0
    skipped_existing = 0
    for out_path, (view_struct, connections) in coalesced.items():
        if out_path.exists() and not args.force:
            # Reclassify scaffolded rows as skipped for these entries
            target = str(out_path.relative_to(REPO_ROOT))
            for i, (status, k, n, t) in enumerate(rows):
                if status == "scaffolded" and t == target:
                    rows[i] = ("skipped", k, n, t)
                    skipped_existing += 1
            continue
        if not args.dry_run:
            out_path.write_text(file_template(view_struct, connections))
        written += 1

    # Render report
    print(f"\nFeature: {args.feature}")
    print(f"State:   {state_path.relative_to(REPO_ROOT)}")
    print(f"Library: {file_name} (key {file_key[:8]}…)")
    if args.dry_run:
        print("Mode:    --dry-run (no files written)")
    print(f"\n{len(rows)} entries:")
    for status, node_key, node_id, target in rows:
        print(report_row(status, node_key, node_id, target))

    counts: dict[str, int] = {}
    for status, _, _, _ in rows:
        counts[status] = counts.get(status, 0) + 1
    print("\nSummary: " + ", ".join(f"{c} {s}" for s, c in sorted(counts.items())))
    print(f"Files: {written} written, {skipped_existing} skipped (already exist; use --force)")

    if unmapped_count:
        print(
            f"\nWARNING: {unmapped_count} Figma node(s) could not be mapped"
            " to a Swift View struct. Either hand-author the .figma.swift"
            " files for these OR add a `code_mapping` block to"
            " state.json::figma_node_ids — see script header for example."
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
