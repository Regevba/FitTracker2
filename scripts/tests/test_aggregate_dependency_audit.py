"""Regression tests for scripts/aggregate-dependency-audit.py.

Primary guard: the markdown + JSON outputs MUST end with a trailing newline.
The consuming workflow (.github/workflows/dependency-audit-weekly.yml) pipes
audit-summary.md into $GITHUB_ENV via a heredoc:

    {
      echo "DIGEST<<DIGEST_EOF"
      cat /tmp/audit-summary.md
      echo "DIGEST_EOF"
    } >> "$GITHUB_ENV"

If the file lacks a trailing newline, `DIGEST_EOF` glues onto the last
markdown line and GitHub's env-file parser fails with
"Invalid value. Matching delimiter not found 'DIGEST_EOF'" — failing the
step on EVERY run regardless of vulnerability count (observed 2026-06-01,
run 26750972795). See observed-patterns catalog.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "aggregate-dependency-audit.py"


def _run(tmp_path: Path, *extra: str) -> tuple[Path, Path]:
    md = tmp_path / "audit-summary.md"
    js = tmp_path / "audit-summary.json"
    missing = tmp_path / "does-not-exist.json"  # parse_npm_audit returns zeros
    cmd = [
        sys.executable, str(SCRIPT),
        "--npm-audit", f"{missing}:root",
        "--output-md", str(md),
        "--output-json", str(js),
        *extra,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return md, js


def test_markdown_ends_with_newline(tmp_path):
    md, _ = _run(tmp_path)
    assert md.read_text().endswith("\n")


def test_json_ends_with_newline(tmp_path):
    _, js = _run(tmp_path)
    assert js.read_text().endswith("\n")


def test_heredoc_delimiter_lands_on_own_line(tmp_path):
    """Simulate the workflow's cat-then-echo heredoc; the closing delimiter
    must be on its own line."""
    md, _ = _run(tmp_path)
    composed = md.read_text() + "DIGEST_EOF\n"  # `cat md` + `echo DIGEST_EOF`
    assert composed.splitlines()[-1] == "DIGEST_EOF"


def test_totals_keys_present_for_github_output(tmp_path):
    """The workflow's inline python reads totals[high|critical|total]."""
    _, js = _run(tmp_path)
    totals = json.loads(js.read_text())["totals"]
    for key in ("high", "critical", "total"):
        assert key in totals
        assert isinstance(totals[key], int)
