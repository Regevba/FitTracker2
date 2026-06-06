#!/usr/bin/env python3
"""HADF signature-expansion T1 — backfill `calibration_status` across the 3 catalogs.

The load-bearing honesty field: every recognition row is either
  - "instrumented"      — produced by MEASURING inference on the substrate
                          (real TTFT/TPS + a sample count n); or
  - "prior_unvalidated" — a published spec-sheet profile, no measured inference.

Migration (idempotent — only sets the field where missing):
  reference-signatures.json   8 measured cloud endpoints  -> instrumented + class:cloud
  chip-profiles.json          24 static on-device profiles -> prior_unvalidated
  hardware-signature-table.json 7 static datacenter sigs   -> prior_unvalidated (per-sig)

Also applies `memory_topology` to Apple SoCs (soc_unified) where absent — the enum
was defined in schema_v1_1_notes but never applied to any profile.

Run from repo root. Re-running is a no-op. See integration-spec.md §6.
"""
import json
import os
import sys

REF = ".claude/shared/hadf/reference-signatures.json"
PROFILES = ".claude/shared/chip-profiles.json"
SIGTABLE = ".claude/shared/hadf/hardware-signature-table.json"


def migrate_reference(path):
    d = json.load(open(path))
    changed = 0
    for e in d.get("endpoints", []):
        if "calibration_status" not in e:
            e["calibration_status"] = "instrumented"  # built from measured sub-exp data
            changed += 1
        if "class" not in e:
            e["class"] = "cloud"  # the 8 baseline endpoints are all cloud APIs
            changed += 1
    if changed:
        json.dump(d, open(path, "w"), indent=2)
    return changed, len(d.get("endpoints", []))


def migrate_profiles(path):
    d = json.load(open(path))
    profs = d.get("profiles", {})
    changed = 0
    for pid, p in profs.items():
        if "calibration_status" not in p:
            p["calibration_status"] = "prior_unvalidated"  # static published spec
            changed += 1
        # apply memory_topology to Apple SoCs where absent (enum already defined)
        if p.get("vendor") == "Apple" and "memory_topology" not in p:
            p["memory_topology"] = "soc_unified"
            changed += 1
    if changed:
        json.dump(d, open(path, "w"), indent=2)
    return changed, len(profs)


def migrate_sigtable(path):
    d = json.load(open(path))
    sigs = d.get("signatures", {})
    changed = 0
    for sid, s in sigs.items():
        if "calibration_status" not in s:
            # table-level says "uncalibrated"; per-sig is prior until Phase-2-bis-style calibration
            s["calibration_status"] = "prior_unvalidated"
            changed += 1
    if changed:
        json.dump(d, open(path, "w"), indent=2)
    return changed, len(sigs)


def main():
    if not os.path.exists(REF):
        print(f"ERROR: run from repo root (missing {REF})", file=sys.stderr)
        sys.exit(1)
    rc, rn = migrate_reference(REF)
    pc, pn = migrate_profiles(PROFILES)
    sc, sn = migrate_sigtable(SIGTABLE)
    print(json.dumps({
        "reference-signatures.json": {"endpoints": rn, "fields_set": rc, "status": "instrumented"},
        "chip-profiles.json": {"profiles": pn, "fields_set": pc, "status": "prior_unvalidated"},
        "hardware-signature-table.json": {"signatures": sn, "fields_set": sc, "status": "prior_unvalidated"},
    }, indent=2))


if __name__ == "__main__":
    main()
