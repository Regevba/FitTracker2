# Onboarding — Phase 2: Task Breakdown

> **Date:** 2026-04-05
> **Feature:** onboarding
> **PRD:** `.claude/features/onboarding/prd.md`

---

## Task List

### T1: Create OnboardingView container + flow navigation
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** None
- **Description:** Create `FitTracker/Views/Onboarding/OnboardingView.swift` — a TabView/PageView container that manages the 5-step flow. Includes:
  - `@State var currentStep: Int` (0-4)
  - Segmented progress bar component at top (5 segments)
  - Forward/back navigation
  - `UserDefaults.hasCompletedOnboarding` guard
  - Skip button logic (visible on steps 1-3)

### T2: Welcome screen (Step 0)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingWelcomeView.swift`:
  - FitMe app icon (locked design: 4 intertwined circles + gradient FitMe text)
  - Animated using FitMeLogoLoader (`.breathe` mode)
  - Tagline: "Your fitness command center"
  - "Get Started" CTA button (AppButton primary)
  - No skip on this screen

### T3: Goals screen (Step 1)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingGoalsView.swift`:
  - 4 large tappable cards: Build Muscle / Lose Fat / Maintain / General Fitness
  - Single selection (highlight selected card)
  - "Continue" button + "Skip" option
  - Persist selection to UserProfile.goal
  - Fire `onboarding_goal_selected` GA4 event with `goal_value` param

### T4: Profile screen (Step 2)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Create `OnboardingProfileView.swift`:
  - Training experience picker: Beginner / Intermediate / Advanced (3 cards or segmented control)
  - Weekly frequency picker: 2-6 days (stepper or horizontal selector)
  - "Continue" button + "Skip" option
  - Persist to UserProfile.experienceLevel + UserProfile.weeklyFrequency
  - Default if skipped: Intermediate, 3 days

### T5: HealthKit permission screen (Step 3)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1, HealthKitService
- **Description:** Create `OnboardingHealthKitView.swift`:
  - Contextual explanation with icon/illustration: "Sync your Apple Watch to track recovery"
  - List of what FitMe will access: Heart Rate, HRV, Steps, Sleep
  - "Connect Health" CTA → triggers `HealthKitService.requestAuthorization()`
  - "Skip" option (can connect later in Settings)
  - Fire `permission_result` GA4 event with `permission_type: healthkit`, `granted: true/false`
  - Handle iPad gracefully (HealthKit not available)

### T6: First Action screen (Step 4)
- **Type:** ui
- **Effort:** 0.5 day
- **Dependencies:** T1, T3
- **Description:** Create `OnboardingFirstActionView.swift`:
  - Personalized message based on selected goal (e.g., "Ready to build muscle?")
  - Two CTA options: "Start Your First Workout" / "Log Your First Meal"
  - Sets `UserDefaults.hasCompletedOnboarding = true`
  - Navigates to Home screen with selected tab
  - No skip on this screen
  - Fire `tutorial_complete` GA4 event

### T7: Wire onboarding into app launch flow
- **Type:** infra
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Modify `FitTrackerApp.swift`:
  - Add `@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false`
  - If `!hasCompletedOnboarding` → show OnboardingView before auth/home
  - After onboarding completes → proceed to normal auth flow
  - Returning users bypass entirely
  - **High-risk file** — minimal change only

### T8: GA4 analytics instrumentation
- **Type:** infra
- **Effort:** 0.5 day
- **Dependencies:** T1
- **Description:** Update analytics infrastructure:
  - `AnalyticsProvider.swift`: Add 5 events, 5 params, 5 screens, 1 user property
  - `AnalyticsService.swift`: Add typed convenience methods
  - `analytics-taxonomy.csv`: Add rows
  - Wire `.analyticsScreen()` modifier on all 5 onboarding views
  - Fire `tutorial_begin` on Welcome screen appear
  - Fire `onboarding_step_viewed` / `onboarding_step_completed` / `onboarding_skipped` per step

### T9: Progress bar component
- **Type:** ui
- **Effort:** 0.25 day
- **Dependencies:** None
- **Description:** Create `OnboardingProgressBar.swift`:
  - 5-segment horizontal bar
  - Active segment uses brand gradient (orange→blue)
  - Completed segments filled, upcoming segments gray
  - Uses AppColor and AppSpacing tokens
  - Animated transitions between steps

### T10: Unit tests + analytics tests
- **Type:** test
- **Effort:** 0.5 day
- **Dependencies:** T1-T8
- **Description:**
  - Test onboarding flow navigation (forward, skip, complete)
  - Test UserDefaults guard (shows only once)
  - Test goal/profile persistence to UserProfile
  - Analytics tests in `AnalyticsTests.swift`:
    - All 5 new events fire correctly
    - Step params are correct
    - Consent gating works
    - Screen tracking for 5 onboarding screens

---

## Summary

| # | Task | Type | Effort | Dependencies |
|---|------|------|--------|-------------|
| T1 | OnboardingView container + navigation | ui | 0.5d | — |
| T2 | Welcome screen | ui | 0.5d | T1 |
| T3 | Goals screen | ui | 0.5d | T1 |
| T4 | Profile screen | ui | 0.5d | T1 |
| T5 | HealthKit permission screen | ui | 0.5d | T1 |
| T6 | First Action screen | ui | 0.5d | T1, T3 |
| T7 | Wire into app launch flow | infra | 0.5d | T1 |
| T8 | GA4 analytics instrumentation | infra | 0.5d | T1 |
| T9 | Progress bar component | ui | 0.25d | — |
| T10 | Unit tests + analytics tests | test | 0.5d | T1-T8 |

**Total effort:** ~4.75 days
**Parallelism:** T1 + T9 can run first, then T2-T6 in parallel, T7-T8 alongside, T10 last.

---

## Execution Order

```
Day 1:  T1 (container) + T9 (progress bar)
Day 2:  T2 (welcome) + T3 (goals) + T8 (analytics)
Day 3:  T4 (profile) + T5 (healthkit)
Day 4:  T6 (first action) + T7 (app launch wiring)
Day 5:  T10 (tests) + polish
```

---

# v2 — UX Alignment Task List

> **Date:** 2026-04-07
> **Parent PRD section:** `prd.md` → `# v2 — UX Alignment`
> **v1 tasks status:** All T1-T10 marked `done` with `version: v1` in state.json
> **Approval gate:** Tasks must be approved before Phase 3 (UX) executes

## Task Principles
- **Audit-driven:** V2-T8 (code deltas) scope depends on V2-T1/T2 audit findings. Task is scaffolded as a placeholder with sub-tasks generated after audit.
- **Manual gate pervasive:** V2-T5 (Figma) and V2-T8 (code) both pause on every UI delta for user confirmation per PRD v2 requirement.
- **v1 preserved:** No v1 task is re-executed. v2 tasks only add, audit, or modify.

## Tasks

### V2-T1: UX audit onboarding against ux-foundations.md
- **Type:** research
- **Skill:** ux
- **Effort:** 0.5 day
- **Priority:** critical
- **Dependencies:** —
- **Description:** Execute `/ux audit onboarding` procedure. For each of the 10 parts of `docs/design-system/ux-foundations.md`, evaluate v1 onboarding code and produce pass/warn/fail + specific findings.
- **Output:** `.claude/features/onboarding/ux-audit-report.md` with compliance matrix
- **Acceptance:** Every foundation part has a row; every warn/fail has a concrete code/screen reference

### V2-T2: Design system audit onboarding
- **Type:** research
- **Skill:** design
- **Effort:** 0.25 day
- **Priority:** critical
- **Dependencies:** —
- **Description:** Execute `/design audit onboarding`: token compliance (no raw hex/font/spacing literals), component reuse (AppButton, AppCard, etc.), pattern consistency with existing screens, motion compliance.
- **Output:** `.claude/features/onboarding/design-audit-report.md`
- **Acceptance:** Every onboarding Swift view evaluated; violations list with file:line references

### V2-T3: Create ux-research.md
- **Type:** docs
- **Skill:** ux
- **Effort:** 0.25 day
- **Priority:** high
- **Dependencies:** V2-T1
- **Description:** Document applicable ux-foundations principles, iOS HIG references, external research. Per skill Step 1 of Phase 3.
- **Output:** `.claude/features/onboarding/ux-research.md`
- **Acceptance:** References ≥5 foundations principles with concrete application to onboarding; ≥3 iOS HIG references; ≥2 external sources

### V2-T4: Create ux-spec.md
- **Type:** docs
- **Skill:** ux
- **Effort:** 0.5 day
- **Priority:** critical
- **Dependencies:** V2-T1, V2-T2, V2-T3
- **Description:** Per `docs/design-system/feature-development-gateway.md`: screen list, wireframe descriptions, component inventory, token mapping, flows, a11y, motion. For each screen: empty/loading/error/success states.
- **Output:** `.claude/features/onboarding/ux-spec.md`
- **Acceptance:** All 6 screens (Welcome, Goals, Profile, HealthKit, Consent, First Action) specified; checklist at `docs/design-system/feature-design-checklist.md` walked through for each

### V2-T5: Build Figma v2 section
- **Type:** design
- **Skill:** design
- **Effort:** 1 day (multi-session if needed)
- **Priority:** critical
- **Dependencies:** V2-T4
- **Description:** Execute `docs/prompts/figma-onboarding-v2-prompt.md` via Figma MCP. Target file `0Ai7s3fCFqR5JXDW8JvgmD`, page "Onboarding", new section `I3.2 — Onboarding v2 (PRD-Aligned)` with 6 screens. **Existing `I3.1` section MUST remain unchanged.**
- **Manual confirm gate:** For each screen delta vs v1 code appearance, present before/after + ux-foundations rationale to user before populating Figma.
- **Output:** 6 Figma frames with node IDs recorded in ux-spec.md
- **Acceptance:** Section created, 6 screens built, v1 section untouched, node IDs documented, screenshots captured

### V2-T6: Design system compliance gateway
- **Type:** test
- **Skill:** design
- **Effort:** 0.25 day
- **Priority:** critical
- **Dependencies:** V2-T4, V2-T5
- **Description:** Run the 5 compliance checks from the pm-workflow skill's Phase 3 gateway: token / component reuse / pattern consistency / accessibility / motion. Produce a pass/fail report.
- **Output:** Compliance report appended to `ux-spec.md`
- **Acceptance:** All 5 checks pass, OR user has explicitly chosen an option (fix / evolve / override) per CLAUDE.md evolution rules

### V2-T7: Generate code delta plan from audit
- **Type:** docs
- **Skill:** dev
- **Effort:** 0.25 day
- **Priority:** high
- **Dependencies:** V2-T1, V2-T2, V2-T6
- **Description:** Synthesize audit + compliance findings into a concrete list of code patches. Each patch: file, lines, before/after, ux-foundations rationale. **Subject to manual confirm gate per PRD v2.**
- **Output:** `.claude/features/onboarding/v2-delta-plan.md`
- **Acceptance:** Every patch explicitly approved by user before V2-T8 begins

### V2-T8: Apply approved code deltas
- **Type:** ui
- **Skill:** dev
- **Effort:** 0.5-1 day (audit-dependent)
- **Priority:** critical
- **Dependencies:** V2-T7
- **Description:** Apply each approved patch from V2-T7 as a discrete commit. Known deltas already likely:
  - Update `OnboardingProgressBar.swift` to support 6 segments (was 5)
  - Verify Consent screen (integrated in commit `d017a30`) matches Figma v2 design
  - Any raw literal → semantic token replacements from V2-T2 findings
  - Any a11y fixes from V2-T1 findings
- **Output:** Commits on `feature/onboarding-ux-align` branch
- **Acceptance:** Every delta has a commit referencing the approved patch ID and Figma node ID

### V2-T9: Refresh analytics + unit tests
- **Type:** test
- **Skill:** qa
- **Effort:** 0.25 day
- **Priority:** high
- **Dependencies:** V2-T8
- **Description:** Re-run v1 tests; add tests for any new events or state introduced by v2. Verify no regression in analytics event firing. If Consent screen was never tested in v1 analytics suite, add coverage.
- **Output:** Updated `FitTrackerTests/OnboardingTests.swift` + `AnalyticsTests.swift`
- **Acceptance:** All tests green, `make tokens-check && xcodebuild test` passes

### V2-T10: Update showcase doc with phase outcomes
- **Type:** docs
- **Skill:** release
- **Effort:** 0.25 day
- **Priority:** medium
- **Dependencies:** V2-T8, V2-T9
- **Description:** Fill in `docs/case-studies/pm-workflow-showcase-onboarding.md` with: actual phase timings, decisions made, manual confirm rounds count, audit findings summary, lessons learned.
- **Output:** Updated showcase doc
- **Acceptance:** Every Phase section has a completion note; Lessons section has ≥3 entries

### V2-T11: PR review + merge
- **Type:** infra
- **Skill:** release
- **Effort:** 0.25 day
- **Priority:** critical
- **Dependencies:** V2-T9, V2-T10
- **Description:** PR to main. Title: `feat(onboarding): v2 UX alignment per ux-foundations.md`. Body links to PRD v2 section, ux-research.md, ux-spec.md, Figma v2 section, audit reports, showcase doc. High-risk file review (FitTrackerApp.swift). CI must be green on both branch and main.
- **Output:** Merged PR, branch deleted
- **Acceptance:** PR merged to main, CI green, change broadcast executed per pm-workflow skill

### V2-T12: Post-merge documentation
- **Type:** docs
- **Skill:** release
- **Effort:** 0.25 day
- **Priority:** medium
- **Dependencies:** V2-T11
- **Description:** Update `docs/design-system/feature-memory.md` with any token/component evolution. Update `CHANGELOG.md`. Update `docs/product/backlog.md`. Close state.json to `complete`.
- **Output:** Updated docs
- **Acceptance:** state.json `current_phase = complete`, metrics first_review_date set

---

## v2 Summary

| # | Task | Type | Skill | Effort | Dependencies | Priority |
|---|------|------|-------|--------|-------------|----------|
| V2-T1 | UX audit | research | ux | 0.5d | — | critical |
| V2-T2 | Design audit | research | design | 0.25d | — | critical |
| V2-T3 | ux-research.md | docs | ux | 0.25d | V2-T1 | high |
| V2-T4 | ux-spec.md | docs | ux | 0.5d | V2-T1,T2,T3 | critical |
| V2-T5 | Figma v2 build | design | design | 1d | V2-T4 | critical |
| V2-T6 | Compliance gateway | test | design | 0.25d | V2-T4,T5 | critical |
| V2-T7 | Delta plan | docs | dev | 0.25d | V2-T1,T2,T6 | high |
| V2-T8 | Apply code deltas | ui | dev | 0.5-1d | V2-T7 | critical |
| V2-T9 | Tests refresh | test | qa | 0.25d | V2-T8 | high |
| V2-T10 | Showcase doc | docs | release | 0.25d | V2-T8,T9 | medium |
| V2-T11 | PR merge | infra | release | 0.25d | V2-T9,T10 | critical |
| V2-T12 | Post-merge docs | docs | release | 0.25d | V2-T11 | medium |

**Total v2 effort:** ~4.5-5 days (but packed into ~2-3 sessions per PRD estimate)

## v2 Parallelism

```
Session 1:  V2-T1 + V2-T2 (parallel audits) → V2-T3 → V2-T4
Session 2:  V2-T5 (Figma, multi-step with manual gates) → V2-T6
Session 3:  V2-T7 → V2-T8 (manual gates per delta) → V2-T9 → V2-T10 → V2-T11 → V2-T12
```

## v2 Risks per task

| Task | Risk | Mitigation |
|------|------|-----------|
| V2-T1 | Audit surfaces >10 high-drift findings | Batch into groups of 3-5 per confirm round |
| V2-T5 | Figma MCP session budget exceeded | Chunk screen-by-screen; resume next session |
| V2-T7 | Delta plan has conflicting patches | Resolve via user decision per manual gate |
| V2-T8 | Code deltas touch high-risk files beyond FitTrackerApp | Kill criteria: escalate at >4 high-risk files |
| V2-T11 | CI fails on main after merge | Hotfix branch; do not revert merge |
