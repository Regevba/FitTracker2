---
slug: control-room-live-feed-case-study
title: "Control Room Live Feed — From Build-Time Snapshot to Fail-Soft Request-Time Data"
date: 2026-06-16
date_written: 2026-06-16
framework_version: v7.10
work_type: enhancement
work_subtype: unified-control-center
parent_feature: unified-control-center
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/control-room-live-feed-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/50-control-room-live-feed.mdx
dispatch_pattern: serial
success_metrics:
  - "Control-room data staleness drops from deploy-bound (hours-to-days) to request-time (<= 120s revalidate) once activated [T2 — declared]."
  - "Zero behavior change before activation: with no secrets set the dashboard renders identically to the build-time snapshot path [T1 — next build green, 118/118 pages]."
  - "Fail-soft proven: 48 unit tests cover no-token / non-200 / network-reject / malformed degradation without throwing [T1]."
related_prs:
  - 224   # fitme-story — Phase 1 PR A: fail-soft live external-source health
  - 225   # fitme-story — Phase 2 PR C: live-or-snapshot Blob data-source layer
  - 226   # fitme-story — Phase 2 PR F: freshness footer live-vs-snapshot
related_prs_ft2:
  - 742   # FT2 — Phase 2 PR D: push-state-bundle producer + workflow
  - 739   # FT2 — source-refresh of health-status + external-sync ledgers
primary_metric:
  name: control_room_data_staleness_seconds
  baseline: deploy-bound (hours-to-days; refreshes only on redeploy)
  target: request-time (<= revalidate window, 120s)
  significance: descriptive
  review_at: 2026-06-30
  tier: T2
  note: "T2 — declared, not yet measured. Activation is gated on two operator secret steps (PR B + PR E); until then the control room serves the build-time snapshot. Measurable once FT2_STATE_BLOB_URL is set."
kill_criteria:
  - "A live fetch failure ever crashes or blanks a control-room page (must always degrade to the snapshot)."
  - "The public state Blob ever contains PII (operator/session labels) that the allow-list should have excluded."
kill_criteria_resolution: >
  Not triggered. Fail-soft is enforced in code + tests: every probe and the
  data-source layer return null/degraded (never throw); 16 + 16 + 9 + 7 unit
  tests cover the no-token / non-200 / network-reject / malformed paths, and the
  producer's allow-list (vs denylist) is asserted to exclude agent-leases.json
  and every non-allow-listed shared file. With no secrets configured the whole
  control room renders identically to the pre-change build-time path
  (`next build` green, 118/118 pages), so the enhancement is reversible by
  simply not setting (or unsetting) the env vars.
---

# Control Room Live Feed

## Problem (T3)

The Unified Control Center (`fitme-story.vercel.app/control-room/*`) was **complete and deployed**, but every panel rendered a **build-time snapshot**. `scripts/sync-from-fittracker2.ts` cloned FitTracker2 at build and copied `.claude/*` JSON into `fitme-story/src/data/*`; pages read those files at render. Freshness was therefore bound to deploy time.

A 2026-06-16 source-refresh made the cost concrete (T1, observed): the synced ledgers were ~10 days stale, and the infrastructure health ledger reported Railway / CloudKit / Firebase as `unknown` purely because **no source was queried at runtime** (FT2 #739 refreshed the ledgers but the staleness was structural, not a one-off).

## Approach (T3)

Two data classes, two phases, one invariant.

- **Phase 1 — external SaaS** (GitHub, Vercel, Linear, Notion, Supabase, GA4): real APIs, fetched server-side at request time.
- **Phase 2 — FT2 framework state** (`state.json`, integrity ledgers, gate-coverage, membrane status): git-resident in FitTracker2, no API. Reaches the site via **Vercel Blob push on commit** — reusing the existing `@vercel/blob` + deterministic-public-URL + `CRON_SECRET` pattern already proven by the audit-log cron.

**The load-bearing invariant: fail-soft.** Build-time sync is fail-fast (a bad sync should break the build). The live runtime is the opposite — any fetch failure must degrade to the existing `src/data/*` snapshot, never crash a page. `src/data/*` + the prebuild sync remain the committed fallback throughout; the live layer is purely additive.

## What shipped (T1 — merged PRs)

| PR | Phase | What |
|---|---|---|
| fitme-story #224 | 1 (A) | `src/lib/control-room/live/*` — one fail-soft probe per source, gathered via `Promise.allSettled`, merged over the synced snapshot; `LiveSourceHealthPanel` on the overview. |
| fitme-story #225 | 2 (C) | `src/lib/live-data/data-source.ts` — reads the FT2 state Blob once per request (React `cache()`); 5 loaders (`builder`, `load-features`, `load-ledgers`, `loadGateCoverage`, `load-membrane`) route through it with an fs fallback. |
| FT2 #742 | 2 (D) | `scripts/push-state-bundle.py` (allow-list assembler) + `scripts/put-state-bundle.mjs` (`@vercel/blob put()`) + `.github/workflows/push-state-bundle.yml` — publishes the public bundle on push to main. |
| fitme-story #226 | 2 (F) | `DataFreshnessFooter` shows provenance: green "Live as of … · commit `<sha7>`" vs "Last synced …". |

Tests: 16 (probes) + 16 (data-source) + 9 (producer) + 7 (footer) = **48 unit tests**, all green; `next build` 118/118 on every fitme-story PR.

## Design decisions (T3)

- **Allow-list, never denylist, for the public bundle.** The producer ships only the ~9 shared files the consumer reads plus all `features/<slug>.json`; PII-bearing ledgers (`agent-leases.json`) are structurally excluded and a test enforces it. A public artifact earns an allow-list.
- **Neutral `src/lib/live-data/`.** `data-source.ts` first lived under `control-room/live/`, but the §7.2 extraction-readiness ESLint rule forbids `framework-health` ("showcase") code from importing `**/control-room/*` ("dashboard"). Caught by lint pre-commit; moved to a neutral location both sides may import.
- **Independent, merge-safe PRs.** Every PR is a no-op without secrets, so all four merged in any order without coordination and without changing observed behavior.

## Status & activation (T2)

Engineering is complete and merged (#224, #225, #742; #226 in review). The feed is **not yet live** — activation is two operator-only secret steps, by design:

1. **PR B** — Phase 1 source tokens in Vercel env → the Source Health panel goes live source-by-source.
2. **PR E** — `BLOB_READ_WRITE_TOKEN` (FT2 repo secret, so the #742 workflow publishes) + `FT2_STATE_BLOB_URL` (fitme-story env) → the loaders + freshness footer flip live.

The primary metric (request-time staleness vs deploy-bound) becomes measurable only after PR E; this case study will be revisited at the 2026-06-30 review.

## Lesson (T3)

Adding a live path to a snapshot-backed surface is safe if and only if the live path is strictly additive and fail-soft: keep the snapshot as the committed fallback, make every accessor return null-not-throw, and prove the no-credential path renders identically. That property is what let four cross-repo PRs ship independently with zero behavior change — the risk lives entirely behind two env vars the operator controls.

**Known nuance:** `.claude/logs/gate-coverage.jsonl` is gitignored, so CI checkout cannot bundle it; that single stream falls back to the consumer's synced snapshot (fail-soft, as designed).
