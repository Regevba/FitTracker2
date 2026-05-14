#!/usr/bin/env python3
"""skills-audit — mechanical conformance check for .claude/skills/*/SKILL.md

Implements P0.4 from docs/skills/skills-review-2026-05-13.md.

Per-skill checks:
  E1  Required frontmatter keys present: name, description, last_updated,
      framework_version, status
  E2  description starts with "Use when " (Anthropic trigger-richness guidance)
  E3  Referenced adapters exist under .claude/integrations/
  E4  Referenced scripts (scripts/foo.py) exist on disk
  W1  Reference to observed-patterns catalog present (warn if missing)
  W2  Sub-commands declared in description match sub-commands documented in body
  W3  Project cross-skill refs (/skill verb) resolve, with vendor-prefix allowlist
  W4  Freshness — last_updated older than --max-age-days (default 90)
  W5  Bidirectional adapter ↔ skill integrity — every SKILL.md `adapters_used`
      entry must appear in that adapter.md's `consumed_by` list, and vice versa

Exit codes:
  0 — no E findings (W findings allowed)
  1 — one or more E findings (or invocation error)

CLI:
  --advisory        Treat E findings as W (always exit 0). Used during
                    v7.8.5 advisory window before v7.9 promotion.
  --quiet           Suppress per-skill PASS lines; print only findings + summary.
  --skill <name>    Audit only the named skill (one of: analytics, brainstorm-pm,
                    cx, design, dev, marketing, ops, pm-workflow, qa, release,
                    research, ux).
  --max-age-days N  Threshold for W4 freshness check (default 90).
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_ROOT = REPO_ROOT / ".claude" / "skills"
INTEGRATIONS_ROOT = REPO_ROOT / ".claude" / "integrations"

REQUIRED_FRONTMATTER_KEYS = (
    "name",
    "description",
    "last_updated",
    "framework_version",
    "status",
)

VALID_STATUS_VALUES = {"active", "stable", "planned", "deprecated"}

# Known wired adapters — anything in .claude/integrations/ excluding _template.
# Computed at runtime; this list is the v7.8.5 baseline for reference.
EXPECTED_ADAPTERS_2026_05_14 = {
    "ga4",
    "app-store-connect",
    "sentry",
    "firecrawl",
    "axe",
    "security-audit",
}


@dataclass
class Finding:
    skill: str
    code: str
    severity: str  # "E" or "W"
    message: str


@dataclass
class SkillFile:
    name: str
    path: Path
    frontmatter: dict[str, str] = field(default_factory=dict)
    body: str = ""
    raw: str = ""


def parse_skill_file(path: Path) -> SkillFile:
    raw = path.read_text(encoding="utf-8")
    name = path.parent.name
    sf = SkillFile(name=name, path=path, raw=raw)

    # Frontmatter is delimited by leading "---" / next "---" lines.
    lines = raw.split("\n")
    if not lines or lines[0].strip() != "---":
        return sf
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        return sf

    fm_lines = lines[1:end_idx]
    body_lines = lines[end_idx + 1:]
    sf.body = "\n".join(body_lines)

    # Tiny YAML: key: value per line. Values may be quoted strings.
    for fm_line in fm_lines:
        if ":" not in fm_line:
            continue
        key, _, val = fm_line.partition(":")
        val = val.strip()
        # Strip matching surrounding quotes
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        sf.frontmatter[key.strip()] = val

    return sf


def check_e1_required_frontmatter(sf: SkillFile) -> list[Finding]:
    findings: list[Finding] = []
    for key in REQUIRED_FRONTMATTER_KEYS:
        if key not in sf.frontmatter or not sf.frontmatter[key].strip():
            findings.append(Finding(sf.name, "E1", "E",
                                    f"missing required frontmatter key '{key}'"))
    status = sf.frontmatter.get("status", "")
    if status and status not in VALID_STATUS_VALUES:
        findings.append(Finding(sf.name, "E1", "E",
                                f"status='{status}' not in {sorted(VALID_STATUS_VALUES)}"))
    return findings


def check_e2_trigger_richness(sf: SkillFile) -> list[Finding]:
    desc = sf.frontmatter.get("description", "")
    if not desc.lower().startswith("use when "):
        return [Finding(sf.name, "E2", "E",
                       "description does not start with 'Use when ' "
                       "(Anthropic trigger-richness guidance)")]
    return []


def existing_adapters() -> set[str]:
    if not INTEGRATIONS_ROOT.is_dir():
        return set()
    return {
        p.name for p in INTEGRATIONS_ROOT.iterdir()
        if p.is_dir() and not p.name.startswith("_")
    }


def load_adapter_consumers() -> dict[str, list[str]]:
    """Parse each adapter.md frontmatter; return {adapter_name: [skill, ...]}.

    Adapters without YAML frontmatter return empty list. Used by W5.
    """
    result: dict[str, list[str]] = {}
    if not INTEGRATIONS_ROOT.is_dir():
        return result
    for adapter_dir in INTEGRATIONS_ROOT.iterdir():
        if not adapter_dir.is_dir() or adapter_dir.name.startswith("_"):
            continue
        adapter_md = adapter_dir / "adapter.md"
        if not adapter_md.is_file():
            result[adapter_dir.name] = []
            continue
        raw = adapter_md.read_text(encoding="utf-8")
        consumers: list[str] = []
        lines = raw.split("\n")
        if lines and lines[0].strip() == "---":
            for line in lines[1:]:
                if line.strip() == "---":
                    break
                if line.startswith("consumed_by:"):
                    val = line.partition(":")[2].strip()
                    if val.startswith("[") and val.endswith("]"):
                        consumers = [s.strip() for s in val[1:-1].split(",") if s.strip()]
                    break
        result[adapter_dir.name] = consumers
    return result


def parse_adapters_used(sf: SkillFile) -> list[str]:
    """Extract `adapters_used:` list from a SKILL.md frontmatter."""
    raw = sf.frontmatter.get("adapters_used", "").strip()
    if not raw:
        return []
    if raw.startswith("[") and raw.endswith("]"):
        return [s.strip() for s in raw[1:-1].split(",") if s.strip()]
    return []


PLACEHOLDER_WORDS = {
    "service", "name", "slug", "repo", "project", "skill", "adapter",
    "feature", "integration", "vendor", "tool",
}


def check_e3_adapter_refs(sf: SkillFile, real_adapters: set[str]) -> list[Finding]:
    """Look for explicit adapter-location references in skill body.

    Strict claim surface: `.claude/integrations/{...}/` path references.
    Either `{ga4,mixpanel}` brace-expansion lists, or single-slug paths.
    Placeholder words (e.g. `{service}` in a template example) are skipped.
    Adapter-style table rows are NOT checked here — they often list real
    MCP/CLI tools that aren't packaged as local adapters (figma MCP, github
    CLI, xcode MCP, codecov REST — all real, none under .claude/integrations/).
    """
    findings: list[Finding] = []
    referenced: set[str] = set()

    # Brace-expansion adapter lists: `.claude/integrations/{ga4,mixpanel}/`
    loc_pattern = re.compile(r"\.claude/integrations/\{([^}]+)\}/")
    for match in loc_pattern.finditer(sf.body):
        items = [n.strip() for n in match.group(1).split(",")]
        # If single-item brace expansion AND that item is a placeholder word
        # (e.g. `{service}` describing where adapters live), skip the whole match.
        if len(items) == 1 and items[0] in PLACEHOLDER_WORDS:
            continue
        for name in items:
            if name not in PLACEHOLDER_WORDS:
                referenced.add(name)

    # Single-slug location: `.claude/integrations/ga4/`
    single_loc = re.compile(r"\.claude/integrations/([a-z][a-z0-9_-]*)/")
    for match in single_loc.finditer(sf.body):
        name = match.group(1).strip()
        if name not in PLACEHOLDER_WORDS:
            referenced.add(name)

    for name in sorted(referenced):
        if name not in real_adapters:
            findings.append(Finding(sf.name, "E3", "E",
                                    f"references adapter '{name}' "
                                    f"but .claude/integrations/{name}/ does not exist"))
    return findings


def check_e4_script_refs(sf: SkillFile) -> list[Finding]:
    """Look for `scripts/<name>.<ext>` references in skill body; verify on disk.

    Cross-repo refs are skipped: if the line context mentions a sibling repo
    (e.g. "In fitme-story:" prefix), the script lives in that repo, not FT2.
    """
    findings: list[Finding] = []
    pattern = re.compile(r"`?(scripts/[a-zA-Z0-9_./-]+\.(?:py|sh|mjs|js|ts))`?")
    cross_repo_markers = ("fitme-story", "cross-repo", "in the web repo", "in the iOS repo")
    referenced: dict[str, str] = {}  # script -> first matching line context
    for line in sf.body.split("\n"):
        for match in pattern.finditer(line):
            ref = match.group(1)
            if ref in referenced:
                continue
            referenced[ref] = line
    for ref, line in sorted(referenced.items()):
        if any(marker in line.lower() for marker in cross_repo_markers):
            continue
        if not (REPO_ROOT / ref).is_file():
            findings.append(Finding(sf.name, "E4", "E",
                                    f"references script '{ref}' that does not exist"))
    return findings


VENDOR_SKILL_PREFIXES = {
    "figma",        # figma:figma-use, figma:figma-generate-design, etc.
    "vercel",       # vercel:* / vercel-plugin:*
    "superpowers",  # superpowers:brainstorming, etc.
    "commit-commands",
    "claude-code-guide",
    "code-connect",
    "code-review",
    "security-review",
    "loop",
    "schedule",
}


def check_w3_cross_skill_refs(sf: SkillFile, known_skills: set[str]) -> list[Finding]:
    """Look for `/skill ...` references in body; warn if no SKILL.md exists.

    Demoted to W3 (warning) because Claude Code surfaces ~150 vendor skills
    via plugins (figma:*, vercel:*, superpowers:*, ...) and the agent often
    cites their short forms (e.g. `/figma generate-design`) that look like
    project-skill references but are vendor-namespaced.
    """
    findings: list[Finding] = []
    pattern = re.compile(r"`/([a-z][a-z0-9-]+)(?:\s+[a-z0-9{}_-]+)?`")
    referenced: set[str] = set()
    for match in pattern.finditer(sf.body):
        referenced.add(match.group(1))
    for ref in sorted(referenced):
        if ref in known_skills or ref in VENDOR_SKILL_PREFIXES or ":" in ref:
            continue
        findings.append(Finding(sf.name, "W3", "W",
                                f"references skill '/{ref}' with no SKILL.md "
                                f"and no known vendor-prefix match"))
    return findings


def check_w1_observed_patterns(sf: SkillFile) -> list[Finding]:
    if "observed-patterns" not in sf.raw:
        return [Finding(sf.name, "W1", "W",
                       "no reference to .claude/integrity/observed-patterns.md "
                       "(per CLAUDE.md §v7.8.5)")]
    return []


def check_w2_sub_commands(sf: SkillFile) -> list[Finding]:
    """Compare sub-commands declared in description vs. mentioned in body.

    Best-effort: extracts `/skill <verb>` patterns from description's sub-command
    list and confirms each appears somewhere in the body. Skipped for /pm-workflow
    (single verb, no list).
    """
    if sf.name == "pm-workflow":
        return []
    desc = sf.frontmatter.get("description", "")
    sub_cmd_section = re.search(r"Sub-commands:(.+?)(?:\.|$)", desc, re.IGNORECASE | re.DOTALL)
    if not sub_cmd_section:
        return []
    pattern = re.compile(rf"/{re.escape(sf.name)}\s+([a-z][a-z0-9-]*)")
    declared = set(pattern.findall(sub_cmd_section.group(1)))
    if not declared:
        return []
    body_pattern = re.compile(rf"/{re.escape(sf.name)}\s+([a-z][a-z0-9-]*)")
    mentioned = set(body_pattern.findall(sf.body))
    missing = sorted(declared - mentioned)
    if missing:
        return [Finding(sf.name, "W2", "W",
                       f"sub-command(s) in description but not in body: {missing}")]
    return []


def check_w5_bidirectional(sf: SkillFile,
                            adapter_consumers: dict[str, list[str]]) -> list[Finding]:
    """Forward direction of W5: every adapter in SKILL.md::adapters_used must
    list this skill in its adapter.md::consumed_by. Reverse direction is
    handled by report_adapter_orphans() at adapter scope.
    """
    findings: list[Finding] = []
    for adapter in parse_adapters_used(sf):
        if adapter not in adapter_consumers:
            findings.append(Finding(sf.name, "W5", "W",
                                    f"adapters_used cites '{adapter}' "
                                    f"but no .claude/integrations/{adapter}/ exists"))
            continue
        if sf.name not in adapter_consumers[adapter]:
            findings.append(Finding(sf.name, "W5", "W",
                                    f"adapters_used cites '{adapter}' but that "
                                    f"adapter.md::consumed_by does not list '{sf.name}'"))
    return findings


def report_adapter_orphans(known_skills: set[str],
                            adapter_consumers: dict[str, list[str]],
                            skill_adapters: dict[str, list[str]]) -> list[Finding]:
    """Reverse direction of W5: every adapter.md::consumed_by entry must appear
    in that skill's adapters_used. Attributed to the adapter (skill field
    holds the adapter name in the Finding).
    """
    findings: list[Finding] = []
    for adapter, consumers in sorted(adapter_consumers.items()):
        for consumer in consumers:
            if consumer not in known_skills:
                findings.append(Finding(adapter, "W5", "W",
                                        f"consumed_by lists '{consumer}' "
                                        f"but no .claude/skills/{consumer}/ exists"))
                continue
            if adapter not in skill_adapters.get(consumer, []):
                findings.append(Finding(adapter, "W5", "W",
                                        f"consumed_by lists '{consumer}' "
                                        f"but that skill's adapters_used does not "
                                        f"include '{adapter}'"))
    return findings


def check_w4_freshness(sf: SkillFile, max_age_days: int, today: date) -> list[Finding]:
    """Warn when last_updated is older than max_age_days."""
    raw = sf.frontmatter.get("last_updated", "").strip()
    if not raw:
        return []  # E1 already flags missing frontmatter
    try:
        last = datetime.strptime(raw, "%Y-%m-%d").date()
    except ValueError:
        return [Finding(sf.name, "W4", "W",
                       f"last_updated='{raw}' does not parse as YYYY-MM-DD")]
    age = (today - last).days
    if age > max_age_days:
        return [Finding(sf.name, "W4", "W",
                       f"last_updated={raw} is {age} days old "
                       f"(>{max_age_days}); review for drift against current framework")]
    return []


def audit_one(path: Path, real_adapters: set[str], known_skills: set[str],
              adapter_consumers: dict[str, list[str]],
              max_age_days: int, today: date) -> tuple[list[Finding], SkillFile]:
    sf = parse_skill_file(path)
    findings: list[Finding] = []
    findings.extend(check_e1_required_frontmatter(sf))
    findings.extend(check_e2_trigger_richness(sf))
    findings.extend(check_e3_adapter_refs(sf, real_adapters))
    findings.extend(check_e4_script_refs(sf))
    findings.extend(check_w3_cross_skill_refs(sf, known_skills))
    findings.extend(check_w1_observed_patterns(sf))
    findings.extend(check_w2_sub_commands(sf))
    findings.extend(check_w4_freshness(sf, max_age_days, today))
    findings.extend(check_w5_bidirectional(sf, adapter_consumers))
    return findings, sf


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--advisory", action="store_true",
                       help="Treat E findings as W (always exit 0)")
    parser.add_argument("--quiet", action="store_true",
                       help="Print only findings + summary")
    parser.add_argument("--skill", default=None,
                       help="Audit only the named skill")
    parser.add_argument("--max-age-days", type=int, default=90,
                       help="W4 freshness threshold (default 90)")
    args = parser.parse_args()

    if not SKILLS_ROOT.is_dir():
        print(f"ERROR: skills root not found at {SKILLS_ROOT}", file=sys.stderr)
        return 1

    skill_dirs = sorted([p for p in SKILLS_ROOT.iterdir()
                        if p.is_dir() and (p / "SKILL.md").is_file()])
    if args.skill:
        skill_dirs = [p for p in skill_dirs if p.name == args.skill]
        if not skill_dirs:
            print(f"ERROR: no skill named '{args.skill}'", file=sys.stderr)
            return 1

    real_adapters = existing_adapters()
    adapter_consumers = load_adapter_consumers()
    known_skills = {p.name for p in SKILLS_ROOT.iterdir()
                    if p.is_dir() and (p / "SKILL.md").is_file()}

    today = date.today()
    all_findings: list[Finding] = []
    skill_adapters: dict[str, list[str]] = {}
    for skill_dir in skill_dirs:
        skill_findings, sf = audit_one(skill_dir / "SKILL.md", real_adapters,
                                        known_skills, adapter_consumers,
                                        args.max_age_days, today)
        skill_adapters[skill_dir.name] = parse_adapters_used(sf)
        all_findings.extend(skill_findings)
        if not args.quiet and not skill_findings:
            print(f"PASS  {skill_dir.name}")
        for f in skill_findings:
            print(f"{f.severity}  [{f.code}] {f.skill}: {f.message}")

    # Reverse-direction W5 (adapter scope). Only runs when auditing all skills.
    if args.skill is None:
        orphans = report_adapter_orphans(known_skills, adapter_consumers, skill_adapters)
        for f in orphans:
            print(f"{f.severity}  [{f.code}] adapter:{f.skill}: {f.message}")
        all_findings.extend(orphans)

    errors = [f for f in all_findings if f.severity == "E"]
    warnings = [f for f in all_findings if f.severity == "W"]
    print(f"\nskills-audit: {len(skill_dirs)} skill(s) audited; "
          f"{len(errors)} error(s), {len(warnings)} warning(s)")
    if args.advisory and errors:
        print("(--advisory mode: treating errors as warnings; exiting 0)")
        return 0
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
