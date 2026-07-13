#!/usr/bin/env python3
"""Create a SIGNED commit + auto-merge PR for automated snapshot crons.

Option B completion (2026-07-13). `main` has `required_signatures` on, so it
refuses to merge any PR that *contains* an unsigned commit. A runner `git commit`
is unsigned, so the cron PRs — even PAT-opened, CI-triggering ones — cannot
auto-merge ("the base branch policy prohibits the merge"). This helper sidesteps
that by creating the snapshot commit through the GitHub GraphQL
`createCommitOnBranch` mutation, which GitHub **auto-signs** (verified=true), so
the PR is signature-clean and auto-merge lands it through the required checks —
no branch-protection change, least-privilege PAT (Contents R/W + PRs R/W).

Flow: reads the STAGED changes (`git diff --cached`) as the file set, creates
<branch> at origin/<base>, commits the staged additions/deletions onto it as one
signed commit, opens a PR, and enables squash auto-merge. Uses GH_TOKEN (the PAT).

Usage:
  git add <paths>
  python3 scripts/create-signed-snapshot-pr.py \
    --repo OWNER/REPO --branch NAME --base main \
    --message "headline" [--message-body "body"] \
    --pr-title T --pr-body B [--label L]...
Exit: 0 on success (PR opened + auto-merge set), non-zero on failure.
"""
from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys


def run(cmd: list[str], *, check: bool = True, stdin: str | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, check=check, input=stdin)


def staged_file_changes() -> dict:
    """Build GraphQL fileChanges from `git diff --cached --name-status`.

    Pure-ish (shells out to git + reads files) — the parsing is unit-tested via
    parse_name_status(). Returns {additions:[{path,contents(b64)}], deletions:[{path}]}.
    """
    out = run(["git", "diff", "--cached", "--name-status"]).stdout
    adds, dels = parse_name_status(out)
    additions = []
    for path in adds:
        with open(path, "rb") as f:
            additions.append({"path": path, "contents": base64.b64encode(f.read()).decode("ascii")})
    return {"additions": additions, "deletions": [{"path": p} for p in dels]}


def parse_name_status(text: str) -> tuple[list[str], list[str]]:
    """Split `git diff --cached --name-status` into (added_or_modified, deleted).

    Rename lines (R100\told\tnew) count the new path as an addition + old as a
    deletion. Copy (C) counts the new path as an addition.
    """
    adds, dels = [], []
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        status = parts[0]
        if status.startswith("D"):
            dels.append(parts[1])
        elif status.startswith(("R", "C")) and len(parts) >= 3:
            dels.append(parts[1])
            adds.append(parts[2])
        else:  # A, M, T
            adds.append(parts[-1])
    return adds, dels


def base_head_oid(repo: str, base: str) -> str:
    """Authoritative remote tip of <base> via the API (no dependence on the
    runner's local fetch depth)."""
    out = run(["gh", "api", f"repos/{repo}/git/ref/heads/{base}"]).stdout
    return json.loads(out)["object"]["sha"]


def ensure_branch(repo: str, branch: str, sha: str) -> None:
    """Create refs/heads/<branch> at <sha>; tolerate 'already exists'."""
    p = run(
        ["gh", "api", "-X", "POST", f"repos/{repo}/git/refs",
         "-f", f"ref=refs/heads/{branch}", "-f", f"sha={sha}"],
        check=False,
    )
    if p.returncode != 0 and "already exists" not in (p.stdout + p.stderr).lower():
        raise RuntimeError(f"could not create branch {branch}: {p.stderr.strip()}")


def create_signed_commit(repo: str, branch: str, oid: str, message: dict, changes: dict) -> str:
    payload = {
        "query": (
            "mutation($input: CreateCommitOnBranchInput!) {"
            " createCommitOnBranch(input: $input) { commit { oid url } } }"
        ),
        "variables": {
            "input": {
                "branch": {"repositoryNameWithOwner": repo, "branchName": branch},
                "message": message,
                "expectedHeadOid": oid,
                "fileChanges": changes,
            }
        },
    }
    p = run(["gh", "api", "graphql", "--input", "-"], check=False, stdin=json.dumps(payload))
    body = json.loads(p.stdout or "{}") if p.stdout.strip().startswith("{") else {}
    if p.returncode != 0 or body.get("errors"):
        raise RuntimeError(f"createCommitOnBranch failed: {p.stdout} {p.stderr}")
    return body["data"]["createCommitOnBranch"]["commit"]["oid"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--branch", required=True)
    ap.add_argument("--base", default="main")
    ap.add_argument("--message", required=True, help="commit headline")
    ap.add_argument("--message-body", default="")
    ap.add_argument("--pr-title", required=True)
    ap.add_argument("--pr-body", default="")
    ap.add_argument("--label", action="append", default=[])
    args = ap.parse_args()

    changes = staged_file_changes()
    if not changes["additions"] and not changes["deletions"]:
        print("no staged changes — nothing to commit.")
        return 0

    oid = base_head_oid(args.repo, args.base)
    ensure_branch(args.repo, args.branch, oid)
    message = {"headline": args.message}
    if args.message_body:
        message["body"] = args.message_body
    new_oid = create_signed_commit(args.repo, args.branch, oid, message, changes)
    print(f"✓ signed commit {new_oid[:8]} created on {args.branch}")

    pr_cmd = ["gh", "pr", "create", "--repo", args.repo, "--base", args.base,
              "--head", args.branch, "--title", args.pr_title, "--body", args.pr_body]
    for lbl in args.label:
        pr_cmd += ["--label", lbl]
    p = run(pr_cmd, check=False)
    print(p.stdout.strip() or p.stderr.strip())
    if p.returncode != 0:
        return p.returncode

    m = run(["gh", "pr", "merge", args.branch, "--repo", args.repo,
             "--squash", "--auto", "--delete-branch"], check=False)
    if m.returncode != 0:
        print(f"::warning title=auto-merge::could not enable auto-merge: {m.stderr.strip()}")
    else:
        print("✓ auto-merge enabled (will land once required checks pass)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001 — cron helper: surface + non-zero
        print(f"::error title=create-signed-snapshot-pr::{e}", file=sys.stderr)
        sys.exit(1)
