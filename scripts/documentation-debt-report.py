#!/usr/bin/env python3
"""Generate a baseline documentation-debt report for case studies and feature links."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CASE_STUDY_ROOT = REPO_ROOT / "docs" / "case-studies"
FEATURE_ROOT = REPO_ROOT / ".claude" / "features"
SNAPSHOT_ROOT = REPO_ROOT / ".claude" / "integrity" / "snapshots"

EXCLUDED_CASE_STUDIES = {
    "README.md",
    "case-study-template.md",
    "normalization-framework.md",
    "fittracker-evolution-walkthrough.md",
    "pm-workflow-evolution-v1-to-v4.md",
    "pm-workflow-skill.md",
    "data-quality-tiers.md",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def percent(present: int, total: int) -> float:
    return round((present / total) * 100, 1) if total else 0.0


def severity_for_ratio(missing: int, total: int, structural: bool = False) -> str:
    if total == 0:
        return "low"
    ratio = missing / total
    if structural and ratio >= 0.2:
        return "high"
    if ratio >= 0.5:
        return "high"
    if ratio >= 0.2:
        return "medium"
    return "low"


def candidate_case_studies() -> list[Path]:
    files: list[Path] = []
    for path in sorted(CASE_STUDY_ROOT.rglob("*.md")):
        if "meta-analysis" in path.parts:
            continue
        if path.name in EXCLUDED_CASE_STUDIES:
            continue
        files.append(path)
    return files


def scan_case_study(path: Path) -> dict[str, object]:
    text = path.read_text()
    return {
        "path": path.relative_to(REPO_ROOT).as_posix(),
        # date_written: body format OR YAML frontmatter key
        "has_date_written": bool(re.search(r"(?im)(^\*\*Date written:\*\*|^>\s*\*\*Date:\*\*|^\|\s*Date written\s*\||^date_written\s*:)", text)),
        # work_type: body text OR YAML frontmatter key
        "has_work_type": bool(re.search(r"(?im)(^\|\s*Work Type\s*\||\bWork Type\b|^work_type\s*:)", text)),
        # dispatch_pattern: body phrase OR YAML frontmatter key
        "has_dispatch_pattern": bool(re.search(r"(?im)(dispatch pattern|^dispatch_pattern\s*:)", text)),
        # success_metrics: body phrase OR YAML frontmatter key
        "has_success_metrics": bool(re.search(r"(?im)(success metrics?|primary metric|^success_metrics\s*:)", text)),
        # kill_criteria: body phrase OR YAML frontmatter key
        "has_kill_criteria": bool(re.search(r"(?im)(kill criteria|^kill_criteria\s*:)", text)),
    }


def build_coverage(items: list[dict[str, object]], key: str) -> dict[str, object]:
    total = len(items)
    present = sum(1 for item in items if item[key])
    missing_paths = [item["path"] for item in items if not item[key]]
    return {
        "present": present,
        "missing": total - present,
        "percent": percent(present, total),
        "examples": missing_paths[:5],
    }


def feature_case_study_linkage() -> dict[str, object]:
    states = sorted(FEATURE_ROOT.glob("*/state.json"))
    linked = 0
    missing: list[str] = []

    for state_path in states:
        data = json.loads(state_path.read_text())
        has_link = any(
            data.get(key) for key in ("case_study", "case_study_link", "case_study_path", "parent_case_study")
        ) or bool(data.get("case_study_type"))
        if has_link:
            linked += 1
        else:
            missing.append(state_path.parent.name)

    total = len(states)
    return {
        "present": linked,
        "missing": total - linked,
        "percent": percent(linked, total),
        "examples": missing[:5],
        "total": total,
    }


def load_snapshot_inventory() -> dict[str, int]:
    total_files = 0
    cycle_eligible = 0
    legacy_without_context = 0

    for path in sorted(SNAPSHOT_ROOT.glob("*.json")):
        total_files += 1
        try:
            payload = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue

        context = payload.get("snapshot_context")
        if isinstance(context, dict):
            if context.get("counts_for_trend") is True:
                cycle_eligible += 1
        else:
            legacy_without_context += 1

    return {
        "total_files": total_files,
        "cycle_eligible": cycle_eligible,
        "legacy_without_context": legacy_without_context,
    }


def build_debt_items(case_studies: list[dict[str, object]], coverage: dict[str, object], linkage: dict[str, object], cycle_snapshot_count: int) -> list[dict[str, object]]:
    total = len(case_studies)
    items = []

    mapping = {
        "date_written": "Case studies missing a written-date marker",
        "work_type": "Case studies missing explicit work-type metadata",
        "dispatch_pattern": "Case studies missing explicit dispatch-pattern declaration",
        "success_metrics": "Case studies missing success-metric restatement",
        "kill_criteria": "Case studies missing kill-criteria restatement",
    }

    for short_key, title in mapping.items():
        metric = coverage[short_key]
        if metric["missing"] == 0:
            continue
        items.append({
            "id": short_key,
            "title": title,
            "severity": severity_for_ratio(metric["missing"], total),
            "count": metric["missing"],
            "examples": metric["examples"],
            "recommended_next_step": f"Touch the missing files opportunistically and add the missing {short_key.replace('_', ' ')} field explicitly.",
        })

    if linkage["missing"] > 0:
        items.append({
            "id": "state_case_study_linkage",
            "title": "Features missing case-study linkage in state.json",
            "severity": severity_for_ratio(linkage["missing"], linkage["total"], structural=True),
            "count": linkage["missing"],
            "examples": linkage["examples"],
            "recommended_next_step": "Backfill case-study linkage or an explicit case_study_type marker when feature state is touched.",
        })

    if cycle_snapshot_count < 3:
        items.append({
            "id": "integrity_trend_window",
            "title": "Integrity-cycle history is too short for trustworthy documentation-debt trends",
            "severity": "medium",
            "count": 3 - cycle_snapshot_count,
            "examples": [],
            "recommended_next_step": "Wait for at least 2-3 scheduled 72h cycle snapshots before treating dashboard trend lines as meaningful.",
        })

    return items


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(REPO_ROOT / ".claude" / "shared" / "documentation-debt.json"),
        help="Output path for the generated JSON report.",
    )
    args = parser.parse_args()

    scanned = [scan_case_study(path) for path in candidate_case_studies()]
    linkage = feature_case_study_linkage()
    snapshot_inventory = load_snapshot_inventory()
    snapshot_count = snapshot_inventory["cycle_eligible"]

    coverage = {
        "date_written": build_coverage(scanned, "has_date_written"),
        "work_type": build_coverage(scanned, "has_work_type"),
        "dispatch_pattern": build_coverage(scanned, "has_dispatch_pattern"),
        "success_metrics": build_coverage(scanned, "has_success_metrics"),
        "kill_criteria": build_coverage(scanned, "has_kill_criteria"),
        "state_case_study_linkage": {
            "present": linkage["present"],
            "missing": linkage["missing"],
            "percent": linkage["percent"],
            "examples": linkage["examples"],
        },
    }

    debt_items = build_debt_items(scanned, coverage, linkage, snapshot_count)
    report = {
        "version": "1.0",
        "updated": utc_now(),
        "description": "Baseline documentation-debt report for case-study structure, state linkage, and integrity-cycle readiness.",
        "summary": {
            "case_studies_scanned": len(scanned),
            "features_scanned": linkage["total"],
            "integrity_snapshot_files": snapshot_inventory["total_files"],
            "integrity_cycle_snapshots": snapshot_count,
            "trend_ready": snapshot_count >= 3,
            "open_debt_items": len(debt_items),
        },
        "coverage": coverage,
        "integrity_cycle": {
            "snapshot_files_available": snapshot_inventory["total_files"],
            "snapshots_available": snapshot_count,
            "legacy_snapshot_files_without_context": snapshot_inventory["legacy_without_context"],
            "trend_ready": snapshot_count >= 3,
            "status": "baseline_only" if snapshot_count < 3 else "trend_ready",
            "notes": "Point-in-time debt metrics are usable immediately. Trend analysis waits for multiple scheduled 72h cycle snapshots; ad hoc local snapshots do not unlock trend mode.",
        },
        "debt_items": debt_items,
    }

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n")
    print(str(output_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
