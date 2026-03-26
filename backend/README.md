# FitTracker Backend

Source of truth for the SQL cohort backend. This directory is intended to become the future `fittracker-backend` repo; until extraction, edit this directory for backend schema, policies, and migration behavior.

## What It Does

- Stores anonymised cohort frequency counts in `cohort_stats`
- Exposes an increment RPC for service-side writes
- Applies RLS for read/write separation
- Schedules retention cleanup when `pg_cron` is available

## Current Layout

- `supabase/migrations/`: ordered schema and policy migrations
- `supabase/seed/`: development and CI seed data
- `.github/workflows/ci.yml`: migration validation workflow

## Operational Truth

- `000002_increment_cohort_frequency.sql` is `SECURITY DEFINER` and now explicitly revokes `PUBLIC` execute access
- `000004_retention_pg_cron.sql` degrades safely when `pg_cron` is unavailable instead of failing all migrations
- Current CI validates migrations against plain PostgreSQL 15, so migrations must stay compatible with non-Supabase environments when possible

## Validation

CI expectations:

- run migrations in order
- verify `cohort_stats` schema
- run seed data
- verify seeded row counts by segment

This backend currently supports cohort intelligence only. It is not yet the canonical app account/auth backend.
