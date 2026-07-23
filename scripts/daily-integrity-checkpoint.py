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

# Import the project's flock_writer helper for race-condition protection
# (#397: 4 parallel cron + manual invocations all passed the idempotency check
# before any wrote, producing 4 duplicate rows for 2026-05-18 in PR #389).
sys.path.insert(0, str(REPO_ROOT / "scripts"))
from flock_writer import flocked  # noqa: E402
LOCAL_BACKUP_ROOT = Path.home() / "Documents" / "FitTracker2-backups" / "daily"
SSD_BACKUP_ROOT = Path("/Volumes/DevSSD/FitTracker2-snapshots")
# DI-Q2 (data-integrity-and-rollback §5): when the daily checkpoint detects a
# regression it captures a SECOND, immutable forensic snapshot alongside the
# daily one — stamped `post-regression-evidence-<ts>` — so the exact platform
# state that tripped the regression is preserved for post-hoc analysis even if
# the next day's checkpoint overwrites the rolling `daily/` view. Sibling of the
# daily root (internal storage, never DevSSD — same drive-risk convention).
POST_REGRESSION_EVIDENCE_ROOT = LOCAL_BACKUP_ROOT.parent
# fitme-story canonical location follows the 2026-07-07 consolidation under
# ~/Developer/FitMe/ (was /Volumes/DevSSD/fitme-story on the retired SSD layout).
# Env override kept so the path survives future relocations without a code edit.
FITME_STORY_REPO = Path(
    os.environ.get("FITME_STORY_REPO", str(Path.home() / "Developer" / "FitMe" / "fitme-story"))
)

LEDGER_JSONL = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-ledger.jsonl"
LEDGER_MD = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-ledger.md"
REGRESSION_FLAG = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-regression.flag"
FOLLOWUPS_FILE = REPO_ROOT / ".claude" / "shared" / "must-have-cadence-followups.md"
FOLLOWUP_LOOKAHEAD_DAYS = 14


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


def gh_auth_context() -> dict:
    """Capture gh auth health + token-expiry signal for R13 (FIT-179).

    Surfaces:
      - `gh` not installed              → {"available": False, "reason": "no-gh"}
      - `gh auth status` returns non-0  → {"available": True, "authenticated": False}
      - authenticated                   → {available: True, authenticated: True,
                                            login, scopes, token_expires_at,
                                            expires_in_days}

    Token expiry: classic PATs + OAuth tokens (`gho_*`) have NO expiry header.
    Only fine-grained PATs return `github-authentication-token-expiration` on
    API responses. The function captures it when present so the SessionStart
    + daily-checkpoint warning surfaces work the day a fine-grained PAT
    enters use.
    """
    if shutil.which("gh") is None:
        return {"available": False, "reason": "no-gh"}

    rc, _ = run(["gh", "auth", "status"], timeout=10)
    if rc != 0:
        return {"available": True, "authenticated": False,
                "reason": "gh-auth-status-failed"}

    rc_u, user_out = run(["gh", "api", "user", "--jq", ".login"], timeout=15)
    login = user_out.strip() if rc_u == 0 else "?"

    # Try to capture token-expiry header (fine-grained PATs only)
    rc_h, hdr_out = run(["gh", "api", "-i", "user"], timeout=15)
    token_expires_at = None
    expires_in_days = None
    scopes: list[str] = []
    if rc_h == 0:
        for raw in hdr_out.splitlines():
            line = raw.strip()
            low = line.lower()
            if low.startswith("github-authentication-token-expiration:"):
                token_expires_at = line.split(":", 1)[1].strip()
                try:
                    exp = dt.datetime.strptime(
                        token_expires_at.replace(" UTC", ""), "%Y-%m-%d %H:%M:%S"
                    ).replace(tzinfo=dt.timezone.utc)
                    delta = exp - dt.datetime.now(dt.timezone.utc)
                    expires_in_days = max(0, delta.days)
                except (ValueError, TypeError):
                    pass
            elif low.startswith("x-oauth-scopes:"):
                scopes = [s.strip() for s in line.split(":", 1)[1].split(",") if s.strip()]

    return {
        "available": True,
        "authenticated": True,
        "login": login,
        "scopes": scopes,
        "token_expires_at": token_expires_at,
        "expires_in_days": expires_in_days,
    }


def hardware_context(mount: Path = Path("/Volumes/DevSSD")) -> dict:
    """Capture SSD identity for the volume hosting the repo.

    Surfaces UUID + media name + protocol + size so that replug events
    (UUID change) and drive swaps (media name change) are visible
    post-hoc in the daily ledger. Required for R4 (replug watcher) and
    R12 (off-SSD heartbeat). See FIT-169.

    Returns {"available": False} on any failure or non-macOS host so
    the daily checkpoint never breaks because of hardware probing.
    """
    if sys.platform != "darwin" or shutil.which("diskutil") is None:
        return {"available": False, "reason": "non-darwin-or-no-diskutil"}
    if not mount.exists():
        return {"available": False, "reason": f"mount-not-found:{mount}"}

    rc_v, vol_info = run(["diskutil", "info", str(mount)], timeout=10)
    if rc_v != 0:
        return {"available": False, "reason": "diskutil-info-volume-failed"}

    fields = {
        "device_identifier": None,
        "volume_uuid": None,
        "volume_name": None,
        "mount_point": str(mount),
        "filesystem": None,
    }
    for raw in vol_info.splitlines():
        line = raw.strip()
        if line.startswith("Device Identifier:"):
            fields["device_identifier"] = line.split(":", 1)[1].strip()
        elif line.startswith("Volume UUID:"):
            fields["volume_uuid"] = line.split(":", 1)[1].strip()
        elif line.startswith("Volume Name:"):
            fields["volume_name"] = line.split(":", 1)[1].strip()
        elif line.startswith("File System Personality:"):
            fields["filesystem"] = line.split(":", 1)[1].strip()

    # Parent disk for media name + protocol (the volume is e.g. disk5s1; parent is disk5).
    parent_disk = None
    dev = fields["device_identifier"] or ""
    if dev.startswith("disk"):
        import re
        m = re.match(r"(disk\d+)", dev)
        if m:
            parent_disk = m.group(1)

    if parent_disk:
        rc_d, disk_info = run(["diskutil", "info", parent_disk], timeout=10)
        if rc_d == 0:
            for raw in disk_info.splitlines():
                line = raw.strip()
                if line.startswith("Device / Media Name:"):
                    fields["media_name"] = line.split(":", 1)[1].strip()
                elif line.startswith("Protocol:"):
                    fields["protocol"] = line.split(":", 1)[1].strip()
                elif line.startswith("Disk Size:"):
                    fields["disk_size"] = line.split(":", 1)[1].strip()
                elif line.startswith("SMART Status:"):
                    fields["smart_status"] = line.split(":", 1)[1].strip()

    fields["available"] = True
    return fields


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


def _jsonl_row_count(p: Path) -> int | None:
    """Non-blank line count for a .jsonl file, or None if unreadable."""
    try:
        return sum(1 for ln in p.read_text().splitlines() if ln.strip())
    except OSError:
        return None


def summarize_fitme_story_cross_repo_state(
    fs_repo: Path, ft2_gate_coverage: Path
) -> dict:
    """FIT-207 — summarize the fitme-story side of the cross-repo mirror for the
    daily forensic baseline.

    The daily checkpoint already captures fitme-story's git head; this adds its
    *shared state*: the sync-freshness marker and the FT2 gate-coverage mirror,
    plus a drift check of that mirror against FT2's own source-of-truth stream.
    That drift check is the content-level complement to the N4 state-sync-health
    probe (which only checks the freshness marker's age).

    Best-effort by construction: a missing fitme-story checkout or any missing
    input degrades to a typed marker rather than raising, so the checkpoint
    never fails because the sibling repo isn't present (e.g. cron/CI contexts).
    """
    data_dir = fs_repo / "src" / "data"
    summary: dict = {"fitme_story_repo": str(fs_repo), "present": fs_repo.is_dir()}
    if not fs_repo.is_dir():
        summary["reason"] = "fitme_story_repo_absent"
        return summary

    summary["freshness_present"] = (data_dir / "freshness.json").is_file()

    # Gate-coverage mirror drift vs the FT2 source stream. fitme-story mirrors
    # FT2's gate-coverage.jsonl verbatim on each prebuild sync, so a fresh mirror
    # has ~equal rows; a mirror far behind the source means the sync has stalled.
    mirror = data_dir / "integrity" / "gate-coverage-ft2.jsonl"
    mirror_rows = _jsonl_row_count(mirror) if mirror.is_file() else None
    source_rows = _jsonl_row_count(ft2_gate_coverage) if ft2_gate_coverage.is_file() else None
    gc: dict = {"mirror_rows": mirror_rows, "ft2_source_rows": source_rows}
    if mirror_rows is not None and source_rows is not None:
        delta = source_rows - mirror_rows
        gc["delta_source_minus_mirror"] = delta
        # In sync when the mirror is at or just behind the source (tolerance
        # scales with corpus so a large stream isn't held to an absolute row).
        tolerance = max(50, source_rows // 20)
        gc["mirror_in_sync"] = 0 <= delta <= tolerance
    else:
        gc["mirror_in_sync"] = None
    summary["gate_coverage_mirror"] = gc

    def _count(rel: str, pattern: str) -> int:
        d = data_dir / rel
        return len(list(d.glob(pattern))) if d.is_dir() else 0

    summary["synced_inventory"] = {
        "features": _count("features", "*.json"),
        "logs": _count("logs", "*.json"),
        "integrity_snapshots": _count("integrity/snapshots", "*.json"),
    }
    return summary


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

        # 5b. FIT-207 — fitme-story cross-repo shared-state baseline. Captures the
        # sibling repo's sync-freshness marker + a gate-coverage mirror-vs-source
        # drift summary, so the daily forensic snapshot records BOTH sides of the
        # cross-repo contract (not just FT2's). Best-effort: absent sibling repo
        # degrades to a typed marker, never fails the snapshot.
        fs_dir = target_dir / "fitme-story"
        fs_dir.mkdir(exist_ok=True)
        fs_summary = summarize_fitme_story_cross_repo_state(
            FITME_STORY_REPO, REPO_ROOT / ".claude" / "logs" / "gate-coverage.jsonl"
        )
        (fs_dir / "cross-repo-summary.json").write_text(json.dumps(fs_summary, indent=2))
        fs_freshness = FITME_STORY_REPO / "src" / "data" / "freshness.json"
        if fs_freshness.is_file():
            shutil.copy2(fs_freshness, fs_dir / "freshness.json")

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


def write_manifest(target_dir: Path, metrics: dict, ft2_git: dict, fs_git: dict, hw: dict | None = None,
                   trigger: str = "daily-integrity-checkpoint.py") -> None:
    iso = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if hw and hw.get("available"):
        # Trim "1000.0 GB (999995129856 Bytes) (exactly ...)" to just "1000.0 GB" for display.
        size_display = (hw.get("disk_size") or "?").split("(")[0].strip()
        hw_line = (
            f"**SSD:** {hw.get('media_name','?')} · {size_display} · "
            f"{hw.get('protocol','?')} · UUID `{hw.get('volume_uuid','?')}`"
        )
    else:
        hw_line = "**SSD:** not captured"
    manifest = f"""# Daily Integrity Checkpoint — {target_dir.name}

**Created:** {iso}
**Trigger:** {trigger}
**FT2 commit:** {ft2_git.get('commit','?')} (branch: {ft2_git.get('branch','?')}, dirty: {ft2_git.get('dirty_files',0)} files)
**fitme-story commit:** {fs_git.get('commit','?')} (branch: {fs_git.get('branch','?')}, dirty: {fs_git.get('dirty_files',0)} files)
{hw_line}

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


def capture_post_regression_evidence(
    today: str,
    deltas: dict,
    prev_date: str | None,
    make_outputs: dict,
    metrics: dict,
    ft2_git: dict,
    fs_git: dict,
    hw: dict | None,
    log,
) -> Path | None:
    """DI-Q2: capture an immutable forensic snapshot when a regression fires.

    Reuses the same `write_snapshot` primitive as the daily checkpoint, into a
    timestamped `post-regression-evidence-<today>T<HHMMZ>/` sibling of the daily
    root, plus a machine-readable `evidence.json` recording the trigger + the
    deltas that caused the regression. Best-effort: a snapshot failure logs and
    returns None (it must never crash the checkpoint pipeline — the regression
    flag write remains the load-bearing signal).
    """
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H%MZ")
    evidence_dir = POST_REGRESSION_EVIDENCE_ROOT / f"post-regression-evidence-{stamp}"
    ok = write_snapshot(evidence_dir, make_outputs, metrics)
    if not ok:
        log(f"   ⚠ post-regression evidence snapshot FAILED ({evidence_dir}); "
            f"regression flag still written")
        return None
    # evidence.json is written BEFORE the manifest/checksums pass so it is
    # covered by CHECKSUMS.sha256 (parity with the snapshot's other files).
    (evidence_dir / "evidence.json").write_text(json.dumps({
        "trigger": "post-regression-evidence",
        "date": today,
        "prev_date": prev_date,
        "deltas": deltas,
        "captured_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }, indent=2))
    # Re-run the checksum pass so evidence.json is included, then the manifest.
    files = sorted(p for p in evidence_dir.rglob("*")
                   if p.is_file() and p.name not in ("CHECKSUMS.sha256", "MANIFEST.md"))
    with (evidence_dir / "CHECKSUMS.sha256").open("w") as f:
        for p in files:
            h = hashlib.sha256(p.read_bytes()).hexdigest()
            rel = p.relative_to(evidence_dir).as_posix()
            f.write(f"{h}  ./{rel}\n")
    write_manifest(evidence_dir, metrics, ft2_git, fs_git, hw,
                   trigger="post-regression forensic evidence (DI-Q2)")
    log(f"   ✓ post-regression evidence snapshot: {evidence_dir}")
    return evidence_dir


def detect_regression(prev: dict | None, curr: dict) -> tuple[bool, dict]:
    """Compare current vs previous metrics. Returns (is_regression, deltas).

    The deltas dict separates regression-causing changes from improvements so
    readers of the regression flag don't mistake `completeness_blocking: -2`
    (a 2-block improvement) for a regression cause.

    Dilution-awareness (data-integrity sub-plan §2.5/§2.6): `adoption_pct_post_v6`
    is a percentage and therefore DILUTION-SENSITIVE — adding a feature with empty
    metrics drags it down even though nothing regressed. So a raw %-drop is recorded
    as a dilution note but gates ONLY when the absolute numerator
    (`fully_adopted_post_v6`) also dropped (numerator monotonicity). This stops the
    phantom day-over-day regression alerts documented in honesty ledger FT2-FH-004.

    Shape: {"regressed": {<metric>: delta, ...}, "improved": {<metric>: delta, ...}}
    """
    if prev is None:
        return False, {"regressed": {}, "improved": {}}
    regressed: dict = {}
    improved: dict = {}
    regression = False
    # Higher-is-worse (findings, blocking, debt) — d > 0 is a regression
    for k in ("integrity_findings", "completeness_blocking", "doc_debt_open"):
        d = curr.get(k, 0) - prev.get(k, 0)
        if d > 0:
            regressed[k] = d
            regression = True
        elif d < 0:
            improved[k] = d
    # Numerator: fully_adopted_post_v6 dropping IS a regression (monotonicity).
    d_num = curr.get("fully_adopted_post_v6", 0) - prev.get("fully_adopted_post_v6", 0)
    if d_num < 0:
        regressed["fully_adopted_post_v6"] = d_num
        regression = True
    elif d_num > 0:
        improved["fully_adopted_post_v6"] = d_num
    # Percentage: gate only when the numerator also dropped; else it is dilution.
    d_pct = curr.get("adoption_pct_post_v6", 0) - prev.get("adoption_pct_post_v6", 0)
    if d_pct < 0 and d_num < 0:
        regressed["adoption_pct_post_v6"] = d_pct
    elif d_pct < 0:
        improved["adoption_pct_post_v6_dilution"] = d_pct  # %-drop explained by corpus growth
    elif d_pct > 0:
        improved["adoption_pct_post_v6"] = d_pct
    # Mechanism A gates dropping is critical (lower-is-worse)
    d = curr.get("gate_coverage_distinct_gates", 0) - prev.get("gate_coverage_distinct_gates", 0)
    if d < 0:
        regressed["gate_coverage_distinct_gates"] = d
        regression = True
    elif d > 0:
        improved["gate_coverage_distinct_gates"] = d
    return regression, {"regressed": regressed, "improved": improved}


def stale_branches() -> tuple[list[str], list[str]]:
    """N2 — find local branches whose remote is gone + orphan worktrees.

    Returns (gone_branches, orphan_worktrees).
    """
    rc, out = run(["git", "branch", "-vv"], timeout=10)
    gone = []
    if rc == 0:
        for line in out.splitlines():
            if ": gone]" not in line:
                continue
            # `git branch -vv` prefixes:
            #   "  branch-name 1234567 [origin/...: gone] msg"  (normal)
            #   "* branch-name ..."                              (HEAD)
            #   "+ branch-name ..."                              (checked-out in another worktree)
            stripped = line[2:] if line[:1] in ("*", "+", " ") and line[1:2] == " " else line
            parts = stripped.split()
            if parts:
                gone.append(parts[0])

    rc, out = run(["git", "worktree", "list", "--porcelain"], timeout=10)
    worktrees = []
    if rc == 0:
        current = None
        for line in out.splitlines():
            if line.startswith("worktree "):
                path = line[len("worktree "):].strip()
                # Anything under .claude/worktrees is an isolated session worktree
                if "/.claude/worktrees/" in path:
                    worktrees.append(path)
    return gone, worktrees


def item_registry_freshness() -> dict:
    """N5 — is the FIT-200 crosswalk index still describing the live corpus?

    `.claude/shared/item-registry.json` is a DERIVED index whose only producer
    is the manual `make crosswalk`. Nothing scheduled regenerated it, so it
    silently drifted to 118 items against a 132-feature corpus (2026-07-23
    W40 sweep) — a stale derived index is indistinguishable from a fresh one
    unless something checks. This surfaces the drift daily.

    Advisory only: returns {} on any tooling failure so a broken checker can
    never block the checkpoint.
    """
    rc, out = run([sys.executable, "scripts/build-item-registry.py", "--check", "--json"],
                  timeout=60)
    if rc not in (0, 3):
        return {}
    try:
        return json.loads(out.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {}


def pr_babysit(repos: tuple[str, ...] = ("Regevba/FitTracker2", "Regevba/fitme-story")) -> dict:
    """N3 — list open PRs idle >24h, oldest first.

    Returns {repo: [{number, title, updated_hours_ago, headRefName}, ...]}.
    Silent failure if `gh` unavailable or auth missing.
    """
    import shutil
    result = {r: [] for r in repos}
    if not shutil.which("gh"):
        return result
    now = dt.datetime.now(dt.timezone.utc)
    for repo in repos:
        rc, out = run(
            ["gh", "pr", "list", "--repo", repo, "--state", "open",
             "--json", "number,title,updatedAt,headRefName"],
            timeout=15,
        )
        if rc != 0:
            continue
        try:
            prs = json.loads(out)
        except json.JSONDecodeError:
            continue
        for p in prs:
            try:
                upd = dt.datetime.fromisoformat(p["updatedAt"].replace("Z", "+00:00"))
            except (ValueError, KeyError):
                continue
            hours = round((now - upd).total_seconds() / 3600, 1)
            if hours >= 24:
                result[repo].append({
                    "number": p["number"],
                    "title": p["title"][:60],
                    "updated_hours_ago": hours,
                    "headRefName": p.get("headRefName", "?"),
                })
        result[repo].sort(key=lambda x: -x["updated_hours_ago"])
    return result


STATE_SYNC_HEALTH_URL = os.environ.get(
    "FT2_STATE_SYNC_HEALTH_URL",
    "https://fitme-story.vercel.app/api/control-room/state-sync-health",
)


def state_sync_health_probe(url: str = STATE_SYNC_HEALTH_URL, timeout: int = 8) -> dict:
    """N4 (FIT-183 / R17) — probe the fitme-story cross-repo state-sync health
    endpoint. Returns a dict describing the outcome; NEVER raises.

    The endpoint returns 200 + healthy=true when the FT2→fitme-story mirror is
    fresh (<6h), or 503 + a reason (`stale` / `empty_mirror` / …) when not. A
    network error / 404 (endpoint not yet deployed) is reported as
    reachable=False — best-effort, so a transient outage never fails the daily
    checkpoint.
    """
    import urllib.error
    import urllib.request

    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310 — fixed https URL
            body = json.loads(resp.read().decode("utf-8"))
            return {"reachable": True, "http_status": resp.status, **body}
    except urllib.error.HTTPError as e:
        # 503 (stale/broken) still carries a JSON body with the reason.
        try:
            body = json.loads(e.read().decode("utf-8"))
        except Exception:  # noqa: BLE001
            body = {}
        return {"reachable": True, "http_status": e.code, **body}
    except Exception as e:  # noqa: BLE001 — best-effort; any failure = unreachable
        return {"reachable": False, "error": f"{type(e).__name__}: {e}"}


def run_integrity_sweep() -> dict:
    """Run the codified cross-layer sweep (scripts/integrity-telemetry-sweep.py)
    and return its verdict so the daily ledger RECORDS the per-layer health over
    time. Uses --no-refresh (the 6 make targets already ran above, so ledgers are
    fresh). Best-effort: an absent script (e.g. before its PR merges) or any error
    yields {"overall": "SKIPPED"} — it must never crash the checkpoint.
    """
    sweep = REPO_ROOT / "scripts" / "integrity-telemetry-sweep.py"
    if not sweep.exists():
        return {"overall": "SKIPPED", "reason": "sweep script not present yet"}
    try:
        p = subprocess.run(
            ["python3", str(sweep), "--no-refresh", "--json"],
            capture_output=True, text=True, timeout=180, check=False,
        )
        data = json.loads(p.stdout or "{}")
        return {
            "overall": data.get("overall", "UNKNOWN"),
            "layers": {row["layer"]: row["status"] for row in data.get("layers", [])},
        }
    except Exception as e:  # noqa: BLE001 — best-effort; never crash the checkpoint
        return {"overall": "SKIPPED", "reason": f"{type(e).__name__}: {e}"}


def upcoming_followups(today: dt.date, lookahead_days: int = FOLLOWUP_LOOKAHEAD_DAYS) -> list[dict]:
    """Parse must-have-cadence-followups.md and return rows whose date is within lookahead_days.

    Format expected: markdown table rows like
        | B1 | **2026-05-21** | description | owner | source |
    Returns list of {id, date, days_away, description}.
    """
    if not FOLLOWUPS_FILE.exists():
        return []
    import re
    rows = []
    for line in FOLLOWUPS_FILE.read_text().splitlines():
        if not line.startswith("| ") or "**" not in line:
            continue
        # Accept both firm dates `**2026-07-23**` and approximate dates
        # `**~2026-07-23**` (a leading `~` means "around this date"). Struck-through
        # rows (`| ~~B16~~ | ~~2026-…~~ |`) still fail the `| Bxx | **date**` anchor
        # since their id/date cells use `~~…~~`, not `**…**`.
        m = re.search(r"\| ([A-Z]\d+) \| \*\*~?\s*(\d{4}-\d{2}-\d{2})\*\* \| (.+?) \|", line)
        if not m:
            continue
        try:
            d = dt.date.fromisoformat(m.group(2))
        except ValueError:
            continue
        days_away = (d - today).days
        if 0 <= days_away <= lookahead_days:
            rows.append({
                "id": m.group(1),
                "date": m.group(2),
                "days_away": days_away,
                "description": m.group(3).strip(),
            })
    return sorted(rows, key=lambda r: r["days_away"])


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


def _running_under_launchd() -> bool:
    """True iff we're in cron context. CRON_CONTEXT=1 (set in the launchd plist)
    is the reliable signal — launchd does NOT dependably export LAUNCHD_LABEL, so
    that check is a best-effort fallback only (see ensure-pr-cache-fresh.py)."""
    if os.environ.get("CRON_CONTEXT") == "1":
        return True
    if os.environ.get("LAUNCHD_LABEL"):
        return True
    xpc = os.environ.get("XPC_SERVICE_NAME", "")
    if xpc and "fittracker" in xpc.lower() and "daily" in xpc.lower():
        return True
    return False


def precheck_cron_context() -> int | None:
    """v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (c): pre-validate gh auth.

    Closes the 2026-05-19 SSD-migration drift class: launchd cron silently ran
    for 5 days without gh keychain access, producing snapshots with phantom
    BROKEN_PR_CITATION findings (319 in one cycle). The phantom findings hid
    the real problem (auth missing in cron context) behind a cloud of noise.

    Behavior:
      - Interactive sessions: never pre-fails (returns None).
      - Cron context + gh missing: returns 78 (EX_CONFIG) — launchd records the
        config failure cleanly; LastExit shows a real reason.
      - Cron context + gh present + auth-fail: returns 78 with explicit stderr.
      - Cron context + auth OK: returns None (proceed normally).

    Exit 78 is the BSD `sysexits(3)` configuration-error code — what launchd
    interprets as "the job is broken; don't keep retrying" without backoff drama.
    """
    if not _running_under_launchd():
        return None
    if shutil.which("gh") is None:
        print(
            "[F-LAUNCHD-DRIFT] gh CLI not installed in launchd PATH; "
            "PR-citation gates would produce phantom findings. Exit 78 (EX_CONFIG).",
            file=sys.stderr,
        )
        return 78
    rc, out = run(["gh", "auth", "status"], timeout=10)
    if rc != 0:
        print(
            f"[F-LAUNCHD-DRIFT] gh auth status failed under launchd context "
            f"(rc={rc}). Keychain may be locked or token unavailable. "
            f"Exit 78 (EX_CONFIG). Output:\n{out}",
            file=sys.stderr,
        )
        return 78
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--force", action="store_true",
                    help="Overwrite today's snapshot if it already exists")
    ap.add_argument("--idempotent", action="store_true",
                    help="Skip silently if today's snapshot exists (for SessionStart hook use)")
    ap.add_argument("--quiet", action="store_true",
                    help="Suppress progress output (errors still print)")
    ap.add_argument("--ci", action="store_true",
                    help="CI mode (R10): run the integrity + regression checks read-only — "
                         "no local/SSD snapshot, no ledger write. Compares vs the last committed "
                         "ledger row and exits non-zero on any finding/blocking/regression so a "
                         "GitHub Actions daily job can alert without depending on the operator's Mac.")
    args = ap.parse_args()

    # R10 CI mode: cloud-independent daily integrity alert. Runs read-only
    # (the launchd job still owns the ledger + on-disk snapshots), so it skips
    # the launchd-specific cron precheck and the flock entirely.
    if args.ci:
        sys.exit(_run_ci_check(args))

    # v7.9.1 F-LAUNCHD-DRIFT-EXTENSION sub-fix (c).
    cron_precheck_exit = precheck_cron_context()
    if cron_precheck_exit is not None:
        sys.exit(cron_precheck_exit)

    today = dt.date.today().isoformat()
    local_dir = LOCAL_BACKUP_ROOT / today
    ssd_dir = SSD_BACKUP_ROOT / today

    log = (lambda *a, **kw: None) if args.quiet else print

    # Race-condition protection (#397): wrap the entire read-check-pipeline-append
    # sequence in an exclusive flock on the ledger file via a sidecar lockfile.
    # Why: the prior design's check-then-act window allowed concurrent fires
    # (cron + manual + SessionStart hook) to all pass the idempotency check
    # before any wrote, producing duplicate ledger rows (4× rows for 2026-05-18
    # in PR #389). Now: concurrent fires serialize at flock acquire; the second-
    # to-acquire sees today's row already present and exits cleanly.
    # Sidecar lockfile pattern follows scripts/flock_writer.py (Mechanism I);
    # see .gitignore: `.claude/shared/*.lock` is already excluded.
    LEDGER_JSONL.parent.mkdir(parents=True, exist_ok=True)
    with flocked(LEDGER_JSONL):
        _run_pipeline(today, local_dir, ssd_dir, args, log)


def _run_ci_check(args) -> int:
    """R10 cloud daily job: read-only integrity + regression check.

    Runs the same make-target sweep + metric collection + regression
    comparison as the full launchd pipeline, but writes nothing (no ledger
    row, no snapshot, no regression-flag file). Compares the freshly computed
    metrics against the last committed ledger row and returns a non-zero exit
    code if there are integrity findings, blocking completeness findings, or a
    metric regression — which the GitHub Actions workflow turns into an alert
    issue. The launchd job remains the sole writer of the ledger + snapshots.
    """
    log = (lambda *a, **kw: None) if args.quiet else print
    today = dt.date.today().isoformat()
    log(f"=== Daily integrity checkpoint — CI mode (read-only) — {today} ===")

    make_outputs = capture_make_outputs()
    metrics = collect_metrics(make_outputs)
    prev_row = load_last_ledger_row()
    regression, deltas = detect_regression(
        prev_row.get("metrics") if prev_row else None, metrics
    )

    findings = int(metrics.get("integrity_findings", 0) or 0)
    blocking = int(metrics.get("completeness_blocking", 0) or 0)

    print(json.dumps({
        "date": today,
        "regression": regression,
        "deltas_vs_prev": deltas,
        "prev_date": prev_row.get("date") if prev_row else None,
        "metrics": metrics,
    }, indent=2))

    problems = []
    if findings > 0:
        problems.append(f"{findings} integrity finding(s)")
    if blocking > 0:
        problems.append(f"{blocking} completeness blocking finding(s)")
    if regression:
        prev_date = prev_row.get("date") if prev_row else "baseline"
        problems.append(f"regression vs {prev_date}: {deltas}")

    if problems:
        print("\n⚠ CI CHECK FAILED: " + "; ".join(problems))
        return 1
    print("\n✓ CI check clean — 0 findings, 0 blocking, no regression.")
    return 0


def _run_pipeline(today: str, local_dir: Path, ssd_dir: Path, args, log) -> None:
    """Read-check-pipeline-append, guarded by the caller's flock."""

    # Idempotency check — keyed on the ledger row, not the snapshot dir.
    # Why: if a prior fire crashed after creating the snapshot dir but before
    # appending the ledger row, gating on `local_dir.exists()` would leave the
    # ledger permanently missing today's row. Gating on the ledger row makes
    # subsequent fires self-heal by re-running the full pipeline.
    last_row = load_last_ledger_row()
    if last_row and last_row.get("date") == today and not args.force:
        if args.idempotent:
            sys.exit(0)
        log(f"Today's ledger row already exists ({today}). Use --force to overwrite.")
        sys.exit(0)

    log(f"=== Daily integrity checkpoint — {today} ===")
    log("[1/5] Running all 6 make targets...")
    make_outputs = capture_make_outputs()

    # R9 coverage telemetry (Follow-up #1) — best-effort durable coverage row.
    # Appends to .claude/shared/coverage-telemetry.jsonl, which rides the digest
    # commit that persists .claude/shared/*, so the 30-day GATE_TEST_MISSING
    # calibration window accumulates. `make coverage-py` produces a local
    # coverage.xml when ai-engine deps are present; `--fetch-ci` falls back to
    # the latest CI coverage.yml artifact via gh when they are NOT (the common
    # checkpoint-host case — this is why the ledger sat at its seed row until the
    # 2026-07-21 fix). Both the make run and the append are fail-soft (exit 0).
    log("      · coverage-telemetry (best-effort)...")
    try:
        subprocess.run(["make", "coverage-py"], cwd=REPO_ROOT,
                       capture_output=True, text=True, timeout=300)
        subprocess.run(["python3", "scripts/append-coverage-telemetry.py",
                        "--fetch-ci", "--provenance", "checkpoint"], cwd=REPO_ROOT,
                       capture_output=True, text=True, timeout=120)
    except Exception:  # noqa: BLE001 — fail-soft by contract
        pass

    log("[2/5] Collecting metrics + git + hardware context...")
    metrics = collect_metrics(make_outputs)
    ft2_git = git_context(REPO_ROOT)
    fs_git = git_context(FITME_STORY_REPO)
    hw = hardware_context()
    gh_auth = gh_auth_context()

    log(f"[3/5] Writing snapshot to local: {local_dir}")
    local_ok = write_snapshot(local_dir, make_outputs, metrics)
    if local_ok:
        write_manifest(local_dir, metrics, ft2_git, fs_git, hw)
        log(f"      ✓ {len(list(local_dir.rglob('*')))} files")

    log(f"[4/5] Writing snapshot to SSD: {ssd_dir}")
    ssd_ok = False
    if SSD_BACKUP_ROOT.parent.exists():  # /Volumes/DevSSD/ mounted
        ssd_ok = write_snapshot(ssd_dir, make_outputs, metrics)
        if ssd_ok:
            write_manifest(ssd_dir, metrics, ft2_git, fs_git, hw)
            log(f"      ✓ {len(list(ssd_dir.rglob('*')))} files")
    else:
        log(f"      ⚠ SSD not mounted ({SSD_BACKUP_ROOT.parent}); skipping SSD copy")

    log("[5/5] Updating ledger + regression check...")
    prev_row = load_last_ledger_row()
    regression, deltas = detect_regression(
        prev_row.get("metrics") if prev_row else None, metrics
    )

    # Cross-layer sweep verdict, recorded into the ledger for over-time tracking.
    sweep = run_integrity_sweep()

    row = {
        "date": today,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ft2_commit": ft2_git.get("commit", "?"),
        "ft2_branch": ft2_git.get("branch", "?"),
        "ft2_dirty": ft2_git.get("dirty_files", 0),
        "fitme_story_commit": fs_git.get("commit", "?"),
        "fitme_story_branch": fs_git.get("branch", "?"),
        "hardware": hw,
        "gh_auth": gh_auth,
        "metrics": metrics,
        "regression": regression,
        "deltas_vs_prev": deltas,
        "integrity_sweep": sweep,
        "snapshot_local": str(local_dir),
        "snapshot_local_ok": local_ok,
        "snapshot_ssd": str(ssd_dir),
        "snapshot_ssd_ok": ssd_ok,
    }
    append_ledger_row(row)
    regenerate_ledger_md()

    if regression:
        prev_date = prev_row.get("date") if prev_row else None
        log(f"\n⚠ REGRESSION DETECTED vs {prev_date or 'baseline'}: {deltas}")
        # DI-Q2: capture the immutable forensic snapshot first, so the flag can
        # cite the evidence directory.
        evidence_dir = capture_post_regression_evidence(
            today, deltas, prev_date, make_outputs, metrics, ft2_git, fs_git, hw, log,
        )
        REGRESSION_FLAG.write_text(json.dumps({
            "date": today,
            "deltas": deltas,
            "prev_date": prev_date,
            "evidence_snapshot": str(evidence_dir) if evidence_dir else None,
        }, indent=2))
        log(f"   Flag written: {REGRESSION_FLAG}")
    elif REGRESSION_FLAG.exists():
        REGRESSION_FLAG.unlink()
        log(f"\n✓ Regression cleared since previous checkpoint.")

    # R13 (FIT-179): gh auth warning. Surfaces critical conditions:
    #   1. gh missing
    #   2. gh auth status fails (token revoked / network)
    #   3. fine-grained PAT expires in <14d
    if gh_auth.get("available") is False:
        log(f"\n⚠ gh not installed — required for PR cache + ledger PR cites")
    elif not gh_auth.get("authenticated", True):
        log(f"\n⚠ gh auth failed — run `gh auth login` to re-authenticate")
    elif gh_auth.get("expires_in_days") is not None:
        days = gh_auth["expires_in_days"]
        if days <= 14:
            log(f"\n⚠ gh token expires in {days}d ({gh_auth.get('token_expires_at','?')})")
            log(f"   Rotate via Settings → Developer settings → Tokens")
        else:
            log(f"\n✓ gh authenticated as {gh_auth.get('login','?')} (token expires in {days}d)")
    else:
        log(f"\n✓ gh authenticated as {gh_auth.get('login','?')} (OAuth/classic; no fixed expiry)")

    log(f"\n✓ Checkpoint complete.")
    log(f"  Local: {local_dir} ({'OK' if local_ok else 'FAILED'})")
    log(f"  SSD:   {ssd_dir} ({'OK' if ssd_ok else 'SKIPPED/FAILED'})")
    log(f"  Ledger: {LEDGER_JSONL} (+1 row)")
    log(f"  Human:  {LEDGER_MD}")

    # Calendar reminders — surface MUST-HAVE follow-ups within 14d
    upcoming = upcoming_followups(dt.date.today())
    if upcoming:
        log("\n📅 Upcoming MUST-HAVE follow-ups (≤14d):")
        for r in upcoming:
            days = "TODAY" if r["days_away"] == 0 else f"in {r['days_away']}d"
            log(f"  - [{r['id']}] {r['date']} ({days}): {r['description']}")
        log(f"  Source: {FOLLOWUPS_FILE.relative_to(REPO_ROOT)}")

    # N2 — Stale-branch + orphan-worktree warning
    gone, worktrees = stale_branches()
    if gone or worktrees:
        log("\n🌿 Stale git state:")
        if gone:
            log(f"  {len(gone)} local branch(es) whose remote is gone:")
            for b in gone[:10]:
                log(f"    - {b}")
            if len(gone) > 10:
                log(f"    ... +{len(gone) - 10} more")
            log("  Cleanup: git branch -d <branch>  (or use commit-commands:clean_gone skill)")
        if worktrees:
            log(f"  {len(worktrees)} isolated worktree(s) on disk:")
            for w in worktrees[:5]:
                log(f"    - {w}")
            if len(worktrees) > 5:
                log(f"    ... +{len(worktrees) - 5} more")

    # N5 — FIT-200 item-registry freshness (added 2026-07-23)
    reg = item_registry_freshness()
    if reg.get("stale"):
        log(f"\n🗂  ITEM-REGISTRY STALE: reason={reg.get('reason')} — "
            f"index has {reg.get('registry_items')} item(s), corpus has {reg.get('live_items')}. "
            f"The FIT-200 slug↔linear_id join is out of date; run `make crosswalk`.")

    # N3 — PR babysit sweep (open PRs idle >24h)
    idle = pr_babysit()
    total_idle = sum(len(v) for v in idle.values())
    if total_idle > 0:
        log(f"\n🔍 Open PRs idle >24h ({total_idle} across both repos):")
        for repo, prs in idle.items():
            if prs:
                log(f"  {repo} ({len(prs)}):")
                for p in prs[:3]:
                    log(f"    #{p['number']} ({p['updated_hours_ago']}h idle): {p['title']}")
                if len(prs) > 3:
                    log(f"    ... +{len(prs) - 3} more")

    # N4 (FIT-183 / R17) — cross-repo state-sync freshness probe
    sync = state_sync_health_probe()
    if not sync.get("reachable"):
        log(f"\n🔗 State-sync health: endpoint unreachable ({sync.get('error', 'unknown')}) "
            "— best-effort, ignoring (transient network).")
    elif "healthy" not in sync:
        # Reachable but no valid health body (e.g. 404 before the route
        # deploys, or an unexpected response) — best-effort, not an alert.
        log(f"\n🔗 State-sync health: endpoint returned http {sync.get('http_status')} "
            "without a health body — best-effort, ignoring (route not deployed yet?).")
    elif sync.get("healthy"):
        age = sync.get("age_minutes")
        log(f"\n🔗 State-sync health: OK (mirror {age}m old, "
            f"{sync.get('ft2_state_count')} states, {sync.get('gate_coverage_lines')} gate-cov lines).")
    else:
        age = sync.get("age_minutes")
        log(f"\n⚠ STATE-SYNC STALE: reason={sync.get('reason')} age={age}m "
            f"(threshold 360m) — the fitme-story FT2 mirror has gone stale. "
            f"Check scripts/sync-from-fittracker2.ts / the pre-build sync.")

    # Cross-layer sweep verdict (recorded in the ledger row above).
    sw_overall = sweep.get("overall", "?")
    if sw_overall == "PASS":
        log("\n🩺 Integrity sweep: PASS — all layers green.")
    elif sw_overall == "WARN":
        warn_layers = [k for k, v in sweep.get("layers", {}).items() if v == "WARN"]
        log(f"\n🩺 Integrity sweep: WARN — {', '.join(warn_layers)}. Run `make integrity-sweep`.")
    elif sw_overall == "FAIL":
        fail_layers = [k for k, v in sweep.get("layers", {}).items() if v == "FAIL"]
        log(f"\n🚨 Integrity sweep: FAIL — {', '.join(fail_layers)}. Run `make integrity-sweep`.")
    else:
        log(f"\n🩺 Integrity sweep: {sw_overall} ({sweep.get('reason', 'n/a')}).")


if __name__ == "__main__":
    main()
