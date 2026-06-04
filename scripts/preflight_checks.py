#!/usr/bin/env python3
"""
Shared preflight check functions — importable module.

Extracted from `scripts/preflight.py` (v7.9.1, pattern↔skill preflight overlay)
so that BOTH the unified `make preflight` runner AND the per-skill
`scripts/skill-preflight.py` overlay runner share one implementation of every
mechanized probe. No behavior change to `make preflight`: `preflight.py`
imports these functions and the public contract (exit codes 0/1/2 + the
`.claude/shared/preflight-cache.json` schema) is preserved verbatim.

Each check returns a dict of shape:

    {"name": str, "status": "ok"|"warning"|"blocking"|"info",
     "detail": str, "blocking": bool, ...check-specific fields...}

Two probes are NEW in the overlay (not part of the original preflight set,
used only by the skill-preflight overlay):
    - check_branch_drift()             — W9 mechanized probe
    - check_workflow_name_collision()  — W26 thin grep probe
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

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
    """Enhancement requires a PARENT feature with a PRD.

    Bug-fix 2026-05-23 (C12): the original implementation read
    `feature/state.json` + `feature/prd.md` directly — but the caller
    passes the ENHANCEMENT's own name. Enhancements don't have their own
    PRD; they extend a parent feature's PRD. So the check was always
    looking at the wrong file and false-positive-blocking when the
    enhancement's directory had no prd.md (which it never does).

    Correct path: read the enhancement's state.json, extract its
    `parent_feature` field, then check THAT parent's state.json + prd.md.
    """
    if not feature:
        return None

    # Read the enhancement's own state.json first to find its parent.
    own_sf = REPO_ROOT / ".claude" / "features" / feature / "state.json"
    if not own_sf.exists():
        return {
            "name": "enhancement_parent",
            "status": "warning",
            "detail": f"no state.json for enhancement '{feature}' — Phase 0 will create it",
            "blocking": False,
        }
    own_s = load_json(own_sf)
    parent_name = own_s.get("parent_feature")
    if not parent_name:
        return {
            "name": "enhancement_parent",
            "status": "warning",
            "detail": f"enhancement '{feature}' has no `parent_feature` field — set it before continuing",
            "blocking": True,
        }

    # Now check the PARENT's state.
    parent_sf = REPO_ROOT / ".claude" / "features" / parent_name / "state.json"
    if not parent_sf.exists():
        return {
            "name": "enhancement_parent",
            "status": "warning",
            "detail": f"parent_feature='{parent_name}' has no state.json — invalid parent reference",
            "blocking": True,
        }
    parent_s = load_json(parent_sf)
    parent_phase = parent_s.get("current_phase", "")
    has_prd = (REPO_ROOT / ".claude" / "features" / parent_name / "prd.md").exists()
    ok = has_prd and parent_phase in ("complete", "implementation", "merge", "docs", "post_launch_review")
    return {
        "name": "enhancement_parent",
        "status": "ok" if ok else "warning",
        "detail": f"parent='{parent_name}' phase={parent_phase}, prd.md present={has_prd}",
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
# Overlay-only probes (W9, W26) — used by scripts/skill-preflight.py
# ─────────────────────────────────────────────────────────────────────────────

def check_branch_drift() -> dict:
    """W9: concurrent-session `git checkout` HEAD-flip detector.

    Runs scripts/check-branch-drift.py (the PostToolUse:Bash hook). On the
    first invocation in a session it records the branch baseline (status ok);
    on a later invocation where HEAD flipped it emits a LOUD stderr warning.
    """
    rc, out = run(["python3", "scripts/check-branch-drift.py"], timeout=10)
    drifted = "BRANCH DRIFT DETECTED" in out
    return {
        "name": "W9_branch_drift",
        "status": "warning" if drifted else "ok",
        "detail": ("branch drift detected — another session flipped HEAD; "
                   "see W9 recovery playbook" if drifted
                   else "no branch drift since last check"),
        "blocking": False,
    }


def check_workflow_name_collision() -> dict:
    """W26: two workflow files sharing `name:` clash in concurrency groups.

    Thin grep probe — scans `.github/workflows/*.yml` for duplicate top-level
    `name:` values. Duplicates that also use `${{ github.workflow }}` in their
    concurrency group will cross-cancel each other and block merges.
    """
    wf_dir = REPO_ROOT / ".github" / "workflows"
    names: dict[str, list[str]] = {}
    if wf_dir.is_dir():
        for f in sorted(wf_dir.glob("*.yml")) + sorted(wf_dir.glob("*.yaml")):
            try:
                for line in f.read_text().splitlines():
                    stripped = line.strip()
                    if stripped.startswith("name:") and not line.startswith(" "):
                        val = stripped.split(":", 1)[1].strip().strip('"').strip("'")
                        names.setdefault(val, []).append(f.name)
                        break  # only the first top-level name:
            except OSError:
                continue
    dups = {n: fs for n, fs in names.items() if len(fs) > 1}
    return {
        "name": "W26_workflow_name_collision",
        "status": "warning" if dups else "ok",
        "detail": ("duplicate workflow name(s): "
                   + "; ".join(f"{n!r} in {', '.join(fs)}" for n, fs in dups.items())
                   + " — audit concurrency groups (W26)" if dups
                   else "no duplicate workflow names"),
        "duplicate_names": dups,
        "blocking": False,
    }
