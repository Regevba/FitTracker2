# FitTracker Backend

Source of truth for the SQL backend. This directory is intended to become the future `fittracker-backend` repo; until extraction, edit this directory for backend schema, policies, and migration behavior.

## What It Does

### Cohort Intelligence (Phase B)
- Stores anonymised cohort frequency counts in `cohort_stats`
- Exposes an increment RPC for service-side writes
- Applies RLS for read/write separation
- Schedules retention cleanup when `pg_cron` is available

### Encrypted Cloud Sync (Phase C)
- Stores per-user encrypted sync blobs in `sync_records` (AES-GCM encrypted on-device; server stores ciphertext only)
- Supports 5 record types: `daily_log`, `weekly_snapshot`, `user_profile`, `user_preferences`, `meal_templates`
- Realtime subscription via Supabase Realtime on `sync_records` — notifies the iOS client of remote changes so it can pull incrementally
- Stores cardio image metadata in `cardio_assets` with encrypted images in the `cardio-images` Supabase Storage bucket

## Current Layout

- `supabase/migrations/`: ordered schema and policy migrations
- `supabase/seed/`: development and CI seed data
- `.github/workflows/ci.yml`: migration validation workflow

### Migration Inventory

| Migration | Purpose |
|---|---|
| `000001_cohort_stats.sql` | Frequency-count table for anonymised cohort data |
| `000002_increment_cohort_frequency.sql` | `SECURITY DEFINER` RPC for atomic increments |
| `000003_rls_cohort_stats.sql` | RLS: authenticated → SELECT; service_role → full |
| `000004_retention_pg_cron.sql` | Daily 03:00 UTC cron: k=50 floor + 90-day GDPR purge |
| `000005_sync_records.sql` | Per-user encrypted sync blob table with composite unique constraints |
| `000006_rls_sync_records.sql` | RLS: owner-scoped CRUD + Supabase Realtime publication |
| `000007_cardio_assets.sql` | Cardio image metadata table with inline RLS |

## Operational Truth

- `000002_increment_cohort_frequency.sql` is `SECURITY DEFINER` and now explicitly revokes `PUBLIC` execute access
- `000004_retention_pg_cron.sql` degrades safely when `pg_cron` is unavailable instead of failing all migrations
- `000006_rls_sync_records.sql` conditionally adds `sync_records` to `supabase_realtime` publication (degrades safely in plain Postgres CI)
- Current CI validates migrations against plain PostgreSQL 15, so migrations must stay compatible with non-Supabase environments when possible

## Security Model

### sync_records
- All operations (SELECT/INSERT/UPDATE/DELETE) restricted to `auth.uid() = user_id`
- UPDATE policies include both USING and WITH CHECK to prevent `user_id` hijack
- `service_role` has unrestricted access for admin operations
- All health data payloads are AES-GCM encrypted on-device — server only stores ciphertext
- SHA-256 checksums enable integrity verification without decryption

### cardio_assets
- Same owner-scoped RLS model as `sync_records`
- References `cardio-images` Supabase Storage bucket (see deployment prerequisites)

## Deployment Prerequisites

1. **Supabase project** with PostgreSQL 15+
2. **Supabase Pro tier** for `pg_cron` (retention migration 000004)
3. **`cardio-images` Storage bucket** — must be created in the Supabase Dashboard or via Storage API before cardio upload works:
   - Bucket name: `cardio-images`
   - Public: `false`
   - File size limit: 10MB recommended
   - Allowed MIME types: `image/jpeg`, `image/heic`
   - Storage RLS policies: owner-scoped read/write using `auth.uid()` matching the path prefix

## Validation

CI expectations:

- Run migrations in order against plain PostgreSQL 15
- Verify `cohort_stats` schema, RLS, and seeded row counts
- Verify `sync_records` schema, RLS enablement, unique constraints, and policy existence
- Verify `cardio_assets` schema, RLS enablement, and policy existence
