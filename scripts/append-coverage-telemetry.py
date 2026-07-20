#!/usr/bin/env python3
"""Append a durable coverage row to .claude/shared/coverage-telemetry.jsonl.

Closes the R9 Track-B gap (docs/master-plan/r9-track-b-30day-coverage-read-2026-07-04.md
Follow-up #1): the coverage.yml workflow ran but persisted no durable,
machine-readable coverage numbers (Slather → stdout, pytest-cov → 14-day
artifact), so the 30-day telemetry window the v8.0 GATE_TEST_MISSING meta-gate
calibrates against was never accumulated.

This script parses a Cobertura `coverage.xml` (pytest-cov output) and appends a
dated, dedup-by-(date,surface) row to an append-only git-committed ledger. It is
invoked best-effort from `daily-integrity-checkpoint.py` so the row rides the
existing daily digest commit — no new CI-commit-to-protected-main plumbing.

Row schema (schema_version 1):
    {date, surface, line_rate, branch_rate, per_module:[{module,line_rate}],
     provenance, ts}

Fail-soft: ANY error prints a warning to stderr and exits 0. Coverage telemetry
must never break the checkpoint.

Usage:
    python3 scripts/append-coverage-telemetry.py \
        [--xml ai-engine/coverage.xml] [--surface python-ai-engine] \
        [--date YYYY-MM-DD] [--ledger .claude/shared/coverage-telemetry.jsonl] \
        [--provenance ci|checkpoint|manual] [--low-threshold 0.60]
"""
from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_XML = REPO_ROOT / "ai-engine" / "coverage.xml"
DEFAULT_LEDGER = REPO_ROOT / ".claude" / "shared" / "coverage-telemetry.jsonl"
SCHEMA_VERSION = 1


def _warn(msg: str) -> None:
    print(f"append-coverage-telemetry: {msg}", file=sys.stderr)


def parse_cobertura(xml_path: Path, low_threshold: float) -> dict:
    """Parse a Cobertura coverage.xml into a telemetry row body.

    Returns {line_rate, branch_rate, per_module}. per_module lists modules whose
    line-rate is below low_threshold (the calibration targets), sorted ascending.
    """
    root = ET.parse(xml_path).getroot()
    line_rate = round(float(root.get("line-rate", 0.0)), 4)
    branch_rate = round(float(root.get("branch-rate", 0.0)), 4)
    per_module = []
    for cls in root.iter("class"):
        fname = cls.get("filename")
        if not fname:
            continue
        rate = round(float(cls.get("line-rate", 0.0)), 4)
        if rate < low_threshold:
            per_module.append({"module": fname, "line_rate": rate})
    per_module.sort(key=lambda m: m["line_rate"])
    return {"line_rate": line_rate, "branch_rate": branch_rate, "per_module": per_module}


def append_row(ledger: Path, row: dict) -> bool:
    """Append row to the JSONL ledger, deduped by (date, surface). Returns True
    if a row was written, False if an identical-key row already exists."""
    key = (row["date"], row["surface"])
    existing = []
    if ledger.exists():
        for line in ledger.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                existing.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # tolerate a corrupt line rather than crash
    if any((r.get("date"), r.get("surface")) == key for r in existing):
        return False
    ledger.parent.mkdir(parents=True, exist_ok=True)
    with ledger.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    return True


def build_row(xml_path: Path, surface: str, date: str, provenance: str,
              low_threshold: float, ts: str) -> dict:
    body = parse_cobertura(xml_path, low_threshold)
    return {
        "schema_version": SCHEMA_VERSION,
        "date": date,
        "surface": surface,
        "line_rate": body["line_rate"],
        "branch_rate": body["branch_rate"],
        "per_module": body["per_module"],
        "provenance": provenance,
        "ts": ts,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--xml", default=str(DEFAULT_XML))
    ap.add_argument("--surface", default="python-ai-engine")
    ap.add_argument("--date", default=None)
    ap.add_argument("--ledger", default=str(DEFAULT_LEDGER))
    ap.add_argument("--provenance", default="checkpoint")
    ap.add_argument("--low-threshold", type=float, default=0.60)
    args = ap.parse_args(argv)

    try:
        xml_path = Path(args.xml)
        if not xml_path.exists():
            _warn(f"no coverage.xml at {xml_path} — skipping (run `make coverage-py` first).")
            return 0
        now = datetime.now(timezone.utc)
        date = args.date or now.strftime("%Y-%m-%d")
        ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        row = build_row(xml_path, args.surface, date, args.provenance,
                        args.low_threshold, ts)
        wrote = append_row(Path(args.ledger), row)
        if wrote:
            print(f"append-coverage-telemetry: +1 row {date}/{args.surface} "
                  f"line={row['line_rate']} branch={row['branch_rate']} "
                  f"({len(row['per_module'])} low modules)")
        else:
            print(f"append-coverage-telemetry: {date}/{args.surface} already present — skipped.")
        return 0
    except Exception as exc:  # noqa: BLE001 — fail-soft by contract
        _warn(f"non-fatal error: {exc}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
