# Trend Alerts (HRV Threshold) — Phase 0 Research

> **Feature type:** Feature (9-phase: Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs)
> **RICE:** 10.5 (second on the refreshed Planned ranking, after C2 which shipped 2026-06-01)
> **Backlog source:** `docs/product/backlog.md` L346 row (line 374): "Trend alerts — no notification when HRV drops below threshold for 3+ days"

## 1. Problem

FitMe has three notification observers operational as of 2026-06-01:

| Observer | Trigger | Window | Status |
|---|---|---|---|
| `ReadinessAlertObserver` | Score crosses ≥80 OR ≤40 | Single-day event | Shipped 2026-05-07 (PR #239) |
| `ReadinessAwareTrainingObserver` (C2) | Readiness + scheduled training day | Today only, at learned start time | Shipped 2026-06-01 (PR #560, awaiting merge) |
| `TrendAlertsObserver` (C4 — this feature) | — | — | **Missing** |

What none of them catches: a **sustained downward HRV pattern** that doesn't trip any single-day score threshold but indicates accumulating fatigue, infection onset, or chronic sleep deficit. Power users with consistent HRV history (4+ weeks of HealthKit data, layer ≥ 2) report wanting an early-warning signal here. The score-crossing observer requires a hard ≤40 hit, which is too late; the pre-training observer fires only on scheduled-training days, leaving the warning silent during rest-day stretches when the pattern is also informative.

## 2. The 3-day-below-baseline pattern

**Trigger algorithm (proposed):**

```
let hrvBaseline = personalBaseline(window: last30Days, percentile: 50)   // user's median
let hrvFloor    = max(hrvBaseline - oneStandardDeviation, hardFloor=25)  // adaptive cutoff

let recentDays  = healthKit.hrvDailyReads(window: last3CompletedDays)
let belowFloor  = recentDays.allSatisfy { $0 <= hrvFloor }
let dataQuality = recentDays.count == 3  // require 3 actual reads, not 2

if belowFloor && dataQuality && !alreadyFiredWithinWindow(7d) {
    fire(.trendAlert(.hrvSustainedLow))
}
```

**Why personal-baseline vs absolute threshold:**

HRV varies 10x across the population (range ~15–150 ms RMSSD). An absolute "below 30 ms" threshold would over-fire for athletes and under-fire for sedentary users. The personal baseline is computed from the user's own 30-day median (matches FitMe's existing `ReadinessEngine` Layer 1+ logic), with adaptive 1-σ offset.

**Why hard floor:**

For cold-start users (< 14 days of data, Layer 0), no reliable personal baseline exists. `hardFloor = 25` is a conservative absolute cutoff (~10th percentile across the general population). At Layer 0, we still fire when 3 days are below 25 ms — but the notification copy is more cautious ("HRV has been low recently — consider extra recovery"). The case study will calibrate this against post-launch FP rate.

**Re-fire de-dupe:**

Once fired, suppress for 7 days. Pattern is sustained — re-firing every day during a multi-week dip would be spam. After 7d, if the pattern persists, re-fire (now with stronger copy referencing the sustained duration).

## 3. The three surfaces

1. **Push notification** at ~08:00 local (fallback; future: learn from app-open time-of-day). Distinct cap tag `.standard` (advisory, not critical). De-dupe per 7-day window per the trigger.
2. **Home `AIInsightCard` banner** — when `TrendAlertStore.current()` is non-nil, the card overrides default content with "HRV trend: 3 days below baseline" headline + "Tap for details" subtitle.
3. **`AIIntelligenceSheet` Why? affordance** — new section "Your HRV Trend" with a 7-day mini-chart showing HRV daily reads + the personal baseline overlay. Reuses the existing readiness-bar visual language for consistency.

**Avatar mode mapping:** sustained-trend pattern → `.pulse` (advisory; matches C2's adaptEasierLoad pattern). No new avatar mode.

## 4. Distinction from C2 (readiness-aware-training-alert)

C2 ships as a parent-smart-reminders Enhancement; this is a parent-NONE Feature.

| Dimension | C2 (readiness-aware-training-alert) | C4 (trend-alerts-hrv) |
|---|---|---|
| Trigger window | Today only | Rolling 3-day window |
| Schedule | At learned training time-of-day | ~08:00 local (advisory morning) |
| Activation | Only if today is scheduled training day | Daily regardless of training schedule |
| Recommendation surface | 3 CTAs (continue / lighten / swap) | Single CTA (acknowledge) + Why? deep-link |
| Avatar mode | `.shimmer` / `.pulse` / `.breathe` mapped to recommendation | Always `.pulse` (advisory) |
| Cap tag | `.standard` | `.standard` |
| Re-fire window | Per-day (one per local day) | Per-7-days (sustained pattern) |

**Shared-file conflict mitigation:** C2 PR #560 modifies `AIInsightCard.swift` + `AIIntelligenceSheet.swift` + `ReminderPreferencesStore.swift` + analytics provider/service. C4 will need to touch the same files. Three options for Phase 1+:

- **Option A** — If C2 merges first: C4 rebases onto main, adds its banner-override logic alongside C2's `readinessAware.current()` check. Both stores coexist as `@EnvironmentObject`s.
- **Option B** — If C4 merges first: C2 rebases onto main, both stores' overrides interleave (C2 takes precedence on training days; C4 fills the gap on rest days when both have an alert ready).
- **Option C** — If both ship in the same window: do C4's Phase 4 (Implement) AFTER C2 merges to avoid pbxproj + Swift-view conflicts. This adds 1–2 days of wait but is the lowest-risk path.

Phase 0 recommends **Option C** if PR #560 still needs operator approval at C4 Phase 1 kickoff; otherwise **Option A** if C2 has merged. Phase 1 (PRD) will codify the picked branch.

## 5. Success metrics + kill criteria

| Metric | Tier | Baseline | Target | Window |
|---|---|---|---|---|
| Trend-alert action-taken rate | T2 | 0% | ≥ 30% (alert tap → AIIntelligenceSheet open) | 14d post-launch |
| User-reported false-positive rate | T3 | 0% | < 15% (via in-app feedback button) | 30d |
| HRV recovery within 7 days of fire | T1 | — (descriptive) | descriptive only | 14d |
| Push-fatigue rate (advisory dismissals / shown) | T2 | 60% (current `ReadinessAlertObserver` baseline) | ≤ 60% | 30d |

**Kill criteria (any of):**

- Action-taken rate < 5% after 14d of organic exposure → advisory ignored
- User-reported FP rate > 20% via in-app feedback → algorithm too noisy (revisit thresholds)
- Push-fatigue rate > 75% → advisory treated as spam (revisit cadence)

If any kill criterion fires during the 30-day window: `make integrity-check` cycle will flag for re-evaluation. Resolution = either threshold-tuning patch OR feature kill via opt-out-default-true setting flip.

## 6. Mechanical dependencies

| Dependency | Status | Notes |
|---|---|---|
| `HealthKitService.hrvDailyReads(window:)` | ✅ shipped | Provides daily aggregated HRV values |
| `ReadinessEngine.personalBaseline(window:percentile:)` | ✅ shipped | Will be reused for the baseline computation |
| `NotificationGateway.dispatch(...)` | ✅ shipped (PR #239) | Standard v2 dispatch path |
| `NotificationConsumerRegistry` | ✅ shipped | Registers new consumer at app-init |
| `DeepLinkRouter` `fitme://nav/home` | ✅ shipped | Reusable from C2 / ReadinessAlertObserver |
| `EncryptedDataStore` (DailyLog persistence) | ✅ shipped | HRV history persists in `DailyBiometrics.hrv` |
| `AIInsightCard` + `AIIntelligenceSheet` | ✅ shipped | Surface-level UI (see Option A/B/C above) |

**No new infrastructure required.** All dependencies are operational at v7.9.

## 7. Scope NOT in C4

To keep scope tight (RICE confidence 0.75 reflects the conservative path):

- **No sleep-trend mirror.** Sleep also has a multi-day pattern but ships as a follow-on if HRV trend works.
- **No nutrition-trend mirror.** Same logic.
- **No multi-metric fusion** (HRV ∩ RHR ∩ Sleep). Composite is harder to explain to the user; one signal at a time.
- **No predictive overlay** ("you'll bottom out tomorrow at 28 ms"). T1/T3 — too low-confidence to surface as a claim.
- **No on-device learning of baseline** beyond the rolling 30-day median already computed by ReadinessEngine. Personalization-layer-3 + adaptive thresholds can ship in follow-up.

Future surface area:

- **C4.b** — multi-signal trend alerts (HRV + RHR + Sleep composite)
- **C4.c** — predictive trend overlay (calibrated 1d / 3d forecast)
- **C4.d** — opt-in early-warning mode (lower threshold + higher cadence)

These all ship as Enhancements parent=trend-alerts-hrv after C4 base ships.

## 8. Phase E discipline

C4 is a Feature; ships during Phase E soak (2026-05-21 → 2026-06-04). **No new enforcement gates added.** Consumes existing v7.9 infrastructure exclusively. Phase E compliant.

## 9. Phase 0 → Phase 1 transition criterion

- Operator approves this research.md (scope + algorithm + thresholds + success metrics)
- PRD authoring begins on operator go-ahead
- Phase 1 (PRD) freezes: trigger algorithm constants (`hardFloor`, `baselineWindow`, `sustainedDays`, `refireWindow`), analytics event names, opt-out toggle copy, Settings screen placement

## 10. Cross-references

- Backlog row: `docs/product/backlog.md` L346 line 374
- E1 RICE refresh PR: #559 (merged 2026-05-31)
- C2 case study (informs scope_vs_c2): `docs/case-studies/readiness-aware-training-alert-case-study.md`
- ReadinessAlertObserver source: `FitTracker/Services/Notifications/ReadinessAlertObserver.swift`
- ReadinessAwareTrainingObserver source: `FitTracker/Services/Reminders/ReadinessAwareTrainingObserver.swift` (in PR #560)
- HealthKit daily read API: `FitTracker/Services/HealthKit/HealthKitService.swift`
