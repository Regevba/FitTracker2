"""F16 try-repo integration test for AN-1B.1 CSV_TAXONOMY_DRIFT (ENFORCED 2026-07-13, cadence B16).

CSV_TAXONOMY_DRIFT was promoted advisory→enforced on 2026-07-13. The real
pre-commit hook BLOCKS (exits non-zero) when AnalyticsProvider.swift is staged
and an `enum AnalyticsEvent` constant's raw value has no row in
docs/product/analytics-taxonomy.csv (and isn't csv_taxonomy_exempt). This
exercises the full integration surface the unit + function tests can't: hook
composition, REPO_ROOT_OVERRIDE resolution, real `git diff --cached` staged-set
detection, the swift-enum + CSV parsers reading the working tree, HOME scrub.

Positive: a new AnalyticsEvent constant whose value is absent from the CSV →
CSV_TAXONOMY_DRIFT blocks the commit (rc != 0) + names the constant.
Negative: same constant WITH a matching CSV row → no drift, commit accepted.

Staged-file gate (like SCHEMA_DIFF), so this uses stage_files with inline
swift/CSV rather than the state.overrides.json fixture harness.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _try_repo_harness import (  # noqa: E402
    make_throwaway_repo,
    run_precommit,
    scrub_home_env,
    stage_files,
)

ANALYTICS_PROVIDER_PATH = "FitTracker/Services/Analytics/AnalyticsProvider.swift"
CSV_PATH = "docs/product/analytics-taxonomy.csv"

# Minimal AnalyticsProvider.swift with a single event constant inside the
# brace-balanced `enum AnalyticsEvent` block the parser scopes to.
_SWIFT = """\
import Foundation

enum AnalyticsEvent {
    static let homeTryRepoFixtureTap = "home_try_repo_fixture_tap"
}
"""

# Positive: CSV has a header + an unrelated row, but NOT the staged event value.
_CSV_DRIFT = """\
Event Name,screen_scope,description
home_action_tap,home,unrelated existing row
"""

# Negative: CSV includes the staged event value → no drift.
_CSV_ALIGNED = """\
Event Name,screen_scope,description
home_action_tap,home,unrelated existing row
home_try_repo_fixture_tap,home,the fixture event
"""


def _run(tmp_path, csv_text):
    repo = make_throwaway_repo(tmp_path)
    (repo / ".claude" / "features").mkdir(parents=True, exist_ok=True)
    stage_files(repo, {ANALYTICS_PROVIDER_PATH: _SWIFT, CSV_PATH: csv_text})
    env = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    return run_precommit(repo, env_overrides=env)


def test_missing_csv_row_blocks(tmp_path):
    result = _run(tmp_path, _CSV_DRIFT)
    combined = result.stdout + result.stderr
    assert "CSV_TAXONOMY_DRIFT" in combined, (
        f"expected CSV_TAXONOMY_DRIFT finding in hook output.\n"
        f"  rc={result.returncode}\n  stdout={result.stdout!r}\n  stderr={result.stderr!r}"
    )
    assert "homeTryRepoFixtureTap" in combined or "home_try_repo_fixture_tap" in combined
    # Enforced (2026-07-13, B16): the commit IS blocked.
    assert result.returncode != 0, (
        f"CSV_TAXONOMY_DRIFT is enforced and must block on drift; "
        f"rc={result.returncode}, stderr={result.stderr!r}"
    )


def test_aligned_csv_no_drift(tmp_path):
    result = _run(tmp_path, _CSV_ALIGNED)
    assert "CSV_TAXONOMY_DRIFT" not in (result.stdout + result.stderr), (
        f"aligned CSV must not fire CSV_TAXONOMY_DRIFT.\n  stderr={result.stderr!r}"
    )
    assert result.returncode == 0
