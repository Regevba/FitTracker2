"""Tests for the REPO_ROOT_OVERRIDE env var support.

Required by the F16 try-repo harness (see
`.claude/features/f16-try-repo-harness/prd.md` §3.5 Q6) — the harness needs
to redirect both gate dispatchers' `REPO_ROOT` to a throwaway test repo so
that `collect_staged_state_files()` looks up files under the throwaway path
rather than the canonical FT2 root.

These tests verify the env-var-override semantics for both
`scripts/check-state-schema.py` and `scripts/check-case-study-preflight.py`.
"""

from __future__ import annotations

import importlib.util
import os
import sys
from pathlib import Path

import pytest


REPO_ROOT_CANONICAL = Path(__file__).resolve().parents[2]
CHECK_STATE = REPO_ROOT_CANONICAL / "scripts" / "check-state-schema.py"
CHECK_CASE_STUDY = REPO_ROOT_CANONICAL / "scripts" / "check-case-study-preflight.py"


def _load_module_with_env(name: str, file: Path, env: dict[str, str]):
    """Load a .py file by absolute path with a temporary env scope.

    Reloads the module on each call to ensure env is read fresh — module-
    level constants are computed at import time and cached otherwise.
    """
    # Stash + apply env
    saved = {k: os.environ.get(k) for k in env}
    try:
        for k, v in env.items():
            os.environ[k] = v
        # Force a fresh import each time
        if name in sys.modules:
            del sys.modules[name]
        spec = importlib.util.spec_from_file_location(name, file)
        assert spec is not None and spec.loader is not None
        mod = importlib.util.module_from_spec(spec)
        sys.modules[name] = mod
        spec.loader.exec_module(mod)
        return mod
    finally:
        # Restore
        for k, prev in saved.items():
            if prev is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = prev


@pytest.mark.parametrize(
    "module_name,module_path",
    [
        ("css_under_test", CHECK_STATE),
        ("ccsp_under_test", CHECK_CASE_STUDY),
    ],
)
def test_repo_root_falls_back_to_canonical_when_override_unset(
    module_name: str, module_path: Path
):
    """Without the env var, REPO_ROOT resolves to canonical FT2.

    This is the production-path test — no regression to the existing
    behavior. Operators and CI never set REPO_ROOT_OVERRIDE.
    """
    mod = _load_module_with_env(module_name, module_path, env={})
    assert hasattr(mod, "REPO_ROOT")
    assert Path(mod.REPO_ROOT) == REPO_ROOT_CANONICAL, (
        f"REPO_ROOT (no override) should resolve to canonical FT2 root.\n"
        f"  Expected: {REPO_ROOT_CANONICAL}\n"
        f"  Got:      {Path(mod.REPO_ROOT)}"
    )


@pytest.mark.parametrize(
    "module_name,module_path",
    [
        ("css_override", CHECK_STATE),
        ("ccsp_override", CHECK_CASE_STUDY),
    ],
)
def test_repo_root_redirects_when_override_set(
    module_name: str, module_path: Path, tmp_path: Path
):
    """With REPO_ROOT_OVERRIDE set, REPO_ROOT resolves to the override path."""
    mod = _load_module_with_env(
        module_name, module_path, env={"REPO_ROOT_OVERRIDE": str(tmp_path)}
    )
    assert Path(mod.REPO_ROOT) == tmp_path.resolve(), (
        f"REPO_ROOT_OVERRIDE was not honored.\n"
        f"  Expected: {tmp_path.resolve()}\n"
        f"  Got:      {Path(mod.REPO_ROOT)}"
    )


def test_features_dir_follows_repo_root_override(tmp_path: Path):
    """FEATURES_DIR (in check-state-schema.py) is REPO_ROOT/.claude/features.

    When the override is set, FEATURES_DIR must also redirect — otherwise
    the path-resolution flow in `collect_staged_state_files` still falls
    back to the canonical FT2 features dir.
    """
    mod = _load_module_with_env(
        "css_features", CHECK_STATE, env={"REPO_ROOT_OVERRIDE": str(tmp_path)}
    )
    expected = tmp_path.resolve() / ".claude" / "features"
    assert Path(mod.FEATURES_DIR) == expected


def test_case_studies_dir_follows_repo_root_override(tmp_path: Path):
    """CASE_STUDIES_DIR (in check-case-study-preflight.py) follows override."""
    mod = _load_module_with_env(
        "ccsp_dir", CHECK_CASE_STUDY, env={"REPO_ROOT_OVERRIDE": str(tmp_path)}
    )
    expected = tmp_path.resolve() / "docs" / "case-studies"
    assert Path(mod.CASE_STUDIES_DIR) == expected
