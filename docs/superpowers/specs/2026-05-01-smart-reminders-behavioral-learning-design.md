# Smart Reminders — Behavioral Learning Layer (design spec)

| Field | Value |
|---|---|
| Date | 2026-05-01 |
| Author | Regev (with Claude Opus 4.7) via brainstorming session |
| Parent feature | `smart-reminders` (shipped 2026-04-16, code; PR #98 tests; case study 2026-04-20) |
| Sub-feature scope | SR-17 (data collection) + SR-18 (smart timing automation) — both already in parent PRD as P2 |
| Work type | Feature (full PM lifecycle — own PRD content lives in this spec) |
| Framework version | v7.7 |
| Branch | `feature/smart-reminders-behavioral-learning` (refreshed off `main` 2026-05-01) |
| Status | Spec (post-brainstorm) — implementation plan pending |
| Brainstorm artifacts | `.claude/features/smart-reminders-behavioral-learning/research/open-questions.md` (full lock record) |

---

## 1. Summary

Adapt the existing six-type smart-reminder system (`ReminderScheduler` + `ReminderType` + `ReminderTriggerEvaluator`) to fire each personalisable reminder type at the per-user hour with the highest tap-through probability, using a Bayesian posterior weighted against a server-side cohort prior. Three of six types personalise (Nutrition Gap, Training Day, Rest Day); the other three (HealthKit Connect, Account Registration, Engagement) cap too low or fire too sparsely and keep their static fire times. Ships in three staged PRs against an A/B test that gates merge of the second PR; success threshold is +5 pp aggregate tap-through lift over a 14 ± 4 day per-user readout window. Reuses the existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC (migrations 000001–000003) — no new tables.

## 2. Why this exists

The parent feature ships every reminder at a globally-fixed hour: nutrition gap at 16:00, training reminder at 10:00, etc. These defaults were picked editorially. Real users have different daily rhythms — some users tap nutrition reminders 80% at 12:30 and 5% at 14:00; others are mirror-flipped. A globally-fixed hour wastes the slot for everyone whose pattern doesn't match the default.

The parent PRD already explicitly lists this as future scope: SR-17 (P2) "Behavioral learning: track which reminder types drive app opens vs. dismissals per user" and SR-18 (P2) "Smart timing optimization: shift reminder fire times based on observed user-open patterns." The Phase 3 rollout sequence is locked in the parent PRD: SR-17 first (data collection only, no UI), then SR-18 (timing automation). This spec ships both together as one staged feature.

PR #158 (merged 2026-04-30) shipped the six lifecycle analytics events (`reminder_scheduled / shown / tapped / dismissed / disabled / suppressed`) that supply the input signal for this feature. Without those events, no behavioral learning is possible. Their merge is what unblocks this spec.

## 3. Locked decisions (from brainstorm session 2026-04-30)

### OQ-1 → β (SR-17 + SR-18 both ship in v1)

Picked over α (SR-17 alone — silent data collection only) and γ (SR-17 + non-PRD automation). β matches the parent PRD's Phase 3 sequence and ships visible behaviour change measurable via A/B test. α would require a follow-up release for the actual win.

**Constraint surfaced:** Of the six `ReminderType` cases, only three are realistic personalisation targets:

| Type | Lifetime cap | Verdict |
|---|---|---|
| HealthKit Connect | 3 lifetime | ❌ never enough data per user |
| Account Registration | 3 lifetime | ❌ never enough data per user |
| Engagement | 3 per lapse, sparse | ❌ bursty + thin |
| **Nutrition Gap** | 5/week | ✅ ~20+ obs in 30 days |
| **Training Day** | 1/day | ✅ ~12 obs in 30 days (5×/week training) |
| **Rest Day** | 1/day | ✅ ~10 obs in 30 days |

The three non-personalisable types keep their static fire times. SR-18 in v1 = adaptive timing for **Nutrition Gap, Training Day, Rest Day only**.

### OQ-2 → Bayesian update with static-default prior

Always personalise; no count-threshold cliff. The per-user posterior is weighted by observation count vs the population prior. The "prior" is the existing static fire time per type (the same `defaultFireHour` already in `ReminderType.swift`) — already in code, no bootstrap needed. Posterior weight `obs / (obs + 10)` means below ~5 observations the posterior is indistinguishable from the static default; behaviour drifts smoothly toward personal as observations accumulate. Picked over (a) hard count threshold (cliff effect) and (c) time + count hybrid (defeats the purpose for users with fast data accumulation).

### OQ-3 → Hybrid (cohort prior server-side + posterior on-device)

Server-side prior comes from the existing Supabase `cohort_stats` table + `increment_cohort_frequency` RPC (migrations 000001–000003), which the AI engine already writes to via service-key. On-device posterior update lives in a new Swift store (`BehavioralLearningStore`).

**No new Supabase table needed** — the existing schema (`segment` / `field_name` / `field_value` / `frequency`) is generic enough to fit the new reminder cohort signal. Backend scope:

- Reuse existing `cohort_stats` table with new `segment` values: `reminders.shows.<type>`, `reminders.taps.<type>`, `reminders.kill_flag`.
- `field_name = "hour"`, `field_value = "00".."23"` for shows/taps; `field_name = "<type>"`, `field_value = "true"` for kill flags.
- Add a **read RPC** (`/reminder-cohort-priors`) — read path doesn't exist today; existing infrastructure is write-only on the client side via service-key.
- Add an **AI-engine writer hook** (`/reminder-cohort-event`) so each `reminder_shown`/`reminder_tapped` event also emits an anonymised cohort write via the existing `increment_cohort_frequency` path.
- Extend the existing pg_cron retention job (migration 000004) to cover the new `reminders.*` segments.

Picked over (1) pure on-device (no cross-user signal) and (2) pure server-side (violates parent PRD's "all trigger evaluation and scheduling fully local" GDPR commitment). Hybrid splits responsibilities cleanly: prior is shared, posterior + decision-making stays local.

### OQ-4 → Global toggle + per-type "Why?" affordance

In Settings → Notifications: one global "Smart timing" toggle row alongside the existing per-type enable/disable toggles. **On by default** (for new installs; existing users get the toggle in `on` state at first launch post-PR-2). Off → revert to static fire times across all three personalisable types. **Plus** a per-type "Why this time?" affordance: each personalisable type's row in Settings shows the current send time; tap opens a sheet that explains the personalisation. Reuses the existing `AIIntelligenceSheet` pattern. Picked over (a) no UI (fails GDPR Article 22 on automated decision-making), (b) toggle without explanation, and (c) per-type toggles (over-promises since 3 of 6 types don't personalise).

### OQ-5 → Aggregate-primary + per-type kill (composite metric)

| Metric | Target | Kill threshold |
|---|---|---|
| Aggregate tap-through lift (treatment − control) | **≥ +5 pp** at p < 0.05 | < +0 pp at end of window |
| Per-type regression (treatment − control, per personalised type) | n/a — composite kill | **< −3 pp** on any single personalised type → per-type rollback to static |
| Dismiss-rate change | flat or down | > +5 pp from baseline (advisory) |
| Disable-rate change | flat or down | > +3 pp (advisory; parent PRD already kills at +25 pp/month) |

**Readout window: 14 ± 4 days** (10–18 day floor / ceiling) per user, flexible to absorb non-uniform sample-accumulation rates. Earliest readout day 10 (when per-user obs count crosses Bayesian saturation point ~10 obs); latest day 18 (cap to prevent indefinite waiting). **Plus a post-population aggregation later** — once each `(type, hour)` cell has ≥ 100 cohort observations (≈ 7,200 total across the 24h × 3 personalisable types matrix), expected ~4–6 weeks post-launch, run a meta-analysis across users to produce robust per-cohort priors. The exact threshold can be tuned post-launch; 100 obs/cell is a defensible default (2× the privacy suppression threshold of 50).

### OQ-6 → resolved by PR #158 merge (2026-04-30); no remaining dependency

### Sequencing → Approach B (3 staged PRs)

| PR | Scope | User-visible change | Rollback |
|---|---|---|---|
| **PR 1** | SR-17 data layer + Settings toggle (defaults *off*) + Supabase migration + AI-engine writer hook + retention extension | None — toggle is off; cohort writes accumulate silently | Single `git revert` |
| **PR 2** | SR-18 timing automation (toggle defaults *on*; A/B test instrumentation begins) | Personalised fire times for ≥10-obs users; static for everyone else | Flip toggle default back to off; no code revert needed |
| **PR 3** | "Why this time?" affordance + per-type transparency rows | Pure UX polish; users tap to read explanation | Single `git revert` |

Picked over A (big-bang — too much novelty in one merge gate) and C (vertical slice — Nutrition Gap caps at 5/week, slowest-accumulating type, inverts the leverage).

## 4. Architecture

```
┌─────────────────────────── Device (Swift) ─────────────────────────────┐
│                                                                          │
│  ReminderTriggerEvaluator  ──→  ReminderScheduler  ──→  UNUserNotif…     │
│         │                              │                                 │
│         │                              ↓                                 │
│         │                  ┌──────────────────────────┐                  │
│         │                  │  SmartTimingResolver     │  ← PR 2          │
│         │                  │  picks per-user fire-time│                  │
│         │                  └──────────┬───────────────┘                  │
│         │                             │                                  │
│         │                  ┌──────────▼───────────────┐                  │
│         │                  │  BehavioralLearningStore │  ← PR 1          │
│         │                  │  per-user posterior      │                  │
│         │                  │  (Bayesian, 24 buckets)  │                  │
│         │                  └──────────┬───────────────┘                  │
│         │                             │                                  │
│         │             ┌───────────────┴──────────┐                       │
│         │             ↓ posterior update         ↓ prior fetch           │
│  AnalyticsService   ReminderNotificationDelegate (existing PR #158)      │
│     │                                                                    │
│     │ reminder_shown / reminder_tapped events                            │
│     ↓                                                                    │
│  AIEngineClient ──→ POST /reminder-cohort-event   ← PR 1 (server hook)   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ↓
┌─────────────────────────── AI Engine (Railway) ────────────────────────┐
│  POST /reminder-cohort-event                                             │
│    → calls increment_cohort_frequency(segment, field_name, field_value)  │
│  GET /reminder-cohort-priors                            ← PR 1 (read RPC)│
│    → returns per-type per-hour tap-through rates + kill flags            │
└──────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ↓
┌─────────────────────────── Supabase (existing) ────────────────────────┐
│  cohort_stats (segment, field_name, field_value, frequency)              │
│  pg_cron retention extended to cover new "reminders.*" segments  ← PR 1  │
└──────────────────────────────────────────────────────────────────────────┘
```

**Architectural decisions:**

- **Decision-making stays on-device.** The resolver picks the send-time using the local Bayesian posterior + cached cohort prior. No round-trip per send decision. Matches parent PRD's "all trigger evaluation and scheduling fully local" rule.
- **Cohort prior is shared, posterior is private.** Aggregated counts (no PII, no per-user values) flow to Supabase via the existing pattern. Per-user posterior lives in `UserDefaults` next to existing scheduler state.
- **AI engine is the only writer.** Client never writes directly to Supabase — it POSTs to the new AI-engine endpoint that calls the existing `increment_cohort_frequency` RPC with service-key. Matches existing security posture.
- **Three personalisable types only.** `SmartTimingResolver` short-circuits for HealthKit / Account / Engagement.
- **PR boundary is the `BehavioralLearningStore` ↔ `SmartTimingResolver` seam.** PR 1 ships the store + write paths + cohort fetch (toggle-off, no resolver). PR 2 ships the resolver. PR 3 ships the "Why?" UI.

## 5. Components

### New Swift files

| File | Responsibility | PR |
|---|---|---|
| `FitTracker/Services/Reminders/BehavioralLearningStore.swift` | Per-user posterior over 24 hour-of-day buckets per personalisable type. `recordObservation(type:hour:tapped:)`, `posterior(type:) -> [Hour: Double]`, `observationCount(type:)`. Persists to `UserDefaults` keys `ft.reminder.posterior.<type>.h<00..23>` and `ft.reminder.obsCount.<type>`. | PR 1 |
| `FitTracker/Services/Reminders/CohortPriorClient.swift` | HTTP client for the two new AI-engine endpoints. `recordEvent(type:hour:tapped:) async` and `fetchPriors() async throws -> CohortPriorResponse`. Reuses existing `AIEngineClient` URL + auth pattern. | PR 1 |
| `FitTracker/Services/Reminders/CohortPriorCache.swift` | On-device cache of cohort prior. 7-day TTL, refreshes on app launch. Falls back to hardcoded static fire times when fetch fails OR cache cold. Single JSON blob in `UserDefaults` key `ft.reminder.cohortPrior.json`. | PR 1 |
| `FitTracker/Services/Reminders/SmartTimingResolver.swift` | Decision-maker. `firingTime(for: ReminderType) -> Hour`. Combines prior (cache) + posterior (store) via Bayesian update; short-circuits to static default for non-personalisable types AND when toggle off AND when type has a server kill_flag. | PR 2 |
| `FitTracker/Views/Settings/BehavioralLearningSettingsView.swift` | Settings → Notifications additions. Global "Smart timing" toggle row (PR 1, defaults *off*) + per-type "Why this time?" rows (PR 3). | PR 1 (toggle) + PR 3 (rows) |
| `FitTracker/Views/Settings/WhyThisTimeSheet.swift` | Per-type explanation: current send time, observation count, prior vs posterior breakdown, Article-22-required opt-out info. Reuses existing `AIIntelligenceSheet` pattern. | PR 3 |

### Modified Swift files

| File | Change | PR |
|---|---|---|
| `FitTracker/Services/Reminders/ReminderScheduler.swift` | Inject the resolver. `scheduleIfAllowed` consults `SmartTimingResolver.firingTime(for: type)` BEFORE building the trigger. Existing `delayMinutes` parameter remains an explicit override. | PR 2 |
| `FitTracker/FitTrackerApp.swift` | Bootstrap: instantiate `BehavioralLearningStore` and `CohortPriorCache` on app launch; trigger fire-and-forget `CohortPriorClient.fetchPriors()` once per app session (cache-TTL guarded). PR 2 wires the resolver into the scheduler. PR 2 also assigns `smartTimingArm` user property on first launch. | PR 1 + PR 2 |
| `FitTracker/Services/Reminders/ReminderNotificationDelegate.swift` | One-line change: `willPresent` calls `BehavioralLearningStore.recordObservation(tapped: false)` (the **denominator**); `didReceive` calls `upgradeLastObservation(tapped: true)` for taps (the **numerator**) — leaves it `false` for dismissals. Also fires `CohortPriorClient.recordEvent` on each. | PR 1 |
| `FitTracker/Services/EncryptedDataStore.swift` (or equivalent GDPR-delete entrypoint) | `deleteAllUserData()` extended to wipe `BehavioralLearningStore` (all `ft.reminder.posterior.*` + `ft.reminder.obsCount.*` keys). | PR 1 |

### AI engine (Railway, Python) — new endpoints

| Endpoint | Behaviour | PR |
|---|---|---|
| `POST /reminder-cohort-event` | Body `{type, hour, tapped}`. Calls `increment_cohort_frequency(segment="reminders.shows.<type>", ...)` always; conditionally calls `...="reminders.taps.<type>"`. Returns `204`. No userId persisted. | PR 1 |
| `GET /reminder-cohort-priors` | Reads `cohort_stats` for `segment LIKE 'reminders.%'`. Computes per-type per-hour rate `taps[h] / shows[h]`. Suppresses cells with `shows < 50`. Returns `{ "priors": { "<type>": { "<hour>": <rate> }, ... }, "kill_flags": ["<type>", ...] }`. | PR 1 |

### Supabase — new migration

| File | Change | PR |
|---|---|---|
| `backend/supabase/migrations/000009_extend_retention_for_reminders.sql` | Extend the existing pg_cron retention job (migration 000004) to cover `segment LIKE 'reminders.%'` with same TTL policy. **No new table** — reuses `cohort_stats` schema verbatim. | PR 1 |

### Tests

| Test file | Coverage focus | PR |
|---|---|---|
| `FitTrackerTests/BehavioralLearningStoreTests.swift` | Bayesian math, per-type isolation, UserDefaults round-trip, denominator/numerator separation | PR 1 |
| `FitTrackerTests/SmartTimingResolverTests.swift` | Static-default short-circuits, toggle-off path, cold-cache fallback, kill-flag honoring | PR 2 |
| `FitTrackerTests/CohortPriorCacheTests.swift` | TTL, fallback, JSON round-trip, malformed-blob recovery | PR 1 |
| `FitTrackerTests/CohortPriorClientTests.swift` | Network-error silent catch, no-PII-in-payload, response shape | PR 1 |
| `FitTrackerTests/ReminderSchedulerSmartTimingTests.swift` | Scheduler-resolver integration, observation recording on delegate callback | PR 2 |
| AI-engine pytest (new file in Railway repo) | Endpoint behaviour, segment values, privacy threshold, kill-flag round-trip | PR 1 |

## 6. Data flow

### Flow A — App launch (PR 1)

1. `FitTrackerApp.task`:
   - `BehavioralLearningStore.loadFromUserDefaults()` (sync, ~5ms)
   - `CohortPriorCache.loadFromUserDefaults()` (sync)
   - If cache stale (> 7d) or cold: `Task { CohortPriorClient.fetchPriors() }` fire-and-forget
   - PR 2 only: `ReminderScheduler.shared.resolver = SmartTimingResolver(store, cache, toggle)`; assign `smartTimingArm` user property

**Latency budget:** App launch must not block on the network. If fetch hasn't completed by the time the first reminder schedules, the resolver uses the static default — that's correct degraded behaviour, not a bug.

### Flow B — Scheduling decision (PR 2 onward)

1. `ReminderTriggerEvaluator` detects condition.
2. `ReminderScheduler.scheduleIfAllowed(type, body)`:
   - `resolver.firingTime(for: type) -> Hour`
     - If `!smartTimingEnabled` OR type ∉ {nutritionGap, trainingDay, restDay} OR type in `cache.killedTypes`: return `type.defaultFireHour`
     - Else: combine prior + posterior via Bayesian update, return `argmax`
   - Existing guards: quiet hours, daily cap, per-type cap, lifetime cap, min interval (unchanged)
   - Build `UNNotificationRequest` with trigger = (today, fire at resolved Hour)
   - `center.add(request)`
   - `analytics.logReminderScheduled(type)` (existing)

**Bayesian formula** (canonical Beta-binomial, simplified):

```
posteriorWeight = obsCount / (obsCount + 10)     # smoothing constant 10 = "10 prior pseudo-observations"
combined[h]     = (1 - posteriorWeight) * prior[h] + posteriorWeight * posterior[h]
```

Smoothing constant `10`: at 0 observations the posterior is ignored (prior wins); at 10 obs `posteriorWeight = 0.5`; at 90 obs `0.9`.

### Flow C — Observation recording (PR 1)

1. `UNUserNotificationCenter` delivers the notification.
2. `ReminderNotificationDelegate.willPresent`:
   - `analytics.logReminderShown(type)` (existing PR #158)
   - `store.recordObservation(type, hour: now.hour, tapped: false)` ← NEW PR 1 (records the **denominator**)
   - `Task { CohortPriorClient.recordEvent(type, hour, tapped: false) }` ← NEW PR 1
3. `ReminderNotificationDelegate.didReceive(response)`:
   - If tap: `analytics.logReminderTapped(type)` (existing) + `store.upgradeLastObservation(type, tapped: true)` ← NEW PR 1 + cohort recordEvent with `tapped: true`
   - If dismiss: `analytics.logReminderDismissed(type)` (existing); no upgrade

**Two-phase observation:** `willPresent` always records the denominator. `didReceive` *upgrades* it for taps. Avoids races where a user taps before the show has been recorded.

### A/B test (PR 2)

```
Assignment: deterministic hash on user UUID, sticky across launches
  if hash(userId) % 100 < 50:
    smartTimingArm = "treatment"   (resolver active)
  else:
    smartTimingArm = "control"     (resolver returns static defaults always — even though store still records observations)

If user manually toggles "Smart timing" off → smartTimingArm = "opted_out" (recorded, excluded from t-test)

Measurement: GA4 user property smartTimingArm + reminder_shown / reminder_tapped events
  Per-user readout: 14 ± 4 day window once obsCount(type) >= 10 for at least one personalisable type
  Aggregate readout: rolling 7-day window across all users in each arm
  Per-type kill: BigQuery → write cohort_stats(segment="reminders.kill_flag", field_name="<type>", field_value="true")
```

### Privacy posture

- Cohort writes carry only `{type, hour, tapped}`. No userId, no timestamp, no device, no metadata.
- Cohort reads are unauthenticated (population data is identical for all users).
- Cells with `shows < 50` suppressed (privacy + statistical-validity threshold).
- Posterior never leaves the device.

## 7. Error handling + opt-out

### Network / fetch failures

| Failure | Behaviour | Surface |
|---|---|---|
| `fetchPriors()` HTTP error / timeout / malformed JSON | Caught silently. Existing cache stays in place; resolver uses cached or static default. **No user-visible degradation.** | `analytics.logEvent("smart_timing_fetch_failed", reason)` + Sentry breadcrumb |
| `recordEvent()` fails | Silently dropped. Per-user observations still recorded in `BehavioralLearningStore`. Cohort write is best-effort. | `analytics.logEvent("smart_timing_record_failed", reason)` |

### Missing / thin cohort data

| Case | Handling |
|---|---|
| Cell suppressed (`shows < 50`) | Server omits entry → resolver treats as no signal (uniform contribution) |
| Whole type has no cohort data | `cache.priors[type]` nil → use `type.defaultPriorDistribution` (tight bell curve around static fire time) |
| User has < 10 personal obs | Posterior weight ~0; prior dominates |
| Empty cohort prior + ≥10 personal obs | Posterior dominates — user's pattern is the strongest signal we have for them |

### Toggle off → revert

- User flips global toggle off → next `scheduleIfAllowed` call short-circuits to static defaults. **Existing pending notifications are NOT rescheduled** (they fire at their already-resolved time).
- Re-enable: store's accumulated observations preserved; learning resumes where it left off.
- Per-type disable (existing) unchanged.

### Per-type kill criterion auto-rollback

| Trigger | Action |
|---|---|
| BigQuery aggregation detects `treatmentRate[type] − controlRate[type] < −0.03` over the 14 ± 4 day window | Server writes `cohort_stats(segment="reminders.kill_flag", field_name="<type>", field_value="true")` |
| Client app launch | `fetchPriors()` response includes `kill_flags`; resolver short-circuits killed types **regardless of toggle** |
| Recovery | Manual: delete kill_flag row in Supabase → next app launch picks up change |

### UserDefaults corruption / first install

| Case | Handling |
|---|---|
| Malformed JSON in `BehavioralLearningStore` | `JSONDecoder` throws → store starts empty. Logged. Resolver falls back to prior + static default. |
| First install, no observations | Same as above |
| Future schema change | Stored blob includes `version: Int`; mismatch → wipe + restart fresh |

### GDPR / Article 22

The "Why this time?" affordance is the Article 22 explanation surface:

1. Current decided send-time per type
2. Observation count (signal strength)
3. Right to opt out (link to global toggle)
4. Right to deletion (handled via `EncryptedDataStore.deleteAllUserData()` extended to wipe `BehavioralLearningStore`)

If the sheet can't render (e.g. empty store mid-fetch), it shows a static "Smart timing is currently active. Tap below to disable." — never a blank or error state.

### Migration / reversibility

- PR 1: toggle-off → no behaviour change for any user.
- PR 2: toggle defaults on for new installs; existing users keep their setting. A/B assignment is deterministic and sticky.
- PR 3: pure UI; no code-path changes.
- Any PR can be reverted independently. Reverting PR 2 makes the toggle inert. Reverting PR 1 takes the store + cohort writes out (resolver in PR 2 still works but only with static defaults — exactly the toggle-off behaviour). Reverting PR 3 just removes the UI.

## 8. Testing + A/B instrumentation

### Critical assertions per file

| File | Highest-value assertions |
|---|---|
| `BehavioralLearningStoreTests` | `posteriorWeight = obs / (obs + 10)`; 0 obs → prior dominates ≥99%; 100 obs → posterior dominates ≥90%; per-type isolation; idempotent `upgradeLastObservation` (calling twice for the same notification id doesn't double-count); UserDefaults round-trip |
| `SmartTimingResolverTests` | The 3 non-personalisable types ALWAYS return `defaultFireHour` regardless of state; toggle-off → static default; toggle-on with cold cache → static default; toggle-on with cache+store → `bayesianCombine.argmax`; killed type → static default even with toggle-on |
| `CohortPriorCacheTests` | TTL: cache age >7d → `isStale == true`; malformed JSON → `loadFromUserDefaults` returns nil; persist round-trip; suppressed cells deserialize as missing entries (not zero) |
| `CohortPriorClientTests` | Network errors caught silently (no throw across API boundary); record-event payload contains ONLY `{type, hour, tapped}` (asserted via captured request body); fetch-priors deserializes documented JSON shape |
| `ReminderSchedulerSmartTimingTests` | Scheduler asks resolver before building trigger; `delayMinutes` still works as override; resolver result honoured even when conflicting with existing per-type default |

### AI-engine pytest

| Test | Asserts |
|---|---|
| `test_reminder_cohort_event_writes_segment` | POST `{type:"nutrition_gap", hour:16, tapped:true}` → calls `increment_cohort_frequency` twice (once for `reminders.shows.nutrition_gap`, once for `reminders.taps.nutrition_gap`) |
| `test_reminder_cohort_event_tapped_false_only_increments_shows` | POST with `tapped:false` → only one increment (shows) |
| `test_reminder_cohort_priors_suppresses_low_volume` | Seed `shows=49, taps=20` → no entry in response; seed `shows=50, taps=20` → response includes rate `20/50` |
| `test_reminder_cohort_priors_returns_kill_flags` | Seed `cohort_stats(segment="reminders.kill_flag", ...)` → response includes `kill_flags: ["<type>"]` |
| `test_no_pii_in_payload` | POST with arbitrary userId in JWT → no userId persisted |

### A/B instrumentation (the novel piece)

Arm assignment as a **GA4 user property** (cheaper than per-event parameter, sticky, segments natively):

```swift
// In FitTrackerApp.task, on first launch post-PR-2:
if !UserDefaults.standard.contains(key: "ft.smart_timing.arm") {
    let arm = computeArm(userId: signIn.userId)  // hash(userId) % 100 < 50 → "treatment"
    UserDefaults.standard.set(arm, forKey: "ft.smart_timing.arm")
    analytics.setUserProperty(arm, forName: AnalyticsUserProperty.smartTimingArm)
}
```

Manual toggle-off → `arm = "opted_out"` (recorded, excluded from t-test).

One new analytics user property: `AnalyticsUserProperty.smartTimingArm`. All existing reminder events automatically carry this dimension via GA4 user-property mechanism — no event-signature changes needed.

### BigQuery readout queries

Committed under `docs/product/analytics-queries/`:

| Query | Purpose | Cadence |
|---|---|---|
| `smart_timing_per_user_readout.sql` | Per-user tap-through rate per type, gated on `obsCount ≥ 10 AND days_since_assignment BETWEEN 10 AND 18` | Daily |
| `smart_timing_aggregate_lift.sql` | Aggregate `tap_through_rate` per arm: `treatment_rate − control_rate` with 95% CI via Wilson score | Daily |
| `smart_timing_per_type_kill_check.sql` | Per-type lift; flags any `< −0.03` for kill-flag write | Daily |
| `smart_timing_post_population_aggregation.sql` | Once each `(type, hour)` cell has ≥ 100 cohort observations (≈ 7,200 total) — meta-analysis for stable per-segment baselines | Manual trigger; expected ~4–6 weeks post-launch |

### Privacy / GDPR test coverage

| Test | Where | Asserts |
|---|---|---|
| `BehavioralLearningStoreTests.testWipedByDeleteAllUserData` | Swift unit | `EncryptedDataStore.deleteAllUserData()` clears all `ft.reminder.posterior.*` + `ft.reminder.obsCount.*` keys |
| `CohortPriorClientTests.testNoPIIInPayload` | Swift unit | Captured POST body keys exactly `{type, hour, tapped}` — no userId / deviceId / locale |
| `test_no_pii_persisted` | Python | Seed events for two userIds → `cohort_stats` rows have identical keys (proves aggregation) |
| Manual smoke | Settings → Account & Data → Delete | After delete, smart-timing reverts to static for that user |

### CI integration

| Hook | What runs | Failure surface |
|---|---|---|
| Existing `xcodebuild test` (FT2 CI) | Auto-discovers new test files via Sources build phase | Standard CI pass/fail |
| Existing `make ui-audit` | Auto-scans new view files | P0 = blocking; P1 = baseline-tracked |
| Existing pre-commit `check-state-schema.py` | Validates state.json schema as feature advances | v7.6 enforcement |
| AI-engine CI (Railway → GitHub Actions) | New pytest for the two endpoints | Standard pass/fail |
| **NEW:** `make smart-timing-readout` (added in PR 2) | Runs the BigQuery queries via `bq` CLI | Manual + scheduled cron |

### Manual smoke playbook

New file `docs/setup/smart-timing-verification-playbook.md` (PR 2):

1. Install on two simulators, force `arm=treatment` on one and `arm=control` on the other via debug menu.
2. Trigger a nutrition reminder via debug menu → verify the resolver picks a non-default hour on treatment, default hour on control.
3. In GA4 DebugView, confirm `smart_timing_arm` user property attached to all reminder events.
4. Toggle "Smart timing" off in Settings → next reminder fires at static default.
5. Toggle back on → resolver picks personalised hour.
6. Tap "Why this time?" → explanation sheet renders with non-zero observation count after enough usage.

### Coverage targets

- New Swift files: **≥ 80% line coverage** (matches existing `FitTrackerTests` standard)
- AI-engine new endpoints: **100% line coverage** (only ~50 LOC each)
- A/B-test analysis SQL: query-by-query review against snapshot fixtures committed alongside

## 9. Success metrics + kill criteria

### Success metrics

1. **Aggregate tap-through lift (treatment − control) ≥ +5 pp at p < 0.05** over the per-user readout window (14 ± 4 days).
2. **Post-population aggregation** confirms the per-user signal at the cohort level once each `(type, hour)` cell has ≥ 100 cohort observations (≈ 7,200 total across the 24h × 3 personalisable types matrix; expected ~4–6 weeks post-launch).
3. **No personalisable type regresses below its static-baseline tap-through by ≥ −3 pp** (composite kill).

### Kill criteria

1. **Aggregate tap-through lift < +0 pp** at end of the per-user readout window AND post-population aggregate also fails → revert PR 2.
2. **Any single personalised type regresses by ≥ −3 pp** vs its static baseline → per-type rollback to static fire time via `kill_flag` mechanism (no PR revert required).
3. **Disable rate increases ≥ +3 pp** from baseline OR **dismiss rate increases ≥ +5 pp** from baseline (advisory; parent PRD already kills at +25 pp/month for disable rate).

### Readout cadence

- **Daily** automated BigQuery query runs during the readout window.
- **Per-user readouts** trigger when `obsCount(type) ≥ 10 AND days_since_assignment BETWEEN 10 AND 18`.
- **Aggregate readout** rolls weekly during the window.
- **Post-population aggregation** is a one-shot manual analysis once the per-cell threshold (≥ 100 cohort observations across the 24h × 3 types matrix) is hit; expected ~4–6 weeks post-launch.

## 10. References

- **Parent PRD:** [`docs/product/prd/smart-reminders.md`](../../product/prd/smart-reminders.md) — SR-17, SR-18, Phase 3 sequencing
- **Parent case study:** [`docs/case-studies/smart-reminders-case-study.md`](../../case-studies/smart-reminders-case-study.md) — flagged this sub-feature as deferred
- **Analytics events shipped:** PR #158 (`reminder_scheduled / shown / tapped / dismissed / disabled / suppressed`) merged 2026-04-30
- **Brainstorm artifacts:** [`.claude/features/smart-reminders-behavioral-learning/research/open-questions.md`](../../../.claude/features/smart-reminders-behavioral-learning/research/open-questions.md)
- **Backend infrastructure:** [`backend/supabase/migrations/000001_cohort_stats.sql`](../../../backend/supabase/migrations/000001_cohort_stats.sql), [`000002_increment_cohort_frequency.sql`](../../../backend/supabase/migrations/000002_increment_cohort_frequency.sql), [`000003_rls_cohort_stats.sql`](../../../backend/supabase/migrations/000003_rls_cohort_stats.sql), [`000004_retention_pg_cron.sql`](../../../backend/supabase/migrations/000004_retention_pg_cron.sql)
- **Related enhancement (PR #162):** E-1 Readiness-Aware Training Alert — explicitly notes "[the] behavioral-learning sub-feature would further personalize the threshold tuning per user"
- **Framework version:** v7.7 (validity closure shipped 2026-04-27 via PR #144)
