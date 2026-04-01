-- Migration 000007: cardio_assets — metadata for encrypted cardio images in Storage
-- Actual image data lives in Supabase Storage bucket "cardio-images".
-- This table stores metadata so the app can locate and verify downloads without
-- listing the storage bucket (which would be slower and require broader permissions).

CREATE TABLE IF NOT EXISTS cardio_assets (
  id             UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  logic_date     DATE        NOT NULL,
  cardio_type    TEXT        NOT NULL,   -- e.g. "run", "cycle", "swim"
  storage_path   TEXT        NOT NULL,   -- path within "cardio-images" bucket
  checksum       TEXT        NOT NULL,   -- SHA-256 hex of the encrypted file bytes
  last_modified  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_cardio_asset UNIQUE (user_id, logic_date, cardio_type)
);

CREATE INDEX IF NOT EXISTS idx_cardio_assets_user_date
  ON cardio_assets (user_id, logic_date);

ALTER TABLE cardio_assets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cardio_assets_owner_select"
  ON cardio_assets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "cardio_assets_owner_insert"
  ON cardio_assets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cardio_assets_owner_update"
  ON cardio_assets
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cardio_assets_owner_delete"
  ON cardio_assets
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "cardio_assets_service_role_all"
  ON cardio_assets
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

COMMENT ON TABLE cardio_assets IS
  'Metadata for encrypted cardio images stored in Supabase Storage bucket "cardio-images". '
  'Actual files are AES-GCM encrypted on-device. The checksum column allows integrity '
  'verification after download without decrypting the file.';
