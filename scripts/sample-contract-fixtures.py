#!/usr/bin/env python3
"""sample-contract-fixtures — sample cross-repo data contracts from the CANONICAL
producer so consumer tests can't silently drift (F-CONTRACT-FIXTURE-SAMPLING).

Closes the W16 silent-pass class (2026-05-24): a consumer-side test fixture
hand-authored to the consumer's *expected* shape stays green even when the
producer's *actual* shape drifts. The structural fix is to draw the fixture
from the producer's real output and assert the contract's required keys are
present at sample time.

Two modes:
  (default)  Regenerate fixtures: read N records from each contract's producer,
             assert required_keys, write tests/fixtures/contracts/<name>.jsonl
             + <name>.meta.json (sampled_at, producer, provenance, count).
  --check    CI gate: every contract must have a fixture that (a) exists,
             (b) is younger than manifest max_age_days, and (c) still contains
             every required_key. Exit 1 on any failure.

Cross-repo producers (producer_repo != FitTracker2) are sampled from their
declared local_mirror with provenance="mirror"; the canonical sample for those
is produced on the producer's own repo side.
"""
from __future__ import annotations

import argparse
import glob
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / ".claude" / "shared" / "contract-manifest.json"


def _load_manifest() -> dict:
    return json.loads(MANIFEST.read_text())


def _read_jsonl(path: Path, n: int) -> list[dict]:
    """Return up to the last n valid JSON objects from a .jsonl file."""
    records: list[dict] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return records[-n:]


def _read_json_glob(pattern: str, n: int) -> list[dict]:
    out: list[dict] = []
    for fp in sorted(glob.glob(str(REPO_ROOT / pattern)))[:n]:
        try:
            out.append(json.loads(Path(fp).read_text()))
        except (OSError, json.JSONDecodeError):
            continue
    return out


def _missing_keys(records: list[dict], required: list[str]) -> list[str]:
    """Keys that are absent from EVERY sampled record (contract drift signal)."""
    if not records:
        return list(required)
    return [k for k in required if not any(k in r for r in records)]


def _sample_source(contract: dict) -> tuple[Path | None, str]:
    """Resolve the readable source for a contract → (path, provenance)."""
    is_local = contract.get("producer_repo") == "FitTracker2"
    if is_local:
        return REPO_ROOT / contract["producer_path"], "canonical"
    mirror = contract.get("local_mirror")
    if mirror:
        return REPO_ROOT / mirror, "mirror"
    return None, "unavailable"


def regenerate(manifest: dict) -> int:
    sample_dir = REPO_ROOT / manifest["sample_dir"]
    sample_dir.mkdir(parents=True, exist_ok=True)
    errors = 0
    for c in manifest["contracts"]:
        name = c["name"]
        n = c.get("sample_size", 10)
        fmt = c.get("producer_format", "jsonl")
        out_path = sample_dir / f"{name}.jsonl"
        meta_path = sample_dir / f"{name}.meta.json"

        if fmt == "json-glob":
            records = _read_json_glob(c["producer_path"], n)
            provenance = "canonical"
        else:
            src, provenance = _sample_source(c)
            if src is None or not src.is_file():
                print(f"  ! {name}: source unavailable ({src}) — skipped")
                errors += 1
                continue
            records = _read_jsonl(src, n)

        missing = _missing_keys(records, c.get("required_keys", []))
        if missing:
            print(f"  ! {name}: producer records MISSING required keys {missing} "
                  f"— contract may have drifted; NOT writing fixture")
            errors += 1
            continue

        out_path.write_text("".join(json.dumps(r) + "\n" for r in records))
        meta_path.write_text(json.dumps({
            "contract": name,
            "sampled_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "provenance": provenance,
            "record_count": len(records),
            "required_keys": c.get("required_keys", []),
            "producer_repo": c.get("producer_repo"),
        }, indent=2) + "\n")
        print(f"  ✓ {name}: {len(records)} records ({provenance}) → "
              f"{out_path.relative_to(REPO_ROOT)}")
    return 1 if errors else 0


def check(manifest: dict, *, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    max_age = manifest.get("max_age_days", 7)
    sample_dir = REPO_ROOT / manifest["sample_dir"]
    failures = 0
    for c in manifest["contracts"]:
        name = c["name"]
        # Cross-repo producers own their canonical fixture on their own repo;
        # FT2 only holds a (gitignored, PII-bearing) mirror, so don't gate on it.
        if c.get("producer_repo") != "FitTracker2":
            print(f"  · {name}: skipped FT2-side (canonical fixture is "
                  f"{c.get('producer_repo')}-side)")
            continue
        out_path = sample_dir / f"{name}.jsonl"
        meta_path = sample_dir / f"{name}.meta.json"
        if not out_path.is_file() or not meta_path.is_file():
            print(f"  ✗ {name}: fixture missing — run `make sample-contract-fixtures`")
            failures += 1
            continue
        meta = json.loads(meta_path.read_text())
        sampled_at = datetime.fromisoformat(meta["sampled_at"])
        age_days = (now - sampled_at).total_seconds() / 86400
        if age_days > max_age:
            print(f"  ✗ {name}: fixture is {age_days:.1f}d old (> {max_age}d) — re-sample")
            failures += 1
        records = _read_jsonl(out_path, 10_000)
        missing = _missing_keys(records, c.get("required_keys", []))
        if missing:
            print(f"  ✗ {name}: fixture missing required keys {missing}")
            failures += 1
        if age_days <= max_age and not missing:
            print(f"  ✓ {name}: fresh ({age_days:.1f}d) + complete ({len(records)} records)")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="CI gate: assert fixtures fresh + complete (no writes)")
    args = ap.parse_args()
    manifest = _load_manifest()
    if args.check:
        print("Contract-fixture freshness check:")
        return check(manifest)
    print("Sampling contract fixtures from canonical producers:")
    return regenerate(manifest)


if __name__ == "__main__":
    sys.exit(main())
