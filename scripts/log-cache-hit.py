#!/usr/bin/env python3
"""Auto-discovering cache-hit logger.

Thin wrapper around scripts/append-feature-log.py that adds active-feature
auto-discovery, so cache read sites can invoke this with just --key and --layer
(no --feature argument required).

Dual-write strategy
-------------------
1. state.json.cache_hits[]  — written directly in this script so v7.7 M1 hook
   (T3) can read it.  This write happens even if the events-log step fails.
2. .claude/logs/<feature>.log.json — delegated to append-feature-log.py for
   Tier 2.2 contemporaneous logging. Failure here is swallowed (fail-soft).

Active-feature selection
------------------------
Scans .claude/features/*/state.json by file mtime (descending). Skips any
feature whose state.json contains a non-None ``paused`` key (explicitly paused
features are not "active").  Returns the first non-paused state.json by mtime.

Fail-soft
---------
Any error exits 0 and prints a warning to stderr.  Logging must never break
cache reads — the call site is in the hot path.

Environment overrides (used by tests)
--------------------------------------
LOG_CACHE_HIT_REPO_ROOT      Override repo root (default: parent of this file)
LOG_CACHE_HIT_APPEND_SCRIPT  Override path to append-feature-log.py

Usage:
    python3 scripts/log-cache-hit.py --key <key> --layer <L1|L2|L3>
                                     [--hit-type <adapted|exact|miss>]
                                     [--skill <skill-name>]
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Repo-root resolution (overridable by tests via env var)
# ---------------------------------------------------------------------------

def _repo_root() -> Path:
    override = os.environ.get("LOG_CACHE_HIT_REPO_ROOT")
    if override:
        return Path(override)
    return Path(__file__).resolve().parents[1]


def _append_script() -> Path:
    override = os.environ.get("LOG_CACHE_HIT_APPEND_SCRIPT")
    if override:
        return Path(override)
    # Always resolve relative to THIS script's location — append-feature-log.py
    # lives next to log-cache-hit.py in the same scripts/ directory.
    # Do NOT use _repo_root() here, because tests override _repo_root() to a
    # temp path that has no scripts/ subtree.
    return Path(__file__).resolve().parent / "append-feature-log.py"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _is_paused(state: dict) -> bool:
    """Return True if the feature is explicitly paused (paused key present and truthy)."""
    return bool(state.get("paused"))


def find_active_feature() -> Path | None:
    """Return the state.json Path of the most-recently-modified non-paused feature.

    Returns None if no eligible feature is found.
    """
    features_dir = _repo_root() / ".claude" / "features"
    if not features_dir.exists():
        return None

    candidates: list[tuple[float, Path]] = []
    for state_path in features_dir.glob("*/state.json"):
        try:
            state = json.loads(state_path.read_text())
        except Exception:  # noqa: BLE001
            continue
        if _is_paused(state):
            continue
        mtime = state_path.stat().st_mtime
        candidates.append((mtime, state_path))

    if not candidates:
        return None

    # Most-recently-modified first
    candidates.sort(key=lambda t: t[0], reverse=True)
    return candidates[0][1]


def _append_to_state(state_path: Path, entry: dict) -> None:
    """Append entry to state.json.cache_hits[]. Mutates the file in place."""
    data = json.loads(state_path.read_text())
    existing = data.get("cache_hits")
    if not isinstance(existing, list):
        data["cache_hits"] = []
    data["cache_hits"].append(entry)
    data["updated"] = _utc_now()
    state_path.write_text(json.dumps(data, indent=2) + "\n")


def _call_append_feature_log(feature: str, key: str, layer: str,
                              hit_type: str, skill: str | None) -> bool:
    """Append a contemporaneous event to the events log via append-feature-log.py.

    This call is ONLY for the events log (Tier 2.2). The state.json.cache_hits[]
    write is handled directly by the wrapper so we own the path and avoid
    append-feature-log.py's hardcoded FEATURES_DIR resolution writing to a
    different location in test environments.

    We therefore do NOT pass --cache-hit / --cache-key / --cache-hit-type flags
    here — those trigger append-feature-log.py's own state.json write, which
    would create a duplicate entry. The events log entry is recorded as an
    ``event_type=cache_hit_logged`` plain event containing the hit metadata in
    the ``metrics`` field.

    Returns True if the subprocess exited 0, False otherwise.
    Never raises — fail-soft contract.

    Passes --output explicitly so the log lands in the correct repo root
    (important for tests that override LOG_CACHE_HIT_REPO_ROOT).
    """
    script = _append_script()
    log_dir = _repo_root() / ".claude" / "logs"
    log_path = log_dir / f"{feature}.log.json"
    skill_part = skill or ""
    cmd = [
        sys.executable, str(script),
        "--feature", feature,
        "--event-type", "cache_hit_logged",
        "--summary", f"{key} ({layer})",
        "--metric", f"layer={layer}",
        "--metric", f"key={key}",
        "--metric", f"hit_type={hit_type}",
        "--output", str(log_path),
    ]
    if skill_part:
        cmd += ["--metric", f"skill={skill_part}"]

    try:
        result = subprocess.run(cmd, check=False, capture_output=True)
        return result.returncode == 0
    except Exception:  # noqa: BLE001
        return False  # fail-soft: subprocess missing or broken


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", required=True, help="Cache entry key (e.g. skill:pm-workflow)")
    parser.add_argument("--layer", required=True, choices=["L1", "L2", "L3"],
                        help="Cache layer where the hit occurred")
    parser.add_argument("--hit-type", dest="hit_type", default="exact",
                        choices=["exact", "adapted", "miss"],
                        help="exact / adapted / miss (default: exact)")
    parser.add_argument("--skill", default=None,
                        help="Skill that made the lookup (optional)")

    try:
        args = parser.parse_args()
    except SystemExit:
        # argparse error — fail soft
        return 0

    try:
        state_path = find_active_feature()
        if state_path is None:
            # No active feature — nothing to record, exit cleanly.
            return 0

        feature = state_path.parent.name
        ts = _utc_now()

        # --- Write 1: state.json.cache_hits[] ---
        # Written directly by this wrapper so we own the path resolution and
        # avoid a double-write (append-feature-log.py's state.json write uses
        # a hardcoded FEATURES_DIR that would add a second entry).
        entry = {
            "ts": ts,
            "key": args.key,
            "layer": args.layer,
            "type": args.hit_type,
        }
        if args.skill:
            entry["skill"] = args.skill
        try:
            _append_to_state(state_path, entry)
        except Exception:  # noqa: BLE001
            pass  # fail-soft

        # --- Write 2: events log via append-feature-log.py (Tier 2.2) ---
        # Called WITHOUT --cache-hit flags to avoid a second state.json write
        # inside append-feature-log.py. The hit metadata is passed as metrics.
        _call_append_feature_log(
            feature=feature,
            key=args.key,
            layer=args.layer,
            hit_type=args.hit_type,
            skill=args.skill,
        )

    except Exception:  # noqa: BLE001
        # Catch-all: logging must never break the caller.
        pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
