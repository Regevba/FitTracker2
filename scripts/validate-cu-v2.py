#!/usr/bin/env python3
"""Validate cu_v2 schema in a state.json file.

Checks:
- factors dict has all 4 expected keys
- each factor is a number in [0, 1]
- total field exists, is numeric, within tolerance 0.01 of sum(factors.values())
- tier_class is one of A_high, B_medium, C_low

Exits 0 on valid (or absent — pre-v6 features exempt). Exits 1 with
CU_V2_INVALID findings on stdout when invalid.

Wired into:
- scripts/check-state-schema.py (T7) — pre-commit + full-corpus scans
- scripts/integrity-check.py (T7) — cycle-time check code CU_V2_INVALID
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


EXPECTED_FACTORS = {"complexity", "blast_radius", "novelty", "verification_difficulty"}
TIER_CLASSES = {"A_high", "B_medium", "C_low"}
TOTAL_TOLERANCE = 0.01


def validate(state: dict) -> list[str]:
    errors = []
    cu = state.get("cu_v2")
    if cu is None:
        return errors  # pre-v6 exempt

    factors = cu.get("factors")
    if not isinstance(factors, dict):
        errors.append("CU_V2_INVALID: factors missing or not a dict")
        return errors

    missing = EXPECTED_FACTORS - set(factors.keys())
    if missing:
        errors.append(f"CU_V2_INVALID: missing factors: {sorted(missing)}")

    for k, v in factors.items():
        if not isinstance(v, (int, float)):
            errors.append(f"CU_V2_INVALID: factor {k!r} is not numeric: {v!r}")
            continue
        if not (0.0 <= v <= 1.0):
            errors.append(f"CU_V2_INVALID: factor {k!r}={v} out of [0,1]")

    total = cu.get("total")
    if total is None:
        errors.append("CU_V2_INVALID: total field missing")
    elif not isinstance(total, (int, float)):
        errors.append(f"CU_V2_INVALID: total is not numeric: {total!r}")
    else:
        expected_total = sum(v for v in factors.values() if isinstance(v, (int, float)))
        if abs(total - expected_total) > TOTAL_TOLERANCE:
            errors.append(
                f"CU_V2_INVALID: total {total} != sum(factors) {expected_total} "
                f"(tolerance {TOTAL_TOLERANCE})"
            )

    tier = cu.get("tier_class")
    if tier not in TIER_CLASSES:
        errors.append(f"CU_V2_INVALID: tier_class {tier!r} not in {sorted(TIER_CLASSES)}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, help="path to state.json")
    args = parser.parse_args()

    state_path = Path(args.state)
    if not state_path.exists():
        print(f"CU_V2_INVALID: state file not found: {args.state}", file=sys.stderr)
        return 1
    state = json.loads(state_path.read_text())
    errors = validate(state)
    if errors:
        for e in errors:
            print(e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
