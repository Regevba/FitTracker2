-- Migration 000004: pg_cron retention policy
-- Bucket-level retention to prevent partial k-floor regression.
-- Entire cohort bucket rows (segment + field_name + field_value) are removed
-- when frequency falls below k=50, preserving anonymity at the bucket level.
-- Also enforces 90-day storage limitation per GDPR Article 5.

-- PREREQUISITE: pg_cron requires the Supabase Pro plan (or higher).
-- On environments where pg_cron is unavailable (for example plain Postgres CI),
-- the migration degrades to a no-op rather than failing the whole migration chain.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_available_extensions
    WHERE name = 'pg_cron'
  ) THEN
    CREATE EXTENSION IF NOT EXISTS pg_cron;

    PERFORM cron.schedule(
      'cohort-retention-daily',     -- job name (idempotent)
      '0 3 * * *',                  -- 03:00 UTC daily
      $job$
      BEGIN;

      -- Remove cohort buckets that have fallen below k=50 anonymity floor.
      -- Bucket-level deletion prevents partial regression where some values
      -- in a (segment, field_name) group meet k-floor but others do not.
      DELETE FROM cohort_stats
      WHERE frequency < 50;

      -- Enforce 90-day storage limitation (GDPR Article 5 — storage limitation).
      -- Buckets not updated in 90 days are stale and no longer representative.
      DELETE FROM cohort_stats
      WHERE updated_at < NOW() - INTERVAL '90 days';

      COMMIT;
      $job$
    );
  ELSE
    RAISE NOTICE 'pg_cron is not available in this environment; skipping retention scheduler setup.';
  END IF;
END;
$$;
