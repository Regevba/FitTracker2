#!/usr/bin/env python3
"""
audit-cache-hit-rate.py — R16 from 2026-05-19 dev-env audit.

Read-only audit of .claude/cache/ entries. Surfaces:
  - Total cache entries + total size
  - Per-tier breakdown (L1 per-skill, L2 _shared/, L3 _project/)
  - Last-modified date per entry
  - Cross-reference with Mechanism C session-event reads to identify
    entries never accessed in any captured session ("cold" candidates
    for review/eviction)

This is purely diagnostic. No writes. Use to inform whether the cache
architecture warrants LRU eviction (R16 in dev-env audit). Recommendation
written only to stdout; operator decides what to delete.

Usage:
  python3 scripts/audit-cache-hit-rate.py
  python3 scripts/audit-cache-hit-rate.py --cold-only
  python3 scripts/audit-cache-hit-rate.py --since-days 30

Linear: FIT-182
Plan: docs/research/2026-05-19-dev-env-audit-stability-and-scale.md (R16)
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = REPO_ROOT / ".claude" / "cache"
LOGS_DIR = REPO_ROOT / ".claude" / "logs"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--cold-only", action="store_true",
                   help="Show only entries with zero recorded reads")
    p.add_argument("--since-days", type=int, default=90,
                   help="Window for 'recently read' classification (default 90)")
    return p.parse_args()


def gather_cache_entries() -> list[dict]:
    if not CACHE_DIR.exists():
        return []
    out = []
    for p in sorted(CACHE_DIR.rglob("*.json")):
        rel = p.relative_to(CACHE_DIR).as_posix()
        size = p.stat().st_size
        mtime = dt.datetime.fromtimestamp(p.stat().st_mtime)
        # Categorize tier from path
        parts = rel.split("/")
        if parts[0] == "_project":
            tier = "L3 _project"
        elif parts[0] == "_shared":
            tier = "L2 _shared"
        elif parts[0] == "research":
            tier = "L2 research"
        else:
            tier = f"L1 {parts[0]}"
        out.append({
            "path": rel,
            "abs_path": str(p),
            "size_bytes": size,
            "mtime": mtime,
            "tier": tier,
        })
    return out


def gather_session_reads(since_days: int) -> dict[str, int]:
    """Return {cache-relative-path: read_count} across all session ledgers."""
    if not LOGS_DIR.exists():
        return {}
    cutoff = dt.datetime.now() - dt.timedelta(days=since_days)
    reads: dict[str, int] = {}
    for ledger in LOGS_DIR.glob("_session-*.events.jsonl"):
        mtime = dt.datetime.fromtimestamp(ledger.stat().st_mtime)
        if mtime < cutoff:
            continue
        try:
            for line in ledger.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except json.JSONDecodeError:
                    continue
                # Event shape: {tool: "Read", file_path: "/abs/path"} OR
                # {"file_path": ".claude/cache/_shared/something.json"}
                fp = ev.get("file_path") or ""
                if not fp:
                    continue
                # Normalize to .claude/cache-relative
                if "/.claude/cache/" in fp:
                    rel = fp.split("/.claude/cache/", 1)[1]
                    reads[rel] = reads.get(rel, 0) + 1
        except OSError:
            continue
    return reads


def fmt_size(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n / (1024 * 1024):.1f} MB"


def main() -> int:
    args = parse_args()
    entries = gather_cache_entries()
    reads = gather_session_reads(args.since_days)

    if not entries:
        print("No cache entries found.")
        return 0

    # Group + summarize
    total_size = sum(e["size_bytes"] for e in entries)
    by_tier: dict[str, list[dict]] = {}
    for e in entries:
        by_tier.setdefault(e["tier"], []).append(e)

    print(f"=== Cache audit ({len(entries)} entries, {fmt_size(total_size)}) ===")
    print(f"  Window for read-attribution: last {args.since_days} days")
    print(f"  Session ledgers found:       {sum(1 for _ in LOGS_DIR.glob('_session-*.events.jsonl'))}")
    print()

    cold = []
    warm = []

    for tier in sorted(by_tier):
        tier_entries = by_tier[tier]
        tier_size = sum(e["size_bytes"] for e in tier_entries)
        print(f"{tier}: {len(tier_entries)} entries · {fmt_size(tier_size)}")
        for e in sorted(tier_entries, key=lambda x: x["path"]):
            hits = reads.get(e["path"], 0)
            mark = "·" if hits > 0 else "○"
            line = f"  {mark} {e['path']:<48} {fmt_size(e['size_bytes']):>8}  mtime={e['mtime'].strftime('%Y-%m-%d')}  reads={hits}"
            if args.cold_only and hits > 0:
                continue
            if hits == 0:
                cold.append(e)
            else:
                warm.append(e)
            print(line)
        print()

    print(f"=== Summary ===")
    print(f"  Total entries:     {len(entries)}")
    print(f"  Warm (≥1 read):    {len(warm)}")
    print(f"  Cold (0 reads):    {len(cold)}")
    if entries:
        cold_pct = 100 * len(cold) / len(entries)
        print(f"  Cold ratio:        {cold_pct:.1f}%")
    print()
    print("Note: 'cold' = no attribution in available session ledgers. This")
    print("does NOT mean the entry was never useful — it may have been read")
    print("by skill-loaders, PostToolUse:Read hooks not yet active, or used")
    print("during sessions whose ledgers have rotated out. Use as a hint, not")
    print("an eviction trigger.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
