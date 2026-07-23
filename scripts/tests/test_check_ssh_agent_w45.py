"""W45 — GitHub SSH auth reachability probe in scripts/check-ssh-agent.sh.

Signing-capable != auth-capable. W1 only ever proved the agent could sign;
on 2026-07-23 it passed green while `git fetch` over SSH was impossible
(sole auth key passphrase-protected, keychain locked during DarkWake).

Contract pinned here: the probe fires only when git actually uses SSH for
github.com, it never blocks, and it stays silent once the transport is HTTPS.
"""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "check-ssh-agent.sh"


def _repo(tmp_path: Path, remote: str) -> Path:
    r = tmp_path / "repo"
    r.mkdir()
    env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)
    subprocess.run(["git", "init", "-q"], cwd=r, check=True, env=env)
    subprocess.run(["git", "remote", "add", "origin", remote], cwd=r, check=True, env=env)
    return r


def _stubs(tmp_path: Path, ssh_output: str, ssh_rc: int = 1) -> Path:
    """PATH shim: a fake `ssh` (GitHub always exits 1) + a passing `ssh-add`."""
    b = tmp_path / "bin"
    b.mkdir()
    (b / "ssh").write_text(f"#!/bin/sh\ncat <<'EOF'\n{ssh_output}\nEOF\nexit {ssh_rc}\n")
    (b / "ssh-add").write_text("#!/bin/sh\nexit 0\n")   # W1 half: silent success
    for f in ("ssh", "ssh-add"):
        (b / f).chmod(0o755)
    return b


def _env(bindir: Path, **extra) -> dict:
    """Isolate git config.

    The operator's real ~/.gitconfig carries the
    `url.https://github.com/.insteadOf git@github.com:` rewrite this work
    applied, which would silently turn every SSH fixture into an HTTPS one
    and make these tests pass for the wrong reason.
    """
    return dict(os.environ,
                PATH=f"{bindir}:{os.environ['PATH']}",
                GIT_CONFIG_GLOBAL=os.devnull,
                GIT_CONFIG_SYSTEM=os.devnull,
                **extra)


def _run(repo: Path, bindir: Path, **extra) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", str(SCRIPT)], cwd=repo, env=_env(bindir, **extra),
                          capture_output=True, text=True)


def test_fires_when_ssh_transport_and_auth_fails(tmp_path):
    repo = _repo(tmp_path, "git@github.com:Regevba/FitTracker2.git")
    out = _run(repo, _stubs(tmp_path, "git@github.com: Permission denied (publickey)."))
    assert "W45 preflight" in out.stderr
    assert "Permission denied" in out.stderr


def test_never_blocks_even_when_it_fires(tmp_path):
    """Advisory only — a preflight that blocks a session is worse than the bug."""
    repo = _repo(tmp_path, "git@github.com:Regevba/FitTracker2.git")
    out = _run(repo, _stubs(tmp_path, "git@github.com: Permission denied (publickey)."))
    assert out.returncode == 0


def test_silent_when_ssh_auth_succeeds(tmp_path):
    repo = _repo(tmp_path, "git@github.com:Regevba/FitTracker2.git")
    out = _run(repo, _stubs(
        tmp_path, "Hi Regevba! You've successfully authenticated, but GitHub does not provide shell access."))
    assert "W45" not in out.stderr and out.returncode == 0


def test_silent_when_transport_is_https(tmp_path):
    """The recommended fix makes SSH auth irrelevant — no noise about it."""
    repo = _repo(tmp_path, "https://github.com/Regevba/FitTracker2.git")
    out = _run(repo, _stubs(tmp_path, "git@github.com: Permission denied (publickey)."))
    assert "W45" not in out.stderr and out.returncode == 0


def test_silent_for_non_github_remote(tmp_path):
    repo = _repo(tmp_path, "git@gitlab.com:someone/thing.git")
    out = _run(repo, _stubs(tmp_path, "Permission denied (publickey)."))
    assert "W45" not in out.stderr and out.returncode == 0


def test_respects_the_probe_kill_switch(tmp_path):
    repo = _repo(tmp_path, "git@github.com:Regevba/FitTracker2.git")
    out = _run(repo, _stubs(tmp_path, "Permission denied (publickey)."),
               CLAUDE_W45_DISABLE_AUTH_PROBE="1")
    assert "W45" not in out.stderr and out.returncode == 0


def test_insteadof_rewrite_counts_as_https(tmp_path):
    """`url.https://github.com/.insteadOf git@github.com:` — the applied fix.

    The remote string is still SSH-shaped; only `git ls-remote --get-url`
    reveals the rewrite. Probing the raw remote would produce a false alarm.
    """
    repo = _repo(tmp_path, "git@github.com:Regevba/FitTracker2.git")
    subprocess.run(["git", "config", "url.https://github.com/.insteadOf",
                    "git@github.com:"], cwd=repo, check=True,
                   env=dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                            GIT_CONFIG_SYSTEM=os.devnull))
    out = _run(repo, _stubs(tmp_path, "git@github.com: Permission denied (publickey)."))
    assert "W45" not in out.stderr and out.returncode == 0
