#!/usr/bin/env python3
"""Cross-layer freshness check — verify session state matches reality.

Read-only advisory. Covers 6 layers that `make preflight` (v7.8.6) does not:

  1. Recent merged PRs (FT2 + fitme-story, default last 7d) — surfaces work
     the operator shipped while the session thought it was open. Root-cause
     pattern for the 2026-05-28 incident where prereg fill-ins were
     duplicated against merged PRs #506 / #507.
  2. Worktree-vs-main divergence — flags worktrees >7 commits behind
     origin/main as stale. Stale worktrees silently overwrite shipped
     operator work on commit.
  3. Memory ↔ feature-state cross-scan — surfaces MEMORY.md entries that
     mention 'in flight' / 'paused' / 'pending' for features whose
     state.json now reports current_phase=complete.
  4. Linear sync (optional, requires LINEAR_API_KEY) — FIT epic status vs
     local state.json. Skipped cleanly when token absent.
  5. gh CLI scope health — detects missing OAuth scopes (e.g. admin:public_key)
     that silently 404 diagnostic API calls. Added 2026-05-28 (R5 of signing
     audit).
  6. Signing sanity — ssh-agent state + user.signingkey resolution + YubiKey
     physical presence. Added 2026-05-28 (R6 of signing audit) to catch the
     "agent has only Touch ID but user.signingkey expects YubiKey" footgun.

Triggered by:
  - `make freshness-check`  (standalone)
  - `make preflight`        (chained automatically)
  - SessionStart hook        (top-line summary surfaced to agent)

Exit code: always 0 (advisory). Use --format=json for downstream consumers.

See: feedback_cross_layer_freshness_check.md (durable behavioral rule).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = REPO_ROOT / ".claude" / "features"
DEFAULT_MEMORY_INDEX = Path.home() / ".claude/projects/-Volumes-DevSSD-FitTracker2/memory/MEMORY.md"
MEMORY_INDEX = Path(os.environ.get("CLAUDE_MEMORY_INDEX", str(DEFAULT_MEMORY_INDEX)))

REPOS = ["Regevba/FitTracker2", "Regevba/fitme-story"]
GH_TIMEOUT_S = 10
GIT_TIMEOUT_S = 5
LINEAR_TIMEOUT_S = 10
STALE_WORKTREE_BEHIND_THRESHOLD = 7
COMPLETE_PHASES = {"complete", "completed", "shipped", "merged"}
CLAIM_PHRASES = ("in flight", "in progress", "paused", "pending", "blocked")


def _gh_recent_prs(repo: str, since_iso: str) -> list | None:
    """Run `gh pr list --state merged` for `repo`. Return None if gh unavailable."""
    try:
        out = subprocess.check_output(
            [
                "gh", "pr", "list",
                "--repo", repo,
                "--state", "merged",
                "--limit", "50",
                "--search", f"merged:>={since_iso}",
                "--json", "number,title,headRefName,mergedAt",
            ],
            text=True, stderr=subprocess.DEVNULL, timeout=GH_TIMEOUT_S,
        )
        return json.loads(out)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
            FileNotFoundError, json.JSONDecodeError):
        return None


def _worktrees() -> list[dict]:
    """Enumerate worktrees via `git worktree list --porcelain`."""
    try:
        out = subprocess.check_output(
            ["git", "worktree", "list", "--porcelain"],
            cwd=str(REPO_ROOT), text=True, stderr=subprocess.DEVNULL,
            timeout=GIT_TIMEOUT_S,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return []
    worktrees: list[dict] = []
    cur: dict = {}
    for line in out.split("\n"):
        if line.startswith("worktree "):
            if cur:
                worktrees.append(cur)
            cur = {"path": line[len("worktree "):]}
        elif line.startswith("HEAD "):
            cur["head"] = line[len("HEAD "):]
        elif line.startswith("branch "):
            ref = line[len("branch "):]
            cur["branch"] = ref.removeprefix("refs/heads/")
    if cur:
        worktrees.append(cur)
    return worktrees


def _divergence(worktree_path: str) -> tuple[int, int] | None:
    """Return (ahead, behind) of HEAD vs origin/main. None on failure."""
    try:
        out = subprocess.check_output(
            ["git", "rev-list", "--left-right", "--count", "HEAD...origin/main"],
            cwd=worktree_path, text=True, stderr=subprocess.DEVNULL,
            timeout=GIT_TIMEOUT_S,
        ).strip()
        ahead_str, behind_str = out.split()
        return int(ahead_str), int(behind_str)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
            FileNotFoundError, ValueError):
        return None


def _feature_slugs() -> list[str]:
    if not FEATURES_DIR.exists():
        return []
    return sorted(d.name for d in FEATURES_DIR.iterdir() if d.is_dir())


def _feature_phase(slug: str) -> str | None:
    state_path = FEATURES_DIR / slug / "state.json"
    if not state_path.exists():
        return None
    try:
        return json.loads(state_path.read_text()).get("current_phase")
    except (OSError, json.JSONDecodeError):
        return None


def _memory_claims() -> list[dict]:
    """Scan MEMORY.md for claim phrases linked to a feature slug.

    Conservative: only flags when a known feature slug appears in the same
    line as a claim phrase. Single-pass; line-bounded.
    """
    if not MEMORY_INDEX.exists():
        return []
    slugs = _feature_slugs()
    if not slugs:
        return []
    try:
        text = MEMORY_INDEX.read_text()
    except OSError:
        return []
    claims: list[dict] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        line_lower = line.lower()
        # Skip the closed-item strikethrough lines so we don't false-positive.
        if "**closed" in line_lower or "~~" in line:
            continue
        matched_phrase = next((p for p in CLAIM_PHRASES if p in line_lower), None)
        if matched_phrase is None:
            continue
        matched_slug = next((s for s in slugs if s in line), None)
        if matched_slug is None:
            continue
        claims.append({
            "line_no": line_no,
            "feature_slug": matched_slug,
            "claim_phrase": matched_phrase,
            "snippet": line[:180],
        })
    return claims


def _gh_scope_check() -> dict:
    """Check whether `gh` CLI has the OAuth scopes we depend on for diagnostics.

    The `admin:public_key` scope is required to enumerate user/keys for the
    signing-audit cross-check. Without it, `gh api user/keys` 404s silently.
    """
    try:
        # `gh auth status` writes to stderr; need stderr=STDOUT to capture.
        out = subprocess.check_output(
            ["gh", "auth", "status"],
            text=True, stderr=subprocess.STDOUT, timeout=GIT_TIMEOUT_S,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        return {"status": "gh_unauthenticated_or_error",
                "error": (e.output[:200] if hasattr(e, "output") else str(e))}
    except FileNotFoundError:
        return {"status": "gh_unavailable", "error": "gh CLI not installed"}

    scopes_line = next(
        (line for line in out.splitlines() if "Token scopes:" in line),
        "",
    )
    # Scopes line example: "  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'"
    has_admin_pubkey = "admin:public_key" in scopes_line
    missing = []
    for required in ("admin:public_key",):
        if required not in scopes_line:
            missing.append(required)

    return {
        "status": "ok" if not missing else "missing_scopes",
        "scopes_line": scopes_line.strip() if scopes_line else "(no scopes line found)",
        "has_admin_pubkey": has_admin_pubkey,
        "missing_scopes": missing,
        "remediation": (
            f"gh auth refresh -h github.com -s {','.join(missing)}"
            if missing else None
        ),
    }


def _signing_sanity() -> dict:
    """Check signing-stack consistency.

    Surfaces 4 sub-checks:
      a) SSH_AUTH_SOCK pointing at a socket
      b) ssh-add -l reports ≥1 key in the agent
      c) git's user.signingkey resolves to a file on disk
      d) YubiKey physically connected (informational; not a failure mode)

    Catches the 2026-05-28 failure mode: agent had Touch ID only but
    user.signingkey defaulted to the YubiKey path → every commit paused
    15s for a YubiKey touch that wasn't going to happen.
    """
    checks: dict = {}

    # (a) SSH_AUTH_SOCK
    sock = os.environ.get("SSH_AUTH_SOCK")
    checks["ssh_auth_sock"] = {
        "ok": bool(sock),
        "value": sock or "(unset)",
        "via_secretive": bool(sock and "Secretive" in sock),
    }

    # (b) ssh-add -l
    try:
        ssh_add_out = subprocess.check_output(
            ["ssh-add", "-l"], text=True, stderr=subprocess.STDOUT, timeout=GIT_TIMEOUT_S,
        )
        keys = [line for line in ssh_add_out.splitlines() if "SHA256" in line]
        checks["agent_keys"] = {
            "ok": len(keys) > 0,
            "count": len(keys),
            "fingerprints": [k.split()[1] if len(k.split()) > 1 else k for k in keys],
            "labels": [
                " ".join(k.split()[3:]) for k in keys
                if len(k.split()) > 3
            ],
        }
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
        out = getattr(e, "output", "") or ""
        # "The agent has no identities." → exit 1 + that text — graceful empty
        checks["agent_keys"] = {
            "ok": False,
            "count": 0,
            "error": out.strip()[:120] if out else "ssh-add failed",
        }
    except FileNotFoundError:
        checks["agent_keys"] = {"ok": False, "count": 0, "error": "ssh-add not installed"}

    # (c) user.signingkey resolves
    try:
        signingkey_raw = subprocess.check_output(
            ["git", "config", "--global", "--get", "user.signingkey"],
            text=True, stderr=subprocess.DEVNULL, timeout=GIT_TIMEOUT_S,
        ).strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        signingkey_raw = ""

    if signingkey_raw:
        signingkey_path = Path(signingkey_raw).expanduser()
        path_exists = signingkey_path.exists()
        # Classify by path heuristic: keys under ~/.config/git-signing-keys
        # vs ~/.ssh/*_sk indicate Touch ID vs YubiKey defaults.
        is_touchid = "touchid" in str(signingkey_path).lower()
        is_yubikey = "_sk" in signingkey_path.name or "yubikey" in str(signingkey_path).lower()
        kind = "touchid" if is_touchid else ("yubikey" if is_yubikey else "unknown")
    else:
        signingkey_path = None
        path_exists = False
        kind = "unset"

    checks["signingkey"] = {
        "ok": path_exists,
        "configured": signingkey_raw or None,
        "exists_on_disk": path_exists,
        "kind": kind,
    }

    # (d) YubiKey physical presence (informational only on macOS)
    yk_present = None
    try:
        ioreg_out = subprocess.check_output(
            ["ioreg", "-p", "IOUSB", "-l"],
            text=True, stderr=subprocess.DEVNULL, timeout=GIT_TIMEOUT_S,
        )
        ioreg_lower = ioreg_out.lower()
        yk_present = "yubico" in ioreg_lower or "yubikey" in ioreg_lower
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        yk_present = None  # cannot detect (not on macOS or ioreg failed)

    checks["yubikey_physical"] = {
        "ok": True,  # informational only
        "present": yk_present,
    }

    # Roll-up: any agent + signingkey mismatch is the operationally-painful case.
    # If signingkey kind is "yubikey" but agent only holds non-SK keys + YubiKey
    # is absent → every commit will pause 15s. Flag it.
    agent_has_keys = checks["agent_keys"]["ok"]
    expects_yubikey = checks["signingkey"]["kind"] == "yubikey"
    yubikey_unavailable = yk_present is False
    mismatch_warning = (
        expects_yubikey and yubikey_unavailable and agent_has_keys
    )

    return {
        "status": "warning" if mismatch_warning or not checks["signingkey"]["ok"] else "ok",
        "mismatch_warning": mismatch_warning,
        "checks": checks,
        "recommendation": (
            "user.signingkey expects YubiKey but YubiKey not detected — "
            "every commit will pause 15s waiting for touch. Run "
            "`git config --global user.signingkey ~/.config/git-signing-keys/touchid.pub` "
            "or plug in the YubiKey."
            if mismatch_warning else None
        ),
    }


def _linear_check() -> dict:
    """Query Linear for FIT-team root issues if LINEAR_API_KEY set."""
    api_key = os.environ.get("LINEAR_API_KEY")
    if not api_key:
        return {"status": "skipped_no_token", "epics": []}
    query = (
        "query { issues("
        'filter: {team: {key: {eq: "FIT"}}, parent: {null: true}}, '
        "first: 50, orderBy: updatedAt"
        ") { nodes { identifier title state { name } updatedAt } } }"
    )
    try:
        req = urllib.request.Request(
            "https://api.linear.app/graphql",
            data=json.dumps({"query": query}).encode("utf-8"),
            headers={"Authorization": api_key, "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=LINEAR_TIMEOUT_S) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        nodes = data.get("data", {}).get("issues", {}).get("nodes", [])
        return {"status": "checked", "epic_count": len(nodes), "epics": nodes}
    except Exception as e:
        return {"status": "error", "error": str(e)[:200], "epics": []}


def collect_freshness(days: int = 7) -> dict:
    since = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")

    # Layer 1: recent merged PRs both repos
    recent_prs: dict = {}
    for repo in REPOS:
        prs = _gh_recent_prs(repo, since)
        repo_short = repo.split("/")[-1]
        if prs is None:
            recent_prs[repo_short] = {"status": "unavailable", "prs": []}
        else:
            recent_prs[repo_short] = {"status": "ok", "count": len(prs), "prs": prs}

    # Layer 2: worktree divergence
    worktree_data: list[dict] = []
    for wt in _worktrees():
        path = wt.get("path", "")
        entry: dict = {"path": path, "branch": wt.get("branch", ""), "head": wt.get("head", "")}
        div = _divergence(path)
        if div is not None:
            ahead, behind = div
            entry["ahead"] = ahead
            entry["behind"] = behind
            entry["stale_warning"] = behind > STALE_WORKTREE_BEHIND_THRESHOLD
        else:
            entry["divergence_unavailable"] = True
        worktree_data.append(entry)

    # Layer 3: memory ↔ feature-phase drift
    drifts: list[dict] = []
    for claim in _memory_claims():
        phase = _feature_phase(claim["feature_slug"])
        if phase in COMPLETE_PHASES:
            drifts.append({**claim, "actual_phase": phase, "drift": True})

    # Layer 4: Linear (optional)
    linear = _linear_check()

    # Layer 5: gh CLI scope health (added 2026-05-28, R5)
    gh_scope = _gh_scope_check()

    # Layer 6: signing sanity (added 2026-05-28, R6)
    signing = _signing_sanity()

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "days": days,
        "since": since,
        "layers": {
            "recent_merged_prs": recent_prs,
            "worktree_divergence": worktree_data,
            "memory_drift": drifts,
            "linear_sync": linear,
            "gh_scope": gh_scope,
            "signing": signing,
        },
        "summary": {
            "recent_pr_count_total": sum(
                r.get("count", 0) for r in recent_prs.values() if r.get("status") == "ok"
            ),
            "stale_worktrees": sum(1 for w in worktree_data if w.get("stale_warning")),
            "memory_drift_count": len(drifts),
            "linear_status": linear.get("status"),
            "gh_scope_status": gh_scope.get("status"),
            "signing_status": signing.get("status"),
        },
    }


def render_ascii(data: dict) -> str:
    s = data["summary"]
    lines = [
        "CROSS-LAYER FRESHNESS CHECK",
        "=" * 80,
        f"Generated: {data['generated_at']}   Since: {data['since']} ({data['days']}d window)",
        "",
        f"  Recent merged PRs (both repos):  {s['recent_pr_count_total']}",
        f"  Stale worktrees (behind > 7):    {s['stale_worktrees']}",
        f"  Memory ↔ feature drifts:         {s['memory_drift_count']}",
        f"  Linear sync:                     {s['linear_status']}",
        f"  gh CLI scopes:                   {s['gh_scope_status']}",
        f"  Signing sanity:                  {s['signing_status']}",
        "",
        "Recent merged PRs:",
    ]
    for repo, info in data["layers"]["recent_merged_prs"].items():
        if info["status"] != "ok":
            lines.append(f"  {repo}: ({info['status']})")
            continue
        lines.append(f"  {repo}: {info['count']} PRs in last {data['days']}d")
        for p in info["prs"][:10]:
            lines.append(f"    #{p['number']:>4} {p['mergedAt'][:10]} {p['title'][:80]}")
        if info["count"] > 10:
            lines.append(f"    ... +{info['count'] - 10} more")

    stale = [w for w in data["layers"]["worktree_divergence"] if w.get("stale_warning")]
    if stale:
        lines.append("")
        lines.append("⚠ Stale worktrees (rebase before editing if you'll commit on these):")
        for w in stale:
            lines.append(
                f"  {w['branch']:<50} ahead {w.get('ahead', '?')}, behind {w.get('behind', '?')}"
            )
            lines.append(f"    {w['path']}")

    drifts = data["layers"]["memory_drift"]
    if drifts:
        lines.append("")
        lines.append("⚠ Memory ↔ feature drift (claim suggests open, but state.json=complete):")
        for d in drifts[:10]:
            lines.append(
                f"  {d['feature_slug']}: '{d['claim_phrase']}' at L{d['line_no']} "
                f"but phase={d['actual_phase']}"
            )

    linear = data["layers"]["linear_sync"]
    if linear["status"] == "checked":
        lines.append("")
        lines.append(f"Linear FIT-team root issues: {linear.get('epic_count', 0)}")
        for e in linear.get("epics", [])[:8]:
            state_name = (e.get("state") or {}).get("name", "?")
            lines.append(f"  {e.get('identifier', '?'):<10} [{state_name:<12}] {e.get('title', '?')[:70]}")
    elif linear["status"] == "error":
        lines.append("")
        lines.append(f"⚠ Linear sync error: {linear.get('error', '?')}")

    gh_scope = data["layers"]["gh_scope"]
    if gh_scope.get("status") == "missing_scopes":
        lines.append("")
        lines.append(f"⚠ gh CLI missing scopes: {', '.join(gh_scope.get('missing_scopes', []))}")
        if gh_scope.get("remediation"):
            lines.append(f"  Fix:  {gh_scope['remediation']}")
    elif gh_scope.get("status") not in ("ok", None):
        lines.append("")
        lines.append(f"⚠ gh CLI: {gh_scope.get('status')} — {gh_scope.get('error', '?')[:120]}")

    signing = data["layers"]["signing"]
    sc = signing.get("checks", {})
    lines.append("")
    lines.append(
        f"Signing: agent={sc.get('agent_keys', {}).get('count', '?')} key(s)  "
        f"signingkey={sc.get('signingkey', {}).get('kind', '?')}"
        f"{'  YubiKey=' + str(sc.get('yubikey_physical', {}).get('present')) if sc.get('yubikey_physical', {}).get('present') is not None else ''}"
    )
    if signing.get("mismatch_warning"):
        lines.append(f"⚠ {signing.get('recommendation', 'signing-config mismatch')}")
    elif not sc.get("signingkey", {}).get("exists_on_disk"):
        lines.append(
            f"⚠ user.signingkey configured but file missing: "
            f"{sc.get('signingkey', {}).get('configured', '(unset)')}"
        )

    lines.append("")
    lines.append(
        "Apply: cross-check this output before producing an operator-gate inventory, "
        "status survey, or editing files operator may have shipped recently. "
        "See feedback_cross_layer_freshness_check.md."
    )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--format", choices=["ascii", "json"], default="ascii")
    ap.add_argument("--days", type=int, default=7,
                    help="Lookback window for recent merged PRs (default: 7)")
    ap.add_argument("--output",
                    help="Write to this path instead of stdout (still prints success line to stdout)")
    args = ap.parse_args()

    data = collect_freshness(days=args.days)

    if args.format == "json":
        rendered = json.dumps(data, indent=2)
    else:
        rendered = render_ascii(data)

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(rendered + ("\n" if not rendered.endswith("\n") else ""))
        print(f"freshness check written to: {out_path}")
    else:
        print(rendered)

    return 0


if __name__ == "__main__":
    sys.exit(main())
