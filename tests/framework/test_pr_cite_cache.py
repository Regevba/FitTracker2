"""D-3 — unified cross-repo PR cite cache.

Task 1.1: refresh-pr-cache.py builds correct multi-repo cache shape.
Task 1.2: regex + routing tests for check-case-study-preflight.py."""
from __future__ import annotations
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
import pytest

PREFLIGHT = Path(__file__).resolve().parents[2] / "scripts" / "check-case-study-preflight.py"


def load_preflight():
    spec = importlib.util.spec_from_file_location("preflight", PREFLIGHT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

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


# ---------------------------------------------------------------------------
# Task 1.2 — regex + routing tests
# ---------------------------------------------------------------------------

def test_pr_citation_pat_matches_three_forms():
    """Regex captures: PR #N (FT2 default), repo#N (cross-repo short), URL form."""
    pf = load_preflight()
    pat = pf._PR_CITATION_PAT

    # FT2 default form: "PR #290"
    m = pat.search("see PR #290")
    assert m and m.group(1) == "290", f"FT2 default form failed, match={m}"

    # Cross-repo short form: "[fitme-story#42]"
    m = pat.search("backed by [fitme-story#42]")
    assert m and m.group(2) == "fitme-story" and m.group(3) == "42", \
        f"cross-repo short form failed, match={m}"

    # URL form: "github.com/Regevba/fitme-story/pull/42"
    m = pat.search("github.com/Regevba/fitme-story/pull/42")
    assert m and m.group(4) == "Regevba" and m.group(5) == "fitme-story" and m.group(6) == "42", \
        f"URL form failed, match={m}"


def test_repo_map_includes_both_repos():
    pf = load_preflight()
    assert "fitme-story" in pf.REPO_MAP
    assert "FitTracker2" in pf.REPO_MAP


def test_resolve_pr_cite_finds_existing_pr():
    """When cache contains the PR number, resolve_pr_cite returns None (no Finding)."""
    pf = load_preflight()
    cache = {
        "schema_version": 1,
        "last_refreshed_at": "2026-05-12T00:00:00Z",
        "repos": {
            "Regevba/FitTracker2": {
                "open": [{"number": 290, "title": "x", "state": "OPEN"}],
                "merged": [], "closed": [],
            },
            "Regevba/fitme-story": {
                "open": [{"number": 42, "title": "y", "state": "OPEN"}],
                "merged": [], "closed": [],
            },
        },
    }

    m = pf._PR_CITATION_PAT.search("PR #290")
    assert pf.resolve_pr_cite(m, cache) is None, "FT2 PR in cache should return None"

    m = pf._PR_CITATION_PAT.search("[fitme-story#42]")
    assert pf.resolve_pr_cite(m, cache) is None, "fitme-story PR in cache should return None"


def test_resolve_pr_cite_unknown_repo_short_name_fails():
    pf = load_preflight()
    cache = {"schema_version": 1, "repos": {}}
    m = pf._PR_CITATION_PAT.search("[unknown-repo#1]")
    assert m is not None, "regex should match unknown-repo#1"
    finding = pf.resolve_pr_cite(m, cache)
    assert finding is not None, "unknown repo short name should produce a finding"
    code_str = str(finding)
    assert "BROKEN_PR_CITATION" in code_str or "unknown" in code_str.lower(), \
        f"finding should mention BROKEN_PR_CITATION or 'unknown': {code_str}"


def test_resolve_pr_cite_missing_pr_fails():
    pf = load_preflight()
    cache = {
        "schema_version": 1,
        "last_refreshed_at": "2026-05-12T00:00:00Z",
        "repos": {
            "Regevba/FitTracker2": {"open": [], "merged": [], "closed": []},
        },
    }
    m = pf._PR_CITATION_PAT.search("PR #999999")
    finding = pf.resolve_pr_cite(m, cache)
    assert finding is not None, "PR not in cache should produce a finding"
    code_str = str(finding)
    assert "BROKEN_PR_CITATION" in code_str or "999999" in code_str, \
        f"finding should mention BROKEN_PR_CITATION or the PR number: {code_str}"
