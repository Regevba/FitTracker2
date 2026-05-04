-- Migration 000009: extend cohort_stats retention coverage to reminders.* segments
--
-- Smart-reminders behavioral-learning PR-1 (FT2 PR #190 backend half).
-- The new reminders.shows.<type>, reminders.taps.<type>, and
-- reminders.kill_flag segments share the same data-volume + sensitivity
-- profile as the original ai-engine cohort segments (anonymised
-- frequency counts), so they share the same retention policy.
--
-- The 000004 retention job already deletes any cohort_stats row whose
-- frequency falls below k=50 OR whose updated_at is older than 90 days,
-- regardless of segment. That scope is already wide enough to cover
-- the new reminders.* segments — no rule change is needed.
--
-- This migration is a NO-OP-but-documented to keep the migration chain
-- self-explanatory: future readers can grep for "reminders" across the
-- migrations dir and find this file. It also re-asserts the policy
-- comment on pg_cron so the canonical scope is captured at the
-- migration layer.
--
-- Rollback: this migration adds no schema or scheduled jobs; rolling
-- back is just dropping the file from the chain. No DROP statements.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_available_extensions
    WHERE name = 'pg_cron'
  ) AND EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'cohort-retention-daily'
  ) THEN
    -- Re-assert the canonical scope on the existing pg_cron job comment.
    COMMENT ON EXTENSION pg_cron IS
      '90-day rolling retention on cohort_stats. Covers ALL segments: '
      'the original ai-engine 4 (training, nutrition, recovery, stats) '
      'AND the smart-reminders behavioral-learning surfaces added 2026-05-01: '
      'reminders.shows.<type>, reminders.taps.<type>, reminders.kill_flag. '
      'Bucket-level k-anonymity floor: any row with frequency < 50 is also '
      'pruned. See migrations 000004 (original) + 000009 (this file).';

    RAISE NOTICE
      'Migration 000009: existing cohort-retention-daily job already covers '
      'reminders.* segments (segment-agnostic predicate); re-asserted the '
      'canonical scope comment.';
  ELSE
    RAISE NOTICE
      'Migration 000009: pg_cron not available OR cohort-retention-daily not '
      'scheduled (likely plain Postgres CI environment). reminders.* segments '
      'will rely on 000004 once that job is scheduled in Supabase Pro.';
  END IF;
END $$;
