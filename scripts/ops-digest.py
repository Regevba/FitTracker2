#!/usr/bin/env python3
"""ops-digest — post-deploy operator digest (FIT-205 / F23).

Composes the framework's existing health/telemetry/CI readouts into ONE
operator-facing digest to run right after a deploy (or any time you want a
single "is everything OK after that ship?" answer). It does not compute
anything new — it aggregates the authoritative producers and renders one
verdict:

  - Deploy/CI      : recent merged PRs + bot-PR health (deadlock detector)
  - Integrity      : integrity-telemetry-sweep 10-layer PASS/WARN/FAIL
  - Telemetry      : measurement-adoption snapshot (Tier 1.1)
  - Cadence        : calendar-anchored follow-ups due within N days

Design: each section is best-effort and independent — a producer that is
missing, times out, or errors degrades that ONE section to `unknown` and
never aborts the digest (post-deploy you always want *a* readout). Stdlib
only; no third-party deps.

Usage:
  python3 scripts/ops-digest.py                 # human-readable digest
  python3 scripts/ops-digest.py --json          # machine-readable JSON
  python3 scripts/ops-digest.py --window-days 7 # cadence look-ahead window
  make ops-digest                               # via Makefile
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path

REPO_ROOT = Path(
    os.environ.get("OPS_DIGEST_REPO_ROOT", Path(__file__).resolve().parent.parent)
)
SHARED = REPO_ROOT / ".claude" / "shared"

# Verdict severity ordering — the digest's overall verdict is the worst section.
SEVERITY = {"ok": 0, "unknown": 1, "warn": 2, "fail": 3}


def _run(cmd: list[str], timeout: int = 60) -> tuple[int, str]:
    """Run a command; return (returncode, combined_output). Fail-soft."""
    try:
        p = subprocess.run(
            cmd,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except (subprocess.TimeoutExpired, OSError) as e:  # pragma: no cover - env dep
        return 124, f"__error__: {e}"


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


# --------------------------------------------------------------------------- #
# Sections
# --------------------------------------------------------------------------- #
def section_deploy_ci() -> dict:
    """Recent merged PRs + bot-PR deadlock health."""
    out: dict = {"verdict": "ok", "recent_merges": [], "bot_pr_health": "unknown"}

    # Squash-merges (the repo's merge style) are ordinary commits, not merge
    # commits, so scan subjects for the trailing "(#N)" PR reference.
    rc2, log2 = _run(
        ["git", "log", "-n", "40", "--pretty=%s", "--since=2.days"], timeout=20
    )
    seen: set[int] = set()
    recent: list[dict] = []
    if rc2 == 0:
        for line in log2.splitlines():
            m = re.search(r"\(#(\d+)\)\s*$", line)
            if m:
                n = int(m.group(1))
                if n not in seen:
                    seen.add(n)
                    recent.append({"pr": n, "subject": line.strip()[:90]})
    out["recent_merges"] = recent[:10]

    rc3, _ = _run(["python3", "scripts/check-bot-pr-health.py"], timeout=45)
    if rc3 == 0:
        out["bot_pr_health"] = "ok"
    elif rc3 == 124:
        out["bot_pr_health"] = "unknown"
        out["verdict"] = _max_verdict(out["verdict"], "unknown")
    else:
        out["bot_pr_health"] = "deadlocked"
        out["verdict"] = "warn"
    return out


def section_integrity() -> dict:
    """integrity-telemetry-sweep 10-layer verdict."""
    out: dict = {"verdict": "unknown", "overall": None, "layers": []}
    rc, log = _run(["python3", "scripts/integrity-telemetry-sweep.py"], timeout=120)
    if log.startswith("__error__") or rc == 124:
        return out
    for line in log.splitlines():
        m = re.match(r"\s*[✓✗•]?\s*(PASS|WARN|FAIL|INFO)\s+(.+?)\s{2,}(.+)$", line)
        if m:
            out["layers"].append(
                {"status": m.group(1), "layer": m.group(2).strip(), "detail": m.group(3).strip()}
            )
    mo = re.search(r"OVERALL:\s*(PASS|WARN|FAIL)", log)
    if mo:
        out["overall"] = mo.group(1)
        out["verdict"] = {"PASS": "ok", "WARN": "warn", "FAIL": "fail"}[mo.group(1)]
    return out


def section_telemetry() -> dict:
    """measurement-adoption Tier 1.1 snapshot (read the ledger, no recompute)."""
    out: dict = {"verdict": "ok", "adoption": None}
    f = SHARED / "measurement-adoption.json"
    if not f.exists():
        out["verdict"] = "unknown"
        return out
    try:
        d = json.loads(f.read_text())
    except (json.JSONDecodeError, OSError):
        out["verdict"] = "unknown"
        return out
    # Dual-read: canonical values live under `summary` (schema 1.0); fall back to
    # top-level keys so a future field move degrades gracefully (pattern #24).
    summary = d.get("summary", {}) if isinstance(d.get("summary"), dict) else {}

    def _pick(*keys):
        for src in (summary, d):
            for k in keys:
                if src.get(k) is not None:
                    return src[k]
        return None

    out["adoption"] = {
        "fully_adopted": _pick("fully_adopted", "fully_adopted_post_v6"),
        "post_v6": _pick("features_post_v6", "post_v6_count", "post_v6"),
        "status": _pick("tier_1_1_status", "status"),
        "generated_at": d.get("updated") or d.get("generated_at"),
    }
    return out


def _parse_iso_date(s: str) -> date | None:
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", s or "")
    if not m:
        return None
    try:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def section_cadence(window_days: int, today: date) -> dict:
    """Calendar-anchored follow-ups due within `window_days` (not yet struck through)."""
    out: dict = {"verdict": "ok", "upcoming": []}
    f = SHARED / "must-have-cadence-followups.md"
    if not f.exists():
        out["verdict"] = "unknown"
        return out
    try:
        text = f.read_text()
    except OSError:
        out["verdict"] = "unknown"
        return out
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            continue
        # Skip completed rows (struck through with ~~).
        if "~~" in line:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        due = _parse_iso_date(cells[1])
        if not due:
            continue
        delta = (due - today).days
        if 0 <= delta <= window_days:
            out["upcoming"].append(
                {"id": cells[0].strip("* "), "due": due.isoformat(), "in_days": delta,
                 "what": re.sub(r"\s+", " ", cells[2])[:100]}
            )
    out["upcoming"].sort(key=lambda r: r["in_days"])
    return out


# --------------------------------------------------------------------------- #
# Assembly
# --------------------------------------------------------------------------- #
def _max_verdict(a: str, b: str) -> str:
    return a if SEVERITY.get(a, 1) >= SEVERITY.get(b, 1) else b


def build_digest(window_days: int, today: date) -> dict:
    rc_head, head = _run(["git", "rev-parse", "--short", "HEAD"], timeout=10)
    rc_br, branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], timeout=10)
    sections = {
        "deploy_ci": section_deploy_ci(),
        "integrity": section_integrity(),
        "telemetry": section_telemetry(),
        "cadence": section_cadence(window_days, today),
    }
    overall = "ok"
    for s in sections.values():
        overall = _max_verdict(overall, s.get("verdict", "unknown"))
    return {
        "generated_at": _now_iso(),
        "head": head.strip() if rc_head == 0 else None,
        "branch": branch.strip() if rc_br == 0 else None,
        "window_days": window_days,
        "overall_verdict": overall,
        "sections": sections,
    }


_ICON = {"ok": "✓", "warn": "⚠", "fail": "✗", "unknown": "•"}


def render_text(d: dict) -> str:
    L: list[str] = []
    ov = d["overall_verdict"]
    L.append("Post-deploy operator digest")
    L.append("=" * 60)
    L.append(f"  {_ICON[ov]} OVERALL: {ov.upper()}   "
             f"HEAD {d.get('head')} ({d.get('branch')})   {d['generated_at']}")
    L.append("")

    ci = d["sections"]["deploy_ci"]
    L.append(f"  {_ICON[ci['verdict']]} Deploy / CI    bot-PR health: {ci['bot_pr_health']}")
    for m in ci["recent_merges"][:6]:
        L.append(f"        · #{m['pr']} {m['subject']}")
    if not ci["recent_merges"]:
        L.append("        (no squash-merges in the last 2 days)")

    it = d["sections"]["integrity"]
    ov_i = it.get("overall") or "unknown"
    L.append(f"  {_ICON[it['verdict']]} Integrity      10-layer sweep: {ov_i}")
    for lyr in it["layers"]:
        if lyr["status"] in ("WARN", "FAIL"):
            L.append(f"        {lyr['status']} {lyr['layer']} — {lyr['detail']}")

    tel = d["sections"]["telemetry"]
    a = tel.get("adoption") or {}
    L.append(f"  {_ICON[tel['verdict']]} Telemetry      "
             f"fully-adopted {a.get('fully_adopted')} / post-v6 {a.get('post_v6')}"
             f" ({a.get('status')})")

    cad = d["sections"]["cadence"]
    L.append(f"  {_ICON[cad['verdict']]} Cadence        "
             f"{len(cad['upcoming'])} follow-up(s) due ≤ {d['window_days']}d")
    for u in cad["upcoming"][:8]:
        L.append(f"        {u['id']}  {u['due']} (in {u['in_days']}d)  {u['what']}")

    L.append("=" * 60)
    L.append(f"  OVERALL: {ov.upper()}"
             + ("  — nothing needs attention" if ov == "ok"
                else "  — see flagged sections above"))
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description="Post-deploy operator digest (F23).")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    ap.add_argument("--window-days", type=int, default=14,
                    help="cadence look-ahead window (default 14)")
    ap.add_argument("--no-write", action="store_true",
                    help="do not write the JSON snapshot to .claude/shared/")
    ap.add_argument("--today", help="override today (YYYY-MM-DD) — for testing")
    args = ap.parse_args()

    today = _parse_iso_date(args.today) if args.today else date.today()
    if today is None:
        print("error: --today must be YYYY-MM-DD", file=sys.stderr)
        return 2

    digest = build_digest(args.window_days, today)

    if not args.no_write:
        try:
            (SHARED / "ops-digest.json").write_text(json.dumps(digest, indent=2))
        except OSError as e:  # pragma: no cover
            print(f"warning: could not write snapshot: {e}", file=sys.stderr)

    if args.json:
        print(json.dumps(digest, indent=2))
    else:
        print(render_text(digest))

    # Exit non-zero only on a hard FAIL so CI/post-deploy hooks can gate on it.
    return 1 if digest["overall_verdict"] == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
