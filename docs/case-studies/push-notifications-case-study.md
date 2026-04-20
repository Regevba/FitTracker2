# Push Notifications — Case Study

> Framework v5.2 | feature | 2026-04-12 → 2026-04-16 | Commits `8d7d2d5` → `b07eb5a`
>
> **Headline:** The first feature to complete a full v5.2 PM lifecycle end-to-end — research through merge in 3.5 calendar days, 12 tasks, 18 tests, 10 analytics events, 2 critical review findings caught and fixed before close.
>
> **Deferred to Phase 2:** remote push (APNs), Settings preferences UI, rich notifications. Phase 1 shipped the local-notification substrate and the priming surface only.

---

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | push-notifications |
| Framework Version | v5.2 (first full lifecycle on this version) |
| Work Type | Feature (9-phase funnel) |
| Phase 1 scope | Local notifications only (`UNUserNotificationCenter`) — no APNs |
| Tasks | 12 (T1 → T12) |
| Files created | 5 (4 Swift sources + 1 test file) |
| Production code | 400 LOC across 4 files (Service 143 + Preferences 89 + Priming view 103 + Content builder 51 + DeepLink 14) |
| Test code | 310 LOC across 2 files (NotificationTests 158 + NotificationServiceTests 152) |
| Tests | 18 (10 in `NotificationTests` + 8 in `NotificationServiceTests`) |
| Analytics events | 10 (all `notification_` prefixed) |
| PRD requirements | 17 (8 P0 + 5 P1 + 4 P2 deferred) |
| Success metrics defined | 5 (opt-in rate, tap-through, ack rate, disable rate, DAU lift) |
| Code review findings | 11 (2 critical, 4 important, 5 suggestions) |
| Review verdict | `APPROVED_AFTER_FIXES` |
| Critical fixes landed | 3 (C1: frequency cap, C2: per-type check, I1: singleton usage) |
| PR delivery model | Direct-to-main commit chain (no feature PR) |
| Post-ship regression | UI-016 — priming view never wired into navigation |

---

## 2. Why This Case Study Exists

Push Notifications was the first feature where the v5.2 PM workflow ran end-to-end on a real product surface: research, PRD, tasks, UX spec, implementation, tests, code review, and merge. It is also the case study that surfaced a specific class of post-ship defect — a complete, reviewed, tested feature whose user-facing view is never instantiated — which later became audit finding **UI-016** and a project-wide lesson about treating "shipped" and "reachable" as two different closure states.

Every feature in FitMe is required to have a case study per the 2026-04-13 project rule. This one had been deferred while the UI-016 finding was being investigated. Documenting it here — with the dead-view outcome recorded honestly — is the correct closure.

---

## 3. PRD Summary

**Purpose:** Deliver a local notification system for workout reminders, readiness alerts, and recovery nudges, using `UNUserNotificationCenter` with UX-Foundations-compliant permission priming. Defer remote push to Phase 2.

**Primary metric:** Notification opt-in rate ≥ 40%. Kill criterion: < 20% after 30 days.

**Success metrics (from `docs/product/prd/push-notifications.md`):**

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Notification opt-in rate | 0% (no system today) | ≥ 40% | < 20% after 30 days |
| Workout reminder tap-through rate | 0% | ≥ 25% | < 10% after 30 days |
| Readiness alert acknowledgement rate | 0% | ≥ 20% | < 8% after 30 days |
| Notification disable rate (post opt-in) | unknown | ≤ 10%/month | > 25%/month |
| DAU lift (notification-attributed sessions) | 0 | +8% WAU | no measurable lift at 60 days |

**Post-launch review cadence:** 2 weeks after first opt-in data, then monthly. (Not yet run — no opt-in data has been collected; see § 7.)

**In-scope (P0 / P1):** three notification types, 3-step permission priming, quiet hours, daily frequency cap, per-type preferences store, deep links, 10 analytics events, unit tests.

**Deferred (P2):** Settings preferences UI (tied to Smart Reminders feature), remote push via APNs, rich notifications with media, notification grouping/threading.

---

## 4. Phase Walkthrough

### Phase 0 — Research (approved 2026-04-13)

`research.md` framed the product gap: strong daily intelligence with no proactive surface. Surveyed Whoop, Oura, Hevy — all of them confirmed the lesson that *high-value notifications are specific, sparse, and tied to a clear user benefit*. Technical feasibility confirmed for local notifications via `UNUserNotificationCenter`; deferred remote push as a Phase 2 decision. Draft opt-in target: > 40%.

### Phase 1 — PRD (approved 2026-04-15)

17 requirements authored across P0 / P1 / P2. 5 success metrics with kill criteria. 10 analytics events specified with parameters. 3 open questions captured (readiness threshold configurability, session attribution window, rest-day-vs-training-day recovery firing). GDPR/privacy clause: all `notification_*` events gated through `ConsentManager`; no notification content logged.

### Phase 2 — Tasks (approved 2026-04-15)

`tasks.md` split the work into 12 tasks along a critical path: `T1 (NotificationService) → T3 (priming view) → T5 (readiness alert) → T8 (lifecycle wiring) → T10 (unit tests) → T12 (build verification)`. Estimated 5.5 days of effort. Architecture notes specified that `NotificationService` would be a singleton wrapping `UNUserNotificationCenter`, that preferences would be UserDefaults-backed, and that readiness alerts would only fire when `readinessResult.confidence >= .medium`.

### Phase 3 — UX / Integration (approved 2026-04-15)

`ux-spec.md` defined:

- **Permission priming flow (3-step):** pre-primer screen (after first workout completion) → system dialog → graceful degradation (Settings deep-link banner, no repeated prompts).
- **Notification content:** three types with title/body/category/action/timing/tone each.
- **Timing rules:** quiet hours 10 PM → 7 AM, max 2 notifications/day across all types, min 4-hour cooldown, 1/day cap on workout and readiness, 1/week on recovery.
- **Token mapping:** CTA at 52pt (above Fitts's 44pt minimum), `AppGradient.screenBackground`, `AppColor.Accent.primary`, `AppText.titleStrong`.

Design-system compliance gateway: 6/6 pass (Fitts, progressive disclosure, celebration-not-guilt, accessibility, reduce-motion, token compliance).

### Phase 4 — Implementation (2026-04-15 → 2026-04-16)

Implementation landed in a chain of direct commits to main (no feature PR). Commit chronology:

| Commit | Date | Task | Summary |
|---|---|---|---|
| `69a9732` | 2026-04-15 | T4–T6 | `NotificationContentBuilder` — 3 content builders (workout, readiness, recovery), all with deep-link userInfo |
| `8e95368` | 2026-04-15 | T3 | `NotificationPermissionPrimingView` — 3-step priming view, full-screen, `AppGradient.screenBackground`, "Not now" secondary |
| `1a4dc37` | 2026-04-15 | T7 + T9 | `DeepLinkHandler` + 10 analytics events wired into `AnalyticsProvider` |
| `cd7d225` | 2026-04-15 | T10 | 8 unit tests in `NotificationTests.swift` for content builder + deep links + preferences |
| `4300ff7` | 2026-04-16 | T8 + T12 | Lifecycle wiring (scheduler invocation on app launch) + pbxproj registration |

### Phase 5 — Testing (complete 2026-04-16)

- `NotificationTests.swift`: 10 tests covering preferences defaults, content builder output for all three types, deep-link routing, `NotificationType` enum completeness, quiet-hours boundary math.
- `NotificationServiceTests.swift`: later backfilled via audit Sprint-F salvage (commit `2e55303`, TEST-013) with 8 tests covering singleton wiring, quiet-hour gates, unauthorized scheduling no-op, per-type-disabled no-op, cancellation idempotency.
- Build verification: `BUILD SUCCEEDED` on the 2026-04-16 run.

### Phase 6 — Review (complete 2026-04-16)

Code review produced 11 findings (stored in `docs/reviews/push-notifications-review.md`), verdict `REQUEST_CHANGES`. Breakdown:

- **2 critical** — C1: `scheduleNotification` did not enforce the daily frequency cap (the whole point of `maxDailyNotifications` was unused). C2: `scheduleNotification` did not check `preferences.isEnabled(for: type)`, so disabled types could still fire.
- **4 important** — I1: priming view called `UNUserNotificationCenter` directly instead of `NotificationService.shared`, defeating the singleton boundary. Plus 3 others recorded in the review doc.
- **5 suggestions** — minor style and naming notes.

Commit `531b196` landed C1 + C2 + I1 fixes the same day. Re-review: approved.

### Phase 7 — Merge (complete 2026-04-16)

Merged directly via commit chain on main. Commit `b07eb5a` flipped state.json to `complete` with the note *"First feature to complete full v5.2 PM lifecycle."*

### Phase 8 — Documentation (complete at state.json close; this case study is the closure)

---

## 5. What Shipped

**Code (production):**

- `FitTracker/Services/Notifications/NotificationService.swift` (143 LOC) — Singleton managing `UNUserNotificationCenter`. Enforces quiet hours (`isQuietHour(at:)` exposed for tests), per-type preferences, daily frequency cap (via date-stamped UserDefaults key), and scheduling short-circuit when unauthorized. Post-C1/C2 fix is the source-of-truth surface.
- `FitTracker/Services/Notifications/NotificationPreferencesStore.swift` (89 LOC) — UserDefaults-backed preferences. Master switch, 3 per-type toggles, and `maxDailyNotifications` (default 2). All keys prefixed `ft.notification.`. `isEnabled(for: NotificationType)` composes master + per-type.
- `FitTracker/Services/Notifications/NotificationContentBuilder.swift` (51 LOC) — Three static builders returning `UNMutableNotificationContent` with title, body, category (`workout` / `readiness` / `recovery`), sound, and deep-link userInfo.
- `FitTracker/Services/Notifications/DeepLinkHandler.swift` (14 LOC) — `fitme://` URL → `AppTab` routing.
- `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift` (103 LOC) — 3-step priming view with bell icon, title, body, CTA (52pt height, `AppColor.Accent.primary`), "Not now" secondary, and a denied-state banner that deep-links to iOS Settings.

**Tests:**

- `FitTrackerTests/NotificationTests.swift` (158 LOC) — 10 tests, isolated UserDefaults suites for hermeticity.
- `FitTrackerTests/NotificationServiceTests.swift` (152 LOC, added later via audit Sprint F) — 8 tests. Key insight from the file header: *"In the test runner, notifications are not authorized → the function must short-circuit. We verify that no daily-cap side-effect occurs in that path."*

**Analytics:** 10 events, all `notification_` prefixed (per project convention): `notification_permission_primed`, `_requested`, `_granted`, `_denied`, `_settings_deeplink_shown`, `_scheduled`, `_cancelled`, `_tapped`, `_dismissed`, `_suppressed`.

---

## 6. What Did Not Ship (or Did Not Reach Users)

- **Settings preferences UI** — P2, deferred to the Smart Reminders feature. The preferences *store* exists but has no editing surface.
- **Remote push via APNs** — P2, Phase 2.
- **Priming view reachability (UI-016)** — The `NotificationPermissionPrimingView` was built, reviewed, fixed (I1), and tested, but never wired into any navigation path. It does not appear in `RootTabView`, is not presented after first-workout completion (the PRD trigger), and is not reachable from Settings (because the Settings preferences UI was deferred). As of 2026-04-16, the file carries a `HISTORICAL — never wired into navigation` header and is documented as dead code. Audit finding UI-016 captured this. **The scheduling substrate works; the consent surface does not reach the user.**
- **Post-launch metrics review** — Not recorded. Because the priming view is unreachable, no opt-in data can be collected, so the 2-week post-launch review has not been run. This is a direct downstream consequence of UI-016.

---

## 7. Lessons

1. **"Shipped" and "reachable" are different closure states.** Every task in `tasks.md` was marked done; every test passed; the code review approved the diff. But T8 ("wire into app lifecycle") landed the *scheduling* wiring without the *presentation* wiring — the priming view was never actually presented. Future features must split "wired into scheduling" from "wired into navigation" as separate, verifiable tasks, and the test plan must include at least one test that *presents* the new view from its intended entry point.

2. **The v5.2 PM workflow caught real bugs before merge.** The 2 critical review findings (C1: cap not enforced; C2: per-type check missing) were both real product defects — a frequency cap that wouldn't cap, a disable toggle that wouldn't disable. Both were caught in Phase 6 review, not in production. This is the outcome the review phase exists to produce. A feature branch with CI would have caught them earlier; the direct-to-main commit chain deferred the check to the end.

3. **Deferring a Settings UI costs more than it saves when it's the only way to reach the feature.** The decision to defer the preferences editing surface to the Smart Reminders feature was defensible on scope. But once the priming view also turned out to be unreachable, Settings became the *only* path to turn notifications on — and it didn't exist. Two independent deferrals composed into a reachability gap. Scope decisions that each look local should be checked against "is there at least one live entry point left?"

4. **Direct-to-main for a 9-phase feature is risky.** This feature shipped as a chain of direct commits on main rather than a feature branch + PR. The CLAUDE.md rule says large features (> 5 files, new services) go on a `feature/{name}` branch. Push Notifications violated that rule: 5 new files, 2 new services. In future, the same lifecycle through a PR would have surfaced the reachability gap during the merge review, not three weeks later in an audit.

5. **Analytics-first metric definition is only useful if the events fire.** 10 analytics events are specified, instrumented, and consent-gated. Not one has fired in production because the priming view is unreachable. The PRD's 5 success metrics have no data. The taxonomy is correct; the pipeline is correct; the dependency chain broke at the entry point.

6. **Audit-driven test salvage is a valid closure pattern.** `NotificationServiceTests.swift` (TEST-013) was not part of the original 12-task plan — it was backfilled during audit Sprint F via commit `2e55303`. The 8 tests cover the exact gating logic (quiet-hour, unauthorized short-circuit, per-type disable) that the C1/C2 critical findings would have benefited from. This is the right pattern: when the audit surfaces missing test coverage, salvaging a test file into the existing suite is cheaper than re-opening the feature cycle.

---

## 8. Links

- **PRD:** `docs/product/prd/push-notifications.md`
- **Research:** `.claude/features/push-notifications/research.md`
- **Tasks:** `.claude/features/push-notifications/tasks.md`
- **UX spec:** `.claude/features/push-notifications/ux-spec.md`
- **State file:** `.claude/features/push-notifications/state.json`
- **Code review:** `docs/reviews/push-notifications-review.md`
- **Key commits:** `69a9732` (T4-T6), `8e95368` (T3), `1a4dc37` (T7+T9), `cd7d225` (T10), `4300ff7` (T8+T12), `e975910` (review), `531b196` (C1+C2+I1 fixes), `b07eb5a` (complete), `2e55303` (TEST-013 salvage)
- **Production files:** `FitTracker/Services/Notifications/` (4 files) + `FitTracker/Views/Notifications/NotificationPermissionPrimingView.swift`
- **Test files:** `FitTrackerTests/NotificationTests.swift` + `FitTrackerTests/NotificationServiceTests.swift`
- **Related audit findings:** UI-016 (priming view dead code), TEST-013 (NotificationService test coverage)
- **Downstream features:** Smart Reminders (blocked-dependency: owns the Settings preferences UI that reaches this subsystem), ReminderScheduler (sibling service for scheduled reminders)
