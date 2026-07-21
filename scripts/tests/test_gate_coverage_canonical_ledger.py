"""Regression test for the gate-coverage worktree telemetry-loss fix.

`gate-coverage.jsonl` is gitignored and was resolved ``__file__``-relative, so a
gate firing inside a linked worktree wrote to that worktree's local copy and was
discarded on `git worktree remove` — the committed F17 index (read from main)
undercounted every gate that fired during worktree-isolated work. Found
2026-07-21: 44 W9 concurrency-check sessions but only 37 rows on main, plus a
real `w9.concurrency` `concurrency_offer` that survived by luck.

`canonical_ledger_path()` sends the telemetry SINK to the git common (main)
worktree so every worktree accumulates into one ledger. These tests pin that
behavior AND prove the F16 try-repo env overrides still isolate.
"""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load():
    src = REPO_ROOT / "scripts" / "gate_coverage.py"
    spec = importlib.util.spec_from_file_location("gate_coverage", src)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["gate_coverage"] = mod
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture
def gc():
    return _load()


def _git(args, cwd):
    subprocess.run(["git", *args], cwd=str(cwd), check=True,
                   capture_output=True, text=True)


def test_env_ledger_override_wins(gc, monkeypatch, tmp_path):
    monkeypatch.setenv("GATE_COVERAGE_LEDGER", "/tmp/explicit.jsonl")
    assert gc.canonical_ledger_path(tmp_path) == Path("/tmp/explicit.jsonl")


def test_repo_root_override_isolates(gc, monkeypatch, tmp_path):
    # F16 try-repo isolation: REPO_ROOT_OVERRIDE → <root>/.claude/logs/...
    monkeypatch.delenv("GATE_COVERAGE_LEDGER", raising=False)
    monkeypatch.setenv("REPO_ROOT_OVERRIDE", str(tmp_path / "tryrepo"))
    got = gc.canonical_ledger_path(Path("/somewhere/else"))
    assert got == tmp_path / "tryrepo" / ".claude" / "logs" / "gate-coverage.jsonl"


def test_linked_worktree_resolves_to_main_ledger(gc, monkeypatch, tmp_path):
    """THE regression: a firing in a linked worktree must land in MAIN's ledger."""
    monkeypatch.delenv("GATE_COVERAGE_LEDGER", raising=False)
    monkeypatch.delenv("REPO_ROOT_OVERRIDE", raising=False)

    main = tmp_path / "main"
    main.mkdir()
    _git(["init", "-q"], main)
    _git(["config", "user.email", "t@t.io"], main)
    _git(["config", "user.name", "t"], main)
    (main / "f.txt").write_text("x\n")
    _git(["add", "."], main)
    _git(["commit", "-qm", "init"], main)

    wt = tmp_path / "linked-wt"
    _git(["worktree", "add", "-q", str(wt)], main)

    main_ledger = main.resolve() / ".claude" / "logs" / "gate-coverage.jsonl"
    # From the MAIN checkout → main's ledger (unchanged behavior).
    assert gc.canonical_ledger_path(main).resolve() == main_ledger
    # From the LINKED worktree → STILL main's ledger (the fix). Not wt-local.
    assert gc.canonical_ledger_path(wt).resolve() == main_ledger
    assert "linked-wt" not in str(gc.canonical_ledger_path(wt))


def test_non_git_dir_falls_back_to_repo_root(gc, monkeypatch, tmp_path):
    monkeypatch.delenv("GATE_COVERAGE_LEDGER", raising=False)
    monkeypatch.delenv("REPO_ROOT_OVERRIDE", raising=False)
    plain = tmp_path / "plain"
    plain.mkdir()
    got = gc.canonical_ledger_path(plain)
    assert got == plain / ".claude" / "logs" / "gate-coverage.jsonl"
