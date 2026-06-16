#!/usr/bin/env python3
"""Assemble the FT2 control-room state bundle for the UCC live feed (Phase 2 PR D).

FitTracker2 CI runs this on every push to main that touches the relevant
`.claude/*` state, producing ONE JSON bundle that the fitme-story control-room
reads from a public Vercel Blob at request time (see fitme-story
src/lib/live-data/data-source.ts). The actual Blob PUT is a separate step
(scripts/put-state-bundle.mjs, official @vercel/blob SDK) so this assembler
stays pure + pytest-testable and carries no network dependency.

Bundle shape (schema_version 1):
  {
    "schema_version": 1,
    "generated_at": "<ISO8601>",
    "commit_sha": "<sha or 'local'>",
    "files": {
      "shared/<name>.json": <parsed JSON>,          # allow-listed only
      "features/<slug>.json": <parsed state.json>,  # all features
      "integrity/gate-coverage-ft2.jsonl": "<raw text>",
    }
  }

PUBLIC-BLOB SAFETY: this artifact is public-readable (deterministic URL, like
the audit-log blob). Shared files are an explicit ALLOW-LIST — only the files
the control-room actually reads — so PII-bearing ledgers (e.g. agent-leases.json
with operator/session labels) are never shipped. Extend SHARED_ALLOWLIST only
after vetting a file for PII.

Keys mirror exactly what data-source.ts requests so the consumer's
getBundleJson('shared/<name>') / listBundleKeys('features/') /
getBundleText('integrity/gate-coverage-ft2.jsonl') resolve.

Usage:
  python3 scripts/push-state-bundle.py [--out PATH] [--summary]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

# Shared ledgers the fitme-story control-room reads (builder.ts + load-ledgers.ts
# + load-membrane-status.ts). Allow-list, NOT denylist — this blob is public.
SHARED_ALLOWLIST: tuple[str, ...] = (
    "framework-manifest.json",
    "external-sync-status.json",
    "case-study-monitoring.json",
    "documentation-debt.json",
    "feature-registry.json",
    "task-queue.json",
    "measurement-adoption-history.json",
    "measurement-adoption.json",
    "membrane-status.json",  # optional — included only when present
)

# FT2's own gate-coverage stream → the key the framework page reads.
GATE_COVERAGE_SRC = ("logs", "gate-coverage.jsonl")
GATE_COVERAGE_KEY = "integrity/gate-coverage-ft2.jsonl"

SCHEMA_VERSION = 1


def build_bundle(claude_dir: Path, *, commit_sha: str, generated_at: str) -> dict:
    """Pure assembler — read state from `claude_dir`, return the bundle dict.

    Deterministic: takes commit_sha + generated_at as inputs (no now()/git) so
    tests can assert exact output.
    """
    files: dict[str, object] = {}

    # 1. Allow-listed shared ledgers (parsed JSON).
    shared_dir = claude_dir / "shared"
    for name in SHARED_ALLOWLIST:
        path = shared_dir / name
        if not path.is_file():
            continue  # optional members (e.g. membrane-status.json) skip cleanly
        try:
            files[f"shared/{name}"] = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue  # skip malformed; consumer falls back to its snapshot

    # 2. Every feature state.json, keyed by its directory slug.
    features_dir = claude_dir / "features"
    if features_dir.is_dir():
        for state_path in sorted(features_dir.glob("*/state.json")):
            slug = state_path.parent.name
            try:
                files[f"features/{slug}.json"] = json.loads(
                    state_path.read_text(encoding="utf-8")
                )
            except (json.JSONDecodeError, OSError):
                continue

    # 3. Gate-coverage stream as RAW TEXT (the consumer reads it via getBundleText).
    gate_path = claude_dir.joinpath(*GATE_COVERAGE_SRC)
    if gate_path.is_file():
        try:
            files[GATE_COVERAGE_KEY] = gate_path.read_text(encoding="utf-8")
        except OSError:
            pass

    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "commit_sha": commit_sha,
        "files": files,
    }


def _resolve_commit_sha() -> str:
    sha = os.environ.get("GITHUB_SHA")
    if sha:
        return sha
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True
        ).strip()
    except (subprocess.CalledProcessError, OSError):
        return "local"


def main() -> int:
    parser = argparse.ArgumentParser(description="Assemble the FT2 state bundle.")
    parser.add_argument(
        "--out",
        default=".build/ft2-state-bundle.json",
        help="output path for the bundle JSON (default: .build/ft2-state-bundle.json)",
    )
    parser.add_argument("--summary", action="store_true", help="print a one-line summary")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    claude_dir = repo_root / ".claude"
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    bundle = build_bundle(
        claude_dir, commit_sha=_resolve_commit_sha(), generated_at=generated_at
    )

    out_path = repo_root / args.out
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(bundle, separators=(",", ":")), encoding="utf-8")

    if args.summary:
        shared = sum(1 for k in bundle["files"] if k.startswith("shared/"))
        feats = sum(1 for k in bundle["files"] if k.startswith("features/"))
        size_kb = out_path.stat().st_size / 1024
        print(
            f"ft2-state-bundle: {shared} shared + {feats} features + "
            f"{'1' if GATE_COVERAGE_KEY in bundle['files'] else '0'} gate-coverage "
            f"= {len(bundle['files'])} files, {size_kb:.1f} KB → {args.out} "
            f"(commit {bundle['commit_sha'][:7]})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
