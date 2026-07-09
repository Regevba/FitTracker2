"""Tests for T12 / FIT-160 SCHEMA_DIFF (test-coverage-master-plan §4).

Covers the SQL DDL parser, the Swift column-reference extractor, the diff logic,
exemptions, trigger/skip semantics, and Mechanism A coverage emission.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_MOD = Path(__file__).resolve().parent.parent / "check-state-schema.py"
_spec = importlib.util.spec_from_file_location("check_state_schema", _MOD)
css = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(css)

# A migration mirroring the real sync_records shape.
SQL_SYNC = """\
CREATE TABLE IF NOT EXISTS sync_records (
  id               UUID        NOT NULL PRIMARY KEY,
  user_id          UUID        NOT NULL,
  record_type      TEXT        NOT NULL,
  logic_date       DATE,                           -- daily_log
  week_start       DATE,                           -- weekly_snapshot
  encrypted_payload TEXT       NOT NULL,
  checksum         TEXT        NOT NULL,
  last_modified    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_sync_daily_log UNIQUE (user_id, record_type, logic_date)
);
"""

# Swift referencing only columns that exist above.
SWIFT_ALIGNED = """\
struct SyncRow: Decodable {
    enum CodingKeys: String, CodingKey {
        case recordType       = "record_type"
        case logicDate        = "logic_date"
        case weekStart        = "week_start"
        case encryptedPayload = "encrypted_payload"
        case checksum
        case lastModified     = "last_modified"
    }
}
let x = client.from("sync_records")
    .select("record_type, logic_date, week_start, encrypted_payload, checksum, last_modified")
    .upsert([...], onConflict: "user_id,record_type,logic_date")
"""


def _mkrepo(tmp: Path, sql: str = SQL_SYNC, swift: str = SWIFT_ALIGNED, exempt=None) -> Path:
    mig = tmp / css.SUPABASE_MIGRATIONS_DIR
    mig.mkdir(parents=True, exist_ok=True)
    (mig / "000005_sync_records.sql").write_text(sql)
    sw = tmp / css.SUPABASE_SYNC_SERVICE_PATH
    sw.parent.mkdir(parents=True, exist_ok=True)
    sw.write_text(swift)
    feats = tmp / ".claude" / "features"
    feats.mkdir(parents=True, exist_ok=True)
    if exempt is not None:
        (feats / "x").mkdir()
        (feats / "x" / "state.json").write_text(json.dumps({"schema_diff_exempt": exempt}))
    return tmp


# ---------------------------------------------------------------- parsers

def test_parse_sql_columns_create_table(tmp_path):
    _mkrepo(tmp_path)
    schema = css._parse_sql_schema_columns(tmp_path)
    assert schema["sync_records"] == {
        "id", "user_id", "record_type", "logic_date", "week_start",
        "encrypted_payload", "checksum", "last_modified", "created_at",
    }
    # constraint line must not be parsed as a column
    assert "uq_sync_daily_log" not in schema["sync_records"]


def test_parse_sql_alter_add_drop_rename(tmp_path):
    sql = SQL_SYNC + """
ALTER TABLE sync_records ADD COLUMN device_id TEXT;
ALTER TABLE sync_records RENAME COLUMN checksum TO payload_checksum;
ALTER TABLE sync_records DROP COLUMN created_at;
ALTER TABLE sync_records DROP CONSTRAINT IF EXISTS uq_sync_daily_log;
"""
    _mkrepo(tmp_path, sql=sql)
    cols = css._parse_sql_schema_columns(tmp_path)["sync_records"]
    assert "device_id" in cols            # ADD COLUMN
    assert "payload_checksum" in cols     # RENAME target
    assert "checksum" not in cols         # RENAME source gone
    assert "created_at" not in cols       # DROP COLUMN
    assert "user_id" in cols              # DROP CONSTRAINT did not drop a column


def test_parse_swift_columns(tmp_path):
    _mkrepo(tmp_path)
    cols = css._parse_swift_referenced_columns(tmp_path)
    assert cols == {
        "record_type", "logic_date", "week_start", "encrypted_payload",
        "last_modified", "user_id", "checksum",  # checksum via .select(...)
    }
    assert "recordType" not in cols  # camelCase case-name not a column


# ---------------------------------------------------------------- gate

def test_no_relevant_files_staged_skips(tmp_path):
    _mkrepo(tmp_path)
    cov = css.GateCoverage(mode="staged")
    out = css.check_schema_diff(["docs/readme.md"], coverage=cov, repo_root=tmp_path)
    assert out == []
    assert cov.gates["SCHEMA_DIFF"]["skipped"] == 1
    assert "no_schema_or_sync_files_staged" in cov.gates["SCHEMA_DIFF"]["skip_reasons"]


def test_aligned_schema_no_drift(tmp_path):
    _mkrepo(tmp_path)
    cov = css.GateCoverage(mode="staged")
    out = css.check_schema_diff([css.SUPABASE_SYNC_SERVICE_PATH], coverage=cov, repo_root=tmp_path)
    assert out == []
    assert cov.gates["SCHEMA_DIFF"]["checked"] == 1  # ran the predicate, no drift


def test_dropped_column_flagged(tmp_path):
    # schema drops week_start; swift still references it → drift
    sql = SQL_SYNC.replace("  week_start       DATE,                           -- weekly_snapshot\n", "")
    _mkrepo(tmp_path, sql=sql)
    out = css.check_schema_diff(
        ["backend/supabase/migrations/000005_sync_records.sql"], repo_root=tmp_path)
    assert len(out) == 1
    assert out[0]["code"] == "SCHEMA_DIFF"
    assert out[0]["drift"] == ["week_start"]
    assert out[0]["advisory"] == css.SCHEMA_DIFF_ADVISORY_MODE


def test_exemption_suppresses_drift(tmp_path):
    sql = SQL_SYNC.replace("  week_start       DATE,                           -- weekly_snapshot\n", "")
    _mkrepo(tmp_path, sql=sql,
            exempt=[{"table": "sync_records", "column": "week_start", "reason": "staged rename, code lands next PR"}])
    out = css.check_schema_diff([css.SUPABASE_SYNC_SERVICE_PATH], repo_root=tmp_path)
    assert out == []


def test_unparseable_side_skips(tmp_path):
    # migrations dir missing entirely → can't diff → skip, not false-flag
    sw = tmp_path / css.SUPABASE_SYNC_SERVICE_PATH
    sw.parent.mkdir(parents=True, exist_ok=True)
    sw.write_text(SWIFT_ALIGNED)
    (tmp_path / ".claude" / "features").mkdir(parents=True, exist_ok=True)
    cov = css.GateCoverage(mode="staged")
    out = css.check_schema_diff([css.SUPABASE_SYNC_SERVICE_PATH], coverage=cov, repo_root=tmp_path)
    assert out == []
    assert "schema_or_code_unparseable" in cov.gates["SCHEMA_DIFF"]["skip_reasons"]


def test_collect_exemptions(tmp_path):
    _mkrepo(tmp_path, exempt=[{"table": "sync_records", "column": "foo", "reason": "r"}])
    assert css._collect_schema_diff_exemptions(tmp_path) == {"foo"}
