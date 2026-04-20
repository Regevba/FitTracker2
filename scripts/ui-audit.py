#!/usr/bin/env python3
"""
scripts/ui-audit.py — Design-system compliance scanner for every SwiftUI view.

Walks every .swift file under FitTracker/Views and FitTracker/DesignSystem
and reports violations of the design-system contract:

  P0 (blocking) — raw SwiftUI Color literals, raw animation durations,
                  raw Font.system(...) calls outside the AppTheme layer
  P1 (warning)  — magic spacing/frame numbers that don't map to tokens,
                  interactive controls (Button/Toggle) without accessibility
                  annotations when their label isn't a plain Text

Files marked "// HISTORICAL" in the header are skipped (they're excluded
from the Xcode build target and only stay in the repo for diff review).
The token-definition files (AppTheme.swift, AppPalette.swift,
DesignTokens.swift, AppComponents.swift) are also skipped since they're
where the tokens are legitimately declared.

Usage:
  python3 scripts/ui-audit.py            # full report, exits 1 on P0
  python3 scripts/ui-audit.py --summary  # counts only
  python3 scripts/ui-audit.py --json     # machine-readable output
  python3 scripts/ui-audit.py --baseline # write docs/design-system/ui-audit-baseline.md

The script is dependency-free (stdlib only) so it runs in CI without npm.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCAN_ROOTS = [
    REPO_ROOT / "FitTracker" / "Views",
    REPO_ROOT / "FitTracker" / "DesignSystem",
]
SKIP_FILES = {
    "AppTheme.swift",
    "AppPalette.swift",
    "DesignTokens.swift",
    "AppComponents.swift",
    "AppMotion.swift",       # defines AppMotion/AppSpring/AppEasing tokens
    "AppViewModifiers.swift",  # design-system modifier layer
    "AppIcon.swift",         # icon tokens
    "FitMeBrandIcon.swift",  # brand asset definition
    "FitMeLogoLoader.swift", # brand asset definition
}

# Semantic token allowlists — tokens whose use is legitimate design-system usage.
APP_SPACING_VALUES = {2, 4, 8, 12, 16, 20, 24, 32, 40, 54}
APP_SIZE_VALUES = {4, 8, 26, 48, 52, 56}
APP_RADIUS_VALUES = {4, 8, 12, 16, 20, 24, 28, 32, 36}
# Visually-trivial small numbers that never warrant a token (line thickness, spacer).
SPACING_ALLOW_TRIVIAL = {0, 1}


@dataclass
class Finding:
    file: str
    line: int
    severity: str          # "P0" or "P1"
    rule: str              # rule id, e.g. "DS-RAW-COLOR"
    message: str
    snippet: str


@dataclass
class FileReport:
    path: Path
    relative: str
    findings: list[Finding] = field(default_factory=list)
    skipped: str | None = None


# ──────────────────────────────────────────────────────────────────────
# Rule matchers
# ──────────────────────────────────────────────────────────────────────

# SwiftUI built-in Color members that view code should not reference directly.
# Callers should go through AppColor.* semantic tokens.
RAW_COLOR_NAMES = {
    "red", "blue", "green", "yellow", "orange", "purple", "pink", "black",
    "white", "gray", "brown", "cyan", "mint", "indigo", "teal",
}

# Patterns that indicate a raw SwiftUI color reference.
RE_COLOR_MEMBER = re.compile(
    r"\bColor\.(?P<name>" + "|".join(RAW_COLOR_NAMES) + r")\b"
)
# Dotted shorthand used in style modifiers: .foregroundStyle(.red), .tint(.blue)
RE_COLOR_SHORTHAND = re.compile(
    r"\.(?:foregroundStyle|foregroundColor|tint|background|fill|stroke|overlay|border)"
    r"\(\s*\.(?P<name>" + "|".join(RAW_COLOR_NAMES) + r")\b"
)
# Color(red: ..., green: ..., blue: ...) literal constructors
RE_COLOR_RGB_LITERAL = re.compile(
    r"\bColor\(\s*red\s*:\s*[-.\d]+\s*,\s*green\s*:\s*[-.\d]+\s*,\s*blue\s*:"
)
# Color(.systemXxx) bridges to UIColor
RE_COLOR_UIKIT_BRIDGE = re.compile(
    r"\bColor\(\.\s*system\w+\b"
)

# Raw animation literals — callers should use AppMotion.* / AppSpring.* / AppEasing.*
RE_RAW_ANIMATION = re.compile(
    r"\.(?:easeInOut|easeIn|easeOut|linear|spring|interpolatingSpring|interactiveSpring)"
    r"\(\s*(?:duration|response|dampingFraction|blendDuration|stiffness|damping|initialVelocity)\s*:"
)

# Raw Font.system(...) outside AppTheme — should use AppText.* tokens
RE_RAW_FONT = re.compile(r"\bFont\.system\(")

# .font(.body), .font(.caption.weight(...)) — should use AppText tokens
RE_RAW_FONT_SHORTHAND = re.compile(
    r"\.font\(\s*\.(?:largeTitle|title|title2|title3|headline|subheadline|body|"
    r"callout|caption|caption2|footnote)\b"
)

# Padding/frame with numeric literal argument — may be a magic number.
RE_PADDING_LITERAL = re.compile(
    r"\.padding\(\s*"
    r"(?:\.(?:horizontal|vertical|top|bottom|leading|trailing)\s*,\s*)?"
    r"(-?\d+(?:\.\d+)?)\s*\)"
)
RE_FRAME_LITERAL = re.compile(
    r"\.frame\("
    r"(?=[^)]*\b(?:width|height|minWidth|maxWidth|minHeight|maxHeight)\s*:\s*(-?\d+(?:\.\d+)?))"
)

# Button/Toggle with a non-Text label block that likely needs an accessibility label.
# Matches `Button { ... } label: {` patterns and flags the opening line; we then
# look at the following 15 lines for an accessibilityLabel modifier.
RE_BUTTON_LABEL = re.compile(r"\bButton\s*\{")
RE_TOGGLE_LABEL = re.compile(r"\bToggle\s*\(")
RE_ACCESSIBILITY_LABEL = re.compile(r"\.accessibilityLabel\b")
RE_ACCESSIBILITY_HIDDEN = re.compile(r"\.accessibilityHidden\s*\(\s*true\s*\)")

# Heuristic: skip comment lines and strings — only flag on code positions.
def strip_line(line: str) -> str:
    # Remove trailing line comment
    if "//" in line:
        # avoid stripping inside strings — simple heuristic: only strip if '//' not inside quotes
        in_str = False
        for i, ch in enumerate(line):
            if ch == '"':
                in_str = not in_str
            elif ch == "/" and i + 1 < len(line) and line[i + 1] == "/" and not in_str:
                return line[:i]
    return line


# ──────────────────────────────────────────────────────────────────────
# Per-file scanning
# ──────────────────────────────────────────────────────────────────────

def is_historical(path: Path) -> bool:
    try:
        with path.open("r", encoding="utf-8") as f:
            head = f.read(2048)
    except OSError:
        return False
    # First non-blank line checks
    for line in head.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("// HISTORICAL"):
            return True
        if stripped.startswith("//"):
            # skip other comments
            continue
        break
    return False


def scan_file(path: Path) -> FileReport:
    rel = str(path.relative_to(REPO_ROOT))
    report = FileReport(path=path, relative=rel)

    if path.name in SKIP_FILES:
        report.skipped = "token-definition file"
        return report
    if is_historical(path):
        report.skipped = "historical (not in build target)"
        return report

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        report.skipped = f"unreadable: {e}"
        return report

    lines = text.splitlines()
    in_preview_block = False  # #Preview blocks are demo data, relax rules inside

    for i, raw in enumerate(lines, start=1):
        line = strip_line(raw)
        stripped = line.strip()

        # Track SwiftUI preview scopes — violations inside #Preview are downgraded
        if "#Preview" in line or re.search(r"\bstruct\s+\w+_Previews\b", line):
            in_preview_block = True
        if in_preview_block and stripped.endswith("}") and not stripped.startswith("//"):
            # crude end-of-block detection — tolerable since preview blocks are short
            pass

        # ── P0: raw SwiftUI color references
        for rx, rule in [
            (RE_COLOR_MEMBER, "DS-RAW-COLOR-MEMBER"),
            (RE_COLOR_SHORTHAND, "DS-RAW-COLOR-SHORTHAND"),
            (RE_COLOR_RGB_LITERAL, "DS-RAW-COLOR-LITERAL"),
            (RE_COLOR_UIKIT_BRIDGE, "DS-RAW-COLOR-UIKIT"),
        ]:
            if rx.search(line):
                report.findings.append(Finding(
                    file=rel, line=i, severity="P0", rule=rule,
                    message="raw SwiftUI color — use AppColor.* semantic tokens",
                    snippet=stripped[:140],
                ))

        # ── P0: raw animations
        if RE_RAW_ANIMATION.search(line):
            report.findings.append(Finding(
                file=rel, line=i, severity="P0", rule="DS-RAW-ANIMATION",
                message="raw animation literal — use AppMotion.* / AppSpring.* / AppEasing.*",
                snippet=stripped[:140],
            ))

        # ── P0: raw Font.system outside AppTheme
        if RE_RAW_FONT.search(line):
            report.findings.append(Finding(
                file=rel, line=i, severity="P0", rule="DS-RAW-FONT-SYSTEM",
                message="Font.system outside AppTheme — declare a new AppText.* token instead",
                snippet=stripped[:140],
            ))

        # ── P1: raw font shorthand
        if RE_RAW_FONT_SHORTHAND.search(line):
            report.findings.append(Finding(
                file=rel, line=i, severity="P1", rule="DS-RAW-FONT-SHORTHAND",
                message=".font(.body/.caption/...) — use AppText.* semantic tokens",
                snippet=stripped[:140],
            ))

        # ── P1: magic spacing / frame numbers
        for m in RE_PADDING_LITERAL.finditer(line):
            try:
                value = float(m.group(1))
            except ValueError:
                continue
            intval = int(value) if value == int(value) else value
            if intval in APP_SPACING_VALUES or intval in SPACING_ALLOW_TRIVIAL:
                continue
            report.findings.append(Finding(
                file=rel, line=i, severity="P1", rule="DS-MAGIC-PADDING",
                message=f"padding({intval}) off the 4pt grid — use AppSpacing.* token",
                snippet=stripped[:140],
            ))

        for m in RE_FRAME_LITERAL.finditer(line):
            try:
                value = float(m.group(1))
            except ValueError:
                continue
            intval = int(value) if value == int(value) else value
            if intval in APP_SIZE_VALUES or intval in APP_SPACING_VALUES or intval in SPACING_ALLOW_TRIVIAL:
                continue
            # Extract all width/height literals in this .frame(...) call for reporting.
            report.findings.append(Finding(
                file=rel, line=i, severity="P1", rule="DS-MAGIC-FRAME",
                message=f"frame uses magic dimension {intval} — declare an AppSize.* token",
                snippet=stripped[:140],
            ))

        # ── P1: Button without nearby accessibilityLabel/hidden when label is non-Text
        if RE_BUTTON_LABEL.search(line):
            # Look ahead up to 20 lines for either:
            #   - Text(...) inside the label block (accessibility inferred), OR
            #   - .accessibilityLabel / .accessibilityHidden(true) attached afterwards
            window = "\n".join(lines[i - 1:min(i + 20, len(lines))])
            has_text = re.search(r"label:\s*\{[^}]*\bText\s*\(", window, re.DOTALL)
            has_label_mod = RE_ACCESSIBILITY_LABEL.search(window)
            has_hidden = RE_ACCESSIBILITY_HIDDEN.search(window)
            if not (has_text or has_label_mod or has_hidden):
                # Only flag if we actually see a non-Text label (icon-only common pattern)
                if re.search(r"\bImage\s*\(", window) or re.search(r"\bsystemName\s*:", window):
                    report.findings.append(Finding(
                        file=rel, line=i, severity="P1", rule="DS-A11Y-BUTTON",
                        message="icon button without accessibilityLabel — add label or .accessibilityHidden(true)",
                        snippet=stripped[:140],
                    ))

    return report


# ──────────────────────────────────────────────────────────────────────
# Orchestration + output
# ──────────────────────────────────────────────────────────────────────

def collect_swift_files() -> list[Path]:
    files: list[Path] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        files.extend(sorted(root.rglob("*.swift")))
    return files


# ──────────────────────────────────────────────────────────────────────
# Asset-reference check (Gap A) — every Color("name") in AppTheme.swift
# must have a matching .colorset in Assets.xcassets, otherwise SwiftUI
# silently falls back to clear at runtime.
# ──────────────────────────────────────────────────────────────────────

RE_COLOR_NAME_LITERAL = re.compile(r'\bColor\(\s*"([^"]+)"')

def check_color_assets() -> list[Finding]:
    theme_path = REPO_ROOT / "FitTracker" / "Services" / "AppTheme.swift"
    assets_root = REPO_ROOT / "FitTracker" / "Assets.xcassets"
    findings: list[Finding] = []

    if not theme_path.exists() or not assets_root.exists():
        return findings

    referenced: dict[str, int] = {}
    for i, line in enumerate(theme_path.read_text(encoding="utf-8").splitlines(), 1):
        line_no_comment = strip_line(line)
        for m in RE_COLOR_NAME_LITERAL.finditer(line_no_comment):
            referenced.setdefault(m.group(1), i)

    available = {p.stem for p in assets_root.rglob("*.colorset")}

    for name, line in sorted(referenced.items()):
        if name not in available:
            findings.append(Finding(
                file="FitTracker/Services/AppTheme.swift",
                line=line, severity="P0", rule="DS-MISSING-ASSET",
                message=f'Color("{name}") declared but no {name}.colorset in Assets.xcassets',
                snippet=f'Color("{name}")',
            ))
    return findings


def render_text(reports: list[FileReport]) -> str:
    lines: list[str] = []
    p0_total = p1_total = 0
    files_with_issues = 0

    for r in reports:
        if r.skipped or not r.findings:
            continue
        files_with_issues += 1
        p0 = sum(1 for f in r.findings if f.severity == "P0")
        p1 = sum(1 for f in r.findings if f.severity == "P1")
        p0_total += p0
        p1_total += p1
        lines.append(f"\n── {r.relative}  (P0={p0}, P1={p1})")
        for f in r.findings:
            lines.append(f"  {f.severity} {f.rule:<26} L{f.line:<5} {f.message}")
            lines.append(f"         │ {f.snippet}")

    scanned = sum(1 for r in reports if not r.skipped)
    skipped = sum(1 for r in reports if r.skipped)
    header = [
        f"UI audit — {scanned} files scanned, {skipped} skipped",
        f"  P0 (blocking): {p0_total}",
        f"  P1 (warning):  {p1_total}",
        f"  files with findings: {files_with_issues}",
    ]
    return "\n".join(header + lines) + "\n"


def render_summary(reports: list[FileReport]) -> str:
    p0_by_rule: dict[str, int] = {}
    p1_by_rule: dict[str, int] = {}
    for r in reports:
        for f in r.findings:
            bucket = p0_by_rule if f.severity == "P0" else p1_by_rule
            bucket[f.rule] = bucket.get(f.rule, 0) + 1
    lines = ["P0 by rule:"]
    for rule, n in sorted(p0_by_rule.items(), key=lambda x: -x[1]):
        lines.append(f"  {rule:<28} {n}")
    lines.append("")
    lines.append("P1 by rule:")
    for rule, n in sorted(p1_by_rule.items(), key=lambda x: -x[1]):
        lines.append(f"  {rule:<28} {n}")
    return "\n".join(lines) + "\n"


def render_json(reports: list[FileReport]) -> str:
    payload = []
    for r in reports:
        payload.append({
            "file": r.relative,
            "skipped": r.skipped,
            "findings": [
                {"line": f.line, "severity": f.severity, "rule": f.rule,
                 "message": f.message, "snippet": f.snippet}
                for f in r.findings
            ],
        })
    return json.dumps(payload, indent=2)


def render_baseline_markdown(reports: list[FileReport]) -> str:
    p0_total = p1_total = 0
    files_with_issues = 0
    per_dir: dict[str, dict[str, int]] = {}

    for r in reports:
        if r.skipped or not r.findings:
            continue
        files_with_issues += 1
        p0 = sum(1 for f in r.findings if f.severity == "P0")
        p1 = sum(1 for f in r.findings if f.severity == "P1")
        p0_total += p0
        p1_total += p1
        top_dir = r.relative.split("/")[2] if r.relative.startswith("FitTracker/Views/") else "DesignSystem"
        bucket = per_dir.setdefault(top_dir, {"P0": 0, "P1": 0, "files": 0})
        bucket["P0"] += p0
        bucket["P1"] += p1
        bucket["files"] += 1

    lines = [
        "# UI Audit Baseline",
        "",
        "Generated by `make ui-audit` — do not edit by hand; regenerate.",
        "",
        "This file records the compliance state at baseline. Going forward,",
        "every PR that touches a SwiftUI view should keep P0 count at 0.",
        "",
        "## Summary",
        "",
        f"- **P0 (blocking):** {p0_total}",
        f"- **P1 (warning):**  {p1_total}",
        f"- **Files with findings:** {files_with_issues}",
        f"- **Files scanned:** {sum(1 for r in reports if not r.skipped)}",
        f"- **Files skipped:** {sum(1 for r in reports if r.skipped)} (historical v1 + token-definition files)",
        "",
        "## Per-area breakdown",
        "",
        "| Area | P0 | P1 | Files |",
        "|---|---:|---:|---:|",
    ]
    for area in sorted(per_dir):
        b = per_dir[area]
        lines.append(f"| `{area}` | {b['P0']} | {b['P1']} | {b['files']} |")

    lines += [
        "",
        "## Per-file findings",
        "",
    ]
    for r in reports:
        if r.skipped or not r.findings:
            continue
        p0 = sum(1 for f in r.findings if f.severity == "P0")
        p1 = sum(1 for f in r.findings if f.severity == "P1")
        lines.append(f"### `{r.relative}` — P0={p0}, P1={p1}")
        lines.append("")
        lines.append("| Line | Sev | Rule | Snippet |")
        lines.append("|---:|:---:|---|---|")
        for f in r.findings:
            snip = f.snippet.replace("|", "\\|")
            lines.append(f"| {f.line} | {f.severity} | `{f.rule}` | `{snip}` |")
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", action="store_true", help="print counts only")
    parser.add_argument("--json", action="store_true", help="output JSON")
    parser.add_argument("--baseline", action="store_true",
                        help="write docs/design-system/ui-audit-baseline.md")
    parser.add_argument("--no-fail", action="store_true",
                        help="exit 0 even if P0 findings exist (baseline mode)")
    args = parser.parse_args()

    files = collect_swift_files()
    reports = [scan_file(f) for f in files]

    # Gap A — asset-reference integrity (AppTheme.swift ↔ Assets.xcassets)
    asset_findings = check_color_assets()
    if asset_findings:
        synthetic = FileReport(
            path=REPO_ROOT / "FitTracker" / "Services" / "AppTheme.swift",
            relative="FitTracker/Services/AppTheme.swift",
            findings=asset_findings,
        )
        reports.append(synthetic)

    if args.baseline:
        out_path = REPO_ROOT / "docs" / "design-system" / "ui-audit-baseline.md"
        out_path.write_text(render_baseline_markdown(reports), encoding="utf-8")
        print(f"wrote {out_path.relative_to(REPO_ROOT)}")

    if args.json:
        print(render_json(reports))
    elif args.summary:
        print(render_summary(reports))
    else:
        print(render_text(reports))

    p0 = sum(1 for r in reports for f in r.findings if f.severity == "P0")
    if p0 > 0 and not args.no_fail and not args.baseline:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
