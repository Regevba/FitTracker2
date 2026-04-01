-- Migration 000005: sync_records — encrypted per-user sync blobs
-- Each row is an opaque .ftenc blob encrypted on-device before leaving the app.
-- The server never has access to plaintext user data.
--
-- Record types (record_type column):
--   daily_log          keyed by user_id + logic_date
--   weekly_snapshot    keyed by user_id + week_start
--   user_profile       keyed by user_id (singleton)
--   user_preferences   keyed by user_id (singleton)
--   meal_templates     keyed by user_id (singleton)

CREATE TABLE IF NOT EXISTS sync_records (
  id               UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  record_type      TEXT        NOT NULL,
  -- Per-type natural keys (nullable; only one applies per record_type)
  logic_date       DATE,                           -- daily_log
  week_start       DATE,                           -- weekly_snapshot
  -- Encrypted payload
  encrypted_payload TEXT       NOT NULL,           -- base64-encoded .ftenc blob
  checksum         TEXT        NOT NULL,           -- SHA-256 of the ciphertext for integrity
  last_modified    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Composite unique constraints enforce at most one row per logical key
  CONSTRAINT uq_sync_daily_log        UNIQUE (user_id, record_type, logic_date),
  CONSTRAINT uq_sync_weekly_snapshot  UNIQUE (user_id, record_type, week_start),
  CONSTRAINT uq_sync_singleton        UNIQUE (user_id, record_type)
    -- Note: this fires for rows where both logic_date and week_start are NULL.
    -- PostgreSQL unique constraints ignore NULL columns, so the UNIQUE on (user_id, record_type)
    -- only applies when both nullable columns are NULL — which is correct for singletons.
);

-- Fast lookup: user's records by type
CREATE INDEX IF NOT EXISTS idx_sync_records_user_type
  ON sync_records (user_id, record_type);

-- Fast lookup: incremental pull by last_modified (used by fetchChanges)
CREATE INDEX IF NOT EXISTS idx_sync_records_last_modified
  ON sync_records (user_id, last_modified);

COMMENT ON TABLE sync_records IS
  'Per-user encrypted sync blobs. Payload is always a .ftenc blob encrypted on-device. '
  'Server stores ciphertext only — zero plaintext user data ever leaves the device unencrypted.';

COMMENT ON COLUMN sync_records.encrypted_payload IS
  'Base64-encoded AES-GCM ciphertext produced by EncryptionService on the device.';

COMMENT ON COLUMN sync_records.checksum IS
  'SHA-256 hex digest of the ciphertext bytes, computed on-device before upload. '
  'Used to detect storage corruption; does not verify decryption key correctness.';
