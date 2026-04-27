#!/usr/bin/env python3
"""Tier-tag correctness heuristic checker.

For each T1-tagged quantitative claim in a case study, cross-reference
the value against numbers in the measurement-adoption.json and
documentation-debt.json ledgers (within 5% relative tolerance). Flag
TIER_TAG_LIKELY_INCORRECT if no plausible match.

T2 and T3 claims pass through (T2 = declared, T3 = narrative).

Pre-2026-04-21 case studies are exempt (tier-tag convention introduced
on that date).

Advisory at ship: exits 0 either way (findings printed to stdout).
Promotion to gating decided +7 days based on FP-rate baseline.
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional, Set, List


CUTOFF_DATE = "2026-04-21"

# Match a T1/T2/T3 tag near a quantitative claim within the same paragraph.
# Patterns covered: **T1**: 22%, [T1]: 6.5x, T1: 100ms, T1 22.2%
TIER_CLAIM_RE = re.compile(
    r"\*?\*?\[?T(?P<tier>[123])\]?\*?\*?\s*[:.]?\s*"
    r"(?P<claim>[^.\n]*?(?P<number>\d+(?:\.\d+)?)\s*"
    r"(?P<unit>%|x|ms|s|min|hr|h|d|/(?:\d+))[^\n.]*)",
    re.IGNORECASE
)


def parse_frontmatter(path: Path) -> dict:
    """Minimal frontmatter parser. Only extracts top-level scalar keys."""
    text = path.read_text()
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}
    fm_text = text[4:end]
    result = {}
    for line in fm_text.split("\n"):
        if ":" in line and not line.startswith(" "):
            k, _, v = line.partition(":")
            result[k.strip()] = v.strip().strip('"').strip("'")
    return result


def numbers_in_ledger(obj) -> Set[float]:
    """Recursively extract every numeric value as rounded float."""
    nums: Set[float] = set()
    if isinstance(obj, (int, float)):
        nums.add(round(float(obj), 2))
    elif isinstance(obj, dict):
        for v in obj.values():
            nums |= numbers_in_ledger(v)
    elif isinstance(obj, list):
        for v in obj:
            nums |= numbers_in_ledger(v)
    return nums


def find_claims(text: str) -> List[dict]:
    """Extract every T-tagged quantitative claim."""
    claims = []
    for m in TIER_CLAIM_RE.finditer(text):
        try:
            value = float(m.group("number"))
        except ValueError:
            continue
        claims.append({
            "tier": m.group("tier"),
            "value": value,
            "unit": m.group("unit") or "",
            "context": m.group("claim").strip()[:120]
        })
    return claims


def validate_file(path: Path, ledger_numbers: Set[float]) -> List[str]:
    fm = parse_frontmatter(path)
    date_written = str(fm.get("date_written", ""))
    if not date_written or date_written < CUTOFF_DATE:
        return []  # exempt

    text = path.read_text()
    claims = find_claims(text)
    findings = []

    for c in claims:
        if c["tier"] != "1":
            continue  # only check T1
        rounded = round(c["value"], 2)
        match = any(
            abs(rounded - n) / max(abs(n), 1.0) < 0.05
            for n in ledger_numbers
        )
        if not match:
            findings.append(
                f"TIER_TAG_LIKELY_INCORRECT: {path.name}: "
                f"T1 claim {c['value']}{c['unit']} has no ledger match. "
                f"Context: {c['context']!r}"
            )
    return findings


def load_all_ledger_numbers(ledger_paths: List[Path]) -> Set[float]:
    nums: Set[float] = set()
    for p in ledger_paths:
        if p.exists():
            try:
                data = json.loads(p.read_text())
                nums |= numbers_in_ledger(data)
            except Exception:
                pass
    return nums


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--ledger", action="append", default=[],
                        help="Path to a ledger JSON (repeatable)")
    args = parser.parse_args()

    ledger_paths = [Path(p) for p in args.ledger] or [
        Path(".claude/shared/measurement-adoption.json"),
        Path(".claude/shared/documentation-debt.json"),
    ]
    ledger_numbers = load_all_ledger_numbers(ledger_paths)

    files: List[Path] = []
    if args.file:
        files = [Path(args.file)]
    elif args.all:
        files = sorted(Path("docs/case-studies").rglob("*.md"))
    else:
        parser.error("Must pass --file or --all")

    all_findings = []
    for f in files:
        all_findings.extend(validate_file(f, ledger_numbers))

    for finding in all_findings:
        print(finding)

    # Advisory: exit 0 even on findings.
    return 0


if __name__ == "__main__":
    sys.exit(main())
