# Phase 0 Research — Garmin Health Connection

> Feature: `garmin-health-connection` · Work type: Feature (new) · Phase 0 (Research) · 2026-06-10
> Parent: Task 10 — Health API connections (Garmin/Whoop/Oura/Samsung/Fitbit). Sibling: `fitbit-health-connection`.
> **Phase 0 entry:** brainstorm-pm framing below, then the standard research template.

---

## Brainstorm framing (problem / solution / assumption / strategy)

**Problem (JTBD).** *"When I train with my Garmin watch, I want the recovery + readiness signals it captures (HRV, sleep, RHR, Body Battery, training load) to drive FitMe's daily readiness + AI recommendations — so I don't have two apps telling me two different stories."* Garmin owns a large share of the serious-endurance/strength wearable market; those users are exactly FitMe's readiness-first audience.

**Solution space (3 alternatives — see comparison table §3).**
- **A — HealthKit relay (indirect).** The Garmin Connect app already writes to Apple Health. FitMe *already reads* HealthKit (`HealthKitService` + `HealthKitAdapter`). So a Garmin user who enables "Garmin Connect → Apple Health" sync already has their HRV/RHR/sleep flowing into FitMe today. The "feature" is mostly UX: detect the source, guide the connection, and confirm the data lands.
- **B — Direct Garmin Connect Health API.** OAuth 2.0 + a **server-side webhook receiver** (Garmin's Health API is push/ping, not client-polled) on the ai-engine backend, normalizing into a new `GarminAdapter: AIInputAdapter`. Gets metrics HealthKit doesn't expose (Body Battery, stress, training load/status). Requires **Garmin developer-program approval** (operator action, weeks of lead time, possible commercial terms).
- **C — Hybrid.** Ship A now; add B later *only* for the HealthKit-gap metrics, gated on measured demand.

**Assumption to test (the load-bearing one).** *Most target Garmin users already sync (or will sync) Garmin Connect → Apple Health, and HealthKit exposes the metrics FitMe's readiness engine needs.* — Partially verifiable now: HealthKit **does** expose HRV (`HKQuantityTypeIdentifier.heartRateVariabilitySDNN`), resting HR, sleep stages, VO2Max, steps — which is exactly what `ReadinessEngine` consumes (40% HRV / 30% RHR / 30% Sleep). The gap is Garmin-proprietary derived metrics (Body Battery, stress, training load) that Garmin does **not** write to HealthKit.

**Strategy (recommended).** **Ship A (HealthKit relay) first** — near-zero new infrastructure, no third-party approval, immediate value for the core readiness signals. **Measure** how many connected users actually have Garmin-sourced HealthKit data + whether they ask for the gap metrics. **Then decide** on B (direct API) with real demand data — avoiding a multi-week backend + approval effort for metrics that may not move retention.

---

## 1. What is this solution?

A first-class "Connect Garmin" path that brings a Garmin user's recovery + activity data into FitMe's readiness score and AI engine. Delivered in two tiers: **(Tier 1)** recognize + surface data Garmin already relays through Apple Health; **(Tier 2, optional)** a direct Garmin Connect Health API integration for the metrics HealthKit can't carry.

## 2. Why this approach?

FitMe's whole value proposition is "the app that knows what you should do today" from recovery signals. Garmin captures best-in-class HRV/sleep/training-load data. Today a Garmin user gets a *degraded* FitMe experience unless they happen to have Apple-Health relay on. Closing that gap directly serves the North-Star (cross-feature WAU) for a high-intent segment. The two-tier approach front-loads value (Tier 1) while deferring the expensive, approval-gated work (Tier 2) until demand justifies it.

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Approval? | Chosen? |
|---|---|---|---|---|---|
| **A — HealthKit relay** | Reuses existing `HealthKitAdapter`; covers HRV/RHR/sleep/VO2Max/steps (the readiness inputs); no OAuth; no backend; ships in days | Misses Garmin-proprietary metrics (Body Battery, stress, training load); depends on the user enabling Garmin→Apple Health | **S (days)** | **None** | **✅ Tier 1** |
| **B — Direct Garmin Connect Health API** | Full Garmin dataset incl. proprietary metrics; works without Apple-Health relay | OAuth + **server-side webhook receiver** (Health API is push, not poll); Garmin **developer-program approval required** (weeks, possible commercial terms); ongoing webhook ops + token refresh | **L (weeks)** | **Garmin partner approval** | **🔶 Tier 2 (deferred, demand-gated)** |
| **C — Hybrid (A now, B later)** | Value now + path to completeness | Two phases to track | — | — | **✅ The plan = A then maybe B** |

## 4. External sources (to deepen in PRD)

- Garmin Health API / Connect Developer Program — server-to-server **push (ping/webhook)** model, OAuth 2.0, daily summaries + wellness (HRV, sleep, stress, Body Battery, training load). *Access is gated behind partner approval; pricing/terms vary — operator must apply.* [docs to pin in PRD]
- Apple HealthKit — `HKQuantityTypeIdentifier` set FitMe already queries (HRV SDNN, resting HR, VO2Max, steps) + `HKCategoryType` sleepAnalysis. **This is the Tier-1 substrate — already built.**
- `ASWebAuthenticationSession` — the iOS OAuth-in-app pattern Tier 2 would use (no existing OAuth-client pattern in `FitTracker/Services`; Apple/Google go through Supabase).

## 5. Market examples

- **Training Today / Athlytic / Bevel / Gentler Streak** — readiness apps that source from **HealthKit only** and explicitly tell users "connect your Garmin to Apple Health." This validates Tier 1 as a legitimate, shipped pattern, not a shortcut.
- **TrainingPeaks / Intervals.icu** — direct Garmin Connect API integrations (Tier-2 class) — used by power users; they carry the partner-approval + webhook burden FitMe would defer.

## 6. UI

**Yes — `has_ui = true`.** A "Data Sources" / "Connect Garmin" surface in Settings: connection state, what data is flowing, a guided "enable Garmin → Apple Health" walkthrough for Tier 1 (deep-link to the Health app source toggle), and (Tier 2) an OAuth connect button + per-metric status. Design inspiration: Apple Health's "Sources" screen, Gentler Streak's source picker, Oura's integrations list. Reuses FitMe's Settings v2 scaffold + DS tokens.

## 7. Data & demand signals

- Garmin's share of the dedicated-fitness-wearable market is large among FitMe's readiness-first target. *(Quantify in PRD from any available analytics / store-review mentions.)* [T3 — narrative until instrumented]
- No in-app event yet measures "user has Garmin-sourced HealthKit data." A Tier-1 success metric is exactly this — instrument a `settings_data_source_detected{source:garmin}` event.

## 8. Technical feasibility

- **Tier 1 — high confidence.** `HealthKitService` + `HealthKitAdapter` already read the readiness inputs; the work is (a) source-attribution UX (HealthKit exposes `HKSource`/`HKSourceRevision` so FitMe can detect a Garmin-originated sample), (b) the guided-connection flow, (c) an analytics event. No new permissions beyond the existing HealthKit grant.
- **Tier 2 — real gates, deferred.** (i) **Garmin developer-program approval** — operator action, non-trivial lead time, the #1 blocker. (ii) **Server-side webhook receiver** — Garmin pushes data to a backend endpoint; ai-engine (FastAPI/Railway) is the natural host (new router + per-user token store + signature verification). (iii) **OAuth 2.0 (PKCE)** client in iOS via `ASWebAuthenticationSession`. (iv) **Encryption/privacy** — pulled data must land in the existing `EncryptedDataStore` (.ftenc) model; a third-party raw-data store on the backend is a new privacy surface needing a DPA review. (v) New `GarminAdapter: AIInputAdapter` for normalization into `LocalUserSnapshot`.

## 9. Proposed success metrics (draft — finalize in PRD)

- **Primary:** % of FitMe WAU with Garmin-sourced HealthKit data who have a non-empty readiness score (Tier 1 closes the "Garmin user, degraded experience" gap). Baseline 0 (uninstrumented); target TBD.
- **Secondary:** connect-flow completion rate; readiness-score coverage delta for the Garmin segment; (Tier 2 only) direct-API metric freshness.
- **Guardrails:** no regression to crash-free rate, cold-start, or the existing HealthKit read path; no plaintext third-party health data leaving the device (zero-knowledge invariant holds).
- **Kill criteria (Tier 2):** if Tier-1 adoption shows <X% of Garmin users ask for the gap metrics within 60 days, do NOT build the direct API.

## 10. Decision (recommended)

**Build Tier 1 (HealthKit relay + source-aware UX) as this feature's v1.** Defer Tier 2 (direct Garmin Connect Health API) behind a demand gate + the operator's developer-program application. This delivers the core readiness value in days instead of weeks, respects the zero-knowledge model, and avoids committing backend + approval effort to proprietary metrics whose retention impact is unproven.

**Open question for the operator (PRD input):** do you want this feature scoped to **Tier 1 only** (ship the HealthKit-relay connection experience), or **Tier 1 + a Tier-2 spike** (also start the Garmin developer-program application now so the option is open)? The Garmin approval lead time means starting the application early is the only thing that can't be parallelized later.
