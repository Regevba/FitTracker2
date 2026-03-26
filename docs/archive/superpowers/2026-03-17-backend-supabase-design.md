# Archived: Backend Supabase Auth + Sync Design

Original local filename: `docs/superpowers/specs/2026-03-17-backend-supabase-design.md`

## Status

Archived on March 26, 2026. This was an approved planning document, but its assumptions no longer match current implementation truth.

## Why It Was Archived

- It assumed full Supabase-backed app auth and sync that are not implemented in the tracked app runtime.
- It treated `UserSession.sessionToken` as a Supabase JWT, which is now explicitly avoided in the app model.
- It described future services and files that do not exist in the current tracked codebase.

## Historical Value

This document is still useful for:

- planned long-term account-bound sync direction
- security goals for encrypted server-side storage
- future extraction boundaries between app and backend

## Replacement Sources

- current backend schema and policy truth: `backend/README.md`
- current app auth/runtime truth: root `README.md` and `FitTracker/Services/Auth/`
