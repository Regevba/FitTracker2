# Push Notifications — Research (Rebuild)

**Phase:** 0 (Research)
**Started:** 2026-05-07
**work_subtype:** new_feature (rebuild from scratch)
**Predecessor:** v1 shipped → reopened (UI-016) → paused (v7.7) → rebuild approved 2026-05-07
**v1 artifacts:** `.claude/features/push-notifications/_v1/` + `docs/case-studies/push-notifications-case-study.md` + v1 PRD (will be overwritten)

This document is intentionally lean. v1 already exhausted the greenfield research surface (market scan of Whoop / Oura / Hevy, iOS HIG patterns, permission-priming UX). The rebuild's research question is narrower: **given that smart-reminders shipped and overlaps substantially, what's the right architecture for v2?**

---

## 1. v1 Retrospective — What Actually Happened

### 1.1 What shipped (2026-04-12 → 2026-04-16)

12-task v5.2 PM lifecycle. 5 Swift files, 18 tests, 10 analytics events, 2 critical review findings caught + fixed pre-merge:

- `FitTracker/Services/Notifications/NotificationService.swift` (143 LOC)
- `FitTracker/Services/Notifications/NotificationPreferencesStore.swift` (89 LOC)
- `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` (103 LOC)
- `FitTracker/Services/Notifications/NotificationContentBuilder.swift` (51 LOC)
- `FitTracker/Services/Notifications/NotificationDeepLinkHandler.swift` (14 LOC)

Functional surface: workout reminder + readiness alert + recovery nudge, 3-step priming pattern, quiet hours (22:00–07:00), per-type preferences store, daily frequency cap, deep links into `fitme://training` / `fitme://readiness`.

### 1.2 What didn't ship (UI-016 partial-ship)

The substrate was complete, tested, and merged — and **was never wired into the runtime**:

| Surface | v1 status | Runtime reachability |
|---|---|---|
| `NotificationService.shared` | merged | **Never called from app lifecycle.** No `FitTrackerApp.swift` initialization, no scheduling at any user moment. |
| `NotificationPermissionPrimingView` | merged + tested + 8 tests | **Never instantiated.** No screen, sheet, or modal ever pushes/presents this view. The first-workout-completed trigger that the v1 PRD specified (PN-2) was never built. |
| `NotificationPreferencesStore` | merged | Used only by `NotificationService` (which is unreachable). |
| 10 analytics events | code-paths exist | **Have never fired in production.** GA4 has zero `notification_*` events. |

The HISTORICAL banner currently on `NotificationPermissionPrimingView.swift:1-4` documents this. `NotificationService.swift` lacks an equivalent banner — that's a doc bug, not a code bug.

### 1.3 Why it happened

Inferred from v1 task breakdown + audit timing:
- T8 ("Wire into app lifecycle (schedule on launch)") was marked `done` based on `scheduleNotification()` call sites in tests, not in `FitTrackerApp.swift`. The wiring was conceptual, not literal.
- Phase 6 (Code Review) caught 2 critical findings (frequency cap, per-type check) — both legitimate substrate bugs — and missed the substrate-isn't-reached issue because the diff against main showed shipped code, not wired code.
- Phase 5 (Testing) tested the substrate in isolation. None of the 18 tests asserted "the priming view is reachable from a user-visible navigation path."
- The v7.5 integrity cycle caught it 4 days later as audit finding UI-016. The Phase 9 case study documented it honestly.

### 1.4 Lesson (carries forward to v2)

A "phase 6 review" gate that diffs feature-vs-main is structurally blind to dead-code partial ships. The v4.X `/design pre-merge-review` (added 2026-05-06, post-v1) closes part of this — it requires Figma node IDs in PR descriptions for UI-touching PRs, which forces a "the screen is real and reachable" check. v2 should plan for that gate to fire.

**v2 must add an explicit reachability check** at Phase 5 testing: at least one test or runtime smoke that asserts every user-facing entry point in the PRD is reachable from a real navigation path, not just a unit-test harness.

---

## 2. Smart-Reminders Coexistence Analysis

### 2.1 Smart-reminders shipped a more capable scheduler

`ReminderScheduler.shared` (shipped 2026-04-16, PR #98 tests; production code merged via direct stress-test commits) is structurally a superset of v1's `NotificationService`:

| Capability | v1 NotificationService | Smart-reminders ReminderScheduler |
|---|---|---|
| Authorization wrapper | ✓ | ✗ (relies on caller having authorization) |
| Quiet hours (22:00–07:00) | ✓ | ✓ (same window) |
| Daily cap | per-pref `maxDailyNotifications` | global cap = 3/day |
| Per-type daily cap | ✗ | ✓ (1/day per type) |
| Per-type lifetime cap | ✗ | ✓ (one-time conversion reminders) |
| Minimum-interval guard | ✗ | ✓ (4h between any two) |
| Analytics suppression logging | ✗ (silent reject) | ✓ (`logReminderSuppressed` with reason) |
| Reminder types | 3 (workout / readiness / recovery) | 6 (healthKitConnect, accountRegistration, nutritionGap, trainingDay, restDay, engagement) |
| Trigger evaluator | inline in caller | `ReminderTriggerEvaluator` (5 evaluators) |
| Behavioral learning | ✗ | PR-1 shipped 2026-05-04 (PR #190 + #198); PR-2 (SmartTimingResolver) gated on cohort data |

### 2.2 Type-level overlap

Three of v1 push-notifications' types are functionally duplicated by smart-reminders, with smart-reminders holding the more sophisticated implementation:

| v1 push-notif type | Smart-reminders equivalent | Verdict |
|---|---|---|
| `workoutReminder` | `trainingDay` | DUPLICATE — smart-reminders wins (has training-plan integration, behavioral learning roadmap) |
| `recoveryNudge` | `restDay` | DUPLICATE — smart-reminders wins (tied to recovery flags via `ReminderTriggerEvaluator`) |
| `readinessAlert` | (none) | UNIQUE to push-notifications — readiness-score-driven, threshold-gated, Combine-bound to ReadinessEngine |

**Authorization is the genuine gap smart-reminders left open.** `ReminderScheduler` schedules on `UNUserNotificationCenter` but has no authorization wrapper or priming UI — it assumes the user already granted permission. Without push-notifications-v2 (or equivalent), the first reminder that fires will hit `removeAllPendingNotificationRequests` failure paths or silently no-op when authorization=denied.

### 2.3 Four shared-substrate surfaces

The backlog item I added flags four integration vectors. Mapping them concretely:

1. **Single shared scheduling guard** — Today, two schedulers exist. Either one becomes the single entry point and the other delegates, or v2 demolishes its own scheduler and everything routes through `ReminderScheduler`. **Risk if not closed:** `notification_scheduled` and `reminder_scheduled` events double-fire when the same trigger condition is satisfied by both systems.
2. **Single permission priming surface** — The priming view was the missing wiring in v1. Whichever system surfaces the priming UI owns the OS dialog; the other system reads `NotificationService.shared.isAuthorized` (or its equivalent) and bails if not granted. **Risk if not closed:** smart-reminders fires its first reminder, hits authorization=denied, silently no-ops, never primes the user.
3. **Unified deep-link router** — Both systems own subsets of `fitme://` URL schemes. v1 had a `NotificationDeepLinkHandler` (14 LOC). Smart-reminders embeds deep links into the `ReminderType` enum (`fitme://settings/health`, `fitme://nutrition`, etc). **Risk if not closed:** notification taps don't route, or route inconsistently depending on system of origin.
4. **Aggregated preferences UI** — v1 PRD deferred this to P2 explicitly. Smart-reminders also has no UI ("backend `NotificationPreferencesStore` exists but no user-facing Settings screen" per backlog line 176). **Risk if not closed:** users can't opt out of specific types.

### 2.4 The architectural implication

If v2 ships as a peer system to smart-reminders:
- Two schedulers, two preference stores, two analytics taxonomies (`notification_*` vs `reminder_*`), two priming surfaces (or one of them owned by v2).
- Integration debt in the backlog item I added becomes mandatory pre-merge work, not deferred work.
- The HISTORICAL banner on `NotificationPermissionPrimingView` is wrong — it'll be revived.

If v2 ships as an extension of smart-reminders (i.e., smart-reminders absorbs the readiness-alert type and authorization wrapper):
- One scheduler. One preferences store. One taxonomy.
- v2 becomes structurally a smart-reminders enhancement, not a peer feature.
- v1 NotificationService.swift + NotificationPermissionPrimingView.swift get deleted (or marked HISTORICAL).
- The 10 v1 analytics events get reduced/renamed to fit the smart-reminders `reminder_*` convention.
- This is the cleaner architecture but also the larger demolition.

---

## 3. Approach Selection

### 3.1 Three candidate architectures

| Approach | Description | Effort | v1 substrate fate | Risk |
|---|---|---|---|---|
| A: Subsume into smart-reminders | Demolish v1 NotificationService stack; add `readinessAlert` type + auth wrapper + revived priming view to smart-reminders. v2 ships as a smart-reminders enhancement. | ~3 days | Demolish 4 files; revive priming view. | Reclassifies feature as enhancement; couples push-notifications' fate to smart-reminders' release schedule; constrains future non-reminder consumers (APNs marketing, training-plan import-complete, GDPR ready, etc.). |
| **B: push-notifications-v2 as the platform layer** *(SELECTED)* | v2 owns the **notification platform**: authorization, permission priming, deep-link routing, and a single dispatch surface. Smart-reminders becomes the **first consumer** — its `ReminderScheduler` calls into v2's gateway for auth + dispatch + URL resolution. Other future consumers (training-plan, marketing campaigns, GDPR exports, in-app metric-tile drill-downs already built separately) plug into the same platform. | ~5–6 days | Keep + re-wire NotificationPermissionPrimingView (un-mark HISTORICAL). Replace v1 NotificationService with `NotificationGateway`. Replace v1 NotificationPreferencesStore with a per-consumer-type registry pattern. Replace v1 DeepLinkHandler (dead-code today) + ReminderType.deepLink + smart-reminders' dead `.fitMeReminderTapped` path with a single `DeepLinkRouter`. | Touches a shipped feature (smart-reminders) at one specific seam: ReminderScheduler's dispatch path. Smart-reminders' public API stays the same; only its internals route through v2. The deep-link unification fixes the smart-reminders silent partial-ship surfaced in §6.1 below. |
| C: Greenfield rebuild, demolish smart-reminders too | Rewrite from scratch as canonical notification system AND fold smart-reminders' types into v2 directly (collapse the layering). | ~7-10 days | Demolish all of v1 + collapse smart-reminders into v2. | Largest blast radius. Loses smart-reminders' behavioral-learning PR-1 work that just shipped 2026-05-04. Premium effort with no proportionate architectural gain. |

### 3.2 Decision: **Approach B (platform-layer)**

User-selected 2026-05-07. Reasoning:

1. **Push notifications are platform infrastructure, not a feature.** The user framing was: "push notification is an ability that is connected to smart reminders activation but also the app will use it in a larger point of view." Smart-reminders is one consumer among several future consumers. Subsuming push-notifications inside smart-reminders (Approach A) would entangle the notification platform with one specific consumer's release cadence and design choices.
2. **The deep-link layer needs unification anyway.** §6 below catalogues three deep-link surfaces today (auth/reset-password, smart-reminders' broken broadcast, v1's dead handler) and a clean separation: notification platform owns auth + priming + dispatch + URL routing; consumers own their content + scheduling rules. Approach B is the architecture that lets that separation actually exist.
3. **The deep-link platform layer doesn't exist yet.** §6.1 shows smart-reminders' delegate broadcasts deep links correctly via `.fitMeReminderTapped` but has no central router to consume them — the router is platform infrastructure that didn't exist when smart-reminders shipped. Approach B builds the platform; Approach A would build a smaller version inside smart-reminders only, leaving future consumers (training-plan, marketing-APNs, GDPR exports) to either reinvent the wheel or refactor.
4. **`work_type: feature`** (not enhancement). The platform layer is a new capability with its own success metrics and its own UI (priming surface). Full 10-phase lifecycle applies.
5. **Effort is reasonable.** ~5–6 days vs ~3 for Approach A — the extra ~2 days buys a clean platform abstraction that all future notification work plugs into.

### 3.3 What Approach B's PRD will need to define

(For the next phase, not to design here.)

**Platform surfaces (owned by push-notifications-v2):**
- `NotificationGateway` — single authorization wrapper + dispatch surface. Owns `UNUserNotificationCenter` access + `isAuthorized` state. ReminderScheduler calls `NotificationGateway.dispatch(content:trigger:tag:)` instead of calling `UNUserNotificationCenter.current().add(_:)` directly.
- `NotificationPermissionPrimingView` — revived from v1, un-marked HISTORICAL. Wired to (a) first-workout-completed trigger AND (b) Settings entry point. Owned by the platform; consumers don't ship their own priming UI.
- `DeepLinkRouter` — central URL → action handler. Replaces the three fragmented surfaces today (see §6). Lives in `FitTracker/Services/Notifications/DeepLinkRouter.swift`.
- `NotificationConsumerRegistry` — a registration mechanism so consumers (smart-reminders, future) declare their types + deep-link patterns + frequency-cap contributions to the platform's global cap.

**Consumer surfaces (smart-reminders adapts; other consumers will plug in similarly):**
- Smart-reminders' `ReminderScheduler` becomes a consumer of `NotificationGateway`. Its public API (`scheduleIfAllowed(type:body:delayMinutes:)`) doesn't change. Its dispatch internals do.
- Smart-reminders registers its 6 types with `NotificationConsumerRegistry` at app init.
- Smart-reminders' deep-link strings (`ReminderType.deepLink`) move from inline strings to a registry registration. The router owns the URL→action map.

**Reachability gate (the v1 lesson):**
- Phase 5 must include a test or runtime smoke that asserts EVERY user-facing entry point in the PRD is reachable from a real navigation path. Specifically: priming view via post-workout sheet AND via Settings; deep-link routes via `onOpenURL` and via `.fitMeReminderTapped` (or its successor) AND landing on the correct target.
- The v4.X `/design pre-merge-review` gate (Figma node IDs in PR description) handles part of this; we add the deep-link-reachability test as an explicit Phase 5 gate.

**v1 demolition list (Phase 4):**
- Replace: `NotificationService.swift` → `NotificationGateway.swift` (new architecture, similar surface).
- Replace: `NotificationPreferencesStore.swift` → consumer-owned per-type preferences via the registry.
- Delete: `NotificationContentBuilder.swift` (consumer-owned now), `NotificationDeepLinkHandler.swift` (replaced by DeepLinkRouter), `DeepLinkHandler.swift` (the dead 14-LOC one in `FitTracker/Services/Notifications/`).
- Revive: `NotificationPermissionPrimingView.swift` — un-mark HISTORICAL.
- Migrate: smart-reminders' `ReminderType.deepLink` strings → `DeepLinkRouter` registration table.

**Analytics:**
- Reuse v1's `notification_permission_*` taxonomy (the priming events are platform-owned).
- Drop the v1 `notification_scheduled` / `notification_tapped` events (duplicates of smart-reminders' `reminder_*`).
- Add platform-level `deep_link_routed` event (carries `source`: `notification | url | universal_link`, `destination`: target screen).

**Success metrics:** inherit v1's 5 metrics. Add one: deep-link-route success rate (% of reminder taps that navigate to the intended destination, vs the silent-fail today).

### 3.4 Open questions for the PRD phase

| # | Question | Owner |
|---|---|---|
| OQ-1 | Should the priming view trigger on first-workout-completed (v1 plan), or first-app-open after the user has logged any data point (broader)? | PM |
| OQ-2 | Does `readinessAlert` sit in smart-reminders' frequency caps (so it counts toward the 3/day global), or in a separate platform-level critical bucket (so it can pre-empt the cap when readiness is low and a workout is scheduled today)? | Design |
| OQ-3 | Do we delete v1 NotificationService.swift outright (clean), or mark HISTORICAL and let the next refactor pass remove it? | Code |
| OQ-4 | Does revived `NotificationPermissionPrimingView` keep its current path (`FitTracker/Views/Notifications/`), or move into `FitTracker/Views/Notifications/v2/` per the V2 Rule? Note: v1 was never reachable, so V2 Rule (which exists for "alignment passes against ux-foundations.md on shipped surfaces") may not apply. | Code |
| OQ-5 | Smart-reminders is already shipped with `case_study_showcase` slot 08a. v2 case study slot — new slot post-23, or 08a-supplement? | Docs |
| OQ-6 | DeepLinkRouter URL grammar — flat (`fitme://training`, `fitme://nutrition`) or nested (`fitme://nav/training`, `fitme://nav/nutrition`, `fitme://action/log-meal`)? Nested supports future deep links into specific actions/sheets, not just tabs. | Code |
| OQ-7 | Universal Links scope — out for v2 (custom scheme only), or in (associated domains + apple-app-site-association)? Universal Links matter for App Store launch (deep links from email, web, push notifications) but add infra. | PM |
| OQ-8 | NotificationConsumerRegistry — does smart-reminders register at app-init time, or lazily on first scheduling call? Init-time is simpler; lazy is more decoupled. | Code |

---

## 4. External Sources (Not Re-Researched)

Carried forward from v1 by reference; nothing materially changed in 4 weeks:

- v1 PRD competitive scan: Whoop / Oura / Hevy notification patterns. Verdict was "specific, sparse, tied to clear benefit."
- iOS Human Interface Guidelines — Notifications. v1 followed the 3-step priming pattern.
- v1 case study `docs/case-studies/push-notifications-case-study.md` for full lifecycle narrative.
- Smart-reminders case study `docs/case-studies/smart-reminders-case-study.md` for its scheduler design.
- Smart-reminders behavioral learning case study (in-flight): `docs/case-studies/smart-reminders-behavioral-learning-case-study.md` for PR-2 SmartTimingResolver context.

---

## 5. Decision

**Selected (2026-05-07):** Approach B — push-notifications-v2 as the platform layer. Smart-reminders becomes the first consumer of the platform; future consumers (training-plan import-complete, app-store-launch APNs marketing, GDPR data-export-ready, etc.) plug into the same gateway.

**work_type:** `feature` (full 10-phase). The platform layer is a new capability with its own success metrics + new UI (priming surface) + a deep-link infrastructure that didn't exist before.

**Scope at a glance:**
- Platform: `NotificationGateway` + revived `NotificationPermissionPrimingView` + `DeepLinkRouter` + `NotificationConsumerRegistry`
- Consumer migration: smart-reminders ReminderScheduler internals (public API unchanged)
- New unique type: `readinessAlert` (registered by a new push-notifications-owned consumer module, OR registered by smart-reminders as its 7th type — TBD at PRD)
- Demolition: 4 v1 files replaced/deleted; smart-reminders' inline deep-link strings migrated to registry

**Next step:** User reviews this research → Phase 1 PRD with the decision encoded.

---

## 6. Deep-Link Routing — First-Class Infrastructure

The user surfaced deep-linking as a research-and-plan scope concern. This section catalogues the actual deep-link surface in the app today (sourced from `grep` of the Swift tree on 2026-05-07), identifies fragmentation, and proposes a unified architecture for v2.

### 6.1 Current state — three fragmented surfaces (and one silent partial-ship)

URL scheme registration: `Info.plist` declares `fitme` as `CFBundleURLSchemes` under `CFBundleURLTypes` named `PasswordReset` (Info.plist:32-34). Single scheme, multiple intended uses.

| # | Surface | Scheme(s) | Routing path | Status |
|---|---|---|---|---|
| 1 | **Auth (password reset)** | `fitme://reset-password?...` | `FitTrackerApp.swift:193 .onOpenURL { url in Task { await signIn.handleIncomingURL(url) } }` → `SignInService.handleIncomingURL` → exchanges URL for Supabase recovery session → sets `pendingPasswordResetURL` → `.fullScreenCover` presents `SetNewPasswordView` | **Working** — only deep link that actually routes end-to-end. Single special-purpose handler. |
| 2 | **v1 NotificationDeepLinkHandler** | `fitme://training`, `fitme://home` (in NotificationContentBuilder) | `NotificationContentBuilder` puts `userInfo["deepLink"]` into the notification payload. `DeepLinkHandler.targetTab(from: URL)` static function maps `host` → `AppTab?`. | **Dead code.** Zero callers of `DeepLinkHandler.targetTab`. Notifications never fire (v1 partial-ship), so the handler was never tested in a real path. |
| 3 | **Smart-reminders broadcast** | `fitme://settings/health`, `fitme://auth`, `fitme://nutrition`, `fitme://training`, `fitme://home` (per `ReminderType.deepLink`) | `ReminderNotificationDelegate.didReceive` → posts `.fitMeReminderTapped` via `NotificationCenter.default.post(...)` with `userInfo["deepLink"]`. | **Pending platform-layer integration.** Smart-reminders shipped what its PRD scoped: scheduling + delegate + broadcast on tap, with the correct deep-link payload. The consumer side — a SwiftUI subscriber that turns the broadcast into navigation — was not in smart-reminders' scope because no central deep-link router existed to plug into. Today, taps open the app to whatever tab was last selected; the deep-link payload is broadcast and dropped. v2 builds the consumer (DeepLinkRouter); the smart-reminders-side wiring is tracked as a backlog enhancement (see §6.6). |

**Note on framing:** v1's situation (UI-016) was a partial-ship — the priming surface was reviewed and merged but never reachable, missing what its own PRD specified. Smart-reminders' situation is different: smart-reminders shipped within scope. The deep-link consumer is platform infrastructure that wasn't a smart-reminders-PRD deliverable. Both look superficially similar ("notification feature merged but deep-linking doesn't fire end-to-end"), but only v1 is a partial-ship; smart-reminders' gap is a missing platform layer.

### 6.2 Adjacent surfaces that today don't deep-link (but should/could)

- **metric-tile-deep-linking** (shipped feature, separate state.json) — handles in-app navigation when users tap a Home metric tile. Uses internal SwiftUI navigation (NavigationStack push), NOT URL routing. Different surface from the notification deep-link path. Future unification possible: `DeepLinkRouter` could become the navigation source-of-truth for both URL-driven AND in-app tile-tap navigation.
- **Training plan import-complete** (just shipped Phase 1 via PR #234) — confirmation today shows in-app only. Future enhancement: post-import notification with `fitme://training` deep link to the imported plan. Plugs into the v2 platform.
- **App Store launch / marketing** (FIT-17, paused) — APNs deferred to Phase 2 of v1 push-notifications. Will need `https://fitme.app/...` Universal Links for outside-app entry points (email, web, push notifications coming from external sources). v2 should at minimum not foreclose Universal Links; the platform should be designed for them even if v2 ships custom-scheme-only.
- **GDPR data export ready** (shipped) — today, only in-app banner. Could deep-link to `fitme://settings/data-export` once the platform exists.

### 6.3 Proposed v2 architecture

Three layers, with crisp ownership:

```
┌──────────────────────────────────────────────────────────────────────┐
│ Consumer layer (multiple)                                            │
│   smart-reminders, training-plan, marketing/APNs, GDPR exports, …    │
│   - Owns: trigger evaluation, content composition, scheduling rules  │
│   - Calls into: NotificationGateway.dispatch(...)                    │
│   - Registers with: NotificationConsumerRegistry                     │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Platform layer (push-notifications-v2)                               │
│   ┌─────────────────────┐  ┌─────────────────────────────────────┐   │
│   │ NotificationGateway │  │ NotificationPermissionPrimingView   │   │
│   │  - auth wrapper     │  │  - 3-step priming UX                │   │
│   │  - dispatch surface │  │  - settings + first-workout entry   │   │
│   │  - global cap audit │  │                                     │   │
│   └──────────┬──────────┘  └─────────────────────────────────────┘   │
│              │                                                       │
│              ▼                                                       │
│   ┌─────────────────────┐  ┌─────────────────────────────────────┐   │
│   │ DeepLinkRouter      │  │ NotificationConsumerRegistry        │   │
│   │  - URL → action     │  │  - per-consumer types               │   │
│   │  - foreground hand. │  │  - per-consumer URL patterns        │   │
│   │  - background hand. │  │  - per-consumer cap contributions   │   │
│   └──────────┬──────────┘  └─────────────────────────────────────┘   │
└──────────────┼───────────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ iOS surfaces                                                         │
│  UNUserNotificationCenter   .onOpenURL   Universal Links (future)    │
└──────────────────────────────────────────────────────────────────────┘
```

**`DeepLinkRouter` responsibilities:**

- Single entry point for ALL `fitme://...` URLs and (future) `https://fitme.app/...` Universal Links.
- Receives URLs from three sources:
  - `FitTrackerApp.onOpenURL` (system → app for any registered URL)
  - `UNUserNotificationCenterDelegate.didReceive` (notification taps; replaces smart-reminders' dead `.fitMeReminderTapped` broadcast)
  - In-app programmatic calls (e.g., metric-tile-deep-linking, future)
- Maintains a registry: `URLPattern → DeepLinkAction` (where `DeepLinkAction` is either a tab switch, a sheet present, an in-place navigation, or a consumer-specific callback like `signIn.handleIncomingURL`).
- Single observation point for the SwiftUI root: `NavigationStack` and `TabView` listen to `@Published` state on `DeepLinkRouter`, NOT to `NotificationCenter` broadcasts. This is the architecturally correct pattern (state-driven, observable, testable) and fixes smart-reminders' silent partial-ship by construction.

**URL grammar (proposal — OQ-6):**

Two candidate grammars; PRD picks one.

| Grammar | Examples | Pros | Cons |
|---|---|---|---|
| Flat (today's de-facto) | `fitme://training`, `fitme://nutrition`, `fitme://reset-password?token=…` | Simple, already partly implemented. | Doesn't scale — `fitme://settings/health` and `fitme://settings/data-export` already need a sub-path; flat collides on namespaces. |
| Nested verb-noun | `fitme://nav/training`, `fitme://nav/nutrition`, `fitme://action/log-meal`, `fitme://auth/reset-password?token=…` | Scales to actions, settings sub-paths, multi-tier deep links. Preserves current paths under `fitme://nav/...` aliases for backwards compatibility. | Requires migrating Info.plist registrations (no, scheme is the same `fitme`) and updating ~10 call sites in smart-reminders. |

Recommendation (deferred to PRD): nested verb-noun. Auth reset stays at `fitme://auth/reset-password` (one-time path migration); smart-reminders' deep-link strings update at registry registration; everything routes through `DeepLinkRouter`.

**Universal Links posture (OQ-7):**

Universal Links matter for App Store launch — they're how email links, web links, and external push notifications open the app at a specific destination instead of cold-starting it. They require an `apple-app-site-association` (AASA) file hosted on `fitme.app` (which fitme-story Vercel project already serves) plus the iOS app's `Associated Domains` capability.

PRD options:
- **In scope for v2:** add Associated Domains, ship a minimal AASA file at `fitme-story/public/.well-known/apple-app-site-association`, route Universal Links through the same `DeepLinkRouter`. Adds ~0.5 day. Forecloses zero future paths.
- **Out of scope for v2, foreclose nothing:** ship the platform layer with Universal Links architecturally accommodated (DeepLinkRouter handles both schemes from day one; Info.plist + AASA work is deferred to a follow-on enhancement). Adds 0 day to v2 scope.

Recommendation (deferred to PRD): out-of-scope for v2, architecturally-accommodated. App Store launch is FIT-17's milestone, not v2's. Tag the follow-on as a smart-reminders-style enhancement: ~1 day.

### 6.4 Deep-link reachability gate (Phase 5 test)

The v1 + smart-reminders silent partial-ships both occurred because the test surface tested *substrate* not *reachability*. v2's Phase 5 must include:

1. **Routing test** — for each registered URL pattern, simulate an `.onOpenURL` event and assert that `DeepLinkRouter` resolves the URL to the correct `DeepLinkAction` AND that the SwiftUI root state change actually presents/navigates to the expected destination.
2. **Notification-tap test** — simulate a `UNNotificationResponse` with each consumer's deep-link payload; assert the same end-to-end navigation lands.
3. **Broadcast-consumer test** — assert that `DeepLinkRouter`'s `@Published` state emits on every routed URL, AND that the SwiftUI root subscribes to it. (This is the test that, had it existed for smart-reminders, would have caught the silent partial-ship.)

These tests run against a SwiftUI view harness (NOT just the route-resolver in isolation). They are XCTest, not XCUITest — fast, hermetic, no simulator parallelism dependency.

### 6.5 Effect on §3 effort estimate

The platform-layer scope (Approach B) + deep-link unification adds ~1 day vs the §3.1 estimate. Updated total: ~6–7 calendar days end-to-end (Phase 0 done; Phases 1–8 across ~5–6 work days).

### 6.6 Smart-reminders consumer-side enhancement (separate backlog item)

The smart-reminders side of the platform integration is a discrete piece of work, distinct from v2's platform-build scope. v2 ships `DeepLinkRouter` + `NotificationGateway` + `NotificationConsumerRegistry`. Smart-reminders adapts to consume them. The smart-reminders adaptation is small but explicit:

- Smart-reminders' `ReminderScheduler.scheduleIfAllowed(...)` internals call `NotificationGateway.dispatch(...)` instead of `UNUserNotificationCenter.current().add(...)` directly. Public API unchanged.
- Smart-reminders registers its 6 reminder types with `NotificationConsumerRegistry` at app init (in `FitTrackerApp.swift`).
- Smart-reminders' inline `ReminderType.deepLink` strings move from the enum into `DeepLinkRouter` registration entries (a registry-table value owned by the router, keyed by reminder type).
- `ReminderNotificationDelegate.didReceive`'s `.fitMeReminderTapped` broadcast either (a) stays as-is and `DeepLinkRouter` becomes its consumer, or (b) is removed and the delegate calls `DeepLinkRouter.handle(url:source:)` directly. PRD picks one.

This adaptation is filed as a backlog enhancement that is **scoped to ship together with v2** — not a v2 deliverable, but the v2 PRD specifies the smart-reminders changes that close the integration. Both halves merge in the same PR (or paired PRs in the same release window).

**Backlog item filed:** `docs/product/backlog.md` → "Smart Reminders ↔ Push Notifications v2 deep-link integration (Enhancement; parent: smart-reminders; ships with push-notifications-v2)"
