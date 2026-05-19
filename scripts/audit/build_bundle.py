#!/usr/bin/env python3
"""Build a deterministic, redacted audit bundle from a profile.

Usage:
    python3 scripts/audit/build_bundle.py --profile=base
    python3 scripts/audit/build_bundle.py --profile=v7-9-promotion --run-label=2026-05-22-claude
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# Make scripts/audit importable when run as a script
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent.parent))

from scripts.audit.redaction import redact  # noqa: E402
from scripts.audit.profile import load_profile, expand_globs  # noqa: E402
from scripts.audit.state_snapshot import build_state_snapshot  # noqa: E402


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SIZE_WARN_BYTES = 2_000_000  # ~500K tokens
DEFAULT_RUNS_DIR = REPO_ROOT / "docs" / "audits" / "runs"


@dataclass
class BundleResult:
    bundle_path: Path
    manifest_path: Path
    redaction_log_path: Path
    bundle_sha256: str
    size_warning_emitted: bool


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _self_sha256() -> str:
    return _sha256(Path(__file__).read_text())


def build(
    profile_name: str,
    repo_root: Path = REPO_ROOT,
    run_label: Optional[str] = None,
    fixed_timestamp: Optional[str] = None,
    runs_dir: Optional[Path] = None,
) -> BundleResult:
    """Build the bundle. Returns a BundleResult with paths + summary hash."""
    # Resolve repo_root so that file paths from expand_globs (which calls .resolve()
    # internally) stay in the subpath of repo_root for relative_to() — handles
    # macOS /var → /private/var tempdir symlink.
    repo_root = repo_root.resolve()

    profile = load_profile(profile_name, profile_dir=repo_root / "scripts" / "audit" / "profiles")
    files = expand_globs(profile.globs, root=repo_root)

    run_label = run_label or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d-%H%M%S")
    timestamp = fixed_timestamp or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    runs_dir = runs_dir or (repo_root / "docs" / "audits" / "runs")
    run_dir = runs_dir / run_label
    run_dir.mkdir(parents=True, exist_ok=True)

    manifest_entries: list[dict] = []
    bundle_parts: list[str] = []
    total_rule_counts: dict[str, int] = {}
    size_warning_emitted = False

    # Body assembly: files first (alphabetical via expand_globs), then state snapshot
    for f in files:
        rel = f.relative_to(repo_root).as_posix()
        original = f.read_text()
        pre_hash = _sha256(original)
        redacted, counts = redact(original)
        post_hash = _sha256(redacted)
        for k, v in counts.items():
            total_rule_counts[k] = total_rule_counts.get(k, 0) + v
        bundle_parts.append(f"### FILE: {rel}\n\n{redacted}\n")
        manifest_entries.append({
            "path": rel,
            "sha256_pre_redaction": pre_hash,
            "sha256_post_redaction": post_hash,
            "bytes": len(redacted.encode("utf-8")),
            "redactions_applied": counts,
        })

    # State snapshot — included whenever any features actually resolve.
    # The profile's `state_snapshot_features` list (if non-empty) restricts the
    # snapshot to that subset; otherwise all features under `.claude/features/`
    # are included. Skip entirely if no features resolve so empty repos (and
    # the minimal test repo) don't get an empty snapshot artifact.
    only = profile.state_snapshot_features or None
    snap = build_state_snapshot(
        features_root=repo_root / ".claude" / "features",
        only=only,
    )
    if snap:
        snap_text = json.dumps(snap, indent=2, sort_keys=True)
        snap_redacted, snap_counts = redact(snap_text)
        for k, v in snap_counts.items():
            total_rule_counts[k] = total_rule_counts.get(k, 0) + v
        bundle_parts.append(f"### FILE: _state-snapshot.json\n\n```json\n{snap_redacted}\n```\n")
        manifest_entries.append({
            "path": "_state-snapshot.json",
            "sha256_pre_redaction": _sha256(snap_text),
            "sha256_post_redaction": _sha256(snap_redacted),
            "bytes": len(snap_redacted.encode("utf-8")),
            "redactions_applied": snap_counts,
        })

    body = "\n---\n\n".join(bundle_parts)
    body_hash = _sha256(body)

    toc_lines = [f"- {e['path']}" for e in manifest_entries]
    header = (
        f"# FitTracker2 Impartial Audit Bundle\n"
        f"# Generated: {timestamp}\n"
        f"# Profile: {profile.name}\n"
        f"# Bundle SHA256: {body_hash}\n"
        f"# build_bundle.py SHA256: {_self_sha256()}\n"
        f"# File count: {len(manifest_entries)}\n"
        f"# Redaction count: {sum(total_rule_counts.values())}\n\n"
        f"## Table of Contents\n" + "\n".join(toc_lines) + "\n\n---\n\n"
    )

    bundle_text = header + body
    bundle_path = run_dir / "bundle.md"
    bundle_path.write_text(bundle_text)

    if len(bundle_text.encode("utf-8")) > SIZE_WARN_BYTES:
        size_warning_emitted = True
        print(
            f"WARNING: bundle is {len(bundle_text):,} bytes (>{SIZE_WARN_BYTES:,}). "
            "Consider --split-by-section in a future version.",
            file=sys.stderr,
        )

    manifest_path = run_dir / "manifest.json"
    manifest_path.write_text(json.dumps({
        "profile": profile.name,
        "generated": timestamp,
        "bundle_sha256": body_hash,
        "build_bundle_py_sha256": _self_sha256(),
        "file_count": len(manifest_entries),
        "files": manifest_entries,
    }, indent=2))

    redaction_log_path = run_dir / "redaction-log.json"
    redaction_log_path.write_text(json.dumps({
        "profile": profile.name,
        "generated": timestamp,
        "rule_counts": total_rule_counts,
        "total_redactions": sum(total_rule_counts.values()),
    }, indent=2))

    return BundleResult(
        bundle_path=bundle_path,
        manifest_path=manifest_path,
        redaction_log_path=redaction_log_path,
        bundle_sha256=body_hash,
        size_warning_emitted=size_warning_emitted,
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--profile", required=True)
    p.add_argument("--run-label", default=None)
    args = p.parse_args()
    result = build(args.profile, run_label=args.run_label)
    print(f"Bundle written: {result.bundle_path}")
    print(f"Manifest:       {result.manifest_path}")
    print(f"Redaction log:  {result.redaction_log_path}")
    print(f"Bundle SHA256:  {result.bundle_sha256}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
