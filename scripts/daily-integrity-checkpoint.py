#!/usr/bin/env python3
"""
Daily integrity checkpoint — full platform telemetry snapshot + ledger update.

Captures the same surfaces as the manual 2026-05-14 platform baseline:
  - All 6 `make` readouts (integrity-check, documentation-debt, measurement-adoption,
    membrane-status, verify-isolation, feature-completeness-audit)
  - All shared ledgers (.claude/shared/*.json)
  - All 70 features' state.json (tarball)
  - Mechanism A gate-coverage summary (17 gates / N rows)
  - Mechanism C session-event count
  - Git head context for both repos

Writes the snapshot to TWO locations:
  - Local internal:  ~/Documents/FitTracker2-backups/daily/YYYY-MM-DD/
  - SSD (sibling):   /Volumes/DevSSD/FitTracker2-snapshots/YYYY-MM-DD/

Appends one row to .claude/shared/integrity-checkpoint-ledger.jsonl per run,
diffs key metrics vs the previous ledger row, and regenerates the human-readable
.claude/shared/integrity-checkpoint-ledger.md companion.

Idempotency: skips silently if today's snapshot already exists in either location
unless --force is passed. Designed to be safe to call from a SessionStart hook,
launchd cron, or operator invocation.

Drive-risk note: the SSD copy may fail (DevSSD unmount, hardware drop). Failure
is logged + flagged in the ledger row but does NOT fail the run — the local
internal copy remains authoritative.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCAL_BACKUP_ROOT = Path.home() / "Documents" / "FitTracker2-backups" / "daily"
SSD_BACKUP_ROOT = Path("/Volumes/DevSSD/FitTracker2-snapshots")
FITME_STORY_REPO = Path("/Volumes/DevSSD/fitme-story")

LEDGER_JSONL = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-ledger.jsonl"
LEDGER_MD = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-ledger.md"
REGRESSION_FLAG = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-regression.flag"


def run(cmd: list[str], cwd: Path = REPO_ROOT, timeout: int = 300) -> tuple[int, str]:
    try:
        r = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False
        )
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except subprocess.TimeoutExpired:
        return 124, f"<timeout after {timeout}s>"
    except FileNotFoundError as e:
        return 127, f"<not found: {e}>"


def sha256_of_dir(d: Path) -> str:
    """Compute a stable sha256 of all files in d (sorted-by-relpath, concatenated hashes)."""
    h = hashlib.sha256()
    for p in sorted(d.rglob("*")):
        if p.is_file():
            rel = p.relative_to(d).as_posix()
            h.update(rel.encode())
            h.update(p.read_bytes())
    return h.hexdigest()


def capture_make_outputs() -> dict:
    """Run all 6 make targets and capture their output (in-memory only)."""
    targets = (
        "integrity-check",
        "documentation-debt",
        "measurement-adoption",
        "membrane-status",
        "verify-isolation",
        "feature-completeness-audit",
    )
    results = {}
    for target in targets:
        rc, out = run(["make", target])
        results[target] = {"rc": rc, "output": out}
    return results


def parse_integrity_findings(text: str) -> tuple[int, int]:
    """Parse 'Findings: N + M advisory ()' line. Returns (findings, advisory)."""
    for line in text.splitlines():
        if line.startswith("Findings:"):
            try:
                _, rhs = line.split(":", 1)
                left = rhs.strip().split("+")[0].strip()
                advisory_part = rhs.split("+", 1)[1] if "+" in rhs else "0"
                adv_n = "".join(c for c in advisory_part if c.isdigit())
                return int(left), int(adv_n or "0")
            except (ValueError, IndexError):
                continue
    return -1, -1


def parse_completeness_audit(text: str) -> tuple[int, int]:
    """Parse 'Total: N blocking + M advisory'. Returns (blocking, advisory)."""
    for line in text.splitlines():
        if line.strip().startswith("Total:"):
            try:
                rhs = line.split(":", 1)[1]
                parts = rhs.split("+")
                blocking = "".join(c for c in parts[0] if c.isdigit())
                advisory = "".join(c for c in parts[1] if c.isdigit())
                return int(blocking or "0"), int(advisory or "0")
            except (ValueError, IndexError):
                continue
    return -1, -1


def load_json(p: Path) -> dict:
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def count_jsonl_lines(p: Path) -> int:
    if not p.exists():
        return 0
    return sum(1 for line in p.read_text().splitlines() if line.strip())


def count_mechanism_c_events() -> int:
    log_dir = REPO_ROOT / ".claude" / "logs"
    total = 0
    for f in log_dir.glob("_session-*.events.jsonl"):
        total += count_jsonl_lines(f)
    return total


def gate_coverage_summary() -> tuple[int, int]:
    p = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
    if not p.exists():
        return 0, 0
    rows = 0
    gates = set()
    for line in p.read_text().splitlines():
        if not line.strip():
            continue
        try:
            d = json.loads(line)
            rows += 1
            if "gate" in d:
                gates.add(d["gate"])
        except json.JSONDecodeError:
            continue
    return rows, len(gates)


def git_context(repo: Path) -> dict:
    if not (repo / ".git").exists() and not (repo / ".git").is_file():
        return {"available": False}
    rc1, sha = run(["git", "rev-parse", "HEAD"], cwd=repo, timeout=10)
    rc2, branch = run(["git", "branch", "--show-current"], cwd=repo, timeout=10)
    rc3, dirty = run(["git", "status", "--porcelain"], cwd=repo, timeout=10)
    return {
        "available": True,
        "commit": sha.strip()[:10] if rc1 == 0 else "(error)",
        "branch": branch.strip() if rc2 == 0 else "(error)",
        "dirty_files": len([l for l in dirty.splitlines() if l.strip()]) if rc3 == 0 else -1,
    }


def collect_metrics(make_outputs: dict) -> dict:
    findings, advisory = parse_integrity_findings(make_outputs["integrity-check"]["output"])
    block, adv2 = parse_completeness_audit(make_outputs["feature-completeness-audit"]["output"])

    debt = load_json(REPO_ROOT / ".claude" / "shared" / "documentation-debt.json")
    debt_summary = debt.get("summary", {})

    adopt = load_json(REPO_ROOT / ".claude" / "shared" / "measurement-adoption.json")
    adopt_summary = adopt.get("summary", {})
    adopt_dim = adopt.get("dimension_coverage", {})

    gate_rows, gate_count = gate_coverage_summary()

    return {
        "integrity_findings": findings,
        "integrity_advisory": advisory,
        "completeness_blocking": block,
        "completeness_advisory": adv2,
        "doc_debt_open": debt_summary.get("open_debt_items", -1),
        "features_total": adopt_summary.get("features_total", -1),
        "features_post_v6": adopt_summary.get("features_post_v6", -1),
        "fully_adopted": adopt_summary.get("fully_adopted", -1),
        "fully_adopted_post_v6": adopt_summary.get("fully_adopted_post_v6", -1),
        "adoption_pct_post_v6": round(
            100 * adopt_summary.get("fully_adopted_post_v6", 0)
            / max(adopt_summary.get("features_post_v6", 1), 1),
            1,
        ),
        "timing_wall_time_pct_post_v6": adopt_dim.get("timing_wall_time", {}).get("post_v6_percent", -1),
        "per_phase_timing_pct_post_v6": adopt_dim.get("per_phase_timing", {}).get("post_v6_percent", -1),
        "cache_hits_pct_post_v6": adopt_dim.get("cache_hits", {}).get("post_v6_percent", -1),
        "cu_v2_pct_post_v6": adopt_dim.get("cu_v2", {}).get("post_v6_percent", -1),
        "gate_coverage_rows": gate_rows,
        "gate_coverage_distinct_gates": gate_count,
        "mechanism_c_session_events": count_mechanism_c_events(),
    }


def write_snapshot(target_dir: Path, make_outputs: dict, metrics: dict) -> bool:
    """Write a full snapshot to target_dir. Returns True if successful."""
    try:
        target_dir.mkdir(parents=True, exist_ok=True)

        # 1. Make outputs (already written into temp, now copy)
        for target, payload in make_outputs.items():
            fname = f"{target}-output.txt"
            (target_dir / fname).write_text(payload["output"])

        # 2. Shared ledgers
        shared = REPO_ROOT / ".claude" / "shared"
        for fname in ("measurement-adoption.json", "measurement-adoption-history.json",
                      "documentation-debt.json", "agent-leases.json"):
            src = shared / fname
            if src.exists():
                shutil.copy2(src, target_dir / fname)

        active = REPO_ROOT / ".claude" / "active-feature"
        if active.exists():
            shutil.copy2(active, target_dir / "active-feature")

        # 3. Mechanism A summary + last 200 rows
        gc = REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
        if gc.exists():
            lines = gc.read_text().splitlines()
            (target_dir / "gate-coverage-last-200.jsonl").write_text(
                "\n".join(lines[-200:])
            )
            from collections import Counter
            gates = Counter()
            for line in lines:
                if line.strip():
                    try:
                        gates[json.loads(line).get("gate", "?")] += 1
                    except json.JSONDecodeError:
                        pass
            (target_dir / "gate-coverage-summary.json").write_text(
                json.dumps({
                    "snapshot_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
                    "total_rows": len(lines),
                    "gates_fired": dict(gates.most_common()),
                }, indent=2)
            )

        # 4. All features state.json (tarball)
        features = REPO_ROOT / ".claude" / "features"
        if features.exists():
            tar_path = target_dir / "all-features-state-json.tar.gz"
            with tarfile.open(tar_path, "w:gz") as tar:
                for state_file in features.rglob("state.json"):
                    arcname = state_file.relative_to(REPO_ROOT).as_posix()
                    tar.add(state_file, arcname=arcname)

        # 5. Git context for both repos
        for label, repo in (("ft2", REPO_ROOT), ("fitme-story", FITME_STORY_REPO)):
            rc, out = run(["git", "log", "--oneline", "-20"], cwd=repo, timeout=10)
            (target_dir / f"{label}-git-log-last-20.txt").write_text(out)

        # 6. Metrics summary
        (target_dir / "metrics.json").write_text(json.dumps(metrics, indent=2))

        # 7. CHECKSUMS + MANIFEST
        files = sorted(p for p in target_dir.rglob("*")
                       if p.is_file() and p.name not in ("CHECKSUMS.sha256", "MANIFEST.md"))
        with (target_dir / "CHECKSUMS.sha256").open("w") as f:
            for p in files:
                h = hashlib.sha256(p.read_bytes()).hexdigest()
                rel = p.relative_to(target_dir).as_posix()
                f.write(f"{h}  ./{rel}\n")

        return True
    except Exception as e:
        print(f"  ✗ snapshot write FAILED for {target_dir}: {e}", file=sys.stderr)
        return False


def write_manifest(target_dir: Path, metrics: dict, ft2_git: dict, fs_git: dict) -> None:
    iso = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest = f"""# Daily Integrity Checkpoint — {target_dir.name}

**Created:** {iso}
**Trigger:** daily-integrity-checkpoint.py
**FT2 commit:** {ft2_git.get('commit','?')} (branch: {ft2_git.get('branch','?')}, dirty: {ft2_git.get('dirty_files',0)} files)
**fitme-story commit:** {fs_git.get('commit','?')} (branch: {fs_git.get('branch','?')}, dirty: {fs_git.get('dirty_files',0)} files)

## Top-line metrics

- Integrity findings: **{metrics['integrity_findings']}** (advisory: {metrics['integrity_advisory']})
- Documentation-debt open items: **{metrics['doc_debt_open']}**
- Feature-closure audit: **{metrics['completeness_blocking']} blocking** + {metrics['completeness_advisory']} advisory
- Features (total/post-v6/fully-adopted): {metrics['features_total']} / {metrics['features_post_v6']} / **{metrics['fully_adopted']}**
- Post-v6 adoption: **{metrics['adoption_pct_post_v6']}%**
- Per-dimension post-v6: timing={metrics['timing_wall_time_pct_post_v6']}% · per-phase={metrics['per_phase_timing_pct_post_v6']}% · cache={metrics['cache_hits_pct_post_v6']}% · cu_v2={metrics['cu_v2_pct_post_v6']}%
- Mechanism A: **{metrics['gate_coverage_rows']} rows** / {metrics['gate_coverage_distinct_gates']} distinct gates
- Mechanism C: **{metrics['mechanism_c_session_events']} session events**

## Verification

```bash
cd {target_dir}
shasum -a 256 -c CHECKSUMS.sha256
```

## Diff vs baseline

See `.claude/shared/integrity-checkpoint-ledger.md` for the latest comparison row.

For diff against the 2026-05-14 inaugural baseline:

```bash
BASELINE=~/Documents/FitTracker2-backups/2026-05-14-analytics-observability-platform-integrity-baseline-2026-05-14/platform-baseline
diff metrics.json <(jq '.' "$BASELINE/measurement-adoption.json")
```

## Related

- Daily snapshot script: `scripts/daily-integrity-checkpoint.py`
- Ledger: `.claude/shared/integrity-checkpoint-ledger.jsonl`
- Master plan: `docs/master-plan/data-integrity-and-rollback-2026-05-14.md`
"""
    (target_dir / "MANIFEST.md").write_text(manifest)


def detect_regression(prev: dict | None, curr: dict) -> tuple[bool, dict]:
    """Compare current vs previous metrics. Returns (is_regression, per-key deltas)."""
    if prev is None:
        return False, {}
    deltas = {}
    regression = False
    # Higher-is-worse (findings, blocking, debt)
    for k in ("integrity_findings", "completeness_blocking", "doc_debt_open"):
        d = curr.get(k, 0) - prev.get(k, 0)
        if d != 0:
            deltas[k] = d
        if d > 0:
            regression = True
    # Lower-is-worse (adoption, fully_adopted)
    for k in ("fully_adopted_post_v6", "adoption_pct_post_v6"):
        d = curr.get(k, 0) - prev.get(k, 0)
        if d != 0:
            deltas[k] = d
        if d < 0:
            regression = True
    # Mechanism A gates dropping is critical
    d = curr.get("gate_coverage_distinct_gates", 0) - prev.get("gate_coverage_distinct_gates", 0)
    if d < 0:
        deltas["gate_coverage_distinct_gates"] = d
        regression = True
    return regression, deltas


def load_last_ledger_row() -> dict | None:
    if not LEDGER_JSONL.exists():
        return None
    lines = [l for l in LEDGER_JSONL.read_text().splitlines() if l.strip()]
    if not lines:
        return None
    try:
        return json.loads(lines[-1])
    except json.JSONDecodeError:
        return None


def append_ledger_row(row: dict) -> None:
    LEDGER_JSONL.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER_JSONL.open("a") as f:
        f.write(json.dumps(row, separators=(",", ":")) + "\n")


def regenerate_ledger_md() -> None:
    if not LEDGER_JSONL.exists():
        return
    rows = []
    for line in LEDGER_JSONL.read_text().splitlines():
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    rows.reverse()  # most-recent first

    md = [
        "# Integrity Checkpoint Ledger\n",
        "> Auto-generated by `scripts/daily-integrity-checkpoint.py`.",
        "> Most recent first. One row per daily checkpoint.",
        "> Source: `.claude/shared/integrity-checkpoint-ledger.jsonl`.\n",
        "",
        "| Date | FT2 | Find | Adv | Debt | Block | Adopt% | Per-phase% | Cache% | CU% | Gates | M-C | Regr | Local | SSD |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        m = r.get("metrics", {})
        regr = "⚠" if r.get("regression") else "—"
        local_ok = "✓" if r.get("snapshot_local_ok") else "✗"
        ssd_ok = "✓" if r.get("snapshot_ssd_ok") else "✗"
        md.append(
            f"| {r.get('date','?')} | {r.get('ft2_commit','?')[:7]} | "
            f"{m.get('integrity_findings','?')} | {m.get('integrity_advisory','?')} | "
            f"{m.get('doc_debt_open','?')} | {m.get('completeness_blocking','?')} | "
            f"{m.get('adoption_pct_post_v6','?')} | "
            f"{m.get('per_phase_timing_pct_post_v6','?')} | "
            f"{m.get('cache_hits_pct_post_v6','?')} | "
            f"{m.get('cu_v2_pct_post_v6','?')} | "
            f"{m.get('gate_coverage_distinct_gates','?')} | "
            f"{m.get('mechanism_c_session_events','?')} | "
            f"{regr} | {local_ok} | {ssd_ok} |"
        )

    md.append("")
    md.append("## Column key")
    md.append("- **FT2** — FitTracker2 commit short-SHA at checkpoint time")
    md.append("- **Find** / **Adv** — `make integrity-check` findings + advisory count")
    md.append("- **Debt** — `make documentation-debt` open items count")
    md.append("- **Block** — `make feature-completeness-audit` blocking findings count")
    md.append("- **Adopt%** — fully_adopted_post_v6 / features_post_v6 × 100")
    md.append("- **Per-phase% / Cache% / CU%** — post-v6 dimension coverage from `measurement-adoption.json`")
    md.append("- **Gates** — distinct gates emitting Mechanism A coverage telemetry")
    md.append("- **M-C** — Mechanism C session-event total (cumulative across all `.claude/logs/_session-*.events.jsonl`)")
    md.append("- **Regr** — `⚠` if any regression flagged vs previous row; `—` otherwise")
    md.append("- **Local** / **SSD** — `✓` if snapshot written successfully to that location; `✗` if failed")

    LEDGER_MD.write_text("\n".join(md))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--force", action="store_true",
                    help="Overwrite today's snapshot if it already exists")
    ap.add_argument("--idempotent", action="store_true",
                    help="Skip silently if today's snapshot exists (for SessionStart hook use)")
    ap.add_argument("--quiet", action="store_true",
                    help="Suppress progress output (errors still print)")
    args = ap.parse_args()

    today = dt.date.today().isoformat()
    local_dir = LOCAL_BACKUP_ROOT / today
    ssd_dir = SSD_BACKUP_ROOT / today

    log = (lambda *a, **kw: None) if args.quiet else print

    # Idempotency check
    if local_dir.exists() and not args.force:
        if args.idempotent:
            sys.exit(0)
        log(f"Today's local snapshot already exists at {local_dir}. Use --force to overwrite.")
        sys.exit(0)

    log(f"=== Daily integrity checkpoint — {today} ===")
    log("[1/5] Running all 6 make targets...")
    make_outputs = capture_make_outputs()

    log("[2/5] Collecting metrics + git context...")
    metrics = collect_metrics(make_outputs)
    ft2_git = git_context(REPO_ROOT)
    fs_git = git_context(FITME_STORY_REPO)

    log(f"[3/5] Writing snapshot to local: {local_dir}")
    local_ok = write_snapshot(local_dir, make_outputs, metrics)
    if local_ok:
        write_manifest(local_dir, metrics, ft2_git, fs_git)
        log(f"      ✓ {len(list(local_dir.rglob('*')))} files")

    log(f"[4/5] Writing snapshot to SSD: {ssd_dir}")
    ssd_ok = False
    if SSD_BACKUP_ROOT.parent.exists():  # /Volumes/DevSSD/ mounted
        ssd_ok = write_snapshot(ssd_dir, make_outputs, metrics)
        if ssd_ok:
            write_manifest(ssd_dir, metrics, ft2_git, fs_git)
            log(f"      ✓ {len(list(ssd_dir.rglob('*')))} files")
    else:
        log(f"      ⚠ SSD not mounted ({SSD_BACKUP_ROOT.parent}); skipping SSD copy")

    log("[5/5] Updating ledger + regression check...")
    prev_row = load_last_ledger_row()
    regression, deltas = detect_regression(
        prev_row.get("metrics") if prev_row else None, metrics
    )

    row = {
        "date": today,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ft2_commit": ft2_git.get("commit", "?"),
        "ft2_branch": ft2_git.get("branch", "?"),
        "ft2_dirty": ft2_git.get("dirty_files", 0),
        "fitme_story_commit": fs_git.get("commit", "?"),
        "fitme_story_branch": fs_git.get("branch", "?"),
        "metrics": metrics,
        "regression": regression,
        "deltas_vs_prev": deltas,
        "snapshot_local": str(local_dir),
        "snapshot_local_ok": local_ok,
        "snapshot_ssd": str(ssd_dir),
        "snapshot_ssd_ok": ssd_ok,
    }
    append_ledger_row(row)
    regenerate_ledger_md()

    if regression:
        REGRESSION_FLAG.write_text(json.dumps({
            "date": today,
            "deltas": deltas,
            "prev_date": prev_row.get("date") if prev_row else None,
        }, indent=2))
        log(f"\n⚠ REGRESSION DETECTED vs {prev_row.get('date') if prev_row else 'baseline'}: {deltas}")
        log(f"   Flag written: {REGRESSION_FLAG}")
    elif REGRESSION_FLAG.exists():
        REGRESSION_FLAG.unlink()
        log(f"\n✓ Regression cleared since previous checkpoint.")

    log(f"\n✓ Checkpoint complete.")
    log(f"  Local: {local_dir} ({'OK' if local_ok else 'FAILED'})")
    log(f"  SSD:   {ssd_dir} ({'OK' if ssd_ok else 'SKIPPED/FAILED'})")
    log(f"  Ledger: {LEDGER_JSONL} (+1 row)")
    log(f"  Human:  {LEDGER_MD}")


if __name__ == "__main__":
    main()
