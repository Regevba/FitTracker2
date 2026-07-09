"""Tests for #397 — daily-integrity-checkpoint file-lock race-condition fix.

The original bug: scripts/daily-integrity-checkpoint.py:715-720 had a check-then-act
race condition. Four concurrent fires (cron + manual + SessionStart hook) all
passed the load_last_ledger_row() == today check before any of them wrote, then
all 4 appended duplicate rows for 2026-05-18 (visible in PR #389).

Fix: wrap the read-check-pipeline-append sequence in `flocked(LEDGER_JSONL)` so
concurrent fires serialize at the flock acquire. The second-to-acquire reads
the ledger again, sees today's row already present (written by the first), and
exits cleanly.

These tests verify the structural fix is in place + concurrent invocations
serialize correctly.
"""
from __future__ import annotations

import ast
import json
import os
import subprocess
import sys
import threading
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = REPO_ROOT / "scripts" / "daily-integrity-checkpoint.py"
SCRIPTS_DIR = REPO_ROOT / "scripts"

sys.path.insert(0, str(SCRIPTS_DIR))
from flock_writer import flocked  # noqa: E402


def test_script_imports_flocked():
    """Regression guard: removing the `from flock_writer import flocked` line
    would silently re-introduce the #397 race. Verify the import exists."""
    src = SCRIPT_PATH.read_text()
    assert "from flock_writer import flocked" in src, (
        "daily-integrity-checkpoint.py must import flocked from flock_writer "
        "to guard the read-check-pipeline-append sequence against #397's race."
    )


def test_main_wraps_pipeline_in_flocked():
    """Regression guard: main() body must contain `with flocked(LEDGER_JSONL):`
    so the pipeline body runs under the exclusive lock. Source-level check —
    structural rather than behavioral — to keep this test fast (<1s) while
    catching the obvious regression of removing the with-block."""
    src = SCRIPT_PATH.read_text()
    tree = ast.parse(src)
    main_func = next(
        (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "main"),
        None,
    )
    assert main_func is not None, "main() function must exist in script"

    has_flocked_with = False
    for node in ast.walk(main_func):
        if isinstance(node, ast.With):
            for item in node.items:
                ctx = item.context_expr
                if isinstance(ctx, ast.Call) and isinstance(ctx.func, ast.Name):
                    if ctx.func.id == "flocked":
                        has_flocked_with = True
                        break
    assert has_flocked_with, (
        "main() body must contain `with flocked(...)` block to guard the "
        "pipeline against #397's check-then-act race condition."
    )


def test_run_pipeline_is_extracted_function():
    """The fix extracts the read-check-pipeline-append into a `_run_pipeline`
    function called from inside the flocked block. Verify the function exists
    + has the expected signature."""
    src = SCRIPT_PATH.read_text()
    tree = ast.parse(src)
    fn = next(
        (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "_run_pipeline"),
        None,
    )
    assert fn is not None, "_run_pipeline function must exist as the locked body"
    arg_names = [a.arg for a in fn.args.args]
    assert "today" in arg_names, "_run_pipeline must accept the date string"
    assert "args" in arg_names, "_run_pipeline must accept parsed argparse Namespace"


def test_idempotent_run_does_not_append_when_today_row_exists():
    """Behavioral smoke test: when today's row is already present, invoking the
    script with --idempotent --quiet exits cleanly without appending a duplicate.

    Subprocess-based to exercise the real flock acquisition path. Hardened to be
    deterministic on a fresh day (2026-07-09 flake): if today's ledger row does
    not yet exist, a minimal one is seeded first so the --idempotent early-exit
    path is exercised regardless of whether a prior checkpoint ran today — which
    also avoids a real snapshot side effect (the early-exit fires before any
    snapshot). The ledger is restored to its exact pre-test contents afterward,
    so the seeded row never leaks into the repo.
    """
    today = subprocess.run(
        [sys.executable, "-c", "import datetime; print(datetime.date.today().isoformat())"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    ledger = REPO_ROOT / ".claude" / "shared" / "integrity-checkpoint-ledger.jsonl"
    if not ledger.exists():
        pytest.skip("ledger not yet initialized in this checkout")

    original = ledger.read_text()
    try:
        # Guarantee the precondition: a today row must exist so --idempotent takes
        # its early-exit. Seed a minimal one (as the last line) if absent.
        if original.count(f'"date":"{today}"') == 0:
            with ledger.open("a") as f:
                # Match the script's compact serialization (append_ledger_row uses
                # separators=(",", ":")) so the `"date":"…"` count pattern matches.
                f.write(json.dumps(
                    {"date": today, "metrics": {}, "_seeded_by_test": True},
                    separators=(",", ":"),
                ) + "\n")

        before = ledger.read_text().count(f'"date":"{today}"')
        assert before >= 1, "precondition seed failed"

        # Run the script in idempotent mode; should exit 0 without appending.
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--idempotent", "--quiet"],
            capture_output=True, text=True, timeout=30, cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"idempotent run exit={result.returncode}; stderr={result.stderr[:200]}"
        )

        after = ledger.read_text().count(f'"date":"{today}"')
        assert after == before, (
            f"idempotent run appended a duplicate row for {today}: "
            f"before={before}, after={after}, stderr={result.stderr[:200]}"
        )
    finally:
        # Restore exact pre-test contents (drops the seeded row + anything an
        # unexpected non-early-exit appended).
        ledger.write_text(original)


def test_concurrent_flocked_acquires_serialize(tmp_path):
    """Behavioral test: two threads both call flocked() on the same path; the
    second blocks until the first releases. Mirrors the protection #397 needs:
    the read-check-pipeline-append sequence is atomic across concurrent fires.
    """
    target = tmp_path / "ledger.jsonl"
    target.write_text("")  # exist so flocked.parent.mkdir is a no-op
    events: list[tuple[str, float]] = []
    import time

    def worker(name: str, hold_seconds: float):
        with flocked(target):
            events.append((f"{name}-acquired", time.monotonic()))
            time.sleep(hold_seconds)
            events.append((f"{name}-releasing", time.monotonic()))

    t1 = threading.Thread(target=worker, args=("A", 0.2))
    t2 = threading.Thread(target=worker, args=("B", 0.05))
    t1.start()
    time.sleep(0.02)  # ensure A acquires first
    t2.start()
    t1.join(timeout=5)
    t2.join(timeout=5)

    assert not t1.is_alive() and not t2.is_alive(), "threads must complete"

    # A must release BEFORE B acquires (proving serialization)
    a_release_time = next(t for (n, t) in events if n == "A-releasing")
    b_acquire_time = next(t for (n, t) in events if n == "B-acquired")
    assert b_acquire_time >= a_release_time, (
        f"B acquired at {b_acquire_time:.3f} BEFORE A released at "
        f"{a_release_time:.3f} — flock not serializing concurrent acquires."
    )
