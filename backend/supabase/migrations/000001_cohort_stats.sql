-- Migration 000001: cohort_stats table
-- Frequency-count model for GDPR-compliant federated cohort intelligence.
-- Stores categorical band counts only — no raw user values, no PII.

CREATE TABLE IF NOT EXISTS cohort_stats (
  segment       TEXT        NOT NULL,  -- 'training' | 'nutrition' | 'recovery' | 'stats'
  field_name    TEXT        NOT NULL,  -- e.g. 'age_band', 'gender_band'
  field_value   TEXT        NOT NULL,  -- e.g. '25-34', 'male'
  frequency     BIGINT      NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (segment, field_name, field_value)
);

-- Index for cohort reads by segment
CREATE INDEX IF NOT EXISTS idx_cohort_stats_segment
  ON cohort_stats (segment);

-- Index for retention job (updated_at scans)
CREATE INDEX IF NOT EXISTS idx_cohort_stats_updated_at
  ON cohort_stats (updated_at);

COMMENT ON TABLE cohort_stats IS
  'Anonymised categorical frequency counts for cohort intelligence. '
  'No raw user metrics stored. GDPR Article 5 — data minimisation.';
