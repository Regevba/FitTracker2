# T12 — Supabase↔iOS schema-diff gate: corrected scope

**Status:** spec (queued for build) · **Date:** 2026-07-09 · **Linear:** FIT-160 · **Plan:** test-coverage-master-plan §4 T12 (RICE 18.0, effort M)

> **Why this doc exists.** A verify-first investigation (2026-07-09) found the
> T12 line in `test-coverage-master-plan-2026-05-13.md` is **mis-specced**. It
> reads "diff Supabase migration files against `DomainModels.swift` matching
> fields." That diff has almost no real surface: the synced domain models are
> JSON-encoded → encrypted → stored as one opaque `encrypted_payload` TEXT blob,
> so they have **no column-level correspondence** to any table. Building T12 as
> written would be a near-no-op that passes trivially and provides false
> assurance. This doc corrects the diff endpoints and budgets the work the
> RICE-18/0.4w estimate omitted. **Build gated on operator approval of this
> corrected scope** (per the 2026-07-09 session decision).

## 1. The real drift surface

The Supabase schema lives **in-repo** as raw SQL migrations — no remote call
needed, so T12 is buildable as a pure offline pre-commit gate:

- `backend/supabase/migrations/000001_cohort_stats.sql` → `cohort_stats(segment, field_name, field_value, frequency, updated_at)`
- `backend/supabase/migrations/000005_sync_records.sql` → `sync_records(id, user_id, record_type, logic_date, week_start, encrypted_payload, checksum, last_modified, created_at)`
- `backend/supabase/migrations/000007_cardio_assets.sql` → `cardio_assets(id, user_id, logic_date, cardio_type, storage_path, checksum, last_modified, created_at)`
- `000002-000004, 000006, 000008-000010` — RLS / pg_cron / functions / uniqueness (no new tables)

The **columns that can actually drift** are the non-blob metadata columns, and
the Swift side that references them by string literal is **`SupabaseSyncService.swift`**
(NOT `DomainModels.swift`):

| Swift reference | Location | Columns named |
|---|---|---|
| upsert dicts | `SupabaseSyncService.swift` L108-139, L307-315, L584-591 | `record_type`, `logic_date`, `week_start`, `encrypted_payload`, `checksum`, `cardio_type`, `storage_path`, … |
| `onConflict:` tuples | same | `user_id,record_type,logic_date` / `…,week_start` / `user_id,logic_date,cardio_type` |
| `.select(...)` column lists | L470-489 (`SyncRow`), L602-609 (`AssetRow`), L391-395 | same set |
| `CodingKeys` | `SyncRow`, `AssetRow`, `CardioAssetPathRow` | `record_type`→`recordType`, `last_modified`→`lastModified`, `storage_path`→`storagePath`, … |

If a migration renames `last_modified` or drops `week_start`, those string
literals silently break at runtime. **That** is what T12 must catch.

## 2. Corrected gate contract

**`SCHEMA_DIFF` — commit-level write-time gate, advisory mode at ship.**

- **Trigger:** fires when a staged file matches `backend/supabase/migrations/*.sql`
  OR `FitTracker/Services/Supabase/SupabaseSyncService.swift`.
- **Extract A (schema):** parse `CREATE TABLE` / `ALTER TABLE … ADD/DROP/RENAME COLUMN`
  across all migration files → per-table column set (final state after all migrations applied).
- **Extract B (code):** parse the Swift column references in `SupabaseSyncService.swift`
  — upsert-dict keys, `.select("…")` lists, `onConflict:` tuples, and `CodingKeys`
  raw values — into the set of columns the code expects per table.
- **Diff:** for each synced table (`sync_records`, `cardio_assets`, `cohort_stats`),
  flag a column the **code references but the schema lacks** (hard drift — will
  break at runtime) and, separately/informationally, a column the **schema has
  but no code references** (soft — often fine, e.g. `id`, `created_at`).
- **Emit:** finding `{code: "SCHEMA_DIFF", table, column, direction}` with
  `advisory: SCHEMA_DIFF_ADVISORY_MODE` (ship `True`); Mechanism A coverage on an
  isolated key. Follows the `check_csv_taxonomy_drift` structure exactly
  (`scripts/check-state-schema.py`, registered commit-level in `main()`).
- **Exemption:** `schema_diff_exempt: [{table, column, reason}]` (mirror the
  `csv_taxonomy_exempt` pattern) for intentional code-only / schema-only columns.

## 3. Work the RICE-18/0.4w estimate omitted (must budget)

1. **SQL DDL parser** tolerant of `IF NOT EXISTS`, constraints, and `ALTER TABLE`
   applied across 10 files (compute the *post-migration* column set, not per-file).
2. **Swift literal extractor** — column names live in string literals
   (`.select`, `onConflict`, upsert keys) + `CodingKeys`; needs a tolerant matcher,
   not reflection. Brittle surface — pin with fixtures.
3. **Try-repo harness extension (the real cost).** The F16 harness
   (`scripts/tests/_try_repo_harness.py`) only overlays a `state.json` via
   `state.overrides.json`. A `.sql`+`.swift` gate needs the harness to **stage
   arbitrary files** into the throwaway repo. This is a new harness capability,
   not just a fixture pair — budget it explicitly. (Coordinate with F16.1, which
   already wants `STATE_OWNER_LOCATION_MISMATCH` path-flexibility.)

## 4. Test plan (per new-gate discipline)

- Unit: DDL parser (rename/drop/add across files) + Swift extractor (each literal form).
- Dispatch: monkeypatched `main()` — gate registers, fires on a planted rename, emits Mechanism A row.
- Try-repo: `tests/fixtures/SCHEMA_DIFF/{positive,negative}/` — positive stages a migration that drops `week_start` while the code still `.select`s it (rc≠0); negative is aligned (rc==0). **Requires the harness extension in §3.3.**
- Gate-catalog: add the `GATES` entry in `scripts/gate-catalog.py`; `make gate-catalog` + `make gate-catalog-check` green.

## 5. Sequencing & calibration

- Build after PR #860 (DI-Q2 + FIT-206) merges.
- Ship **advisory**; 14-day Mechanism A window; promote advisory→enforced per infra-master-plan §2.2 (≥7d coverage, 0 false positives, no silent skips, single-flag reversible) — same ladder as `CSV_TAXONOMY_DRIFT`.
- Update the test-coverage-plan T12 line to point here and correct the "DomainModels" wording.

## 6. Feasibility verdict

Buildable as a pure in-repo offline gate (schema + mapping both committed) —
**not blocked on groundwork**, but blocked on (a) this corrected scope and
(b) the try-repo harness extension. The RICE-18 stands for value; the effort is
closer to **M-plus** once the harness work is counted.
