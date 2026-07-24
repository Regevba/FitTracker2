# Backend Test Gap — Re-scope: SQL/RLS harness, not "Edge Functions"

**Status:** SCOPE CORRECTION + build spec (build gated on local Postgres/Docker).
**Supersedes the phantom line:** backlog "Supabase Edge Functions test suite (backend/ 0 tests)" + test-coverage-master-plan §2.4 "Edge Functions (if any exist)".

## §1 Ground truth (verified 2026-07-24)

`backend/` contains **no Edge Functions**. The full tree is SQL only:

```
backend/supabase/migrations/   10 files (000001…000010)
backend/supabase/seed/         seed_cohort_stats.sql
backend/README.md
```

There is **no `backend/supabase/functions/` directory, zero `.ts`/`.js` Deno functions**, and **Deno is not installed**. The test-coverage plan already hedged this ("Edge Functions (if any exist)", §2.4 line 149 + §5 open Q5); this confirms the hedge — **none exist**.

The "backend 0 tests" framing is therefore **misleading**: the *Swift* backend surface (EncryptionService, SupabaseSyncService, CloudKitSyncService, …) **is** tested — 248 methods across 22 Swift test files (test-coverage plan §2.4). The genuinely-untested backend surface is the **SQL layer**: table schema, constraints, and **RLS policies** (`000003_rls_cohort_stats.sql`, `000006_rls_sync_records.sql`, `000010_cohort_stats_k_anon_rls.sql`).

## §2 Why this matters (not cosmetic)

RLS is a **security boundary**. `cohort_stats` currently has an open advisor finding — RLS disabled / k-anon gaps (**FIT-202**, High). A test harness that asserts "anon/authenticated cannot read/write rows they shouldn't" is the durable regression guard for exactly that class. Untested RLS = a silent-pass security surface.

## §3 Proposed harness (build when tooling exists)

- **Tool:** pgTAP (`pg_prove`) against a throwaway Postgres seeded by applying `migrations/*.sql` in order, or `supabase db test` (both need a local Postgres — via Docker or a native install).
- **Coverage (v1):**
  - schema: each migration's tables/columns/constraints exist after apply;
  - RLS: for `cohort_stats`, `sync_records`, `cardio_assets` — an `anon` role and a non-owner `authenticated` role are **denied** SELECT/INSERT/UPDATE on rows they don't own; the owner **is** allowed; k-anon threshold rows behave per `000010`.
  - retention: `pg_cron` retention jobs (`000004`, `000009`) delete rows past the window.
- **CI:** a GH Actions job with a `postgres` service container + `pgtap` extension, applying migrations then running `pg_prove`. Runs on changes to `backend/supabase/**`.

## §4 Why NOT built in this pass (blocker)

**Postgres, pgTAP, pg_prove, and Docker are all absent from the current dev environment** (only the `supabase` CLI is present, and its local stack needs Docker). A pgTAP/RLS harness cannot be **built-and-verified locally** here. Pushing a CI-only harness that cannot be run first would violate verify-before-completion and risks a silent no-op (pgTAP not installed in the container → tests skip green). Per the "CI-green can mask a no-op" rule, we do not push an unverifiable harness.

## §5 Prerequisite to build

One of: (a) Docker available locally (→ `supabase db start` / a `postgres:16` + `pgtap` container), or (b) a native Postgres + pgTAP install, or (c) accept CI-first authoring with a mandatory first-run log inspection to prove pgTAP actually executed (not skipped). Recommend (a).

## §6 Disposition

- The **"Supabase Edge Functions test suite" backlog line is retired as mislabeled** and replaced by this SQL/RLS harness scope.
- Tracked against **FIT-202** (RLS remediation) as the natural pairing — remediate RLS + land the regression harness together once Postgres tooling is available.
- test-coverage-master-plan §2.4 "Edge Functions (if any exist)" annotated: **confirmed none exist 2026-07-24**.

## §7 Cross-references

- FIT-202 (Supabase RLS on `cohort_stats` + advisor remediation).
- `docs/setup/supabase-advisor-remediation-2026-06-30*` (draft remediation SQL).
- test-coverage-master-plan §2.4 + §5 Q5.
- backlog "Self-test meta-analysis follow-ups" (the source line).
