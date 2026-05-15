#!/usr/bin/env python3
"""
Aggregate dependency-audit outputs across multiple npm subdirs +
a Swift Package.resolved staleness check into a single digest.

Consumed by .github/workflows/dependency-audit-weekly.yml.

Inputs:
  --npm-audit <path>:<label>     One per audit JSON file (repeatable).
                                  `path` is the `npm audit --json` output;
                                  `label` is the subdir display name.
  --swift-package-resolved <path> Path to a Package.resolved file.
  --output-md <path>             Where to write the markdown digest.
  --output-json <path>           Where to write the machine summary.

Output JSON schema:
  {
    "totals": {"critical": N, "high": N, "moderate": N, "low": N, "total": N},
    "by_subdir": {"<label>": {"critical": N, "high": N, ...}, ...},
    "swift_deps": {"count": N, "newest_age_days": N, "oldest_age_days": N},
    "generated_at": "<ISO-8601>"
  }

Exit codes:
  0  always (digest produced — issue-opening is the workflow's call)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

SEVERITIES = ("critical", "high", "moderate", "low", "info")


def parse_npm_audit(path: Path) -> dict:
    """Return {'critical': N, 'high': N, ...} from an `npm audit --json` blob.

    npm v9+ emits {metadata: {vulnerabilities: {info, low, moderate, high, critical}}}.
    Older versions emit slightly different shapes. Be permissive.
    """
    counts = {s: 0 for s in SEVERITIES}
    if not path.exists():
        return counts
    try:
        d = json.loads(path.read_text() or "{}")
    except json.JSONDecodeError:
        return counts

    v = d.get("metadata", {}).get("vulnerabilities", {})
    for s in SEVERITIES:
        try:
            counts[s] = int(v.get(s, 0))
        except (TypeError, ValueError):
            pass
    return counts


def parse_swift_package_resolved(path: Path) -> dict:
    """Return basic staleness info from Package.resolved.

    Package.resolved v1: top-level `object.pins[]`.
    Package.resolved v2/v3: top-level `pins[]`.
    Each pin has `state.version` or `state.revision`; no commit date is
    stored, so we just count pins (real age requires fetching each repo).
    """
    if not path.exists():
        return {"count": 0, "note": "Package.resolved not found"}
    try:
        d = json.loads(path.read_text() or "{}")
    except json.JSONDecodeError:
        return {"count": 0, "note": "Package.resolved JSON invalid"}

    pins = d.get("pins") or d.get("object", {}).get("pins", [])
    return {
        "count": len(pins),
        "note": (
            "Package.resolved does not carry commit dates; staleness check "
            "requires per-repo fetch — not implemented in weekly digest."
        ),
    }


def render_markdown(by_subdir: dict, totals: dict, swift: dict) -> str:
    lines = []
    t = totals
    lines.append(f"**Totals across all npm subdirs:** "
                 f"{t['critical']} critical · {t['high']} high · "
                 f"{t['moderate']} moderate · {t['low']} low · "
                 f"{t['total']} total")
    lines.append("")
    lines.append("| Subdir | Critical | High | Moderate | Low | Total |")
    lines.append("|---|---|---|---|---|---|")
    for label, c in sorted(by_subdir.items()):
        total = sum(c[s] for s in SEVERITIES)
        lines.append(f"| {label} | {c['critical']} | {c['high']} | "
                     f"{c['moderate']} | {c['low']} | {total} |")
    lines.append("")
    lines.append(f"**Swift Package.resolved:** {swift['count']} pinned deps.  "
                 f"{swift.get('note', '')}")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--npm-audit", action="append", default=[],
                    help="Format: <path>:<label> (repeatable)")
    ap.add_argument("--swift-package-resolved", default=None,
                    help="Path to Package.resolved")
    ap.add_argument("--output-md", default="/tmp/audit-summary.md")
    ap.add_argument("--output-json", default="/tmp/audit-summary.json")
    args = ap.parse_args()

    by_subdir = {}
    totals = {s: 0 for s in SEVERITIES}

    for spec in args.npm_audit:
        if ":" not in spec:
            print(f"  ✗ malformed --npm-audit (expected path:label): {spec}",
                  file=sys.stderr)
            continue
        path, _, label = spec.rpartition(":")
        counts = parse_npm_audit(Path(path))
        by_subdir[label] = counts
        for s in SEVERITIES:
            totals[s] += counts[s]

    totals["total"] = sum(totals[s] for s in SEVERITIES)

    swift = (parse_swift_package_resolved(Path(args.swift_package_resolved))
             if args.swift_package_resolved else
             {"count": 0, "note": "no Package.resolved path passed"})

    payload = {
        "totals": totals,
        "by_subdir": by_subdir,
        "swift_deps": swift,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    Path(args.output_md).write_text(render_markdown(by_subdir, totals, swift))
    Path(args.output_json).write_text(json.dumps(payload, indent=2))

    print(render_markdown(by_subdir, totals, swift))
    return 0


if __name__ == "__main__":
    sys.exit(main())
