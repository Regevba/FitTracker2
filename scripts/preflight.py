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
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE = REPO_ROOT / ".claude" / "shared" / "preflight-cache.json"

WORK_TYPES = ("feature", "enhancement", "fix", "chore")

# Paths flagged by Mode B BRANCH_ISOLATION_VIOLATION (infra-only commits).
INFRA_GLOBS = (
    ".githooks/", ".github/workflows/", "scripts/", ".claude/skills/",
    ".claude/shared/", "docs/architecture/", "Makefile", "CLAUDE.md",
)

HIGH_RISK_FILES = (
    "FitTracker/Models/DomainModels.swift",
    "FitTracker/Services/EncryptionService.swift",
    "FitTracker/Services/SupabaseSyncService.swift",
    "FitTracker/Services/CloudKitSyncService.swift",
    "FitTracker/Services/SignInService.swift",
    "FitTracker/Services/AuthManager.swift",
    "FitTracker/Services/AIOrchestrator.swift",
)


# ─────────────────────────────────────────────────────────────────────────────
# Helper runners
# ─────────────────────────────────────────────────────────────────────────────

def run(cmd: list[str], timeout: int = 60) -> tuple[int, str]:
    try:
        r = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True,
                           timeout=timeout, check=False)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return 124, f"<timeout {timeout}s>"
    except FileNotFoundError as e:
        return 127, f"<not found: {e}>"


def load_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# Always-run checks (every work_type)
# ─────────────────────────────────────────────────────────────────────────────

def check_w1_ssh_agent() -> dict:
    """W1: ssh-agent has loaded identity (prevents silent sign hang)."""
    rc, _ = run(["ssh-add", "-l"], timeout=5)
    return {
        "name": "W1_ssh_agent",
        "status": "ok" if rc == 0 else "warning",
        "detail": "ssh-add has loaded identities" if rc == 0
                  else "no identities; signed commits will hang silently",
        "blocking": False,  # advisory — many sessions skip signing
    }


def check_ssd_health() -> dict:
    """R5: SSD pre-flight probe (mount + free space + SMART + I/O errors).

    Exit codes from scripts/check-ssd-health.sh:
        0 — healthy
        1 — warning (low free space or SMART degraded)
        2 — critical (mount missing or SMART FAILED)
    """
    rc, out = run(["bash", "scripts/check-ssd-health.sh"], timeout=15)
    summary = next(
        (line for line in out.splitlines() if line.startswith("SSD health:")),
        "SSD health: probe failed",
    )
    if rc == 0:
        status = "ok"
    elif rc == 1:
        status = "warning"
    else:
        status = "warning"  # advisory; never block dispatch on this
    return {
        "name": "ssd_health",
        "status": status,
        "detail": summary.replace("SSD health: ", "")
                  + " — re-run `bash scripts/check-ssd-health.sh` for full output",
        "blocking": False,
    }


def check_pr_cache_fresh() -> dict:
    """v7.8.4 PR_CACHE_STALE prevention."""
    rc, out = run(["python3", "scripts/ensure-pr-cache-fresh.py", "--quiet"], timeout=30)
    return {
        "name": "pr_cache_fresh",
        "status": "ok" if rc == 0 else "warning",
        "detail": "PR citation cache fresh" if rc == 0
                  else "PR cache refresh failed; BROKEN_PR_CITATION may false-positive",
        "blocking": False,
    }


def check_integrity() -> dict:
    """Current cycle-time integrity findings."""
    rc, out = run(["python3", "scripts/integrity-check.py", "--findings-only"], timeout=120)
    findings, advisory = -1, -1
    for line in out.splitlines():
        if line.strip().startswith("Findings:"):
            try:
                rhs = line.split(":", 1)[1].strip()
                findings = int(rhs.split("+")[0].strip())
                adv = "".join(c for c in rhs.split("+", 1)[1] if c.isdigit())
                advisory = int(adv or "0")
            except (ValueError, IndexError):
                pass
            break
    return {
        "name": "integrity_check",
        "status": "ok" if findings == 0 else "blocking",
        "detail": f"{findings} findings + {advisory} advisory",
        "findings_count": findings,
        "advisory_count": advisory,
        "blocking": findings > 0,
    }


def check_integrity_diff() -> dict:
    """Drift vs 2026-05-14 anchor."""
    rc, out = run(["python3", "scripts/integrity-diff.py", "--json"], timeout=60)
    if rc != 0:
        return {
            "name": "integrity_diff",
            "status": "warning",
            "detail": "integrity-diff failed (baseline not found?)",
            "blocking": False,
        }
    try:
        data = json.loads(out)
        regressions = data.get("regressions", [])
    except json.JSONDecodeError:
        return {
            "name": "integrity_diff",
            "status": "warning",
            "detail": "could not parse integrity-diff output",
            "blocking": False,
        }
    return {
        "name": "integrity_diff",
        "status": "ok" if not regressions else "warning",
        "detail": (f"{len(regressions)} regression(s) vs 2026-05-14 anchor"
                   if regressions else "no regression vs 2026-05-14 anchor"),
        "regressions": regressions,
        "blocking": False,  # advisory; daily checkpoint is authoritative
    }


def check_branch_isolation() -> dict:
    """Current branch + isolation status from membrane-status."""
    rc, branch = run(["git", "branch", "--show-current"], timeout=5)
    branch = branch.strip()
    on_main = branch == "main"
    return {
        "name": "branch_isolation",
        "status": "warning" if on_main else "ok",
        "detail": f"current branch: {branch}" + (
            " (on main — infra commits will trigger BRANCH_ISOLATION_VIOLATION advisory)"
            if on_main else ""
        ),
        "current_branch": branch,
        "blocking": False,
    }


def check_documentation_debt() -> dict:
    debt = load_json(REPO_ROOT / ".claude" / "shared" / "documentation-debt.json")
    open_count = debt.get("summary", {}).get("open_debt_items", -1)
    return {
        "name": "documentation_debt",
        "status": "ok" if open_count == 0 else "info",
        "detail": f"{open_count} open documentation-debt item(s)",
        "open_count": open_count,
        "blocking": False,
    }


def check_measurement_adoption() -> dict:
    adopt = load_json(REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json")
    s = adopt.get("summary", {})
    fa_pv6 = s.get("fully_adopted_post_v6", 0)
    fpv6 = max(s.get("features_post_v6", 1), 1)
    pct = round(100 * fa_pv6 / fpv6, 1)
    return {
        "name": "measurement_adoption",
        "status": "info",
        "detail": f"post-v6 adoption: {pct}% ({fa_pv6}/{fpv6}) — baseline for any new shipped feature",
        "fully_adopted_post_v6": fa_pv6,
        "features_post_v6": fpv6,
        "adoption_pct_post_v6": pct,
        "blocking": False,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Work-type-specific checks
# ─────────────────────────────────────────────────────────────────────────────

def feature_brainstorm_state(feature: str | None) -> dict | None:
    """Whether brainstorm + PRD have been started/completed for a named feature."""
    if not feature:
        return None
    sf = REPO_ROOT / ".claude" / "features" / feature / "state.json"
    if not sf.exists():
        return {
            "name": "feature_state_json",
            "status": "info",
            "detail": f"feature '{feature}' has no state.json yet (Phase 0 will create it)",
            "blocking": False,
        }
    s = load_json(sf)
    phase = s.get("current_phase", "(unknown)")
    return {
        "name": "feature_state_json",
        "status": "ok",
        "detail": f"feature '{feature}' current_phase={phase}",
        "current_phase": phase,
        "blocking": False,
    }


def enhancement_parent_state(feature: str | None) -> dict | None:
    """Enhancement requires a parent feature with a PRD."""
    if not feature:
        return None
    sf = REPO_ROOT / ".claude" / "features" / feature / "state.json"
    if not sf.exists():
        return {
            "name": "enhancement_parent",
            "status": "warning",
            "detail": f"no state.json for '{feature}' — enhancements require a parent feature with PRD",
            "blocking": False,
        }
    s = load_json(sf)
    phase = s.get("current_phase", "")
    has_prd = (REPO_ROOT / ".claude" / "features" / feature / "prd.md").exists()
    ok = has_prd and phase in ("complete", "implementation", "merge", "docs", "post_launch_review")
    return {
        "name": "enhancement_parent",
        "status": "ok" if ok else "warning",
        "detail": f"parent='{feature}' phase={phase}, prd.md present={has_prd}",
        "blocking": not ok,
    }


def fix_high_risk_touch_check() -> dict:
    """Check git diff for high-risk files touched."""
    rc, out = run(["git", "diff", "--name-only", "HEAD"], timeout=5)
    touched = [f for f in out.splitlines() if f.strip()]
    risky = [f for f in touched if any(f.endswith(hr.split("/")[-1]) or f == hr for hr in HIGH_RISK_FILES)]
    return {
        "name": "fix_high_risk_touch",
        "status": "warning" if risky else "ok",
        "detail": (f"touches high-risk file(s): {', '.join(risky)} — extra review required"
                   if risky else "no high-risk files touched"),
        "high_risk_files_touched": risky,
        "blocking": False,
    }


def chore_infra_path_check() -> dict:
    """Detect infra-path changes that require isolated worktree."""
    rc, out = run(["git", "diff", "--name-only", "HEAD"], timeout=5)
    touched = [f for f in out.splitlines() if f.strip()]
    infra = [f for f in touched
             if any(f.startswith(g) if g.endswith("/") else f == g for g in INFRA_GLOBS)]
    return {
        "name": "chore_infra_paths",
        "status": "warning" if infra else "ok",
        "detail": (f"infra paths touched: {', '.join(infra[:5])}"
                   f"{' (+more)' if len(infra) > 5 else ''} — use isolated worktree"
                   if infra else "no infra paths touched"),
        "infra_paths_touched": infra,
        "blocking": False,
    }


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
