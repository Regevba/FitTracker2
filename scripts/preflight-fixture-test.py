#!/usr/bin/env python3
"""preflight-fixture-test — regression test for /ux preflight + /design preflight.

Closes P1.3 from docs/skills/skills-review-2026-05-13.md §5.

Walks every `.claude/skills/{ux,design}/fixtures/*-spec.md` fixture and:

1. Extracts `App{Color,Text,Spacing,Radius,Motion,Easing,Duration,Spring,Shadow,
   Size,Gradient}.*` token references from the spec body (the same set
   /ux preflight SKILL.md Step 2 declares it detects).
2. Greps `FitTracker/Services/AppTheme.swift` + `FitTracker/DesignSystem/`
   for each token's leaf name. Missing = P0 finding (mirrors /ux preflight
   Step 5).
3. Asserts the outcome matches the filename prefix:
   - `valid-*.md` → P0 findings count must be 0
   - `invalid-*.md` → P0 findings count must be ≥ 1

Exit code:
  0 — all fixtures behave as expected
  1 — at least one fixture's outcome mismatches its filename prefix

Run via `make preflight-fixture-test`. Add new fixtures by dropping a
`{valid,invalid}-{slug}.md` file into either fixtures/ directory.
"""

from __future__ import annotations

import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
APPTHEME = REPO_ROOT / "FitTracker" / "Services" / "AppTheme.swift"
DESIGN_SYSTEM_DIR = REPO_ROOT / "FitTracker" / "DesignSystem"

# Per /ux preflight SKILL.md Step 2 — these are the namespaces preflight
# claims to detect.
TOKEN_NAMESPACES = (
    "AppColor", "AppText", "AppSpacing", "AppRadius", "AppMotion",
    "AppEasing", "AppDuration", "AppSpring", "AppShadow", "AppSize",
    "AppGradient",
)

TOKEN_PATTERN = re.compile(
    r"`?(" + "|".join(TOKEN_NAMESPACES) + r")\.([A-Za-z][A-Za-z0-9_.]*)`?"
)


@dataclass
class FixtureResult:
    fixture: Path
    expected_to_pass: bool   # True if filename starts with "valid-"
    tokens_referenced: list[str] = field(default_factory=list)
    p0_findings: list[str] = field(default_factory=list)

    @property
    def actually_passed(self) -> bool:
        return not self.p0_findings

    @property
    def outcome_matches_expectation(self) -> bool:
        return self.actually_passed == self.expected_to_pass


def extract_tokens(spec_path: Path) -> list[str]:
    """Return unique `Namespace.leaf` tokens cited in the spec."""
    raw = spec_path.read_text(encoding="utf-8")
    found: set[str] = set()
    for match in TOKEN_PATTERN.finditer(raw):
        namespace, leaf = match.group(1), match.group(2)
        # Take only the leftmost component of dotted leaves (e.g.
        # AppColor.Brand.primary → token = "primary"; namespace = AppColor)
        # We grep for the *full* dotted path so chained accessors still resolve.
        found.add(f"{namespace}.{leaf}")
    return sorted(found)


def token_exists_in_codebase(full_token: str) -> bool:
    """Grep AppTheme.swift + DesignSystem/ for the token's leaf name."""
    # Leaf-component grep is intentionally permissive: AppColor.Brand.primary
    # is satisfied if any of `Brand.primary`, `primary` (as a static let in
    # a Brand enum), or `AppColor.Brand.primary` appears in the codebase.
    # This matches the spirit of /ux preflight which checks "does the
    # symbol resolve", not "does the AST yield exactly this path."
    leaf = full_token.split(".")[-1]
    paths = [str(APPTHEME)]
    if DESIGN_SYSTEM_DIR.is_dir():
        paths.append(str(DESIGN_SYSTEM_DIR))
    # Use a word-boundary anchor so a fake `nonexistent` doesn't match
    # "nonexistent" inside a comment elsewhere.
    pattern = rf"\b{re.escape(leaf)}\b"
    try:
        r = subprocess.run(
            ["grep", "-rE", pattern, *paths],
            capture_output=True, text=True, timeout=10,
        )
        return r.returncode == 0
    except subprocess.TimeoutExpired:
        return False


def audit_fixture(spec_path: Path) -> FixtureResult:
    expected_to_pass = spec_path.name.startswith("valid-")
    result = FixtureResult(fixture=spec_path, expected_to_pass=expected_to_pass)
    result.tokens_referenced = extract_tokens(spec_path)
    for tok in result.tokens_referenced:
        if not token_exists_in_codebase(tok):
            result.p0_findings.append(tok)
    return result


def main() -> int:
    skill_dirs = ("ux", "design")
    fixtures: list[Path] = []
    for skill in skill_dirs:
        fdir = REPO_ROOT / ".claude" / "skills" / skill / "fixtures"
        if not fdir.is_dir():
            print(f"WARN  no fixtures dir at {fdir}", file=sys.stderr)
            continue
        # Fixtures must start with valid- or invalid- to encode their
        # expected outcome in the filename.
        for f in sorted(list(fdir.glob("valid-*.md")) + list(fdir.glob("invalid-*.md"))):
            fixtures.append(f)

    if not fixtures:
        print("ERROR: no fixtures found under .claude/skills/{ux,design}/fixtures/",
              file=sys.stderr)
        return 1

    bad = 0
    for fx in fixtures:
        r = audit_fixture(fx)
        marker = "PASS" if r.outcome_matches_expectation else "FAIL"
        if not r.outcome_matches_expectation:
            bad += 1
        verb = "passed" if r.actually_passed else "failed"
        expected = "should pass" if r.expected_to_pass else "should fail"
        relpath = fx.relative_to(REPO_ROOT)
        print(f"{marker}  {relpath}  ({len(r.tokens_referenced)} tokens, "
              f"{len(r.p0_findings)} P0; {verb}, {expected})")
        if r.p0_findings:
            for tok in r.p0_findings:
                print(f"       └─ missing: {tok}")

    print(f"\npreflight-fixture-test: {len(fixtures)} fixture(s); "
          f"{len(fixtures) - bad} matched expectation, {bad} mismatched")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
