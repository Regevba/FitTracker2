#!/usr/bin/env python3
"""Membrane status — read-only smartlog of in-flight feature work.

v7.8 Mechanism F (advisory, bridge design §4.6 + §4.7.3). Surfaces a
table of which agents are currently working in which feature branches +
which paths they declared as `agent_manifest.writes`. v7.8 is read-only
— no enforcement, no lease acquisition. v7.9 wires `/pm-workflow` to
call `scripts/membrane-acquire.py` at session start; same data shape,
same UI.

Three sources, joined by feature slug:

1. `.claude/features/<slug>/state.json` — current_phase + last-touched
   mtime.
2. `.claude/shared/agent-leases.json` — declared writes + last_heartbeat
   (v7.8: empty in fresh installs; agents populate via /pm-workflow on
   acquire).
3. `git for-each-ref refs/heads/feature/* refs/heads/feat/* refs/heads/chore/*`
   — open feature branches with their HEAD commit + age.

Output: ASCII table sorted by last-touched mtime descending. JSON output
also available via --format=json for the UCC dashboard.

Pattern: Sapling smartlog (Meta), Jujutsu op-log. Branch-isolation
survey §6 Phase 1.

Usage:
    scripts/membrane-status.py                 # ASCII table
    scripts/membrane-status.py --format=json   # JSON for UCC

Exit 0 always — read-only advisory.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
LEASES_FILE = REPO_ROOT / ".claude" / "shared" / "agent-leases.json"


def _load_leases() -> dict:
    """Return parsed agent-leases.json or a default empty registry."""
    if not LEASES_FILE.exists():
        return {"version": "1.0", "epoch": 0, "leases": []}
    try:
        return json.loads(LEASES_FILE.read_text())
    except json.JSONDecodeError:
        return {"version": "1.0", "epoch": 0, "leases": []}


def _load_features() -> list[dict]:
    """Walk .claude/features/*/state.json. Return summaries sorted by mtime desc."""
    if not FEATURES_DIR.exists():
        return []
    summaries = []
    for state_path in sorted(FEATURES_DIR.glob("*/state.json")):
        try:
            data = json.loads(state_path.read_text())
        except json.JSONDecodeError:
            continue
        slug = state_path.parent.name
        mtime = datetime.fromtimestamp(state_path.stat().st_mtime, tz=timezone.utc)
        summaries.append({
            "slug": slug,
            "current_phase": data.get("current_phase", "unknown"),
            "framework_version": data.get("framework_version", ""),
            "branch": data.get("branch", ""),
            "last_touched_utc": mtime.isoformat(timespec="seconds"),
            "agent_manifest_present": "agent_manifest" in data,
            "manifest_writes": (data.get("agent_manifest") or {}).get("writes", []),
        })
    summaries.sort(key=lambda s: s["last_touched_utc"], reverse=True)
    return summaries


def _open_branches() -> dict[str, dict]:
    """Run `git for-each-ref` on feature/feat/chore branches.

    Returns a dict mapping branch_name → {commit, committer_date, age_seconds}.
    Falls back to empty dict if git is unavailable.
    """
    try:
        out = subprocess.check_output(
            [
                "git", "for-each-ref",
                "--format=%(refname:short)|%(objectname:short)|%(committerdate:iso8601)",
                "refs/heads/feature/", "refs/heads/feat/", "refs/heads/chore/",
            ],
            cwd=str(REPO_ROOT), text=True, stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {}
    branches: dict[str, dict] = {}
    now = datetime.now(timezone.utc)
    for line in out.strip().split("\n"):
        if not line:
            continue
        parts = line.split("|", 2)
        if len(parts) != 3:
            continue
        name, commit, date_iso = parts
        try:
            committer_date = datetime.fromisoformat(date_iso.replace(" ", "T"))
        except ValueError:
            continue
        age_s = int((now - committer_date).total_seconds())
        branches[name] = {
            "commit": commit,
            "committer_date": committer_date.isoformat(timespec="seconds"),
            "age_seconds": age_s,
        }
    return branches


def render_status() -> dict:
    """Return a structured status snapshot for both ASCII + JSON output."""
    leases_data = _load_leases()
    features = _load_features()
    branches = _open_branches()

    # Join: each feature's branch gets its git age if matchable.
    by_slug: dict[str, dict] = {}
    for f in features:
        f_copy = dict(f)
        branch = f.get("branch") or ""
        if branch and branch in branches:
            f_copy["branch_meta"] = branches[branch]
        by_slug[f["slug"]] = f_copy

    # Decorate with lease info.
    lease_by_slug: dict[str, dict] = {
        l.get("agent", ""): l for l in leases_data.get("leases", [])
    }
    for slug, entry in by_slug.items():
        if slug in lease_by_slug:
            entry["lease"] = lease_by_slug[slug]

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "epoch": leases_data.get("epoch", 0),
        "lease_count": len(leases_data.get("leases", [])),
        "feature_count": len(features),
        "branch_count": len(branches),
        "features": list(by_slug.values()),
        "_advisory_note": (
            "v7.8 Mechanism F is advisory — no lease acquisition is "
            "required. v7.9 will wire /pm-workflow to call membrane-acquire.py "
            "at session start."
        ),
    }


def render_ascii(status: dict) -> str:
    rows = ["MEMBRANE STATUS  (v7.8 advisory — read-only)",
            "=" * 80,
            f"Epoch: {status['epoch']}    "
            f"Active leases: {status['lease_count']}    "
            f"Features: {status['feature_count']}    "
            f"Open branches: {status['branch_count']}",
            ""]
    rows.append(f"{'feature':<40} {'phase':<14} {'fv':<10} {'manifest':<10} {'last touched':<20}")
    rows.append("-" * 100)
    # Show top 30 by mtime (truncated to fit a terminal).
    for f in status["features"][:30]:
        slug = f["slug"][:39]
        phase = (f["current_phase"] or "?")[:13]
        fv = (f["framework_version"] or "?")[:9]
        manifest = "yes" if f["agent_manifest_present"] else "no"
        last = f["last_touched_utc"][:19]
        rows.append(f"{slug:<40} {phase:<14} {fv:<10} {manifest:<10} {last:<20}")
    if len(status["features"]) > 30:
        rows.append(f"... +{len(status['features']) - 30} more (run with --format=json for full list)")
    rows.append("")
    rows.append(status["_advisory_note"])
    return "\n".join(rows)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--format", choices=["ascii", "json"], default="ascii")
    args = ap.parse_args()

    status = render_status()
    if args.format == "json":
        json.dump(status, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        print(render_ascii(status))
    return 0


if __name__ == "__main__":
    sys.exit(main())
