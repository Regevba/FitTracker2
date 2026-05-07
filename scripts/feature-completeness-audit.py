#!/usr/bin/env python3
"""T23 (framework-v7-8-branch-isolation): feature-completeness-audit.py

System-wide phase-appropriate completeness check. For every feature:
  - Research phase: schema basics (work_type, framework_version)
  - PRD phase: + cu_v2 + phases.prd.path
  - Tasks phase: + tasks[] populated
  - Implementation+: + phases.implementation.commits[]
  - Complete: + full FEATURE_CLOSURE_COMPLETENESS check

Output: punch list grouped by feature.
Exit 0 if 0 blocking findings; 1 otherwise.

Per PRD §6.2 + integration-spec §2.1. Replaces the manual reconcile pass.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"


def _load_check_state_schema():
    """Dynamically import check-state-schema.py for predicate reuse."""
    spec = importlib.util.spec_from_file_location(
        "_css", REPO_ROOT / "scripts" / "check-state-schema.py",
    )
    if spec is None or spec.loader is None:
        return None
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def _audit_feature(state_path: Path, css_module) -> list[dict]:
    """Run phase-appropriate checks; return list of findings.

    Forward-only by design: historical features (created before specific
    framework-feature ship dates) are exempt from checks the framework
    didn't enforce when they were created.
    """
    findings = []
    feature = state_path.parent.name
    try:
        state = json.loads(state_path.read_text())
    except json.JSONDecodeError as e:
        return [{"feature": feature, "phase": "?", "severity": "blocking",
                 "code": "INVALID_JSON", "message": str(e)}]

    phase = state.get("current_phase", "?")
    created = state.get("created_at") or state.get("created", "")
    created_date = created[:10] if created else ""

    V6_SHIP = "2026-04-16"      # cu_v2 introduction
    V7_6_SHIP = "2026-04-25"    # tasks discipline (v7.6)
    V7_8_SHIP = "2026-05-07"    # this feature's ship — closure-completeness gates

    is_terminal = phase in ("complete", "closed")
    is_recent = created_date >= V7_8_SHIP

    # Universal checks (all phases, all ages)
    if not state.get("work_type"):
        findings.append({"feature": feature, "phase": phase, "severity": "blocking",
                         "code": "MISSING_WORK_TYPE", "message": "state.json::work_type not set"})

    # Research phase — minimal requirements (forward-only on framework_version
    # since v7.6 introduced its enforcement)
    if phase == "research" and created_date >= V7_6_SHIP:
        if not state.get("framework_version"):
            findings.append({"feature": feature, "phase": phase, "severity": "advisory",
                             "code": "MISSING_FRAMEWORK_VERSION",
                             "message": "framework_version not set (recommended for v7.6+ features)"})

    # PRD phase — cu_v2 required (forward-only since V6 ship)
    if (phase == "prd" or _phase_index(phase) >= _phase_index("prd")) and not is_terminal:
        if created_date >= V6_SHIP and not (state.get("cu_v2") or state.get("complexity")):
            findings.append({"feature": feature, "phase": phase, "severity": "blocking",
                             "code": "MISSING_CU_V2",
                             "message": "cu_v2 (or complexity) required at PRD phase and beyond (post-V6)"})

    # Tasks phase — tasks[] populated (forward-only since v7.6, skip terminal)
    if _phase_index(phase) >= _phase_index("tasks") and not is_terminal:
        if created_date >= V7_6_SHIP and not state.get("tasks"):
            findings.append({"feature": feature, "phase": phase, "severity": "advisory",
                             "code": "EMPTY_TASKS",
                             "message": "tasks[] is empty post-tasks-phase (v7.6+ features)"})

    # Implementation phase — commits tracked (forward-only since v7.6, skip terminal)
    if _phase_index(phase) >= _phase_index("implementation") and not is_terminal:
        if created_date >= V7_6_SHIP:
            impl = (state.get("phases") or {}).get("implementation") or {}
            if isinstance(impl, dict) and not impl.get("commits"):
                findings.append({"feature": feature, "phase": phase, "severity": "advisory",
                                 "code": "NO_IMPL_COMMITS",
                                 "message": "phases.implementation.commits[] empty (v7.6+ features)"})

    # Complete phase — full closure-completeness (forward-only since v7.8 ship)
    if is_terminal and is_recent and css_module is not None:
        try:
            sub_findings = css_module.check_feature_closure_completeness(
                state, state_path, coverage=None, enforce_transition=True,
            )
            for sf in sub_findings:
                findings.append({
                    "feature": feature,
                    "phase": phase,
                    "severity": "advisory" if sf.get("advisory") else "blocking",
                    "code": sf.get("code", "FEATURE_CLOSURE_COMPLETENESS"),
                    "message": f"{sf.get('violation', 'unknown')}: {sf.get('remediation', '')[:120]}",
                })
        except Exception as e:
            findings.append({"feature": feature, "phase": phase, "severity": "advisory",
                             "code": "AUDIT_ERROR",
                             "message": f"closure-completeness predicate raised: {e}"})

    return findings


_PHASE_ORDER = [
    "research", "prd", "tasks", "ux_or_integration",
    "implementation", "test", "review", "merge",
    "documentation", "complete", "closed",
]


def _phase_index(phase: str) -> int:
    try:
        return _PHASE_ORDER.index(phase)
    except ValueError:
        return -1


def main() -> int:
    if not FEATURES_DIR.exists():
        print("No features directory.")
        return 0

    css = _load_check_state_schema()
    if css is None:
        print("⚠ Could not load check-state-schema.py; complete-phase checks skipped",
              file=sys.stderr)

    all_findings: list[dict] = []
    by_phase: dict[str, int] = {}
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        findings = _audit_feature(state_path, css)
        if findings:
            all_findings.extend(findings)
        try:
            state = json.loads(state_path.read_text())
            phase = state.get("current_phase", "?")
            by_phase[phase] = by_phase.get(phase, 0) + 1
        except json.JSONDecodeError:
            pass

    # Print summary
    print(f"Feature completeness audit")
    print("=" * 80)
    print(f"Phases: " + ", ".join(f"{p}={n}" for p, n in sorted(by_phase.items())))
    print()

    if not all_findings:
        print(f"✓ All {sum(by_phase.values())} features clean.")
        return 0

    # Group by phase
    findings_by_phase: dict[str, list[dict]] = {}
    for f in all_findings:
        findings_by_phase.setdefault(f["phase"], []).append(f)

    blocking_count = sum(1 for f in all_findings if f["severity"] == "blocking")
    advisory_count = sum(1 for f in all_findings if f["severity"] == "advisory")

    for phase, items in sorted(findings_by_phase.items(), key=lambda x: _phase_index(x[0])):
        print(f"{'✗' if any(f['severity'] == 'blocking' for f in items) else '⚠'} "
              f"{phase} phase ({len(items)} finding(s)):")
        for f in items:
            sev = "[BLOCK]" if f["severity"] == "blocking" else "[advisory]"
            print(f"  {sev} {f['feature']}: {f['code']} — {f['message'][:100]}")
        print()

    print(f"Total: {blocking_count} blocking + {advisory_count} advisory")
    return 1 if blocking_count > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
