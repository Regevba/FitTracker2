-- Migration 000006: Row Level Security for sync_records
-- Users can only read and write their own rows.
-- Service role retains unrestricted access for admin/support operations.

ALTER TABLE sync_records ENABLE ROW LEVEL SECURITY;

-- Authenticated users: SELECT their own records only
CREATE POLICY "sync_records_owner_select"
  ON sync_records
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Authenticated users: INSERT their own records only
CREATE POLICY "sync_records_owner_insert"
  ON sync_records
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Authenticated users: UPDATE their own records only
CREATE POLICY "sync_records_owner_update"
  ON sync_records
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Authenticated users: DELETE their own records only (account wipe)
CREATE POLICY "sync_records_owner_delete"
  ON sync_records
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role: unrestricted (admin, export, account deletion pipeline)
CREATE POLICY "sync_records_service_role_all"
  ON sync_records
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Realtime: enable publication for incremental pull subscriptions.
-- Only rows where auth.uid() = user_id will be sent to the subscriber (RLS enforced).
-- Guard: supabase_realtime publication only exists in real Supabase environments,
-- not in plain PostgreSQL CI — degrade safely.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sync_records;
  END IF;
END
$$;
