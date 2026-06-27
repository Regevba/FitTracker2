#!/usr/bin/env python3
"""F18 mutation-testing summary reader (version-proof).

mutmut 2.5.1's own `mutmut results` / `mutmut junitxml` readers crash on recent
peewee (`QueryResultIterator object is not iterable`). The *run* writes results
correctly to the `.mutmut-cache` sqlite db regardless. This reader queries that
db directly with stdlib sqlite3 — no mutmut/peewee/ORM dependency — so it works
on any Python/peewee combination CI or an operator happens to have.

Status vocabulary (mutmut `Mutant.status`):
  ok_killed      — a test failed when the mutant was applied  → GOOD (killed)
  bad_timeout    — the suite hung on the mutant               → killed (counted good)
  ok_suspicious  — suite slowed oddly; treat as needs-review  → not counted either way
  bad_survived   — all tests passed with the mutant applied   → BAD (survivor; test gap)
  skipped        — excluded (e.g. not on a covered line)      → not counted
  untested       — not yet run (partial/interrupted pass)     → not counted

Mutation score = killed / (killed + survived) over TESTED mutants only.

Usage:
  python3 scripts/mutation-summary.py [--cache .mutmut-cache] [--json PATH]
Exit code is always 0 (warn-only posture) unless --fail-under N is given AND the
score is below N (then exit 1) — for a future enforced calibration step.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

KILLED = {"ok_killed", "bad_timeout"}
SURVIVED = {"bad_survived"}


def summarize(cache_path: Path) -> dict:
    if not cache_path.exists():
        return {"error": f"no cache at {cache_path}", "total": 0}
    con = sqlite3.connect(str(cache_path))
    try:
        rows = dict(con.execute("select status, count(*) from Mutant group by status").fetchall())
        total = con.execute("select count(*) from Mutant").fetchone()[0]
        files = con.execute("select count(*) from SourceFile").fetchone()[0]
    finally:
        con.close()
    killed = sum(rows.get(s, 0) for s in KILLED)
    survived = sum(rows.get(s, 0) for s in SURVIVED)
    suspicious = rows.get("ok_suspicious", 0)
    skipped = rows.get("skipped", 0)
    untested = rows.get("untested", 0)
    tested = killed + survived
    score = (killed / tested) if tested else None
    return {
        "total_mutants": total,
        "source_files": files,
        "killed": killed,
        "survived": survived,
        "suspicious": suspicious,
        "skipped": skipped,
        "untested": untested,
        "tested": tested,
        "mutation_score": round(score, 4) if score is not None else None,
        "status_breakdown": rows,
    }


def render(s: dict) -> str:
    if s.get("error"):
        return f"mutation-summary: {s['error']} (run `make mutation-test` first)"
    score = s["mutation_score"]
    score_str = f"{score:.1%}" if score is not None else "n/a (no tested mutants yet)"
    pct_done = (s["tested"] + s["skipped"]) / s["total_mutants"] if s["total_mutants"] else 0
    lines = [
        f"Mutation testing summary — {s['source_files']} dispatcher file(s), {s['total_mutants']} mutants",
        f"  killed:     {s['killed']}",
        f"  survived:   {s['survived']}   (test gaps — gate logic no test catches)",
        f"  suspicious: {s['suspicious']}",
        f"  skipped:    {s['skipped']}",
        f"  untested:   {s['untested']}",
        f"  mutation score (killed / tested): {score_str}",
        f"  progress: {pct_done:.1%} of mutants resolved",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=".mutmut-cache")
    ap.add_argument("--json", dest="json_path", default=None)
    ap.add_argument("--fail-under", type=float, default=None,
                    help="exit 1 if mutation score < N (0-1). Default: never fail (warn-only).")
    args = ap.parse_args()

    s = summarize(Path(args.cache))
    print(render(s))
    if args.json_path:
        Path(args.json_path).write_text(json.dumps(s, indent=2) + "\n")

    if args.fail_under is not None and s.get("mutation_score") is not None:
        if s["mutation_score"] < args.fail_under:
            print(f"mutation score {s['mutation_score']:.1%} < threshold {args.fail_under:.1%}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
