#!/usr/bin/env python3
"""
Unified preflight entry point — single command surfaces all data the next
work-step depends on, adapted by work_type (feature / enhancement / fix / chore).

Why this exists
---------------
Before v7.8.5, preflight checks were scattered across:
  - `/ux preflight {feature}`         (Phase 3 only, UX-spec specific)
  - `/design preflight {feature}`     (Phase 3 only, DS + Figma MCP)
  - `make integrity-check`            (system-wide, no work-type lens)
  - `make documentation-debt`         (system-wide)
  - `make measurement-adoption`       (system-wide)
  - `make membrane-status`            (operator readout)
  - `make verify-isolation`           (branch isolation status)
  - `scripts/check-ssh-agent.sh`      (W1, SessionStart only)
  - `make observed-patterns`          (pattern catalog)

Every new feature, enhancement, fix, or chore re-runs an overlapping subset
of these manually. This script aggregates them into one call, returns a
structured snapshot at `.claude/shared/preflight-cache.json`, and tailors
the output to the work_type:

  - feature     → full lifecycle preflight (research baseline, gate health, similar-feature scan, anchor diff)
  - enhancement → parent-feature integrity + gate health + anchor diff
  - fix         → high-risk-area touch detection + gate health
  - chore       → infra-path detection (auto-isolation reminder) + gate health

Downstream skills (ux, design, dev, qa, analytics, cx, marketing, research, ops, release)
read the cache instead of re-computing. The cache schema is documented at
`docs/skills/preflight-cache-schema.md`.

Usage
-----
  python3 scripts/preflight.py --work-type {feature|enhancement|fix|chore} \\
                               [--feature <name>] \\
                               [--json] \\
                               [--quiet]

  # Via Makefile:
  make preflight WORK_TYPE=feature FEATURE=my-feature-name
  make preflight WORK_TYPE=chore

Exit codes
----------
  0  — no blocking issues (advisories OK)
  1  — blocking issues found
  2  — invalid inputs

Cache path
----------
  .claude/shared/preflight-cache.json (overwritten each run)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

# Shared check functions live in preflight_checks.py (extracted v7.9.1 so the
# per-skill overlay runner reuses the same probe implementations).
from preflight_checks import (  # noqa: E402  (path injected below if needed)
    REPO_ROOT,
    check_w1_ssh_agent,
    check_ssd_health,
    check_pr_cache_fresh,
    check_integrity,
    check_integrity_diff,
    check_branch_isolation,
    check_documentation_debt,
    check_measurement_adoption,
    feature_brainstorm_state,
    enhancement_parent_state,
    fix_high_risk_touch_check,
    chore_infra_path_check,
)

CACHE = REPO_ROOT / ".claude" / "shared" / "preflight-cache.json"

WORK_TYPES = ("feature", "enhancement", "fix", "chore")


# ─────────────────────────────────────────────────────────────────────────────
# Orchestrator
# ─────────────────────────────────────────────────────────────────────────────

def run_preflight(work_type: str, feature: str | None) -> dict:
    checks = []

    # Always-run (every work_type)
    checks.append(check_w1_ssh_agent())
    checks.append(check_ssd_health())
    checks.append(check_pr_cache_fresh())
    checks.append(check_branch_isolation())
    checks.append(check_integrity())
    checks.append(check_integrity_diff())
    checks.append(check_documentation_debt())
    checks.append(check_measurement_adoption())

    # Work-type-specific
    if work_type == "feature":
        bs = feature_brainstorm_state(feature)
        if bs:
            checks.append(bs)
    elif work_type == "enhancement":
        ep = enhancement_parent_state(feature)
        if ep:
            checks.append(ep)
    elif work_type == "fix":
        checks.append(fix_high_risk_touch_check())
    elif work_type == "chore":
        checks.append(chore_infra_path_check())

    blocking = [c for c in checks if c.get("blocking")]
    warnings = [c for c in checks if c["status"] == "warning"]

    return {
        "work_type": work_type,
        "feature": feature,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checks": checks,
        "summary": {
            "total_checks": len(checks),
            "blocking": len(blocking),
            "warnings": len(warnings),
            "ok": len([c for c in checks if c["status"] == "ok"]),
        },
        "blocking_issues": [c["name"] for c in blocking],
    }


# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────

GLYPH = {"ok": "✓", "warning": "⚠", "blocking": "✗", "info": "·"}


def render_human(report: dict) -> str:
    lines = []
    lines.append(f"=== Preflight — work_type={report['work_type']}"
                 f"{' feature=' + report['feature'] if report['feature'] else ''} ===")
    lines.append(f"Generated: {report['generated_at']}")
    lines.append("")
    for c in report["checks"]:
        g = GLYPH.get(c["status"], "?")
        lines.append(f"  {g} {c['name']:<28} {c['detail']}")
    lines.append("")
    s = report["summary"]
    lines.append(f"Summary: {s['ok']} ok · {s['warnings']} warning · {s['blocking']} blocking")
    if s["blocking"]:
        lines.append(f"\n✗ BLOCKING: {', '.join(report['blocking_issues'])}")
    else:
        lines.append("\n✓ No blocking issues. Cache written: .claude/shared/preflight-cache.json")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--work-type", choices=WORK_TYPES, required=True)
    ap.add_argument("--feature", default=None,
                    help="Feature name (required for enhancement; optional for feature)")
    ap.add_argument("--json", action="store_true",
                    help="Output machine-readable JSON")
    ap.add_argument("--quiet", action="store_true",
                    help="Suppress human output (still writes cache)")
    args = ap.parse_args()

    report = run_preflight(args.work_type, args.feature)

    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(report, indent=2))

    if args.json:
        print(json.dumps(report, indent=2))
    elif not args.quiet:
        print(render_human(report))

    return 1 if report["summary"]["blocking"] > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
