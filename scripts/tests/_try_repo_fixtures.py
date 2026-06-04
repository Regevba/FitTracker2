"""F16 try-repo harness — fixture helpers.

This module is the producer side of the hybrid fixture format locked in the
F16 PRD (Q2). It exports two helpers:

- `BASELINE_STATE_PATH` — path to the canonical baseline state.json
- `make_state_json(overrides, dest)` — deep-merge overrides onto the baseline
  and write the result to `dest`

Per-gate fixtures live under `tests/fixtures/<gate-id>/{positive,negative}/`
and contain ONLY the overrides (as `state.json.yaml` partial-record files).
The harness reads the YAML, calls `make_state_json(overrides, throwaway_path)`,
and stages the resulting state.json in the throwaway git repo.

This is a TEST-ONLY module. Importing it from production code is a smell.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any, Mapping


# Path to the canonical baseline. Resolves relative to repo root so that
# both `pytest` invocations from repo root and from `scripts/tests/` work.
REPO_ROOT = Path(__file__).resolve().parents[2]
BASELINE_STATE_PATH = REPO_ROOT / "tests" / "fixtures" / "_baseline" / "state.json"


def _deep_merge(base: dict, overrides: Mapping[str, Any]) -> dict:
    """Recursively merge `overrides` into a copy of `base`.

    Semantics:
    - For each key in overrides: if both `base[key]` and `overrides[key]` are
      dicts, recurse. Otherwise replace.
    - Lists are REPLACED wholesale, not concatenated. (If a fixture wants to
      append to a list, it must spell out the full list. This keeps fixture
      reads unambiguous.)
    - Setting a key to `None` in overrides deletes the key from base (sentinel
      for "remove this required field").
    """
    result = copy.deepcopy(base)
    for key, value in overrides.items():
        if value is None:
            result.pop(key, None)
            continue
        if (
            key in result
            and isinstance(result[key], dict)
            and isinstance(value, Mapping)
        ):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def load_baseline() -> dict:
    """Read the canonical baseline state.json. Cached implicitly by callers."""
    with BASELINE_STATE_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def make_state_json(overrides: Mapping[str, Any], dest: Path) -> Path:
    """Write a merged state.json to `dest`.

    Args:
        overrides: dict of fields to merge onto the baseline. Nested dicts are
            deep-merged. A value of `None` deletes the key (for testing
            REQUIRED-field omission gates).
        dest: file path to write the merged JSON to. Parent directories are
            created if missing.

    Returns:
        The `dest` path (for caller chaining).

    Raises:
        OSError: if `dest`'s parent cannot be created or `dest` cannot be
            written.
    """
    baseline = load_baseline()
    merged = _deep_merge(baseline, overrides)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, sort_keys=False)
        f.write("\n")
    return dest


__all__ = ["BASELINE_STATE_PATH", "load_baseline", "make_state_json"]
