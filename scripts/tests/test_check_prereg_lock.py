"""Isolation tests for scripts/check-prereg-lock.sh.

Spawns a throwaway git repo at tmp_path, stages canonical scenarios, and runs
the REAL check script via subprocess against the staged index — the same
"test the real script" philosophy as the F16 try-repo harness. Covers the four
branches: lock-introducing (permit), unlock (permit), forward-edit (block),
and sha-mismatch lock (block).
"""
import hashlib
import json
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "check-prereg-lock.sh"
PREREG_REL = ".claude/shared/hadf/preregistration-phase2bis-subexp1.json"


def _git(repo, *args):
    return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)


def _init(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "t@t.t")
    _git(repo, "config", "user.name", "t")
    (repo / ".claude/shared/hadf").mkdir(parents=True)
    return repo


def _write_prereg(repo, content):
    p = repo / PREREG_REL
    p.write_text(content)
    return p


def _lock_for(content, **overrides):
    sha = hashlib.sha256(content.encode()).hexdigest()
    d = {"sha256": sha, "locked_at": "2026-06-07T00:00:00Z",
         "locked_by": "t@t.t", "locked_commit": "deadbeef"}
    d.update(overrides)
    return json.dumps(d, indent=2) + "\n"


def _run(repo):
    return subprocess.run(["bash", str(SCRIPT)], cwd=repo,
                          capture_output=True, text=True)


def test_lock_introducing_commit_permitted(tmp_path):
    repo = _init(tmp_path)
    content = '{"experiment": "subexp1"}\n'
    _write_prereg(repo, content)
    (repo / f"{PREREG_REL}.lock").write_text(_lock_for(content))
    _git(repo, "add", PREREG_REL, f"{PREREG_REL}.lock")
    r = _run(repo)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "permitted" in r.stdout


def test_lock_introducing_sha_mismatch_blocked(tmp_path):
    repo = _init(tmp_path)
    content = '{"experiment": "subexp1"}\n'
    _write_prereg(repo, content)
    # Lock records a sha for DIFFERENT content → mismatch.
    bad = _lock_for('{"experiment": "tampered"}\n')
    (repo / f"{PREREG_REL}.lock").write_text(bad)
    _git(repo, "add", PREREG_REL, f"{PREREG_REL}.lock")
    r = _run(repo)
    assert r.returncode == 1
    assert "does not match" in r.stdout


def test_forward_edit_against_existing_lock_blocked(tmp_path):
    repo = _init(tmp_path)
    content = '{"experiment": "subexp1"}\n'
    _write_prereg(repo, content)
    (repo / f"{PREREG_REL}.lock").write_text(_lock_for(content))
    _git(repo, "add", PREREG_REL, f"{PREREG_REL}.lock")
    _git(repo, "commit", "-q", "--no-verify", "-m", "lock")
    # Now modify the prereg while the lock stays in place.
    _write_prereg(repo, '{"experiment": "subexp1", "edited": true}\n')
    _git(repo, "add", PREREG_REL)
    r = _run(repo)
    assert r.returncode == 1
    assert "is locked at" in r.stdout


def test_unlock_commit_permitted(tmp_path):
    repo = _init(tmp_path)
    content = '{"experiment": "subexp1"}\n'
    _write_prereg(repo, content)
    (repo / f"{PREREG_REL}.lock").write_text(_lock_for(content))
    _git(repo, "add", PREREG_REL, f"{PREREG_REL}.lock")
    _git(repo, "commit", "-q", "--no-verify", "-m", "lock")
    # Unlock: remove the lock AND edit the prereg in the same commit.
    (repo / f"{PREREG_REL}.lock").unlink()
    _write_prereg(repo, '{"experiment": "subexp1", "edited": true}\n')
    _git(repo, "add", "-A")
    r = _run(repo)
    assert r.returncode == 0, r.stdout + r.stderr


def test_unrelated_commit_noop(tmp_path):
    repo = _init(tmp_path)
    (repo / "README.md").write_text("hi\n")
    _git(repo, "add", "README.md")
    r = _run(repo)
    assert r.returncode == 0
