-- Migration 000002: increment_cohort_frequency RPC
-- Atomic upsert via SECURITY DEFINER function.
-- Called by AI engine via PostgREST /rpc/increment_cohort_frequency.
-- PostgREST merge-duplicates header replaces rather than increments,
-- so this explicit function is required for correct atomic increments.

CREATE OR REPLACE FUNCTION increment_cohort_frequency(
  p_segment     TEXT,
  p_field_name  TEXT,
  p_field_value TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO cohort_stats (segment, field_name, field_value, frequency, updated_at)
  VALUES (p_segment, p_field_name, p_field_value, 1, NOW())
  ON CONFLICT (segment, field_name, field_value)
  DO UPDATE SET
    frequency  = cohort_stats.frequency + 1,
    updated_at = NOW();
END;
$$;

COMMENT ON FUNCTION increment_cohort_frequency IS
  'Atomically increments frequency count for a cohort bucket. '
  'SECURITY DEFINER so AI engine service key can write despite RLS restrictions.';

REVOKE ALL ON FUNCTION increment_cohort_frequency(TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_cohort_frequency(TEXT, TEXT, TEXT) TO service_role;
