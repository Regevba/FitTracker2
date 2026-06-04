#!/usr/bin/env python3
"""
Per-skill pattern preflight overlay (v7.9.1 pattern↔skill overlay).

When one of the 12 skills (`.claude/skills/*`) activates, it should know
exactly which Observed-Patterns-Catalog patterns can block its kind of work,
and proactively probe the mechanized ones so blockers are cleared BEFORE work
begins. HYBRID approach:

  - mechanized patterns (detector != "manual") → run the probe now
  - manual / compile / discipline patterns       → emit an awareness checklist

Usage
-----
  python3 scripts/skill-preflight.py --skill <name> [--json]
  make skill-preflight SKILL=<name>

Reads
-----
  .claude/shared/pattern-skill-map.json   (source of truth — 51 patterns)

Writes (ADDITIVE — never clobbers existing keys)
-----
  .claude/shared/preflight-cache.json :: skill_overlay.<skill> = {
      "generated_at", "checked": [...], "blocking": [...],
      "advisory": [...], "manual": [...]
  }

Exit codes
----------
  0  — no mechanized blocker tripped (advisories / manual items OK)
  1  — a blocker-tagged detector tripped
  2  — invalid inputs (unknown skill, missing map)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

# Reuse the shared probe implementations (single source of truth).
from preflight_checks import (
    REPO_ROOT,
    check_integrity,
    check_pr_cache_fresh,
    check_w1_ssh_agent,
    check_branch_drift,
    check_workflow_name_collision,
)

MAP_PATH = REPO_ROOT / ".claude" / "shared" / "pattern-skill-map.json"
CACHE = REPO_ROOT / ".claude" / "shared" / "preflight-cache.json"

VALID_SKILLS = (
    "pm-workflow", "dev", "qa", "design", "ops", "release",
    "marketing", "analytics", "cx", "research", "ux", "brainstorm-pm",
)

# detector path → callable probe (lazy: invoked at most once per run + cached)
DETECTOR_PROBES = {
    "scripts/integrity-check.py": check_integrity,
    "scripts/ensure-pr-cache-fresh.py": check_pr_cache_fresh,
    "scripts/check-ssh-agent.sh": check_w1_ssh_agent,
    "scripts/check-branch-drift.py": check_branch_drift,
    "scripts/preflight_checks.py": check_workflow_name_collision,
}


def load_map() -> list[dict]:
    return json.loads(MAP_PATH.read_text())


def run_skill_preflight(skill: str) -> dict:
    patterns = [p for p in load_map() if skill in p.get("skills", [])]

    probe_cache: dict[str, dict] = {}

    def probe(detector: str) -> dict:
        if detector not in probe_cache:
            fn = DETECTOR_PROBES.get(detector)
            probe_cache[detector] = fn() if fn else {
                "status": "info", "blocking": False,
                "detail": f"no overlay probe registered for {detector}",
            }
        return probe_cache[detector]

    checked: list[dict] = []
    blocking: list[dict] = []
    advisory: list[dict] = []
    manual: list[dict] = []

    for p in patterns:
        base = {
            "id": p["id"],
            "title": p["title"],
            "blocker": p["blocker"],
            "remediation": p["remediation"],
        }
        detector = p.get("detector", "manual")

        if detector == "manual":
            manual.append({**base, "detector": "manual"})
            continue

        result = probe(detector)
        tripped = bool(result.get("blocking")) or result.get("status") in ("blocking", "warning")
        rec = {**base, "detector": detector,
               "status": result.get("status", "info"),
               "detail": result.get("detail", "")}
        checked.append(rec)
        if tripped and p["blocker"]:
            blocking.append(rec)
        elif tripped:
            advisory.append(rec)

    return {
        "skill": skill,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checked": checked,
        "blocking": blocking,
        "advisory": advisory,
        "manual": manual,
    }


def write_overlay(skill: str, overlay: dict) -> None:
    """Additively merge skill_overlay.<skill> into the existing cache."""
    cache: dict = {}
    if CACHE.exists():
        try:
            cache = json.loads(CACHE.read_text())
        except json.JSONDecodeError:
            cache = {}
    cache.setdefault("skill_overlay", {})
    cache["skill_overlay"][skill] = {
        "generated_at": overlay["generated_at"],
        "checked": [r["id"] for r in overlay["checked"]],
        "blocking": [r["id"] for r in overlay["blocking"]],
        "advisory": [r["id"] for r in overlay["advisory"]],
        "manual": [r["id"] for r in overlay["manual"]],
    }
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(cache, indent=2) + "\n")


GLYPH = {"ok": "✓", "warning": "⚠", "blocking": "✗", "info": "·"}


def render_human(o: dict) -> str:
    lines = []
    n_mech = len(o["checked"])
    lines.append(f"=== Skill preflight — {o['skill']} ===")
    lines.append(f"Generated: {o['generated_at']}")
    lines.append(f"Mapped patterns: {n_mech} mechanized probed · {len(o['manual'])} manual checklist")
    lines.append("")
    lines.append("Mechanized probes:")
    if o["checked"]:
        for r in o["checked"]:
            g = GLYPH.get(r["status"], "?")
            lines.append(f"  {g} {r['id']:<5} {r['title']}")
            lines.append(f"        {r['detail']}")
    else:
        lines.append("  (none mapped for this skill)")
    lines.append("")
    lines.append("Manual / discipline checklist (awareness — clear before proceeding):")
    if o["manual"]:
        for r in o["manual"]:
            mark = "‼" if r["blocker"] else "·"
            lines.append(f"  {mark} {r['id']:<5} {r['title']}")
            lines.append(f"        → {r['remediation']}")
    else:
        lines.append("  (none)")
    lines.append("")
    if o["blocking"]:
        lines.append(f"✗ BLOCKING ({len(o['blocking'])}): "
                     + ", ".join(r["id"] for r in o["blocking"]))
        for r in o["blocking"]:
            lines.append(f"    {r['id']}: {r['remediation']}")
    else:
        lines.append("✓ No mechanized blocker tripped.")
    if o["advisory"]:
        lines.append(f"⚠ Advisories: " + ", ".join(r["id"] for r in o["advisory"]))
    lines.append("")
    lines.append("Overlay written: .claude/shared/preflight-cache.json :: "
                 f"skill_overlay.{o['skill']}")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--skill", required=True, help="skill name (one of .claude/skills/*)")
    ap.add_argument("--json", action="store_true", help="machine-readable JSON output")
    args = ap.parse_args()

    if args.skill not in VALID_SKILLS:
        print(f"error: unknown skill '{args.skill}'. Valid: {', '.join(VALID_SKILLS)}",
              file=sys.stderr)
        return 2
    if not MAP_PATH.exists():
        print(f"error: missing map {MAP_PATH}", file=sys.stderr)
        return 2

    overlay = run_skill_preflight(args.skill)
    write_overlay(args.skill, overlay)

    if args.json:
        print(json.dumps(overlay, indent=2))
    else:
        print(render_human(overlay))

    return 1 if overlay["blocking"] else 0


if __name__ == "__main__":
    sys.exit(main())
