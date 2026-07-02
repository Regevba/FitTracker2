#!/usr/bin/env python3
"""
scripts/gate-catalog.py — T16 (test-coverage master plan §4, TC-T16).

The machine-derived **gate catalog**: one queryable manifest that annotates
every framework gate with

  • an AUTHORED `stage`  — write-time | cycle-time | hook | standalone
  • an AUTHORED `source` — the file that defines/fires the gate
  • an AUTHORED `enforcement` — enforced | advisory | advisory-only |
                                advisory-permanent | finding
  • a DERIVED  `tier`   — the deepest TEST layer that covers the gate:
                          try-repo > dispatch > unit > none

plus the concrete coverage refs used to derive the tier (`fixture_path`,
`test_files` with their layer). The derivation scans the live repo, so the
catalog cannot silently drift from reality — `--check` re-derives and fails
on any mismatch.

Why this exists: before T16 there was no single place that answered "which
stage does gate X fire at, and is it tested?" The count lived in prose in
docs/FRAMEWORK-FACTS.md and the test coverage was implicit in
tests/fixtures/ + scripts/tests/. This manifest makes both queryable and
directly feeds the planned **T1 GATE_TEST_MISSING** meta-gate: `tier ==
"none"` is the machine signal for "this gate ships without a test".

Usage:
    python3 scripts/gate-catalog.py            # write .claude/shared/gate-catalog.json
    python3 scripts/gate-catalog.py --check     # validate committed catalog vs live derivation (CI)
    python3 scripts/gate-catalog.py --print      # write + print a human summary table

Exit codes:
    0  success (write) OR catalog matches live derivation (--check)
    1  --check drift: committed catalog != freshly derived, or an authored
       gate/fixture is orphaned
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

SCHEMA_VERSION = 1
REPO_ROOT = Path(
    os.environ.get("REPO_ROOT_OVERRIDE", Path(__file__).resolve().parent.parent)
)
CATALOG_PATH = REPO_ROOT / ".claude" / "shared" / "gate-catalog.json"
FIXTURES_DIR = REPO_ROOT / "tests" / "fixtures"
TESTS_DIR = REPO_ROOT / "scripts" / "tests"

# Test-layer ranking (higher = deeper coverage). Mirrors the F16 3-layer model:
# unit (per-function) < dispatch (monkey-patched main()) < try-repo (real hook
# via subprocess against a throwaway git repo).
TIER_RANK = {"none": 0, "unit": 1, "dispatch": 2, "try-repo": 3}

# --------------------------------------------------------------------------
# AUTHORED gate metadata — the canonical 32-gate set.
# Source of truth for the enumeration: docs/FRAMEWORK-FACTS.md (reconciled
# 2026-06-29): 20 write-time + 9 cycle-time + 2 W9 hooks + 1 standalone.
#
# `fixture_key` overrides the try-repo fixture directory name when it differs
# from the gate id (e.g. the Mode B gate's fixture is suffixed).
# --------------------------------------------------------------------------
GATES: dict[str, dict] = {
    # ---- Write-time (20) — scripts/check-state-schema.py ----
    "BRANCH_ISOLATION_VIOLATION": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced", "fixture_key": "BRANCH_ISOLATION_VIOLATION_MODE_B",
        "description": "Mode B — infra-path commit staged on a non-isolated branch.",
    },
    "BRANCH_ISOLATION_VIOLATION_MODE_C": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Mode C — state.json current_phase mutation from a non-feature branch.",
    },
    "CACHE_HITS_AUTO_INSTRUMENTATION_DRIFT": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Empty cache_hits[] on a post-v6 feature at complete-transition.",
    },
    "CSV_TAXONOMY_DRIFT": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "advisory",
        "description": "AN-1B.1 — staged AnalyticsEvent value has no analytics-taxonomy.csv row.",
    },
    "CU_V2_INVALID": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "cu_v2 schema invalid (4 factors in [0,1], total within 0.01, valid tier_class).",
    },
    "FEATURE_CLOSURE_COMPLETENESS": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "complete-transition missing required case-study frontmatter / kill_criteria_resolution / PR parity.",
    },
    "FRAMEWORK_VERSION_FORMAT": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "framework_version not in canonical vX.Y form.",
    },
    "FRAMEWORK_VERSION_STALE": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "advisory",
        "description": "F4 — framework_version behind the current framework version (advisory→enforced review ~2026-06-30).",
    },
    "GA4_MCP_DISCONNECTED": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "advisory-only",
        "description": "AN-1B.2 — analytics code staged while GA4 MCP env unreachable. Never blocks by design.",
    },
    "ISOLATION_OPT_OUT_REASON_MISSING": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "isolation_opt_out:true with empty isolation_opt_out_reason.",
    },
    "PHASE_TRANSITION_NO_LOG": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "current_phase change without a matching .claude/logs/<feature>.log.json event in 15 min.",
    },
    "PHASE_TRANSITION_NO_TIMING": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "current_phase change without timing.phases.<phase> started_at/ended_at.",
    },
    "PLATFORMS_TESTED": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "T14 — complete-transition with no platforms_tested platform true (Q2-exempt for framework-meta).",
    },
    "PR_NUMBER_UNRESOLVED": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "phases.merge.pr_number does not resolve in the cached gh pr list (skipped when gh unavailable).",
    },
    "SCHEMA_DRIFT_LEGACY_CREATED": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Legacy `created` key present; canonical is `created_at`.",
    },
    "SCHEMA_DRIFT_LEGACY_PHASE": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Legacy `phase` key present; canonical is `current_phase`.",
    },
    "STATE_NO_CASE_STUDY_LINK": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Terminal phase with no case_study link and no case_study_type exemption.",
    },
    "STATE_OWNER_INVALID": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "state_owner not in the valid enum {ft2, fitme-story}.",
    },
    "STATE_OWNER_LOCATION_MISMATCH": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "state.json file location does not match state_owner (reverse-sync mirrors exempt).",
    },
    "STATE_OWNER_MISSING": {
        "stage": "write-time", "source": "scripts/check-state-schema.py",
        "enforcement": "enforced",
        "description": "Required state_owner field absent.",
    },
    "CASE_STUDY_MISSING_FIELDS": {
        "stage": "write-time", "source": "scripts/check-case-study-preflight.py",
        "enforcement": "enforced",
        "description": "Post-cutoff (>= 2026-04-21) scoped case study missing required frontmatter fields. "
                       "Lives in check-case-study-preflight.py (a 2nd pre-commit gate host), NOT check-state-schema.py.",
    },
    # ---- Cycle-time (9) — scripts/integrity-check.py ----
    "BROKEN_PR_CITATION": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "finding",
        "description": "Case study cites a PR number that does not resolve (skipped gracefully when gh unavailable).",
    },
    "CASE_STUDY_MISSING_TIER_TAGS": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "finding",
        "description": "Scoped case study (dated >= 2026-04-21) with no T1/T2/T3 tier tag.",
    },
    "PATTERN_SKILL_UNMAPPED": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "finding",
        "description": "Observed-patterns entry not mapped to a skill in pattern-skill-map.json.",
    },
    "TIER_TAG_LIKELY_INCORRECT": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "advisory-permanent",
        "description": "Heuristic T1/T2/T3 mismatch (kill criterion 2 fired at baseline; ships advisory-permanent).",
    },
    "PHASE_LIE": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "finding",
        "description": "state.json current_phase inconsistent with the phases block / evidence.",
    },
    "CACHE_HITS_AUTO_INSTRUMENTATION_INACTIVE": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "advisory",
        "description": "Session events show Reads but state.json cache_hits[] is empty.",
    },
    "BRANCH_ISOLATION_HISTORICAL": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "advisory",
        "description": "T17 forward-only audit of past infra commits' isolation.",
    },
    "STATE_TASKS_FILESYSTEM_DRIFT": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "advisory-permanent",
        "description": "f1 — state.json tasks reference files that do not exist (shipped 2026-06-17 #752).",
    },
    "DEPENDENCY_GRAPH_CYCLE": {
        "stage": "cycle-time", "source": "scripts/integrity-check.py",
        "enforcement": "advisory-permanent",
        "description": "f3 — Phase 2 task dependency graph contains a cycle/mismatch (shipped 2026-06-17 #753).",
    },
    # ---- W9 real-time hooks (2) — PostToolUse ----
    "w9.auto_isolate": {
        "stage": "hook", "source": "scripts/check-branch-drift.py",
        "enforcement": "advisory",
        "description": "W9 — offers auto-isolation when infra work is detected off an isolated branch.",
    },
    "w9.concurrency": {
        "stage": "hook", "source": "scripts/check-branch-drift.py",
        "enforcement": "advisory",
        "description": "W9 — detects an unexpected concurrent branch flip within a session (HOLD at advisory 2026-06-28).",
    },
    # ---- Standalone (1) ----
    "FIGMA_MIRROR_STALENESS": {
        "stage": "standalone", "source": "scripts/figma-mirror-staleness.py",
        "enforcement": "advisory-permanent",
        "description": "Code-token (tokens.json) vs Figma-mirror-snapshot drift. Runs on `make figma-mirror-staleness`.",
    },
}


# The catalog's own test file mentions many gate ids in its assertions; it is
# NOT a test *of* those gates, so it must be excluded from the coverage scan to
# avoid self-referential over-crediting.
_SELF_TEST = "test_gate_catalog.py"


def _iter_test_files() -> list[Path]:
    if not TESTS_DIR.is_dir():
        return []
    return sorted(
        p for p in TESTS_DIR.glob("test_*.py")
        if p.is_file() and p.name != _SELF_TEST
    )


def _layer_for_test_file(name: str) -> str:
    """Classify a scripts/tests/ file into a test layer by naming convention.

    Note: `try-repo` is deliberately NOT inferable from a filename. The
    try-repo harness is fixture-driven, so real try-repo coverage is proven by
    a `tests/fixtures/<GATE>/` directory — not by a gate id appearing inside
    some other gate's `test_try_repo_*` file (that is an incidental mention via
    the shared baseline state, and would over-credit the tier)."""
    if "dispatch" in name:
        return "dispatch"
    return "unit"


def derive_coverage(gate_id: str, meta: dict, test_files: list[Path]) -> dict:
    """Derive the test tier + concrete coverage refs for one gate by scanning
    the live repo (fixtures + scripts/tests). Pure filesystem read — no guess."""
    fixture_key = meta.get("fixture_key", gate_id)
    fixture_dir = FIXTURES_DIR / fixture_key
    has_fixture = fixture_dir.is_dir()

    found: list[dict] = []
    layers_present: set[str] = set()
    for tf in test_files:
        try:
            text = tf.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if gate_id in text:
            layer = _layer_for_test_file(tf.name)
            found.append({"file": f"scripts/tests/{tf.name}", "layer": layer})
            layers_present.add(layer)

    # Fixture presence is the ONLY authoritative try-repo signal (the harness is
    # fixture-driven). This is what the future T1 GATE_TEST_MISSING meta-gate
    # keys on when it asserts "every enforced write-time gate has a try-repo
    # fixture".
    if has_fixture:
        layers_present.add("try-repo")

    tier = "none"
    for layer in layers_present:
        if TIER_RANK[layer] > TIER_RANK[tier]:
            tier = layer

    return {
        "tier": tier,
        "fixture_path": (
            f"tests/fixtures/{fixture_key}/" if has_fixture else None
        ),
        "test_files": found,
    }


def build_catalog() -> dict:
    test_files = _iter_test_files()
    gates: dict[str, dict] = {}
    for gate_id, meta in GATES.items():
        cov = derive_coverage(gate_id, meta, test_files)
        entry = {
            "stage": meta["stage"],
            "source": meta["source"],
            "enforcement": meta["enforcement"],
            "description": meta["description"],
            "tier": cov["tier"],
            "fixture_path": cov["fixture_path"],
            "test_files": cov["test_files"],
        }
        gates[gate_id] = entry

    stages: dict[str, int] = {}
    tiers: dict[str, int] = {}
    for e in gates.values():
        stages[e["stage"]] = stages.get(e["stage"], 0) + 1
        tiers[e["tier"]] = tiers.get(e["tier"], 0) + 1

    untested = sorted(g for g, e in gates.items() if e["tier"] == "none")
    # T1 GATE_TEST_MISSING precursor signal: write-time gates without their own
    # try-repo fixture (the F16 discipline says every write-time gate should
    # ship one). Distinct from `untested` — these DO have unit/dispatch tests
    # but lack the deepest (integration) layer.
    write_time_without_try_repo = sorted(
        g for g, e in gates.items()
        if e["stage"] == "write-time" and e["tier"] != "try-repo"
    )

    return {
        "schema_version": SCHEMA_VERSION,
        "gate_count": len(gates),
        "summary": {
            "by_stage": dict(sorted(stages.items())),
            "by_tier": dict(sorted(tiers.items())),
            "untested_gates": untested,
            "write_time_without_try_repo": write_time_without_try_repo,
        },
        "gates": gates,
    }


def orphan_fixtures() -> list[str]:
    """Fixture dirs on disk that no authored gate claims (via id or fixture_key)."""
    if not FIXTURES_DIR.is_dir():
        return []
    claimed = set()
    for gate_id, meta in GATES.items():
        claimed.add(meta.get("fixture_key", gate_id))
    orphans = []
    for p in sorted(FIXTURES_DIR.iterdir()):
        if not p.is_dir() or p.name.startswith("_") or p.name == "contracts":
            continue
        if p.name not in claimed:
            orphans.append(p.name)
    return orphans


def _dump(catalog: dict) -> str:
    return json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"


def cmd_check() -> int:
    fresh = build_catalog()
    if not CATALOG_PATH.exists():
        print(f"FAIL: {CATALOG_PATH} does not exist — run `make gate-catalog`.", file=sys.stderr)
        return 1
    committed = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    rc = 0
    if committed != fresh:
        print("FAIL: committed gate-catalog.json is stale vs live derivation.", file=sys.stderr)
        print("      Run `make gate-catalog` and commit the result.", file=sys.stderr)
        # surface the first-level diff for the operator
        cg = committed.get("gates", {})
        fg = fresh.get("gates", {})
        for gid in sorted(set(cg) | set(fg)):
            if cg.get(gid) != fg.get(gid):
                print(f"      drift: {gid}", file=sys.stderr)
        rc = 1
    orphans = orphan_fixtures()
    if orphans:
        print(f"FAIL: try-repo fixtures with no catalog gate: {orphans}", file=sys.stderr)
        print("      Add the gate to GATES or remove/rename the fixture.", file=sys.stderr)
        rc = 1
    if rc == 0:
        print(f"OK: gate-catalog.json matches live derivation ({fresh['gate_count']} gates, "
              f"{len(fresh['summary']['untested_gates'])} untested).")
    return rc


def cmd_write(do_print: bool) -> int:
    catalog = build_catalog()
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(_dump(catalog), encoding="utf-8")
    print(f"Wrote {CATALOG_PATH.relative_to(REPO_ROOT)} — {catalog['gate_count']} gates.")
    orphans = orphan_fixtures()
    if orphans:
        print(f"  warning: orphan try-repo fixtures (no catalog gate): {orphans}")
    if do_print:
        s = catalog["summary"]
        print("\n  by stage:", ", ".join(f"{k}={v}" for k, v in s["by_stage"].items()))
        print("  by tier: ", ", ".join(f"{k}={v}" for k, v in s["by_tier"].items()))
        print(f"  untested ({len(s['untested_gates'])}):", ", ".join(s["untested_gates"]) or "none")
        print(f"\n  {'GATE':<44} {'STAGE':<11} {'TIER':<9} ENFORCEMENT")
        for gid, e in catalog["gates"].items():
            print(f"  {gid:<44} {e['stage']:<11} {e['tier']:<9} {e['enforcement']}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Build/validate the framework gate catalog (T16).")
    ap.add_argument("--check", action="store_true",
                    help="Validate committed catalog vs live derivation; exit 1 on drift/orphans.")
    ap.add_argument("--print", dest="do_print", action="store_true",
                    help="Write, then print a human summary table.")
    args = ap.parse_args()
    if args.check:
        return cmd_check()
    return cmd_write(args.do_print)


if __name__ == "__main__":
    sys.exit(main())
