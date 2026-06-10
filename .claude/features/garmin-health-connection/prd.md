# PRD — Garmin Health Connection (Tier 1, v1)

> Feature: `garmin-health-connection` · Phase 1 (PRD) · 2026-06-10
> **Scope (operator-approved 2026-06-10): Tier 1 only.** HealthKit-relay connection
> experience. Tier 2 (direct Garmin Connect Health API) is explicitly OUT of scope for
> v1 and deferred to a future demand-gated feature.
> Sibling: `fitbit-health-connection` (shares the Data-Sources surface + adapter contract).
> Research: [`research.md`](research.md).

## 1. Problem & opportunity

A Garmin user who installs FitMe today gets a **degraded** readiness experience unless
they already happen to have "Garmin Connect → Apple Health" sync enabled — and even then,
FitMe gives them no signal that their Garmin data *is* the thing powering their readiness
score. FitMe's entire value proposition ("the app that knows what you should do today")
depends on recovery signals; Garmin captures best-in-class HRV/sleep/RHR. The gap is not
data access (HealthKit already carries it) — it's **discovery, guidance, and
confirmation**.

## 2. Goals / non-goals

**Goals (v1, Tier 1):**
- Let a Garmin user connect their Garmin data to FitMe in a guided, legible way (via the existing HealthKit grant + Garmin Connect's Apple-Health export).
- Detect when HealthKit samples originate from Garmin (`HKSource`) and surface that the readiness engine is using them.
- Give a clear empty/partial state when the readiness signals are NOT present (Garmin→Apple Health not enabled, or signal missing).
- Instrument the connection so we can measure adoption + the readiness-coverage delta for the Garmin segment.

**Non-goals (v1):**
- ❌ Direct Garmin Connect Health API / OAuth / backend webhook (Tier 2 — deferred).
- ❌ Garmin-proprietary metrics (Body Battery, stress, training load) — not exposed to HealthKit.
- ❌ Writing data back to Garmin.
- ❌ Android / Health Connect (iOS-first; FitMe is SwiftUI).

## 3. Scope (Tier 1 deliverables)

1. **Multi-source "Data Sources" Settings surface** (shared with Fitbit sibling) — a new Settings v2 screen listing connectable sources; Garmin row shows connection state + which signals are flowing.
2. **Garmin source detection** — read `HKSource` / `HKSourceRevision` on the readiness-input sample types (HRV SDNN, resting HR, sleep, VO2Max, steps) to determine whether Garmin-origin data is present.
3. **Guided connection flow** — when Garmin data isn't detected, a walkthrough: "Open Garmin Connect → enable Apple Health sync" (with a deep-link to the Health app source screen where the OS allows).
4. **`GarminAdapter` (thin, Tier-1)** — conforms to `AIInputAdapter`; in v1 it is a *source-attribution + presence* layer over the existing HealthKit reads, NOT a separate data fetch (the data already arrives via `HealthKitAdapter`). Establishes the contract Tier 2 would later fill.
5. **Analytics** — events per §5.

## 4. User stories

- *As a Garmin owner*, I open FitMe Settings → Data Sources, see "Garmin", and understand whether my watch's data is feeding my readiness score.
- *As a Garmin owner without Apple-Health sync on*, I get a clear, actionable walkthrough to enable it — and FitMe confirms once data starts flowing.
- *As a Garmin owner whose readiness score looks empty*, I see *why* (signal not present) instead of a silent blank.

## 5. Analytics spec (screen-prefixed per CLAUDE.md convention)

| Event | Trigger | Key params | screen_scope |
|---|---|---|---|
| `settings_data_sources_viewed` | Data Sources screen shown | — | settings |
| `settings_data_source_detected` | A source's data found in HealthKit | `source: garmin`, `signals: [hrv,rhr,sleep,...]` | settings |
| `settings_data_source_connect_started` | User taps "Connect Garmin" / guided flow opened | `source: garmin` | settings |
| `settings_data_source_connect_completed` | Garmin data first detected after a connect flow | `source: garmin`, `time_to_detect_s` | settings |
| `settings_data_source_empty_state_shown` | Garmin selected but no signal present | `source: garmin`, `missing: [hrv,...]` | settings |

All events follow the `settings_` screen-prefix rule. `source` is a dimension so the same
events serve Fitbit/Whoop/Oura without new event names.

## 6. Success metrics

- **Primary:** **% of Garmin-connected WAU with a non-empty readiness score.**
  - *Baseline:* 0 (uninstrumented today — no source-attribution exists).
  - *Target:* ≥ 70% of users who complete the connect flow have a populated readiness score within 7 days. [T2 — Declared target]
  - *Measurement:* `settings_data_source_detected{source:garmin}` ∩ readiness-score-populated event.
- **Secondary:**
  - Connect-flow completion rate (`connect_started` → `connect_completed`) ≥ 50%. [T2]
  - Readiness-score coverage delta for the Garmin segment vs pre-feature baseline. [T1 once instrumented]
- **Guardrails (must not regress):** crash-free > 99.5%; cold start < 2s; existing HealthKit read path unaffected; **zero-knowledge invariant holds** (no plaintext health data leaves device).
- **Kill criteria:** if, 60 days post-launch, **< 20%** of users who open the Data Sources screen with a Garmin device actually complete a connection (i.e., the guided flow doesn't move the needle), reassess whether Tier 1 UX is worth maintaining vs jumping straight to a Tier-2 demand signal. [T2]
- **First review:** 14 days post-launch, then at the 60-day kill-criteria checkpoint.

## 7. Technical approach (Tier 1)

- **No new permissions** — rides the existing HealthKit authorization (`HealthKitService`).
- **Source attribution** — `HKSource.name` / `bundleIdentifier` matching for Garmin Connect (`com.garmin.connect.mobile`) across the readiness-input sample types.
- **`GarminAdapter: AIInputAdapter`** — `sourceID = "garmin"`, `lastUpdated` from the newest Garmin-origin sample, `contribute(to:)` is a no-op pass-through in v1 (data already flows via `HealthKitAdapter`); the adapter's job is *presence + attribution*, establishing the Tier-2 seam.
- **UI** — new `DataSourcesScreen` under `FitTracker/Views/Settings/v2/Screens/`, DS-token compliant, reuses Settings v2 row components. Phase 3 (UX) gateway is **non-skippable** (new UI surface).
- **Privacy** — nothing new leaves the device; no backend; DPA unaffected.

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Garmin's Apple-Health bundle ID / source name varies by app version | Med | Match on a set of known identifiers + fall back to "any non-Apple-Watch HR/HRV source" heuristic; log unknowns |
| Users conflate "connect" with a direct login (expect OAuth) | Med | Copy makes clear this routes through Apple Health, not a Garmin login |
| Readiness signals present but sparse (Garmin syncs daily, not continuously) | Low | Empty-state copy distinguishes "not connected" from "connected, waiting for sync" |
| Scope creep toward Tier 2 | Med | This PRD explicitly fences Tier 2; the adapter seam is the only forward hook |

## 9. Rollout

Standard PM lifecycle. New UI ⇒ Phase 3 UX gateway + `ux-spec.md` required before view code. Snapshot/UI-audit gates apply. Ships behind no flag (additive Settings surface); analytics live from day 1 so the 14-day + 60-day reviews have data.

## 10. Open questions for Tasks phase

- Exact Garmin Connect bundle identifier(s) to match (verify against a real device export).
- Whether the Data Sources screen ships first as Garmin+Fitbit together or Garmin-first then Fitbit appends a row (recommend together — sibling PRDs reviewed jointly).
- Deep-link availability to the Health app's per-source screen (iOS version dependent).
