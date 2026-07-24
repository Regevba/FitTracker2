"""F16 try-repo integration test for AN-1B.2 GA4_MCP_DISCONNECTED (ADVISORY-ONLY by design).

GA4_MCP_DISCONNECTED never blocks a commit (analytics-master-plan §8.3): when
analytics-affecting code is staged and GA4 MCP is unreachable via env
(GA4_PROPERTY_ID unset OR GOOGLE_APPLICATION_CREDENTIALS not a file), the hook
prints a `[ADVISORY] GA4_MCP_DISCONNECTED` line to stderr but returns 0. This
test covers the emit path end-to-end through the real pre-commit — the surface
the unit/function tests can't see (hook composition, env read, staged-set
detection) — asserting on the advisory line + rc == 0 rather than on blocking.

Positive (disconnected): analytics file staged, GA4_PROPERTY_ID empty →
advisory printed, rc == 0.
Negative (connected): GA4_PROPERTY_ID set + GOOGLE_APPLICATION_CREDENTIALS
points at a real file → no advisory, rc == 0.

Staged file is a benign `FitTracker/Services/Analytics/*` file (NOT
AnalyticsProvider.swift) so the enforced CSV_TAXONOMY_DRIFT gate stays out of
the picture and rc stays 0 in both arms.
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

# Matches ANALYTICS_AFFECTING_GLOBS "FitTracker/Services/Analytics/*" but is not
# AnalyticsProvider.swift, so it does not engage CSV_TAXONOMY_DRIFT.
ANALYTICS_FILE = "FitTracker/Services/Analytics/AnalyticsEventBuffer.swift"
_SWIFT = """\
import Foundation

struct AnalyticsEventBuffer {
    var pending: [String] = []
}
"""


def _run(tmp_path, env_extra):
    repo = make_throwaway_repo(tmp_path)
    (repo / ".claude" / "features").mkdir(parents=True, exist_ok=True)
    stage_files(repo, {ANALYTICS_FILE: _SWIFT})
    env = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
        **env_extra,
    }
    return run_precommit(repo, env_overrides=env)


def test_disconnected_emits_advisory_but_does_not_block(tmp_path):
    result = _run(tmp_path, {"GA4_PROPERTY_ID": ""})
    combined = result.stdout + result.stderr
    assert "GA4_MCP_DISCONNECTED" in combined, (
        f"expected GA4_MCP_DISCONNECTED advisory in hook output.\n"
        f"  rc={result.returncode}\n  stdout={result.stdout!r}\n  stderr={result.stderr!r}"
    )
    # Advisory-only by design: must NOT block.
    assert result.returncode == 0, (
        f"GA4_MCP_DISCONNECTED is advisory-only and must not block; "
        f"rc={result.returncode}, stderr={result.stderr!r}"
    )


def test_connected_env_emits_no_advisory(tmp_path):
    creds = tmp_path / "ga4-creds.json"
    creds.write_text('{"type": "service_account"}\n')
    result = _run(tmp_path, {
        "GA4_PROPERTY_ID": "test-property-123",
        "GOOGLE_APPLICATION_CREDENTIALS": str(creds),
    })
    assert "GA4_MCP_DISCONNECTED" not in (result.stdout + result.stderr), (
        f"connected GA4 env must not emit the advisory.\n  stderr={result.stderr!r}"
    )
    assert result.returncode == 0
