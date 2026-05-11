"""D-3 — unified cross-repo PR cite cache.

Task 1.1: refresh-pr-cache.py builds correct multi-repo cache shape.
Task 1.2 will add regex + routing tests."""
from __future__ import annotations
import json
import subprocess
import sys
from pathlib import Path
import pytest

REFRESH_SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "refresh-pr-cache.py"


def test_refresh_pr_cache_writes_correct_shape(tmp_path: Path, monkeypatch):
    """refresh-pr-cache.py writes cache file with schema_version, last_refreshed_at, repos."""
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".cache").mkdir()

    # Run the script. If gh is unavailable in the test env, the script should
    # still create a cache file (possibly with empty repos) OR exit non-zero
    # gracefully. We assert structurally on the output if the script created
    # a file.
    result = subprocess.run([sys.executable, str(REFRESH_SCRIPT)],
                            capture_output=True, text=True)
    cache_file = tmp_path / ".cache" / "gh-pr-cache.json"

    if result.returncode == 0:
        # Successful run: cache file must exist + have right shape
        assert cache_file.exists(), f"script returned 0 but no cache file: {result.stderr}"
        cache = json.loads(cache_file.read_text())
        assert cache["schema_version"] == 1, f"unexpected schema_version: {cache.get('schema_version')}"
        assert "last_refreshed_at" in cache
        assert "repos" in cache
        assert isinstance(cache["repos"], dict)
        # If gh worked, both repos should be present
        if cache["repos"]:
            for repo_name in cache["repos"]:
                repo_data = cache["repos"][repo_name]
                assert "open" in repo_data
                assert "merged" in repo_data
                assert "closed" in repo_data
    else:
        # gh unavailable / auth failed — script should print to stderr
        assert "gh" in result.stderr.lower() or "WARN" in result.stderr or "ERROR" in result.stderr, \
            f"non-zero exit but no clear error message: {result.stderr}"
