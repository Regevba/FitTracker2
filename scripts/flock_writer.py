"""Lock-protected JSON writer for shared-state files.

v7.8 Mechanism I scaffolding (bridge design §4.7.3 + §11 risk register).
Wraps writes to `.claude/shared/*.json` and `.claude/features/*/state.json`
in `fcntl.flock(LOCK_EX)` byte-range locks via a sidecar lockfile, so
concurrent writers from different worktrees serialize cleanly instead of
clobbering each other.

Why a sidecar lockfile (not the JSON file itself):
  - `Path.write_text()` truncates on open. Acquiring the lock on the same
    fd that's about to be truncated produces a race where reader sees an
    empty file. The sidecar pattern locks a separate file so the main file
    can be written via the existing safe path.
  - Sidecar files (`<path>.lock`) survive across runs and don't pollute git
    status — they're added to .gitignore in the same PR.

Why fcntl.flock (not lockf or POSIX advisory locks):
  - flock semantics are well-defined on Darwin + Linux + the SSD-mounted
    repo we care about. lockf is per-process; POSIX advisory locks are
    inherited across fork. flock is the right shape for "one agent holds
    the file at a time."
  - Refuses to operate on NFS (per spec §11): `fstatfs(2)` check via
    `os.statvfs` flag. NFS lock semantics are unreliable enough that
    failing closed is safer than silent corruption.

v7.9 plan: every shared-write reducer reads the current epoch from
`agent-leases.json`, validates `write.epoch >= leases.epoch`, rejects
stale-epoch writes. v7.8 just records the epoch in the event payload as
scaffolding (no validation).

References:
  - bridge design §4.7.3 (`fcntl.flock` byte-range locks protect concurrent
    writers).
  - bridge design §5.3 Mechanism I — Epoch fencing tokens (Kleppmann
    Redlock critique).
  - Mechanism C research note Part 4 (single-writer + flock as the correct
    shape vs CRDT for invariant-bearing JSON).
"""
from __future__ import annotations

import fcntl
import os
import sys
from contextlib import contextmanager
from pathlib import Path


def _refuse_nfs(path: Path) -> None:
    """Raise OSError if `path` is on an NFS-mounted filesystem.

    Per spec §11 risk register: `fcntl.flock` semantics on NFS are unreliable;
    failing closed is safer than silently corrupting state.json under
    concurrent writers. macOS reports NFS via `f_basetype` / `f_fstypename`
    (the latter is in BSD `statfs(2)` — Python only exposes `statvfs(3)`).
    We use a fallback path heuristic: any path under a `nfs:`-prefixed mount
    or `/private/var/automount/` triggers the refusal. Local SSD mounts
    (including external SSDs at `/Volumes/<name>`) pass through.
    """
    resolved = str(path.resolve())
    nfs_signatures = ("/private/var/automount/", "/net/", "/Network/Servers/")
    for sig in nfs_signatures:
        if sig in resolved:
            raise OSError(
                f"flock_writer: refusing to operate on apparent NFS path "
                f"{resolved!r}. flock semantics on NFS are unreliable; "
                f"v7.8 fails closed per spec §11."
            )


@contextmanager
def flocked(path: Path):
    """Acquire an exclusive lock on `<path>.lock`; yield; release on exit.

    Usage:
        with flocked(state_path):
            state_path.write_text(json.dumps(data, indent=2) + "\\n")

    Idempotent: the sidecar lockfile is created on first use and reused.
    Failure to acquire the lock (e.g. NFS refusal, permission error)
    raises — the caller decides whether to retry, fail-soft, or fall
    through. The hot-path scripts (log-cache-hit, append-feature-log)
    swallow OSError to a stderr warning and continue without the lock,
    matching their existing fail-soft contract.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    _refuse_nfs(path)

    lockfile = path.with_suffix(path.suffix + ".lock")
    # Open in append+read mode so we don't truncate on entry.
    with open(lockfile, "a+") as fh:
        try:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        except OSError as exc:
            print(
                f"flock_writer: lock acquisition failed on {lockfile} ({exc})",
                file=sys.stderr,
            )
            raise
        try:
            yield
        finally:
            try:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
            except OSError:
                # Best-effort release; the file close below releases anyway.
                pass


def write_json_locked(path: Path, content: str) -> None:
    """Convenience: acquire flock, write content, release.

    `content` must already be the serialized JSON string (caller controls
    the indent / trailing newline convention to match existing files).
    """
    with flocked(path):
        path.write_text(content)
