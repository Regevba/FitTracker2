"""Tests for the W9 drift-triggered auto-isolation primitive + hook escalation.

Feature: w9-drift-triggered-auto-isolation (T4).

The load-bearing guarantee is GR4/KC3: **uncommitted work is never lost**. The
tests build throwaway git repos (try-repo style) and exercise the primitive's
success + every failure path, asserting recoverability at each step.

Run: python3 -m pytest scripts/tests/test_w9_auto_isolate.py -q
"""
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).resolve().parents[1]


def _load(name: str, env_overrides: dict):
    """Import a script module with REPO_ROOT_OVERRIDE/GATE_COVERAGE_LEDGER set."""
    for k, v in env_overrides.items():
        os.environ[k] = str(v)
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[name] = mod  # register before exec (dataclass needs it on 3.14)
    spec.loader.exec_module(mod)
    return mod


def _git(*args, cwd, check=True):
    return subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, text=True, check=check)


@pytest.fixture
def repo(tmp_path):
    """A throwaway git repo with one commit on `feature/<slug>`, active-feature set."""
    root = tmp_path / "repo"
    root.mkdir()
    _git("init", "-q", "-b", "main", cwd=root)
    _git("config", "user.email", "t@t.dev", cwd=root)
    _git("config", "user.name", "t", cwd=root)
    _git("config", "commit.gpgsign", "false", cwd=root)
    slug = "demo-feat"
    (root / "seed.txt").write_text("seed\n")
    (root / ".claude").mkdir()
    # Mirror production: the session-state dir (where the isolate lock lives) is
    # gitignored, so the lock never shows as an untracked change.
    (root / ".gitignore").write_text(".claude/_session-state/\n.claude/logs/\n")
    (root / ".claude" / "active-feature").write_text(slug + "\n")
    (root / ".claude" / "features" / slug).mkdir(parents=True)
    (root / ".claude" / "features" / slug / "state.json").write_text(json.dumps({"feature": slug}))
    # Commit the scaffold on MAIN so both main and feature/<slug> inherit it
    # (a clean baseline tree on either branch; tests that checkout main keep it).
    _git("add", "-A", cwd=root)
    _git("commit", "-qm", "scaffold", cwd=root)
    _git("checkout", "-q", "-b", f"feature/{slug}", cwd=root)
    ledger = root / ".claude" / "logs" / "gate-coverage.jsonl"
    return {"root": root, "slug": slug, "ledger": ledger}


def _wai(repo):
    return _load("w9_auto_isolate", {
        "REPO_ROOT_OVERRIDE": repo["root"],
        "GATE_COVERAGE_LEDGER": repo["ledger"],
        "W9_FAKE_NOW": "2026-06-06T05:40:00Z",
    })


# ── primitive: noop / skip paths ────────────────────────────────────────────

def test_clean_tree_is_noop(repo):
    wai = _wai(repo)
    res = wai.isolate_current_work()
    assert res.result == "noop" and res.reason == "clean_tree"


def test_lock_contended_skips(repo):
    wai = _wai(repo)
    # Pre-create the lock so acquisition fails.
    lock = repo["root"] / ".claude" / "_session-state" / "w9-isolate.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    lock.write_text("held")
    res = wai.isolate_current_work()
    assert res.result == "skipped" and res.reason == "lock_contended"


def test_no_active_feature_skips(repo):
    (repo["root"] / ".claude" / "active-feature").write_text("")
    wai = _wai(repo)
    # Make the tree dirty so we get past the clean-tree check to the feature check.
    (repo["root"] / "dirty.txt").write_text("x")
    res = wai.isolate_current_work()
    assert res.result == "skipped" and res.reason == "no_active_feature"


# ── primitive: GR4/KC3 data-loss safety ─────────────────────────────────────

def test_dirty_work_untouched_when_worktree_script_missing(repo):
    """If the worktree-create script is absent, the precondition fails FAST — the
    working tree is never touched, so the uncommitted work stays exactly in
    place. This is the GR4 hard stop (no data loss, no stash dance needed)."""
    wai = _wai(repo)
    # No create-isolated-worktree.py in the throwaway repo -> forced failure path.
    assert not (repo["root"] / "scripts" / "create-isolated-worktree.py").exists()
    (repo["root"] / "wip.txt").write_text("precious uncommitted work\n")
    res = wai.isolate_current_work()
    assert res.result == "error" and res.reason == "create_worktree_script_missing"
    # Work is untouched in the working tree (not lost, not even stashed).
    assert (repo["root"] / "wip.txt").read_text() == "precious uncommitted work\n"
    assert _git("stash", "list", cwd=repo["root"]).stdout.strip() == ""
    # Still on the original feature branch.
    branch = _git("branch", "--show-current", cwd=repo["root"]).stdout.strip()
    assert branch == f"feature/{repo['slug']}"


def test_full_isolation_happy_path(repo, tmp_path):
    """End-to-end success: stash -> worktree -> apply -> verify -> drop stash.

    A minimal create-isolated-worktree.py stub stands in for the real script so
    the full success path runs in a throwaway repo. Proves: the uncommitted work
    lands in the worktree, the digest verification passes, and the source stash
    is dropped (result=isolated)."""
    wt = tmp_path / "wt"
    slug = repo["slug"]
    # Model post-drift: source HEAD on main (feature/<slug> free for a worktree).
    _git("checkout", "-q", "main", cwd=repo["root"])
    stub = repo["root"] / "scripts"
    stub.mkdir(parents=True, exist_ok=True)
    # Stub: `--feature X --create-if-missing` -> `git worktree add <wt> feature/X`.
    (stub / "create-isolated-worktree.py").write_text(
        "import subprocess,sys,os\n"
        f"wt = {str(wt)!r}\n"
        "root = os.environ['REPO_ROOT_OVERRIDE']\n"
        "if not os.path.exists(wt):\n"
        f"    subprocess.run(['git','worktree','add',wt,'feature/{slug}'],cwd=root,check=True,capture_output=True)\n"
        "sys.exit(0)\n"
    )
    # Commit the stub on main so `git stash -u` (untracked sweep) doesn't remove
    # it — mirrors production where create-isolated-worktree.py is tracked.
    _git("add", "-A", cwd=repo["root"])
    _git("commit", "-qm", "add worktree stub", cwd=repo["root"])
    wai = _wai(repo)
    (repo["root"] / "wip.txt").write_text("precious\n")
    res = wai.isolate_current_work()
    assert res.result == "isolated", f"got {res.result}/{res.reason}"
    # Work is now in the worktree.
    assert (wt / "wip.txt").read_text() == "precious\n"
    # Source stash was dropped after verified apply (no lingering stash).
    assert _git("stash", "list", cwd=repo["root"]).stdout.strip() == ""


def test_dry_run_does_not_stash_or_lose_work(repo):
    wai = _wai(repo)
    (repo["root"] / "wip.txt").write_text("data\n")
    res = wai.isolate_current_work(dry_run=True)
    assert res.result == "noop" and res.reason == "dry_run"
    # Working tree untouched.
    assert (repo["root"] / "wip.txt").read_text() == "data\n"
    assert _git("stash", "list", cwd=repo["root"]).stdout.strip() == ""


# ── telemetry (T3) ──────────────────────────────────────────────────────────

def test_emit_telemetry_writes_mechanism_a_row(repo):
    wai = _wai(repo)
    wai.emit_telemetry(candidates=1, checked=0, skipped=1,
                       skip_reasons=["offer_not_acted"], outcome="offer",
                       drift={"from_branch": "a", "to_branch": "b"})
    rows = [json.loads(l) for l in repo["ledger"].read_text().splitlines() if l.strip()]
    assert rows and rows[-1]["gate"] == "w9.auto_isolate"
    assert rows[-1]["outcome"] == "offer"
    assert rows[-1]["skip_reasons"] == ["offer_not_acted"]


def test_status_readout_reflects_telemetry(repo):
    wai = _wai(repo)
    wai.emit_telemetry(candidates=1, checked=1, skipped=0, skip_reasons=[], outcome="isolated")
    wai.emit_telemetry(candidates=1, checked=0, skipped=1, skip_reasons=["offer_not_acted"], outcome="offer")
    status = _load("w9_isolation_status", {
        "REPO_ROOT_OVERRIDE": repo["root"], "GATE_COVERAGE_LEDGER": repo["ledger"]})
    s = status.collect()
    assert s["drift_events"] == 2
    assert s["isolated"] == 1
    assert s["offers"] == 1


# ── hook escalation (T2) ────────────────────────────────────────────────────

def test_hook_offer_path_emits_offer_telemetry(repo, monkeypatch):
    """With no CLAUDE_W9_AUTO_ISOLATE, a dirty drift emits an 'offer' row and does NOT act."""
    # Load the real hook module by file (hyphenated filename).
    spec = importlib.util.spec_from_file_location("cbd", SCRIPTS / "check-branch-drift.py")
    cbd = importlib.util.module_from_spec(spec)
    import sys
    sys.modules["cbd"] = cbd
    spec.loader.exec_module(cbd)
    # Point the hook at the throwaway repo.
    monkeypatch.setattr(cbd, "REPO_ROOT", repo["root"])
    monkeypatch.setenv("GATE_COVERAGE_LEDGER", str(repo["ledger"]))
    monkeypatch.delenv("CLAUDE_W9_AUTO_ISOLATE", raising=False)
    (repo["root"] / "wip.txt").write_text("x\n")
    # _escalate_on_drift imports w9_auto_isolate from SCRIPTS; ensure its env is set.
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(repo["root"]))
    cbd._escalate_on_drift(f"feature/{repo['slug']}", "main")
    rows = [json.loads(l) for l in repo["ledger"].read_text().splitlines() if l.strip()]
    assert any(r["outcome"] == "offer" for r in rows)
    # No worktree created, no stash (did not act).
    assert _git("stash", "list", cwd=repo["root"]).stdout.strip() == ""


def test_hook_optout_path_emits_optout(repo, monkeypatch):
    spec = importlib.util.spec_from_file_location("cbd2", SCRIPTS / "check-branch-drift.py")
    cbd = importlib.util.module_from_spec(spec)
    import sys
    sys.modules["cbd2"] = cbd
    spec.loader.exec_module(cbd)
    monkeypatch.setattr(cbd, "REPO_ROOT", repo["root"])
    monkeypatch.setenv("GATE_COVERAGE_LEDGER", str(repo["ledger"]))
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(repo["root"]))
    # Set opt-out in state.json.
    sj = repo["root"] / ".claude" / "features" / repo["slug"] / "state.json"
    sj.write_text(json.dumps({"feature": repo["slug"], "isolation_opt_out": True}))
    (repo["root"] / "wip.txt").write_text("x\n")
    cbd._escalate_on_drift(f"feature/{repo['slug']}", "main")
    rows = [json.loads(l) for l in repo["ledger"].read_text().splitlines() if l.strip()]
    assert any(r["outcome"] == "opt_out" for r in rows)


def test_hook_clean_tree_no_escalation(repo, monkeypatch):
    spec = importlib.util.spec_from_file_location("cbd3", SCRIPTS / "check-branch-drift.py")
    cbd = importlib.util.module_from_spec(spec)
    import sys
    sys.modules["cbd3"] = cbd
    spec.loader.exec_module(cbd)
    monkeypatch.setattr(cbd, "REPO_ROOT", repo["root"])
    monkeypatch.setenv("GATE_COVERAGE_LEDGER", str(repo["ledger"]))
    # Clean tree -> no telemetry, no action.
    cbd._escalate_on_drift(f"feature/{repo['slug']}", "main")
    assert not repo["ledger"].exists() or repo["ledger"].read_text().strip() == ""
