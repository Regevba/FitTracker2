-- Migration 000003: Row Level Security for cohort_stats
-- authenticated role: SELECT only (cohort insight queries from AI engine)
-- service_role: full access (AI engine writes via increment_cohort_frequency RPC)

ALTER TABLE cohort_stats ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read population-level cohort aggregates
CREATE POLICY "cohort_stats_authenticated_read"
  ON cohort_stats
  FOR SELECT
  TO authenticated
  USING (true);

-- Service role retains unrestricted access for AI engine writes
CREATE POLICY "cohort_stats_service_role_all"
  ON cohort_stats
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
