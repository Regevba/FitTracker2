#!/usr/bin/env python3
"""
State.json integrity check + snapshot + cross-cycle diff.

Scans .claude/features/*/state.json for inconsistencies (phase lies, task lies,
missing case-study linkage) and produces a snapshot JSON. When run with
--compare-to, also emits a diff vs a previous snapshot.

Usage:
    scripts/integrity-check.py --snapshot .claude/integrity/snapshots/2026-04-20T04-00Z.json
    scripts/integrity-check.py --snapshot <new> --compare-to <previous>
    scripts/integrity-check.py --findings-only

Exit codes:
    0  clean / same-or-better-than-previous
    1  new findings introduced OR features disappeared since previous

Designed to run both locally (make integrity-check) and in the 72h GitHub
Actions cycle (.github/workflows/integrity-cycle.yml).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
CASE_STUDIES_DIR = REPO_ROOT / "docs" / "case-studies"

COMPLETE_PHASE_STATUSES = {"approved", "complete", "completed", "done", "skipped", "closed"}
OPEN_TASK_STATUSES = {"pending", "in_progress", "open", "blocked"}
TERMINAL_FEATURE_PHASES = {"complete", "completed", "closed", "done", "cancelled"}

SKIP_CASE_STUDY_FILES = {"README.md", "case-study-template.md"}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except Exception:
        return "unknown"


def first_commit_date(path: Path) -> str | None:
    try:
        rel = path.relative_to(REPO_ROOT)
    except ValueError:
        return None
    try:
        out = subprocess.check_output(
            [
                "git", "-C", str(REPO_ROOT), "log",
                "--follow", "--diff-filter=A", "--format=%ad", "--date=short",
                "--", str(rel),
            ],
            text=True,
        ).strip()
    except Exception:
        return None
    lines = [l for l in out.splitlines() if l]
    return lines[-1] if lines else None


def feature_phase(d: dict) -> str | None:
    return d.get("current_phase") or d.get("phase")


def audit_feature(feat_dir: Path) -> tuple[dict, list[dict]]:
    """Audit one feature directory. Returns (summary, findings)."""
    findings: list[dict] = []
    state_path = feat_dir / "state.json"
    summary = {
        "name": feat_dir.name,
        "phase": None,
        "case_study": None,
        "case_study_type": None,
        "task_total": 0,
        "task_completed": 0,
        "state_hash": None,
    }
    if not state_path.exists():
        findings.append({
            "feature": feat_dir.name, "severity": "CRITICAL", "code": "NO_STATE",
            "message": "no state.json",
        })
        return summary, findings

    raw = state_path.read_text()
    summary["state_hash"] = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
    try:
        d = json.loads(raw)
    except Exception as e:
        findings.append({
            "feature": feat_dir.name, "severity": "CRITICAL", "code": "INVALID_JSON",
            "message": f"invalid JSON: {e}",
        })
        return summary, findings

    feat = d.get("feature", feat_dir.name)
    summary["name"] = feat
    phase = feature_phase(d)
    summary["phase"] = phase
    summary["case_study"] = d.get("case_study") or d.get("parent_case_study")
    summary["case_study_type"] = d.get("case_study_type")

    if phase is None:
        findings.append({
            "feature": feat, "severity": "WARN", "code": "NO_PHASE",
            "message": "no phase field (neither current_phase nor phase)",
        })
        return summary, findings

    # Task summary
    tasks_raw = d.get("tasks")
    task_list: list = []
    if isinstance(tasks_raw, list):
        task_list = tasks_raw
    elif isinstance(tasks_raw, dict):
        task_list = tasks_raw.get("task_list", []) or []
    summary["task_total"] = len([t for t in task_list if isinstance(t, dict)])
    summary["task_completed"] = sum(
        1 for t in task_list
        if isinstance(t, dict) and t.get("status") in ("completed", "done", "complete")
    )

    is_terminal = phase in TERMINAL_FEATURE_PHASES

    # Phase-lie exemptions:
    # - pre-PM-workflow backfills (use legacy phase vocabulary)
    # - roundup-classified features (covered by consolidation CS, sub-phase granularity not meaningful)
    cs_type = d.get("case_study_type")
    is_phase_check_exempt = cs_type in ("pre_pm_workflow_backfill", "roundup")

    # Check #1: phase lie
    if is_terminal and not is_phase_check_exempt:
        incomplete = []
        for pname, pobj in (d.get("phases") or {}).items():
            if not isinstance(pobj, dict):
                continue
            pstatus = pobj.get("status")
            if pstatus and pstatus not in COMPLETE_PHASE_STATUSES and pstatus != "pending_na":
                incomplete.append(f"{pname}={pstatus}")
        if incomplete:
            findings.append({
                "feature": feat, "severity": "INCONSISTENT", "code": "PHASE_LIE",
                "message": f"top-level {phase} but sub-phases not approved: {', '.join(incomplete)}",
            })

    # Check #2: task lie
    if is_terminal and task_list:
        open_tasks = [
            t for t in task_list
            if isinstance(t, dict) and t.get("status") in OPEN_TASK_STATUSES
        ]
        if open_tasks:
            ids = [t.get("id", "?") for t in open_tasks[:10]]
            findings.append({
                "feature": feat, "severity": "INCONSISTENT", "code": "TASK_LIE",
                "message": f"top-level {phase} but {len(open_tasks)} tasks not done: {','.join(ids)}"
                           + (",…" if len(open_tasks) > 10 else ""),
            })

    # Check #3: missing case-study linkage (excluding roundup + backfill)
    if is_terminal and not is_phase_check_exempt:
        has_cs = bool(d.get("case_study") or d.get("parent_case_study"))
        if not has_cs and d.get("case_study_type") != "roundup":
            findings.append({
                "feature": feat, "severity": "MISSING", "code": "NO_CS_LINK",
                "message": "terminal phase but no case_study / parent_case_study / case_study_type linkage",
            })

    # Check #4: declared v2 file missing
    v2_path = d.get("v2_file_path")
    if v2_path and is_terminal:
        full = REPO_ROOT / v2_path
        if not full.exists():
            findings.append({
                "feature": feat, "severity": "MISSING", "code": "V2_FILE_MISSING",
                "message": f"v2_file_path declared ({v2_path}) but file does not exist",
            })

    # Check #5: partial_ship flagged alongside terminal phase
    if is_terminal and d.get("partial_ship") is True:
        findings.append({
            "feature": feat, "severity": "INCONSISTENT", "code": "PARTIAL_SHIP_TERMINAL",
            "message": "partial_ship=true with terminal phase — should be downgraded OR flag removed",
        })

    return summary, findings


def discover_case_studies() -> list[dict]:
    results = []
    if not CASE_STUDIES_DIR.exists():
        return results
    for f in sorted(CASE_STUDIES_DIR.glob("*.md")):
        if f.name in SKIP_CASE_STUDY_FILES:
            continue
        stat = f.stat()
        results.append({
            "path": str(f.relative_to(REPO_ROOT)),
            "size_bytes": stat.st_size,
            "first_commit_date": first_commit_date(f),
        })
    return results


def build_snapshot() -> dict:
    feature_summaries = []
    findings = []
    for d in sorted(FEATURES_DIR.iterdir()) if FEATURES_DIR.exists() else []:
        if not d.is_dir():
            continue
        summary, feat_findings = audit_feature(d)
        feature_summaries.append(summary)
        findings.extend(feat_findings)
    return {
        "timestamp": now_iso(),
        "commit_head": git_head(),
        "feature_count": len(feature_summaries),
        "case_study_count": len(discover_case_studies()),
        "finding_count": len(findings),
        "findings_by_severity": {
            sev: sum(1 for x in findings if x["severity"] == sev)
            for sev in ["CRITICAL", "INCONSISTENT", "MISSING", "WARN"]
        },
        "features": feature_summaries,
        "case_studies": discover_case_studies(),
        "findings": findings,
    }


def diff_snapshots(current: dict, previous: dict) -> dict:
    prev_feats = {f["name"]: f for f in previous.get("features", [])}
    curr_feats = {f["name"]: f for f in current.get("features", [])}
    added = sorted(set(curr_feats) - set(prev_feats))
    removed = sorted(set(prev_feats) - set(curr_feats))
    changed = []
    for name in sorted(set(curr_feats) & set(prev_feats)):
        pf, cf = prev_feats[name], curr_feats[name]
        if pf.get("phase") != cf.get("phase"):
            changed.append({"name": name, "field": "phase",
                            "from": pf.get("phase"), "to": cf.get("phase")})
        if pf.get("state_hash") != cf.get("state_hash") and \
           pf.get("phase") == cf.get("phase"):
            changed.append({"name": name, "field": "state_hash",
                            "from": pf.get("state_hash"), "to": cf.get("state_hash")})
        if pf.get("case_study") != cf.get("case_study"):
            changed.append({"name": name, "field": "case_study",
                            "from": pf.get("case_study"), "to": cf.get("case_study")})

    prev_cs = {c["path"] for c in previous.get("case_studies", [])}
    curr_cs = {c["path"] for c in current.get("case_studies", [])}
    cs_added = sorted(curr_cs - prev_cs)
    cs_removed = sorted(prev_cs - curr_cs)

    prev_findings = {(f["feature"], f["code"]) for f in previous.get("findings", [])}
    curr_findings = {(f["feature"], f["code"]) for f in current.get("findings", [])}
    findings_new = sorted(curr_findings - prev_findings)
    findings_resolved = sorted(prev_findings - curr_findings)

    return {
        "previous_timestamp": previous.get("timestamp"),
        "current_timestamp": current.get("timestamp"),
        "features": {"added": added, "removed": removed, "changed": changed},
        "case_studies": {"added": cs_added, "removed": cs_removed},
        "findings": {
            "new": [{"feature": f, "code": c} for f, c in findings_new],
            "resolved": [{"feature": f, "code": c} for f, c in findings_resolved],
            "prev_count": previous.get("finding_count", 0),
            "curr_count": current.get("finding_count", 0),
        },
    }


def render_findings(findings: list[dict]) -> str:
    if not findings:
        return "✅ No findings."
    lines = [f"{len(findings)} findings:\n"]
    by_sev: dict[str, list] = {}
    for f in findings:
        by_sev.setdefault(f["severity"], []).append(f)
    for sev in ["CRITICAL", "INCONSISTENT", "MISSING", "WARN"]:
        if sev not in by_sev:
            continue
        lines.append(f"## {sev} ({len(by_sev[sev])})")
        for f in sorted(by_sev[sev], key=lambda x: x["feature"]):
            lines.append(f"  - {f['feature']} [{f['code']}]: {f['message']}")
        lines.append("")
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--snapshot", help="Write snapshot to this path")
    p.add_argument("--compare-to", help="Previous snapshot path for diff")
    p.add_argument("--findings-only", action="store_true",
                   help="Print findings to stdout, no file writes")
    p.add_argument("--strict", action="store_true",
                   help="Exit 1 on ANY findings (default: only on regressions)")
    args = p.parse_args()

    snapshot = build_snapshot()
    print(f"Features scanned: {snapshot['feature_count']}")
    print(f"Case studies: {snapshot['case_study_count']}")
    print(f"Findings: {snapshot['finding_count']} "
          f"({', '.join(f'{k}={v}' for k, v in snapshot['findings_by_severity'].items() if v)})")
    print()
    print(render_findings(snapshot["findings"]))

    if args.findings_only:
        sys.exit(1 if (args.strict and snapshot["finding_count"]) else 0)

    if args.snapshot:
        sp = Path(args.snapshot)
        sp.parent.mkdir(parents=True, exist_ok=True)
        sp.write_text(json.dumps(snapshot, indent=2) + "\n")
        print(f"\nSnapshot written: {sp}")

    if args.compare_to:
        prev = json.loads(Path(args.compare_to).read_text())
        diff = diff_snapshots(snapshot, prev)
        print("\n=== Diff vs previous ===")
        print(json.dumps(diff, indent=2))

        # Exit status
        regression = (
            bool(diff["features"]["removed"]) or
            bool(diff["case_studies"]["removed"]) or
            bool(diff["findings"]["new"])
        )
        if regression:
            print("\n❌ REGRESSION detected vs previous snapshot.")
            sys.exit(1)
        print("\n✅ No regression vs previous snapshot.")

    if args.strict and snapshot["finding_count"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
