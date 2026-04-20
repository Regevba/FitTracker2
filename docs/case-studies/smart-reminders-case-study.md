# Smart Reminders — Case Study

**Date written:** 2026-04-20

> Framework v5.1 | feature (new_capability) | 2026-04-15 → 2026-04-16 | surfaced retroactively 2026-04-20
>
> **Headline:** Six reminder types, a reusable guest-lock overlay, and a frequency-cap engine — all designed, specified, implemented, and test-covered during a parallel stress test that advanced four features simultaneously. No dedicated PR, no feature branch: the work landed through the v5.1 stress-test phase commits, and this case study is the first time it is documented end-to-end.

---

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | Smart Reminders |
| Framework Version | v5.1 (Adaptive Batch) |
| Work Type | feature / new_capability |
| Parent Feature | onboarding-v2-auth-flow |
| PRD Path | `docs/product/prd/smart-reminders.md` |
| State Path | `.claude/features/smart-reminders/state.json` |
| Current Phase | `complete` (phases 6-9 never formally advanced; feature_complete transition jumped from `implementation`) |
| Wall-clock Span | ~12 hours across two days (2026-04-15 17:33 UTC → 2026-04-16 05:30 UTC), inside a multi-feature stress test |
| Tasks | 14 planned (T1-T14), T1-T8 + T11 confirmed in commits, T9/T13 via the F3+F4 completion commit |
| Production Files | 4 — `ReminderType.swift` (53 LOC), `ReminderScheduler.swift` (192 LOC), `ReminderTriggers.swift` (127 LOC), `LockedFeatureOverlay.swift` (60 LOC) |
| Test Files | 2 — `ReminderTests.swift` (89 LOC, 10 cases), `ReminderSchedulerTests.swift` (146 LOC, 7 cases) |
| Analytics Events Declared | 6 generic + 12 per-type + 3 locked-feature = 21 events planned; 6 generic constants shipped in `AnalyticsProvider.swift` |
| Dedicated PR | None — work landed via stress-test phase commits (`d62741c`, `fe1295a`, `33b4e72`, `2910762`) and test PR #98 |
| Primary Metric | reminder tap-through rate ≥ 25% across all types |
| Post-launch Review | Not yet run (feature not yet live with users) |

---

## 2. Why This Case Study Exists

The "every feature gets a case study" rule was introduced on 2026-04-13 (two days before Smart Reminders started) and applies to every feature that transitions to `complete`. Smart Reminders transitioned on 2026-04-16 and has sat in `complete` with no accompanying narrative for four days.

The gap is explained by how the feature was built, not by oversight: Smart Reminders never existed as a standalone branch or PR. It was one of four features pushed through the v5.1 Adaptive Batch stress test concurrently, landing through commits like `feat: v5.1 stress test phase 6 — UI views + orchestrator + triggers, BUILD SUCCEEDED`. The state file advanced from `init` to `complete` in 12 hours, and the six-phase audit trail documents the PM lifecycle cleanly — but no standalone PR description exists to harvest into a case study.

This document reconstructs the feature from primary evidence: the state transitions, the PRD, the UX spec, the commit graph, and the shipped source files.

---

## 3. PRD Summary

**Purpose:** proactive, state-aware notification layer that surfaces nudges at the moment they are actionable, replacing FitMe's passive "open the app to see value" posture with a Whoop/Oura-style outreach model.

**Primary metric:** reminder tap-through rate ≥ 25% across all types. Kill criteria: < 5% after 30 days → prune to one type only.

**North Star:** tap-through trending up or flat, disable rate trending flat or down, guest conversion rate > 5% sustained.

### Scope — Six Reminder Types

| ID | Type | Trigger | Caps |
|---|---|---|---|
| 1 | HealthKit Connect | HealthKit not authorized, day 2/5/10 post-onboarding | 1/day, 3 lifetime |
| 2 | Account Registration | Guest user, day 3/7/14 post-onboarding | 1/day, 3 lifetime |
| 3 | Goal-Gap Nutrition | Protein < 50% target after 4 PM | 1/day (unlimited lifetime) |
| 4a | Training Day | Training day, no workout logged by 10 AM | 1/day |
| 4b | Rest Day | Readiness < 40, confidence gate (≥ 2 HealthKit signals, < 12h stale) | 1/day |
| 5 | Engagement | 3+ days since last open, copy escalates across day 3/5/7 | 3 per lapse, resets on open |

(The shipped enum split type 4 into `.trainingDay` and `.restDay` for a total of six cases, matching the frequency-cap tests.)

**Deferred (P2):** behavioral learning (SR-17), smart timing optimization (SR-18), A/B copy variants (SR-19 — blocked on A/B framework), APNs remote push for 7+ day lapses (SR-20 — blocked on push backend).

---

## 4. Phase Walkthrough

State transitions come verbatim from `.claude/features/smart-reminders/state.json`.

### Research (17:33 → 17:35 UTC, 2 min)

Deliverable: `.claude/features/smart-reminders/research.md`. Competitive analysis across Whoop, Oura, MyFitnessPal, Noom, Apple Health. Key insight recorded: "state-aware, not schedule-based" — the Whoop/Oura model. Each of the five reminder types was defined with trigger conditions, message templates, frequency caps, and analytics events. Phased rollout plan drafted: types 3+4 first, 1+2 next, 5 last.

### PRD (17:35 → 17:42 UTC, 7 min)

Deliverable: `docs/product/prd/smart-reminders.md` — 349 lines. 20 requirements across P0 / P1 / P2 tiers. Five-column metric table with baselines, targets, kill criteria, and post-launch cadence (2 weeks → monthly for 3 months). Four open questions routed to PM / Design / Analytics owners with resolution notes.

### Tasks (17:42 → 17:50 UTC, 8 min)

Deliverable: `.claude/features/smart-reminders/tasks.md` — 14 tasks across service / model / ui / analytics / test layers. Critical path: T1 (scheduler) → T2 (enum) → T3/T4 (trigger types 3+4) → T10 (AIOrchestrator wiring) → T8 (cap manager) → T13 (lifecycle) → T14 (build verification). Estimated effort: 6.5 days.

### UX / Integration (17:50 → 17:58 UTC, 8 min)

Deliverable: `.claude/features/smart-reminders/ux-spec.md`. Notification copy for all five types with tone guidance ("Celebration Not Guilt" — never guilt-inducing). Locked Feature Overlay ASCII mock + design token mapping (backdrop `AppColor.Background.appPrimary.opacity(0.85)`, card radius `AppRadius.card`, CTA height `AppSize.ctaHeight`). Typical-day timing visual showing the 3/day global cap and 4-hour minimum interval between notifications.

### Implementation (17:58 → 05:30+1d UTC)

The implementation window overlapped with the v5.1 stress test. Key commits:

| SHA | Commit | Scope |
|---|---|---|
| `bbbcd66` | `feat(smart-reminders): write PRD` | PRD authored |
| `d62741c` | `feat(smart-reminders): T1+T2 — ReminderType enum + ReminderScheduler with frequency caps` | T1 + T2 |
| `fe1295a` | `feat(smart-reminders): T8+T11 — frequency cap tracking + 6 reminder analytics events` | T8 + T11 |
| `33b4e72` | `feat: v5.1 stress test phase 6 — UI views + orchestrator + triggers, BUILD SUCCEEDED` | `ReminderTriggers.swift` for T3-T7 + T10 |
| `2910762` | `feat: complete F3+F4 implementation — ImportPreviewView + LockedFeatureOverlay + lifecycle wiring` | T9 (LockedFeatureOverlay) + T13 (lifecycle hook in `FitTrackerApp.swift`) |

### Complete (05:30 UTC, 2026-04-16)

State transition note: "All tasks implemented. BUILD SUCCEEDED. Feature complete." Phases `testing`, `review`, `merge`, `documentation` remained `pending` in the state file — a PM-workflow gap discussed in §6.

### Tests (2026-04-18, PR #98 / Sprint J)

Two days after the state file closed, test coverage was added as part of audit sprint J. `ReminderTests.swift` (10 cases) locks the enum contract: 6 cases exist, all have non-empty titles, all deep links are `fitme://`, lifetime caps are exactly 3 for the three attention-bounded types and `nil` for the other three, raw values are snake_case, and Codable round-trips preserve identity. `ReminderSchedulerTests.swift` (7 cases) covers the observable surface: singleton identity, `cancelAll` idempotence, UserDefaults key contract (`ft.reminder.dailyCount.YYYY-MM-DD` for the global count, `ft.reminder.{type}.sentCount` for lifetime), quiet-hours math (22:00-7:00 boundary), and per-type `maxPerDay` ≥ 1. The test file explicitly documents what was *not* testable without a mock UNUserNotificationCenter, making the coverage gap visible rather than faked.

---

## 5. What Shipped

### Source files (listed in `git grep`)

- `FitTracker/Services/Reminders/ReminderType.swift` — 53 LOC. Enum with six cases, display titles, per-type `maxPerDay` (all = 1), per-type `maxLifetime` (3 for healthKitConnect / accountRegistration / engagement, `nil` for the rest), deep-link destinations.
- `FitTracker/Services/Reminders/ReminderScheduler.swift` — 192 LOC. Singleton (`@MainActor`). Enforces: quiet hours (22:00-7:00), global daily cap (3), per-type daily cap, per-type lifetime cap, 4-hour minimum interval between any two reminders. All state persisted via `UserDefaults` with date-scoped keys. Wraps `UNUserNotificationCenter.add` with silent failure (notifications are best-effort).
- `FitTracker/Services/Reminders/ReminderTriggers.swift` — 127 LOC. `ReminderTriggerEvaluator` class with five `evaluate*` methods (one per type) and an `evaluateAll(...)` that calls them in phase order (nutrition + training first, HealthKit + registration next, engagement last). Each evaluator is a pure condition check → `scheduler.scheduleIfAllowed(type:body:)` call.
- `FitTracker/Views/Shared/LockedFeatureOverlay.swift` — 60 LOC. SwiftUI overlay: `AppColor.Overlay.scrim` backdrop with `onTapGesture(perform: onDismiss)`, card with SF Symbol icon (`AppText.iconXL`, `AppColor.Accent.primary`), "Unlock {feature}" title, benefit body, full-width CTA at `AppSize.ctaHeight`, and a "Maybe later" caption-style dismiss. Accessibility: `.accessibilityElement(children: .contain)` + labeled container.

### Analytics

Six generic reminder event constants shipped in `FitTracker/Services/Analytics/AnalyticsProvider.swift:258-268`:

```
reminder_scheduled / reminder_shown / reminder_tapped / reminder_dismissed /
reminder_disabled / reminder_suppressed
```

The PRD called for an additional 12 per-type events (`reminder_healthkit_shown`, etc.) and 3 `locked_feature_*` events. These constants are not yet in `AnalyticsProvider.swift`, though the `type` parameter on the generic events carries the equivalent signal.

### Lifecycle wiring

`FitTracker/FitTrackerApp.swift:147` references `_ = ReminderScheduler.shared` inside the post-sync init block, with a comment: "actual trigger evaluation happens in MainScreenView when data is available." The scheduler is warm on app launch; the `ReminderTriggerEvaluator.evaluateAll(...)` call site is wired to `MainScreenView` data availability.

---

## 6. Lessons

**Stress-test velocity traded PM hygiene for throughput.** The state file shows six clean transitions from init to complete in 12 hours. But four phases (`testing`, `review`, `merge`, `documentation`) stayed marked `pending` in the state file even though the work landed. The v5.1 stress test optimized for "four features advanced simultaneously, BUILD SUCCEEDED" as the phase-completion signal, and that signal doesn't carry the explicit phase-advance approval the state machine expects. Future stress-test phases should include a closing pass that advances the state machine through every phase it touched — or the PM dashboard will keep showing tests/review/merge as pending for features that are fully shipped.

**Testing arrived two days late and documented its own gap.** PR #98 (Sprint J) added `ReminderSchedulerTests.swift` two days after the feature closed. The test author was honest about what couldn't be tested: "The full scheduling path goes through UNUserNotificationCenter, which isn't reliably testable without a mock. Where the production code's effect is observable through state/defaults, we test it directly; where it isn't, we document the gap rather than fake it." This is the right pattern — a coverage note inside the test file is more useful than fake green tests, and it turned into a backlog item (a mock `UNUserNotificationCenter` protocol) rather than a hidden liability.

**The single-enum-six-cases decision simplified the frequency-cap engine.** The PRD listed five reminder types; the shipped enum has six. The split (type 4 into `.trainingDay` and `.restDay`) lets the scheduler treat each trigger as its own lifetime-capped series and lets the UI render distinct titles ("Time to train 💪" vs "Rest day — recover well 🧘") without branching inside the same case. It also made the caps test — "lifetime-limited types have the expected caps; unlimited types return nil" — a flat table instead of a nested conditional.

**Locked Feature Overlay generalized beyond Smart Reminders.** The overlay was specified inside the Smart Reminders PRD as a guest-conversion component, but the shipped file (`Views/Shared/LockedFeatureOverlay.swift`) is a generic reusable view: `featureIcon`, `featureTitle`, `benefitText`, `onCreateAccount`, `onDismiss`. Any future gated surface (monetization, entitlements) can mount it. This is a good outcome — the Smart Reminders PRD happened to be where it got specified, but the component has no coupling to reminders.

**Stress-test commits don't produce PR-linkable case-study evidence.** Three of the four load-bearing commits landed under stress-test phase labels, not `feat(smart-reminders)`. Reconstructing this case study required pattern-matching on file paths (`--follow` on `ReminderScheduler.swift` plus a grep for `LockedFeatureOverlay`) rather than reading a PR thread. For future stress tests, each per-feature commit inside the phase should keep its `feat({feature-name})` prefix even when it ships under a phase banner — the two mechanisms compose cleanly.

---

## 7. Links

- State file: `.claude/features/smart-reminders/state.json`
- Research: `.claude/features/smart-reminders/research.md`
- Tasks: `.claude/features/smart-reminders/tasks.md`
- UX Spec: `.claude/features/smart-reminders/ux-spec.md`
- PRD: `docs/product/prd/smart-reminders.md`
- Source: `FitTracker/Services/Reminders/` (3 files) + `FitTracker/Views/Shared/LockedFeatureOverlay.swift`
- Tests: `FitTrackerTests/ReminderTests.swift`, `FitTrackerTests/ReminderSchedulerTests.swift`
- Lifecycle hook: `FitTracker/FitTrackerApp.swift:147`
- Analytics constants: `FitTracker/Services/Analytics/AnalyticsProvider.swift:256-268`
- Test PR: #98 (`fix/audit-sprint-j`, merged 2026-04-18)
- Load-bearing commits: `bbbcd66`, `d62741c`, `fe1295a`, `33b4e72`, `2910762`, `3bc960c`
