-- Migration 000010: enforce the k-anonymity floor in cohort_stats authenticated RLS
--
-- Fixes a privacy gap found in the 2026-06-15 audit. Migration 000003's
-- authenticated SELECT policy used `USING (true)`, so ANY logged-in user could
-- read sub-threshold cohort buckets directly via PostgREST
-- (`GET /rest/v1/cohort_stats`) with their own JWT — bypassing the k>=50
-- anonymity floor that previously lived ONLY in AI-engine app code
-- (`cohort_service.get_cohort_totals`). This pushes the k-anonymity guarantee
-- down to the database layer, where it cannot be bypassed.
--
-- The AI engine is UNAFFECTED: it reads via the `service_role` key, which
-- bypasses RLS (covered by `cohort_stats_service_role_all`) and continues to
-- apply the same floor in app code.
--
-- NOTE: the threshold 50 is hardcoded to match `settings.k_anonymity_floor`'s
-- default. RLS cannot read app config; if that setting is ever changed, update
-- this policy in a follow-up migration to keep the two in lockstep.

DROP POLICY IF EXISTS "cohort_stats_authenticated_read" ON cohort_stats;

CREATE POLICY "cohort_stats_authenticated_read_k_anon"
  ON cohort_stats
  FOR SELECT
  TO authenticated
  USING (frequency >= 50);  -- k-anonymity floor

COMMENT ON POLICY "cohort_stats_authenticated_read_k_anon" ON cohort_stats IS
  'Authenticated reads limited to buckets with frequency >= 50 (k-anonymity '
  'floor). Sub-threshold buckets are visible only to service_role (AI engine), '
  'which applies the same floor in app code. Closes the 000003 USING(true) bypass.';
