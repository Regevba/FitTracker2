-- ============================================================================
-- Supabase advisor remediation — FitMe BE & AI engine
-- ============================================================================
-- STATUS:   DRAFT — NOT APPLIED. Do not run as-is in production.
-- PROJECT:  hwbbdzwaismlajtfsbed  (FitmeBe&AI engine15042026, ap-northeast-1)
-- DRAFTED:  2026-06-30  (from `get_advisors` security + performance lints)
-- CONTEXT:  Project is normally PAUSED pre-launch; it was woken for the advisor
--           run on 2026-06-30 and re-paused afterward. Wake it again before
--           applying any of this.
--
-- BEFORE APPLYING — two open items:
--   1. cohort_stats lockdown assumes it is backend-only (service_role bypasses
--      RLS). If the iOS/AI client reads it directly, replace the REVOKEs with a
--      restrictive policy instead.
--   2. The PERFORMANCE section's RLS rewrites are TEMPLATES. Pull the live
--      policy bodies first (DB must be active):
--        SELECT schemaname, tablename, polname, roles, cmd, qual, with_check
--        FROM pg_policies
--        WHERE tablename IN ('user_profiles','sync_records','cardio_assets');
--      then finalize the exact USING / WITH CHECK expressions below.
--
-- FINDINGS COVERED:
--   SECURITY  1  ERROR  rls_disabled_in_public            public.cohort_stats
--   SECURITY  2  WARN   function_search_path_mutable      increment_cohort_frequency
--   SECURITY  3  WARN   pg_graphql_anon_table_exposed     4 tables (anon SELECT)
--   PERF      1  WARN   auth_rls_initplan                 user_profiles/sync_records/cardio_assets
--   PERF      2  WARN   multiple_permissive_policies      cardio_assets, sync_records
--   PERF      3  INFO   unused_index                      sync_records_user_modified
-- ============================================================================


-- ============================================================
-- SECURITY  (run in one transaction; verify; then COMMIT)
-- ============================================================
BEGIN;

-- ------------------------------------------------------------
-- 🔴 SECURITY 1 (ERROR): RLS disabled on public.cohort_stats
-- cohort_stats is an analytics aggregate, not user-facing. Default-deny:
-- enable RLS + revoke anon/authenticated SELECT so only the backend
-- (service_role — bypasses RLS) reaches it.
-- ⚠ If a client reads cohort_stats directly, DO NOT use the REVOKEs;
--   add a restrictive policy instead.
-- ------------------------------------------------------------
ALTER TABLE public.cohort_stats ENABLE ROW LEVEL SECURITY;
REVOKE SELECT ON public.cohort_stats FROM anon, authenticated;

-- ------------------------------------------------------------
-- 🟡 SECURITY 2 (WARN): mutable search_path on the cohort function
-- Pin search_path so it can't be hijacked. '' = fully-qualified names
-- only; if the body uses unqualified object names, use 'public, pg_temp'.
-- ------------------------------------------------------------
ALTER FUNCTION public.increment_cohort_frequency()
  SET search_path = '';            -- fallback: SET search_path = public, pg_temp

-- ------------------------------------------------------------
-- 🟡 SECURITY 3 (WARN): anon can discover tables via GraphQL.
-- Revoke pre-sign-in (anon) SELECT on user-owned tables. Their RLS
-- already gates rows for `authenticated`, so leave authenticated as-is
-- (revoking it would break legitimate signed-in access).
-- ------------------------------------------------------------
REVOKE SELECT ON public.user_profiles FROM anon;
REVOKE SELECT ON public.sync_records  FROM anon;
REVOKE SELECT ON public.cardio_assets FROM anon;

-- Verify before committing:
--   SELECT relname, relrowsecurity FROM pg_class
--   WHERE relname IN ('cohort_stats','user_profiles','sync_records','cardio_assets');
COMMIT;


-- ============================================================
-- PERFORMANCE  (separate transaction; needs live policy defs first)
-- ============================================================

-- ------------------------------------------------------------
-- 🟡 PERF 1 (WARN): auth_rls_initplan
-- Wrap auth.uid()/current_setting() in a scalar subquery so it is
-- evaluated ONCE per query instead of once per row.
-- TEMPLATE — recreate each flagged policy with its REAL column/expr:
-- ------------------------------------------------------------
-- ALTER POLICY own_profile ON public.user_profiles
--   USING ( user_id = (select auth.uid()) );
--
-- ALTER POLICY own_records ON public.sync_records
--   USING ( user_id = (select auth.uid()) )
--   WITH CHECK ( user_id = (select auth.uid()) );
--
-- ALTER POLICY own_assets ON public.cardio_assets
--   USING ( user_id = (select auth.uid()) )
--   WITH CHECK ( user_id = (select auth.uid()) );
-- (also applies to the named "Users read/insert/update/delete own ..." policies)

-- ------------------------------------------------------------
-- 🟡 PERF 2 (WARN): multiple_permissive_policies
-- cardio_assets & sync_records each carry TWO permissive policies for the
-- same role+action: a named "Users … own …" set AND a generic
-- own_assets / own_records. Keep one, drop the duplicate.
-- Verify which is canonical (pg_policies) before dropping.
-- ------------------------------------------------------------
-- DROP POLICY own_assets  ON public.cardio_assets;   -- if "Users … own cardio_assets" is canonical
-- DROP POLICY own_records ON public.sync_records;     -- if "Users … own sync_records"  is canonical

-- ------------------------------------------------------------
-- 🟦 PERF 3 (INFO): unused index — drop only if confirmed unneeded
-- ------------------------------------------------------------
-- DROP INDEX IF EXISTS public.sync_records_user_modified;
