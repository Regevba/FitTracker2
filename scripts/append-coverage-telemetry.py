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
import subprocess
import sys
import tempfile
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


def fetch_latest_ci_coverage_xml(dest_dir: Path) -> Path | None:
    """Best-effort: download the most recent successful `coverage.yml` artifact
    (`ai-engine-coverage-xml`, 90d retention) via `gh` and return the extracted
    coverage.xml path, or None. Never raises.

    Why this exists: the daily checkpoint runs on a host where ai-engine deps
    are usually absent, so `make coverage-py` produces no local coverage.xml.
    CI *does* measure it on every push-to-main, so we pull that artifact instead
    of relying on a local pytest run — decoupling the durable ledger from local
    deps (the reason the ledger sat at only its seed row on 2026-07-21)."""
    try:
        res = subprocess.run(
            ["gh", "run", "list", "--workflow", "coverage.yml", "--branch", "main",
             "--status", "success", "--limit", "10", "--json", "databaseId"],
            capture_output=True, text=True, timeout=30,
        )
        if res.returncode != 0:
            return None
        run_ids = [r["databaseId"] for r in json.loads(res.stdout or "[]")]
        for rid in run_ids:
            dl = subprocess.run(
                ["gh", "run", "download", str(rid), "-n", "ai-engine-coverage-xml",
                 "-D", str(dest_dir)],
                capture_output=True, text=True, timeout=60,
            )
            if dl.returncode == 0:
                # the artifact may unpack the xml at the root or nested
                for cand in (dest_dir / "coverage.xml", *dest_dir.rglob("coverage.xml")):
                    if cand.exists():
                        return cand
        return None
    except Exception:  # noqa: BLE001 — fail-soft by contract
        return None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--xml", default=str(DEFAULT_XML))
    ap.add_argument("--surface", default="python-ai-engine")
    ap.add_argument("--date", default=None)
    ap.add_argument("--ledger", default=str(DEFAULT_LEDGER))
    ap.add_argument("--provenance", default="checkpoint")
    ap.add_argument("--low-threshold", type=float, default=0.60)
    ap.add_argument("--fetch-ci", action="store_true",
                    help="if no local coverage.xml, download the latest CI "
                         "coverage.yml artifact via gh (used by the checkpoint, "
                         "where ai-engine deps are absent).")
    args = ap.parse_args(argv)

    try:
        xml_path = Path(args.xml)
        provenance = args.provenance
        if not xml_path.exists() and args.fetch_ci:
            fetched = fetch_latest_ci_coverage_xml(Path(tempfile.mkdtemp()))
            if fetched is not None:
                xml_path = fetched
                provenance = f"{args.provenance}-ci-fetch"
        if not xml_path.exists():
            _warn(f"no coverage.xml at {xml_path}"
                  f"{' and CI fetch found none' if args.fetch_ci else ''}"
                  f" — skipping (run `make coverage-py` first, or use --fetch-ci).")
            return 0
        now = datetime.now(timezone.utc)
        date = args.date or now.strftime("%Y-%m-%d")
        ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        row = build_row(xml_path, args.surface, date, provenance,
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
