# Tasks — Garmin Health Connection (Tier 1, v1)

> Phase 2 (Tasks) · 2026-06-10 · scope = Tier 1 (HealthKit relay).
> **Garmin carries the shared foundation** (T1–T3, T6, T8) that the Fitbit sibling
> depends on. Fitbit's tasks.md lists those as upstream dependencies.
> Complexity tiers drive dispatch (lightweight=haiku, standard=sonnet, heavyweight=opus).

## Shared foundation (Garmin-owned; Fitbit depends on these)

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T1** | `DataSourcesScreen` scaffold — multi-source Settings v2 screen, DS-token compliant, one row per source, connection-state + signal chips | `FitTracker/Views/Settings/v2/Screens/DataSourcesScreen.swift` + nav wiring in Settings v2 root | **heavyweight** | New UI surface → **Phase 3 UX spec required first**. Designed multi-source (Garmin + Fitbit rows from day 1). |
| **T2** | Extend `AIInputAdapter` usage with a *source-presence* protocol — a way to ask "is there `<source>`-origin data for sample type X?" over HealthKit | `FitTracker/AI/Adapters/AIInputAdapter.swift` (or a sibling `HealthKitSourceProbe.swift`) | **standard** | Read-only `HKSource`/`HKSourceRevision` probe across readiness-input sample types (HRV SDNN, RHR, sleep, VO2Max, steps). No new permission. |
| **T3** | `HealthKitSourceProbe` impl — query newest sample per readiness type, expose `{type → set<HKSource>}` + `lastUpdated` | `FitTracker/Services/HealthKit/HealthKitSourceProbe.swift` + unit-testable shim | **standard** | Pure over an injectable HK store so it's unit-testable without a device. |
| **T6** | UX spec for the Data Sources screen (`/ux` + `/design preflight`) | `.claude/features/garmin-health-connection/ux-spec.md` + `figma_node_ids` | **heavyweight** | Phase 3 gateway. Covers both Garmin + Fitbit rows + the empty/partial/connected states. |
| **T8** | Analytics taxonomy rows — register the 5 `settings_data_source_*` events (with `source` dimension) in `docs/product/analytics-taxonomy.csv` | `docs/product/analytics-taxonomy.csv` | **lightweight** | Screen-prefix compliant (`settings_`). |

## Garmin-specific

| # | Task | Files | Complexity | Notes |
|---|---|---|---|---|
| **T4** | `GarminAdapter: AIInputAdapter` — `sourceID="garmin"`, presence/attribution via T3 probe matching Garmin bundle IDs (`com.garmin.connect.mobile`); `contribute(to:)` no-op pass-through in v1 | `FitTracker/AI/Adapters/GarminAdapter.swift` | **standard** | The Tier-2 seam. Match a *set* of known Garmin source identifiers + log unknowns. |
| **T5** | Garmin guided-connection flow — empty-state walkthrough ("Open Garmin Connect → enable Apple Health"), deep-link to Health app source screen where available | within `DataSourcesScreen` + a `ConnectGuidanceView` | **standard** | Distinguish "not connected" vs "connected, awaiting daily sync". |
| **T7** | Wire the 5 analytics events at their triggers (viewed/detected/connect_started/connect_completed/empty_state) | `DataSourcesScreen` + analytics service | **standard** | `source:garmin`. `time_to_detect_s` on completed. |
| **T9** | Tests — `HealthKitSourceProbe` unit tests (injected HK store, Garmin-origin fixtures) + `GarminAdapter` presence tests; snapshot-skip until T4-Phase-A baselines blessed | `FitTrackerTests/HealthKitSourceProbeTests.swift`, `GarminAdapterTests.swift` | **standard** | Device-free, deterministic fixtures (mirrors T3/T5/T10 discipline). |
| **T10** | Pre-merge: `/ux pre-merge-review` + `/design pre-merge-review` (ui-audit P0=0, figma_node_ids referenced in PR) | — | **lightweight** | Phase 6 gates. |

## Sequencing

1. **T6 (UX spec)** → gates all view code (Phase 3, non-skippable).
2. **T2 + T3** (probe foundation) can proceed in parallel with T6.
3. **T1** (screen) after T6 approved; **T4 + T5** after T1 + T3.
4. **T8** early (taxonomy); **T7** after T1; **T9** alongside T3/T4.
5. **T10** at Phase 6.

## Platform-test parity (`platforms_tested`)

This feature is **iOS-only** (`ios: true`; web/backend/ai: false — Tier 1 has no backend). T9 establishes the `ios` test evidence.

## Out of scope (Tier 2 — deferred)

Direct Garmin Connect Health API, OAuth (`ASWebAuthenticationSession`), backend webhook receiver, Body Battery / stress / training-load ingestion. The `GarminAdapter` `contribute(to:)` seam is the only forward hook left in place.
