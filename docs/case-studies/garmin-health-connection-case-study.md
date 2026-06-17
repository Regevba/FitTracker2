---
slug: garmin-health-connection-case-study
title: "Garmin Health Connection (Tier 1) — Source Attribution Without a Backend"
date: 2026-06-12
date_written: 2026-06-12
framework_version: v7.10
work_type: feature
work_subtype: new_feature
case_study_type: shipped
tier_tags_present: true
status: shipped
case_study: docs/case-studies/garmin-health-connection-case-study.md
case_study_showcase: fitme-story/content/04-case-studies/49-garmin-health-connection.mdx
dispatch_pattern: serial
related_prs:
  - 705  # Phase 0-6: research → PRD → tasks → UX → implementation → CI green
primary_metric:
  name: garmin_connected_wau_with_readiness_pct
  baseline: 0.0
  target: 70.0
  significance: descriptive
  review_at: 2026-06-26
  tier: T2
  note: "Target 70% of users who complete the connect flow have a populated readiness score within 7 days. T2 — declared, not yet measured; Tier-1 ships uninstrumented for connect-rate (baseline 0, no prior source-attribution surface existed)."
success_metrics:
  - name: garmin_connected_wau_with_readiness_pct
    baseline: 0.0
    target: 70.0
    significance: descriptive
    review_at: 2026-06-26
    tier: T2
  - name: connect_flow_completion_rate_pct
    baseline: 0.0
    target: 50.0
    significance: descriptive
    review_at: 2026-06-26
    tier: T2
kill_criteria: "If, 60 days post-launch, <20% of users who open the Data Sources screen with a Garmin device complete a connection, reassess whether Tier-1 UX is worth maintaining vs jumping straight to a Tier-2 demand signal."
kill_criteria_resolution: "not_yet_evaluated — pre-registered threshold: <20% of Garmin-device users who open Data Sources complete a connection within 60 days. First review 2026-06-26 (14d post-launch); kill checkpoint at 60d (~2026-08-11). Tier-1 ships uninstrumented for connect-rate; baseline 0."
platforms_tested:
  ios: true
  web: false
  backend: false
  ai: false
---

# Garmin Health Connection (Tier 1) — Source Attribution Without a Backend

## Summary

A Garmin owner who installs FitMe gets a degraded readiness experience unless they
already happen to have "Garmin Connect → Apple Health" sync enabled — and even then,
FitMe gives them no signal that their Garmin data *is* what powers their readiness
score. The gap was never data **access** (HealthKit already carries HRV/sleep/RHR);
it was **discovery, guidance, and confirmation**.

Tier 1 (this feature) closes that gap with **zero new backend, zero new permissions,
and zero new data leaving the device** — by attributing existing HealthKit samples to
their originating source (`HKSource`) and surfacing it in a new multi-source **Data
Sources** Settings surface. [T1 — shipped via PR #705]

## The Tier-1 / Tier-2 reframe (Phase 0)

The original backlog item ("Health API connections — Garmin/Whoop/Oura/Samsung/Fitbit")
implied direct vendor OAuth + backend webhooks. Phase 0 research reframed the scope into
two tiers:

- **Tier 1 (shipped):** HealthKit-relay. Garmin Connect already exports HRV/sleep/RHR/
  VO2Max/steps to Apple Health. FitMe just needs to *detect, attribute, and confirm*.
  No backend. No OAuth. No DPA change.
- **Tier 2 (deferred, demand-gated):** direct Garmin Connect Health API for the
  proprietary signals Apple Health never receives (Body Battery, stress, training load).

The operator approved **Tier 1 only for v1** (2026-06-10). The single forward hook is
the `GarminAdapter` seam — a thin `AIInputAdapter` whose `contribute(to:)` is a no-op
pass-through in v1 (the data already flows via `HealthKitAdapter`); its job is *presence
+ attribution*, leaving the contract Tier 2 would later fill.

## What shipped (PR #705)

| Task | Deliverable |
|---|---|
| T1 | `DataSourcesScreen` — shared multi-source Settings v2 surface (Garmin row + state) |
| T2 | `AIInputAdapter` source-presence protocol |
| T3 | `HealthKitSourceProbe` — `HKSource`/`HKSourceRevision` matching + testable shim |
| T4 | `GarminAdapter` — presence/attribution layer, Tier-2 seam |
| T5 | Guided connection flow + empty/partial states |
| T6 | UX spec (Phase 3 gateway — non-skippable for new UI) |
| T7 | 5 `settings_data_source_*` analytics events (screen-prefixed) |
| T8 | Analytics taxonomy rows |
| T9 | Device-free unit tests (probe + adapter) |
| T10 | Phase 6 ux + design pre-merge-review |

Source attribution matches Garmin Connect's Apple-Health bundle identifier
(`com.garmin.connect.mobile`) across the readiness-input sample types, with a fallback
heuristic for unknown source-name variants (logged for later refinement).

## Design-system + privacy posture

- New UI ⇒ **Phase 3 UX gateway non-skippable**; `ux-spec.md` authored and preflight-passed
  before any view code. `make ui-audit` P0=0; `DataSourcesScreen` 0 findings.
- No high-risk files touched (no `DomainModels` / `EncryptionService` / `*SyncService` /
  `SignInService` / `AuthManager` / `AIOrchestrator`). Review risk: **LOW**.
- **Zero-knowledge invariant holds** — nothing new leaves the device; no backend; DPA
  unaffected. The feature reads what HealthKit already has and labels its origin.

## Metrics & kill criteria

- **Primary:** % of Garmin-connected WAU with a non-empty readiness score. Baseline 0
  (no source-attribution existed); target ≥70% within 7 days of connect. [T2 — declared]
- **Secondary:** connect-flow completion rate ≥50% [T2]; readiness-coverage delta for the
  Garmin segment [T1 once instrumented].
- **Guardrails:** crash-free >99.5%, cold start <2s, existing HealthKit read path
  unaffected, zero-knowledge invariant holds.
- **Kill criteria:** <20% connect-completion among Garmin-device Data-Sources openers at
  60 days ⇒ reassess Tier-1 UX vs Tier-2 demand signal. **Resolution:** not yet evaluated;
  first review 2026-06-26 (14d), kill checkpoint ~2026-08-11 (60d).

## Framework provenance

- **CU v2:** 2.0 (B_medium) — moderate complexity, low-medium blast radius, medium novelty
  (first source-attribution surface), medium-high verification difficulty (true connect
  verification needs a physical Garmin device — Tier 2.1 area).
- **Closure note:** PR #705 squash-merged to `main` 2026-06-12 (`c8ba299`, 17/17 CI checks
  green). The state.json closure (cu_v2 backfill + phase advance merge → complete) landed
  separately as a post-merge chore — the documented squash-merge drift pattern that F2
  Phase-0 reality-check and `make close-feature` exist to reconcile.

## What Tier 2 would add (deferred)

Direct Garmin Connect Health API + backend webhook for Body Battery / stress / training
load — the proprietary signals Apple Health never carries. Demand-gated: it ships only if
the Tier-1 connect-rate clears the kill threshold and there's pull for the proprietary
metrics.
