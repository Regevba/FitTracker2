"""F16 try-repo integration test for T12 SCHEMA_DIFF (ENFORCED 2026-07-20, cadence B17).

SCHEMA_DIFF was promoted advisory→enforced on 2026-07-20 (all 4 §2.2 criteria
met; 1 genuine field firing 2026-07-16). The real pre-commit hook now BLOCKS
(exits non-zero) when the gate fires, so the standard rc-based fixture harness
convention applies (positive → rc != 0). This asserts on rc AND the hook's
STDERR, exercising the full integration surface the unit + function tests
can't: hook composition, REPO_ROOT_OVERRIDE resolution, real
`git status --porcelain`, HOME scrub.

Positive: a migration that drops `week_start` while the sync code still
references it → SCHEMA_DIFF blocks the commit (rc != 0) + names the column.
Negative: aligned schema → no SCHEMA_DIFF finding, commit passes.
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

MIGRATION_PATH = "backend/supabase/migrations/000005_sync_records.sql"
SWIFT_PATH = "FitTracker/Services/Supabase/SupabaseSyncService.swift"

_SQL_WITH_WEEK_START = """\
CREATE TABLE IF NOT EXISTS sync_records (
  id                UUID        NOT NULL PRIMARY KEY,
  user_id           UUID        NOT NULL,
  record_type       TEXT        NOT NULL,
  logic_date        DATE,
  week_start        DATE,
  encrypted_payload TEXT        NOT NULL,
  checksum          TEXT        NOT NULL,
  last_modified     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""

# Same table with week_start dropped — the drift the gate must catch.
_SQL_NO_WEEK_START = _SQL_WITH_WEEK_START.replace("  week_start        DATE,\n", "")

# Sync code references week_start (among other sync_records columns).
_SWIFT = """\
struct SyncRow: Decodable {
    enum CodingKeys: String, CodingKey {
        case recordType       = "record_type"
        case logicDate        = "logic_date"
        case weekStart        = "week_start"
        case encryptedPayload = "encrypted_payload"
        case lastModified     = "last_modified"
    }
}
let q = client.from("sync_records")
    .select("record_type, logic_date, week_start, encrypted_payload, checksum, last_modified")
    .upsert([...], onConflict: "user_id,record_type,logic_date")
"""


def _run(tmp_path, sql):
    repo = make_throwaway_repo(tmp_path)
    (repo / ".claude" / "features").mkdir(parents=True, exist_ok=True)
    stage_files(repo, {MIGRATION_PATH: sql, SWIFT_PATH: _SWIFT})
    env = {
        "GATE_COVERAGE_LEDGER_DISABLED": "1",
        "REPO_ROOT_OVERRIDE": str(repo),
        **scrub_home_env(tmp_path),
    }
    return run_precommit(repo, env_overrides=env)


def test_dropped_column_blocks(tmp_path):
    result = _run(tmp_path, _SQL_NO_WEEK_START)
    combined = result.stdout + result.stderr
    assert "SCHEMA_DIFF" in combined, (
        f"expected SCHEMA_DIFF finding in hook output.\n"
        f"  rc={result.returncode}\n  stdout={result.stdout!r}\n  stderr={result.stderr!r}"
    )
    assert "week_start" in combined
    # Enforced (2026-07-20, B17): the commit IS blocked.
    assert result.returncode != 0, (
        f"SCHEMA_DIFF is enforced and must block on drift; rc={result.returncode}, "
        f"stderr={result.stderr!r}"
    )


def test_aligned_schema_no_advisory(tmp_path):
    result = _run(tmp_path, _SQL_WITH_WEEK_START)
    assert "SCHEMA_DIFF" not in (result.stdout + result.stderr), (
        f"aligned schema must not fire SCHEMA_DIFF.\n  stderr={result.stderr!r}"
    )
    assert result.returncode == 0
