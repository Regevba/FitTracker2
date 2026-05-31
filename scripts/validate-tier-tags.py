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
# v7.8.4: tightened unit boundary — `\b` after the unit eliminates false
# positives where the unit letter is the first char of a longer word
# ("h" matching "hook", "s" matching "schema", "d" matching "declared").
TIER_CLAIM_RE = re.compile(
    r"\*?\*?\[?T(?P<tier>[123])\]?\*?\*?\s*[:.]?\s*"
    r"(?P<claim>[^.\n]*?(?P<number>\d+(?:\.\d+)?)\s*"
    r"(?P<unit>%|x|ms|s|min|hr|h|d|/(?:\d+))\b[^\n.]*)",
    re.IGNORECASE
)

# v7.8.4: detects T1 ↔ T2/T3 confusion where the regex captures the
# digit from a SECOND tier marker as if it were a measurement. Matches
# "T2", "T3", "[T2]", "**T3**" (case-insensitive) within the claim text.
INTERVENING_TIER_RE = re.compile(r"\*?\*?\[?T[123]\b", re.IGNORECASE)


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


# v7.8.4: threshold-language markers that flip a T1 claim into a forward-looking
# declaration (target/kill criterion) rather than an observation. These are
# legitimately T1 ("T1-instrumented metric") but the *value* is a threshold,
# not a measurement, so it has no ledger row. Skipping them eliminates the
# largest false-positive class without weakening the heuristic for real
# observed T1 values.
TARGET_KILL_MARKERS = (
    "target",
    "kill <",
    "kill >",
    "kill ≥",
    "kill ≤",
    "kill if",
    "goal:",
    "goal ",
    "threshold",
    "≥",
    "≤",
)

# v7.9.1 F-TIER-TAG-FORWARD-DEADLINE-FILTER (added 2026-05-31): extend the
# v7.8.4 filter to recognize forward-looking deadline / measurement-window /
# kill-criterion-window patterns. These are NOT measurements — they're
# durations attached to a threshold or evaluation window, so the number is a
# declaration, not an observation. Closes the 4 false-positive advisories
# surfaced 2026-05-30 (framework-v7-8-branch-isolation, framework-v7-9-promotion,
# ucc-passkey-auth, ucc-passkey-auth-security-hardening).
FORWARD_DEADLINE_RE = re.compile(
    r"""
    (
        # "T+7d", "T+14d" (post-promotion soak windows)
        T\+\d+\s*[dhm]
        |
        # "0 events / 7d", "10 events/30d" (rate / window threshold)
        \d+\s*events?\s*/\s*\d+\s*[dhm]
        |
        # "within 7d", "within T+14d" (kill-criterion evaluation window)
        within\s+T?\+?\d+\s*[dhm]
        |
        # "events / Nd window" (measurement-window declarations)
        events?\s*/\s*\d+\s*[dhm]\s+window
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


def is_target_or_kill_claim(context: str) -> bool:
    """True when the claim context is a forward-looking threshold declaration.

    Added v7.8.4 to narrow the false-positive class — see CLAUDE.md "v7.8.4"
    section. Extended v7.9.1 (F-TIER-TAG-FORWARD-DEADLINE-FILTER) to also
    recognize T+Nd / events/Nd / within-Nd forward-deadline patterns.

    Targets/kill criteria/measurement-windows are legitimately T1-tagged
    because the *metric* is instrumented, but the *number* is a declaration
    of intent rather than an observation, so it will never have a ledger
    match.
    """
    lower = context.lower()
    if any(marker in lower for marker in TARGET_KILL_MARKERS):
        return True
    if FORWARD_DEADLINE_RE.search(context):
        return True
    return False


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
        if is_target_or_kill_claim(c["context"]):
            continue  # v7.8.4: target/kill thresholds are declarations, not observations
        if INTERVENING_TIER_RE.search(c["context"]):
            continue  # v7.8.4: claim context contains another tier marker — number likely belongs to it
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
        # v7.8.4: dedicated reference ledger for T1 claims whose values are
        # computed/derived and not naturally captured by the two ledgers above
        # (e.g., wall-time totals, ui-audit reductions).
        Path(".claude/shared/case-study-t1-references.json"),
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
