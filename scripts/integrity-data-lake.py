#!/usr/bin/env python3
"""
Unified telemetry data-layer analyzer — the "layer ALL data" read-only OLAP surface.

Ingests every framework telemetry source (state corpus, append-only ledgers, cron
outputs, derived indices, snapshots, anchors), normalizes each to tabular rows,
joins them on common keys (time / feature / gate), and emits a layered analysis for
system-health + forward decision-making.

DESIGN PRINCIPLES
- Read-only. Never writes to any source ledger/state/snapshot (non-superseding).
  The only output is the optional --json artifact + stdout.
- Observability, not enforcement. No gate; no exit-non-zero on findings (unless
  --exit-on-anomaly is passed for CI use).
- Stdlib-first. Works with zero third-party deps (neither duckdb nor pandas is
  required). If `duckdb` is importable, normalized tables are registered as SQL
  views and `--sql "<query>"` runs against them (the "local BigQuery": SQL over
  local files, ZERO data egress). NOT cloud BigQuery — these are framework-internal
  ledgers; uploading to GCP would be needless external egress + setup.

SOURCES (data-integrity-and-rollback-2026-05-14.md §2.7)
  state corpus       .claude/features/*/state.json
  Mechanism A        .claude/logs/gate-coverage.jsonl
  daily checkpoints  .claude/shared/integrity-checkpoint-ledger.jsonl
  weekly gate trend  .claude/shared/gate-coverage-weekly.jsonl
  adoption history   .claude/shared/measurement-adoption-history.json
  F17 index          .claude/shared/gate-last-fired.json
  live adoption      .claude/shared/measurement-adoption.json
  doc-debt           .claude/shared/documentation-debt.json
  anchors            ~/Documents/FitTracker2-backups/<dated>/.../measurement-adoption.json
  daily snapshots    ~/Documents/FitTracker2-backups/daily/* + /Volumes/DevSSD/FitTracker2-snapshots/*

Usage:
    scripts/integrity-data-lake.py                       # full human report
    scripts/integrity-data-lake.py --json PATH           # + machine artifact
    scripts/integrity-data-lake.py --section reconcile    # one section only
    scripts/integrity-data-lake.py --sql "SELECT ..."    # DuckDB only (if installed)
    scripts/integrity-data-lake.py --exit-on-anomaly      # exit 2 if any anomaly

Exit codes:
    0  ran (no anomaly, or anomalies present without --exit-on-anomaly)
    2  anomaly present AND --exit-on-anomaly
"""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
SHARED = REPO_ROOT / ".claude" / "shared"
LOGS = REPO_ROOT / ".claude" / "logs"
FEATURES = REPO_ROOT / ".claude" / "features"
# Backups moved during the 2026-07-07 ~/Developer/FitMe consolidation; keep the legacy
# ~/Documents path as a fallback. First existing root wins (mirrors integrity-diff.py +
# integrity-multi-anchor.py). Anchor loading itself defers to the multi-anchor registry
# (which resolves each anchor across both roots); this constant is only the daily-snapshot
# inventory root below.
_BACKUP_ROOTS = (
    HOME / "Developer" / "FitMe" / "backups" / "FitTracker2-backups",
    HOME / "Documents" / "FitTracker2-backups",
)
BACKUPS = next((r for r in _BACKUP_ROOTS if r.exists()), _BACKUP_ROOTS[0])
SSD_SNAPSHOTS = Path("/Volumes/DevSSD/FitTracker2-snapshots")
DIMENSIONS = ["timing_wall_time", "per_phase_timing", "cache_hits", "cu_v2"]
V6_SHIP_DATE = "2026-04-16"

# Calibration ladder — sourced from CLAUDE.md v7.10 section + must-have-cadence-followups.md.
# Static reference (these are calendar commitments, not live telemetry).
CALIBRATION_LADDER = [
    ("2026-06-18", "F16 try-repo harness advisory→enforced flip"),
    ("2026-06-20", "W9 drift-auto-isolation calibration"),
    ("2026-06-21", "PLATFORMS_TESTED (T14) advisory→enforced review (B15)"),
    ("2026-07-04", "R9 Track-B 30-day coverage read → GATE_TEST_MISSING calibration"),
    ("2026-08-12", "Data Freshness Audit #1 (uses F17 index)"),
]


# ── shared classifier import (single-source the dilution verdict) ───────────────
def _multi_anchor():
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "integrity_multi_anchor", REPO_ROOT / "scripts" / "integrity-multi-anchor.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_json(p: Path):
    try:
        return json.loads(p.read_text())
    except (OSError, json.JSONDecodeError):
        return None


def _iter_jsonl(p: Path):
    if not p.is_file():
        return
    for line in p.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


# ── LOADERS: each returns a list[dict] (a normalized "table") ───────────────────
def load_features() -> list[dict]:
    rows = []
    for sp in sorted(FEATURES.glob("*/state.json")):
        d = _load_json(sp)
        if d is None:
            rows.append({"feature": sp.parent.name, "error": "invalid_json"})
            continue
        created = (d.get("created_at") or d.get("created") or "")[:10]
        timing = d.get("timing") or {}
        prov = timing.get("total_wall_time_minutes_provenance") or ""
        rows.append({
            "feature": sp.parent.name,
            "phase": d.get("current_phase") or d.get("phase"),
            "framework_version": d.get("framework_version"),
            "created": created or None,
            "post_v6": bool(created) and created >= V6_SHIP_DATE,
            "wall_time_minutes": timing.get("total_wall_time_minutes"),
            "wall_time_provenance": "derived" if prov.startswith("backfill-derived") else ("instrumented" if timing.get("total_wall_time_minutes") else None),
            "wall_time_backfill_excluded": timing.get("wall_time_backfill"),
        })
    return rows


def load_gate_coverage() -> list[dict]:
    """Aggregate Mechanism A gate-coverage.jsonl per gate."""
    agg = defaultdict(lambda: {"candidates": 0, "checked": 0, "skipped": 0, "rows": 0, "last_ts": None})
    for r in _iter_jsonl(LOGS / "gate-coverage.jsonl"):
        gate = r.get("gate")
        if not gate:
            continue
        a = agg[gate]
        a["candidates"] += r.get("candidates", 0)
        a["checked"] += r.get("checked", 0)
        a["skipped"] += r.get("skipped", 0)
        a["rows"] += 1
        ts = r.get("timestamp") or r.get("ts")
        if ts and (a["last_ts"] is None or ts > a["last_ts"]):
            a["last_ts"] = ts
    return [{"gate": g, **v} for g, v in sorted(agg.items())]


def load_f17_index() -> list[dict]:
    d = _load_json(SHARED / "gate-last-fired.json") or {}
    gates = d.get("gates", d)
    if not isinstance(gates, dict):
        return []
    return [{"gate": g, **(v if isinstance(v, dict) else {})} for g, v in sorted(gates.items())
            if g not in ("schema_version", "generated_at", "gates")]


def load_weekly_gate_trend() -> list[dict]:
    return list(_iter_jsonl(SHARED / "gate-coverage-weekly.jsonl"))


def load_daily_checkpoints() -> list[dict]:
    return list(_iter_jsonl(SHARED / "integrity-checkpoint-ledger.jsonl"))


def load_adoption_history() -> list[dict]:
    d = _load_json(SHARED / "measurement-adoption-history.json") or {}
    return d.get("snapshots", []) if isinstance(d, dict) else []


def load_anchors() -> list[dict]:
    """Discover dated platform anchors with a per-feature measurement-adoption.json."""
    mod = _multi_anchor()
    out = []
    for label, cands in mod.ANCHOR_REGISTRY:
        for c in cands:
            if c.is_file():
                feats = mod.load_adoption_features(c)
                out.append({"label": label, "canonical": label == mod.CANONICAL_ANCHOR,
                            "n_features": len(feats or {}), "path": str(c).replace(str(HOME), "~")})
                break
    return out


def load_snapshots() -> dict:
    local = sorted([p.name for p in (BACKUPS / "daily").glob("*") if p.is_dir()]) if (BACKUPS / "daily").is_dir() else []
    ssd = sorted([p.name for p in SSD_SNAPSHOTS.glob("*") if p.is_dir()]) if SSD_SNAPSHOTS.is_dir() else []
    return {"local": local, "ssd": ssd, "ssd_mounted": SSD_SNAPSHOTS.is_dir()}


# ── ANALYSES ────────────────────────────────────────────────────────────────────
def reconcile(tables: dict) -> list[dict]:
    """Cross-source consistency checks. Each finding: {id, severity, message}."""
    f = []
    cov = tables["gate_coverage"]
    f17 = tables["f17_index"]
    weekly = tables["weekly_gate_trend"]

    cov_gates = len([g for g in cov if g["candidates"] > 0 or g["checked"] > 0])
    f17_gates = len(f17)
    # R1 — weekly distinct-gate-count vs F17 index vs live gate-coverage
    latest_weekly = weekly[-1] if weekly else {}
    wk = latest_weekly.get("distinct_gate_count", None)
    if wk is not None and f17_gates > 0 and wk == 0:
        f.append({"id": "R1-weekly-zero-vs-index", "severity": "HIGH",
                  "message": f"weekly gate trend reports distinct_gate_count=0 ({latest_weekly.get('date')}) "
                             f"but F17 index has {f17_gates} gates and gate-coverage.jsonl has {cov_gates} "
                             "emitting gates — the weekly observer is blind (cron-context emptiness or reader divergence)."})

    # R2 — live adoption fully_adopted vs latest daily-checkpoint row
    live = _load_json(SHARED / "measurement-adoption.json") or {}
    live_fa = (live.get("summary") or {}).get("fully_adopted")
    chk = tables["daily_checkpoints"]
    if chk and live_fa is not None:
        last = chk[-1]
        chk_fa = (last.get("metrics") or {}).get("fully_adopted_post_v6")
        # not directly comparable (post_v6 subset) — report side by side as info
        f.append({"id": "R2-adoption-vs-checkpoint", "severity": "INFO",
                  "message": f"live fully_adopted={live_fa}; latest daily-checkpoint ({last.get('date')}) "
                             f"fully_adopted_post_v6={chk_fa}."})

    # R3 — anchor feature-set deltas (dilution attribution) vs canonical
    anchors = tables["anchors"]
    canonical = next((a for a in anchors if a["canonical"]), None)
    live_n = (live.get("summary") or {}).get("features_total")
    if canonical and live_n is not None:
        grew = live_n - canonical["n_features"]
        f.append({"id": "R3-corpus-growth", "severity": "INFO",
                  "message": f"corpus grew {canonical['n_features']} → {live_n} (+{grew}) since canonical "
                             f"anchor {canonical['label']} — raw % targets are diluted by this; use cohort view."})

    # R4 — snapshot local vs SSD parity
    snaps = tables["snapshots"]
    if snaps["ssd_mounted"]:
        only_local = set(snaps["local"]) - set(snaps["ssd"])
        only_ssd = set(snaps["ssd"]) - set(snaps["local"])
        if only_local or only_ssd:
            f.append({"id": "R4-snapshot-parity", "severity": "LOW",
                      "message": f"daily snapshot dirs differ: {len(only_local)} local-only, {len(only_ssd)} SSD-only "
                                 "(dual-write drift; SSD is the non-authoritative copy)."})
    else:
        f.append({"id": "R4-ssd-unmounted", "severity": "LOW",
                  "message": "DevSSD snapshot sibling not mounted — SSD parity not checkable this run."})

    # R5 — zero-candidate gates in F17 (mis-wire class) cross-ref
    zero_cand = [g["gate"] for g in f17 if g.get("total_candidates", g.get("total_firings", 1)) == 0
                 and g.get("total_firings", 0) == 0]
    if zero_cand:
        f.append({"id": "R5-zero-candidate-gates", "severity": "LOW",
                  "message": f"{len(zero_cand)} gate(s) in F17 index with 0 candidates+0 firings "
                             f"({', '.join(zero_cand[:6])}) — verify via GATE_COVERAGE_ZERO whether healthy-zero or mis-wired."})

    # R6 — doc-debt open vs latest checkpoint
    debt = (_load_json(SHARED / "documentation-debt.json") or {}).get("summary", {}).get("open_debt_items")
    if debt is not None and chk:
        chk_debt = (chk[-1].get("metrics") or {}).get("doc_debt_open")
        if chk_debt is not None and chk_debt != debt:
            f.append({"id": "R6-debt-drift", "severity": "LOW",
                      "message": f"doc-debt open={debt} but latest checkpoint row={chk_debt} (stale checkpoint)."})

    # R7 — canonical anchor resolvability (path-drift guard). If the canonical anchor
    # does not resolve, the dilution-normalized adoption section is UNVERIFIED — surface
    # it as HIGH so --exit-on-anomaly trips instead of silently reporting "none".
    mod = _multi_anchor()
    canonical_ok = any(
        label == mod.CANONICAL_ANCHOR and any(c.is_file() for c in cands)
        for label, cands in mod.ANCHOR_REGISTRY
    )
    if not canonical_ok:
        f.append({"id": "R7-canonical-anchor-unresolved", "severity": "HIGH",
                  "message": f"canonical anchor {mod.CANONICAL_ANCHOR} did not resolve under any "
                             "backup root — dilution vs regression NOT checked (path drift). "
                             "Fix _BACKUP_ROOTS in integrity-multi-anchor.py."})
    return f


def adoption_normalized(tables: dict) -> dict:
    """Dilution-normalized adoption vs the canonical anchor (reuses classify_delta)."""
    mod = _multi_anchor()
    canonical_path = None
    for label, cands in mod.ANCHOR_REGISTRY:
        if label == mod.CANONICAL_ANCHOR:
            canonical_path = next((c for c in cands if c.is_file()), None)
    out = {"canonical_anchor": mod.CANONICAL_ANCHOR, "dimensions": {},
           "real_regressions": [], "anchor_available": False}
    if not canonical_path:
        # The canonical anchor did not resolve (path drift / missing backup). This is
        # NOT "no regressions" — it is "not checked". anchor_available stays False so the
        # printer + callers surface UNVERIFIED instead of a vacuous clean bill of health.
        return out
    anc = mod.load_adoption_features(canonical_path)
    live = mod.load_adoption_features(SHARED / "measurement-adoption.json")
    if not anc or not live:
        return out
    out["anchor_available"] = True
    for dim in DIMENSIONS:
        c = mod.classify_delta(anc, live, dim)
        out["dimensions"][dim] = c
        if c["verdict"] == "REAL_REGRESSION":
            out["real_regressions"].append(dim)
    return out


def forward_digest(tables: dict, reconcile_findings: list[dict]) -> dict:
    anomalies = [x for x in reconcile_findings if x["severity"] in ("HIGH", "CRITICAL")]
    return {
        "calibration_ladder": [{"date": d, "item": i} for d, i in CALIBRATION_LADDER],
        "open_anomalies": len(anomalies),
        "ranked_anomalies": sorted(reconcile_findings,
                                   key=lambda x: {"CRITICAL": 0, "HIGH": 1, "LOW": 2, "INFO": 3}[x["severity"]]),
    }


# ── REPORT ──────────────────────────────────────────────────────────────────────
def build(tables: dict) -> dict:
    rec = reconcile(tables)
    return {
        "generated_for": "integrity-data-lake",
        "source_counts": {
            "features": len(tables["features"]),
            "gate_coverage_gates": len(tables["gate_coverage"]),
            "f17_gates": len(tables["f17_index"]),
            "weekly_gate_snapshots": len(tables["weekly_gate_trend"]),
            "daily_checkpoints": len(tables["daily_checkpoints"]),
            "adoption_history_snapshots": len(tables["adoption_history"]),
            "anchors": len(tables["anchors"]),
            "daily_snapshots_local": len(tables["snapshots"]["local"]),
            "daily_snapshots_ssd": len(tables["snapshots"]["ssd"]),
        },
        "reconciliation": rec,
        "adoption_normalized": adoption_normalized(tables),
        "forward_digest": forward_digest(tables, rec),
    }


def print_report(report: dict, tables: dict, section: str | None):
    sc = report["source_counts"]
    if section in (None, "sources"):
        print("=== Unified Telemetry Data-Lake — source inventory ===")
        for k, v in sc.items():
            print(f"  {k:32s} {v}")
        print()
    if section in (None, "reconcile"):
        print("=== Cross-source reconciliation ===")
        for x in report["reconciliation"]:
            print(f"  [{x['severity']:8s}] {x['id']}: {x['message']}")
        if not report["reconciliation"]:
            print("  (no findings)")
        print()
    if section in (None, "adoption"):
        an = report["adoption_normalized"]
        print(f"=== Dilution-normalized adoption vs canonical anchor {an['canonical_anchor']} ===")
        if not an.get("anchor_available"):
            print("  ⚠ canonical anchor UNAVAILABLE — dilution vs regression NOT checked "
                  "(path drift / missing backup). This is NOT a clean bill of health.")
        else:
            for dim, c in an["dimensions"].items():
                print(f"  {dim:22s} raw {c['raw_anchor']:.1f}%→{c['raw_latest']:.1f}%  "
                      f"cohort {c['cohort_anchor']:.1f}%→{c['cohort_latest']:.1f}% ({c['cohort_delta']:+.1f})  "
                      f"num {c['num_anchor']}→{c['num_latest']}  [{c['verdict']}]")
            print(f"  REAL regressions: {an['real_regressions'] or 'none'}")
        print()
    if section in (None, "forward"):
        fd = report["forward_digest"]
        print("=== Forward-decision digest ===")
        print(f"  open anomalies (HIGH/CRITICAL): {fd['open_anomalies']}")
        print("  calibration ladder:")
        for c in fd["calibration_ladder"]:
            print(f"    {c['date']}  {c['item']}")
        print()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", help="write the structured report to this path")
    ap.add_argument("--section", choices=["sources", "reconcile", "adoption", "forward"],
                    help="print only one section")
    ap.add_argument("--sql", help="run a SQL query against the normalized tables (requires duckdb)")
    ap.add_argument("--exit-on-anomaly", action="store_true",
                    help="exit 2 if any HIGH/CRITICAL reconciliation finding")
    args = ap.parse_args()

    tables = {
        "features": load_features(),
        "gate_coverage": load_gate_coverage(),
        "f17_index": load_f17_index(),
        "weekly_gate_trend": load_weekly_gate_trend(),
        "daily_checkpoints": load_daily_checkpoints(),
        "adoption_history": load_adoption_history(),
        "anchors": load_anchors(),
        "snapshots": load_snapshots(),
    }

    if args.sql:
        try:
            import duckdb
        except ImportError:
            print("⚠ --sql requires duckdb (not installed); SKIPPING. "
                  "Install with `pip install duckdb` for the local-SQL backend.")
            return 0
        con = duckdb.connect(":memory:")
        for name in ("features", "gate_coverage", "f17_index", "weekly_gate_trend",
                     "daily_checkpoints", "adoption_history", "anchors"):
            rows = tables[name]
            if rows:
                con.register(name, _to_columnar(rows))
        print(con.execute(args.sql).fetchdf().to_string())
        return 0

    report = build(tables)
    print_report(report, tables, args.section)
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2) + "\n")
        print(f"wrote {args.json}")

    anomalies = [x for x in report["reconciliation"] if x["severity"] in ("HIGH", "CRITICAL")]
    return 2 if (anomalies and args.exit_on_anomaly) else 0


def _to_columnar(rows: list[dict]):
    """List-of-dicts → dict-of-lists for duckdb.register (union of keys)."""
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    return {k: [r.get(k) for r in rows] for k in keys}


if __name__ == "__main__":
    raise SystemExit(main())
