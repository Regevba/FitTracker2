-- Migration 000008: fix sync_records uniqueness for dated record types
--
-- The original UNIQUE (user_id, record_type) constraint blocks multiple
-- daily_log / weekly_snapshot rows per user. Keep singleton enforcement only
-- for true singleton record types via partial unique indexes.

ALTER TABLE sync_records
  DROP CONSTRAINT IF EXISTS uq_sync_singleton;

CREATE UNIQUE INDEX IF NOT EXISTS uq_sync_singleton_user_profile
  ON sync_records (user_id, record_type)
  WHERE record_type = 'user_profile';

CREATE UNIQUE INDEX IF NOT EXISTS uq_sync_singleton_user_preferences
  ON sync_records (user_id, record_type)
  WHERE record_type = 'user_preferences';

CREATE UNIQUE INDEX IF NOT EXISTS uq_sync_singleton_meal_templates
  ON sync_records (user_id, record_type)
  WHERE record_type = 'meal_templates';
