# PRD: Onboarding Flow

> **Owner:** Regev
> **Date:** 2026-04-05
> **Phase:** Phase 1 — PRD
> **Status:** In Review

---

## Purpose

Guide new FitMe users through goal selection, profile setup, and HealthKit authorization in a 5-screen progressive flow — maximizing D1 retention and enabling AI-powered personalization from the first session.

## Business Objective

Onboarding is the highest-leverage retention intervention. Industry benchmarks show users who complete onboarding have 2-3x higher D7 retention. FitMe's AI engine and readiness scoring depend on user goal, training level, and HealthKit data — without onboarding, these features start cold. A well-designed flow also drives HealthKit authorization (critical for readiness) and goal setting (critical for macro targets and AI recommendations).

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| The Consistent Lifter | Needs to set training goal + experience level for progressive overload tracking |
| Health-Conscious Professional | Needs HealthKit connected for readiness scoring (HRV, sleep, HR) |
| Data-Driven Optimizer | Needs goal + profile for AI recommendations and cohort banding |

## Has UI?

Yes — 5 new screens in a dedicated onboarding flow.

## Functional Requirements

| # | Requirement | Priority | Status | Details |
|---|-------------|----------|--------|---------|
| 1 | Welcome screen with FitMe branding | P0 | Planned | Logo animation (FitMeLogoLoader), tagline, "Get Started" CTA |
| 2 | Goal selection screen | P0 | Planned | 4 cards: Build Muscle / Lose Fat / Maintain / General Fitness |
| 3 | Profile screen | P1 | Planned | Training experience (3 levels) + weekly frequency (2-6 days) |
| 4 | HealthKit permission screen | P0 | Planned | Contextual explanation → system HealthKit auth prompt |
| 5 | First Action screen | P0 | Planned | Personalized dashboard preview + CTA to first workout or meal |
| 6 | Segmented progress bar | P1 | Planned | 5-segment bar at top of each screen showing position |
| 7 | Skip option on non-critical screens | P1 | Planned | "Skip" on Goals, Profile, HealthKit; not on Welcome/First Action |
| 8 | Persist user selections | P0 | Planned | Save goal + experience to UserProfile, set hasCompletedOnboarding flag |
| 9 | Guard against re-showing | P0 | Planned | `UserDefaults.hasCompletedOnboarding` — show only on first launch |
| 10 | Handle returning users | P1 | Planned | If already onboarded, skip directly to auth/home |
| 11 | GA4 analytics events | P0 | Planned | Track each step, completion, skips, permissions |
| 12 | Defer notification permission | P1 | Planned | Request after first completed workout, not during onboarding |

## User Flows

### Primary Flow (Happy Path)
1. User opens app for the first time
2. **Welcome** → sees FitMe logo animation + tagline → taps "Get Started"
3. **Goals** → selects one of 4 goal cards → taps "Continue"
4. **Profile** → selects experience level + weekly frequency → taps "Continue"
5. **HealthKit** → reads explanation → taps "Connect" → approves HealthKit prompt
6. **First Action** → sees personalized dashboard preview → taps "Start Your First Workout" or "Log Your First Meal"
7. Lands on Home screen with readiness data populating

### Skip Flow
1. User can tap "Skip" on Goals (defaults to General Fitness), Profile (defaults to Intermediate/3 days), or HealthKit (skips auth)
2. Skipped data can be set later in Settings
3. Skipped screens are tracked via `onboarding_skipped` event

### Returning User Flow
1. User who has `hasCompletedOnboarding = true` bypasses onboarding entirely
2. Goes directly to auth/home screen

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| No onboarding exists | P0 | New users land on auth screen with no guidance |
| Goal not collected | P0 | AI recommendations and macro targets are generic |
| HealthKit auth not prompted | P0 | ~70% auth rate vs target >85% |
| No first-action guidance | P1 | Users don't know what to do first |
| No progressive profiling | P2 | Body weight, diet prefs deferred to later |

## Acceptance Criteria

- [ ] 5-screen onboarding flow renders correctly on iPhone SE through iPhone 15 Pro Max
- [ ] Goal selection persists to UserProfile and feeds AIOrchestrator
- [ ] Experience level + frequency persist to UserProfile
- [ ] HealthKit authorization flow triggers correctly with contextual explanation
- [ ] Onboarding only shows on first app launch (UserDefaults guard)
- [ ] "Skip" buttons work on screens 2-4 with sensible defaults
- [ ] Progress bar shows correct position on each screen
- [ ] All 7 GA4 events fire correctly with consent gating
- [ ] FitMeLogoLoader animation renders on Welcome screen
- [ ] Under 60 seconds total flow time
- [ ] Notification permission NOT requested during onboarding

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** Onboarding completion rate (% of users who reach First Action screen)
- **Baseline:** N/A (no onboarding exists)
- **Target:** >80%
- **Timeframe:** Within 30 days of launch

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| HealthKit authorization rate | ~70% | >85% | HealthKitService + GA4 `permission_granted` |
| D1 retention (post-onboarding users) | — | >60% | Firebase cohort analysis |
| Time to first training session | — | <24 hours | GA4 `workout_start` timestamp delta |
| Goal selection rate | N/A | >70% (not skipped) | GA4 `onboarding_goal_selected` |
| Average onboarding duration | N/A | <60 seconds | GA4 `tutorial_begin` → `tutorial_complete` delta |

### Guardrail Metrics
| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s (onboarding adds no cold start cost) |
| Sync success rate | >99% | Must stay >99% |
| Auth flow reliability | >99% | Must not break existing auth |

### Leading Indicators
- >50% of new installs complete onboarding within first 7 days
- >60% of onboarding completers grant HealthKit access
- Onboarding skip rate <20% per screen (average across screens 2-4)

### Lagging Indicators
- D7 retention improves by 10%+ for onboarding completers vs historical baseline
- D30 retention improves by 5%+ for onboarding completers
- HealthKit-connected WAU increases by 15%

### Instrumentation Plan
| Event/Metric | Method | Status |
|-------------|--------|--------|
| Onboarding start | GA4 `tutorial_begin` | Ready (event exists) |
| Step tracking | GA4 `onboarding_step_viewed` | New — define below |
| Step completion | GA4 `onboarding_step_completed` | New — define below |
| Step skipped | GA4 `onboarding_skipped` | New — define below |
| Goal selected | GA4 `onboarding_goal_selected` | New — define below |
| Permission result | GA4 `permission_result` | New — define below |
| Onboarding complete | GA4 `tutorial_complete` | Ready (event exists) |
| HealthKit auth rate | HealthKitService | Available now |
| D1/D7/D30 retention | Firebase cohort | Available now |

### Analytics Spec (GA4 Event Definitions)

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| `onboarding_step_viewed` | Engagement | Custom | Each onboarding screen | `step_name`, `step_index` | No | Tracks funnel drop-off per step |
| `onboarding_step_completed` | Engagement | Custom | User taps Continue | `step_name`, `step_index` | No | Completion per step |
| `onboarding_skipped` | Engagement | Custom | User taps Skip | `step_name`, `step_index` | No | Skip rate per step |
| `onboarding_goal_selected` | Engagement | Custom | Goal screen selection | `goal_value` | No | Which goal is most popular |
| `permission_result` | Engagement | Custom | HealthKit auth response | `permission_type`, `granted` | No | Auth grant/deny rate |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| `step_name` | string | `welcome`, `goals`, `profile`, `healthkit`, `first_action` | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` | Max 20 chars |
| `step_index` | int | 0-4 | `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped` | 0-based screen index |
| `goal_value` | string | `build_muscle`, `lose_fat`, `maintain`, `general_fitness` | `onboarding_goal_selected` | Matches UserProfile goal enum |
| `permission_type` | string | `healthkit`, `notifications` | `permission_result` | Type of system permission |
| `granted` | string | `true`, `false` | `permission_result` | Whether user granted permission |

#### New Screens
| Screen Name | View Name | SwiftUI View | Category |
|-------------|-----------|--------------|----------|
| Onboarding Welcome | `onboarding_welcome` | `OnboardingWelcomeView` | auth |
| Onboarding Goals | `onboarding_goals` | `OnboardingGoalsView` | auth |
| Onboarding Profile | `onboarding_profile` | `OnboardingProfileView` | auth |
| Onboarding HealthKit | `onboarding_healthkit` | `OnboardingHealthKitView` | auth |
| Onboarding First Action | `onboarding_first_action` | `OnboardingFirstActionView` | auth |

#### New User Properties
| Property Name | Type | Values | Notes |
|--------------|------|--------|-------|
| `onboarding_completed` | string | `true`, `false` | Whether user finished onboarding (7th user property — still under 25 limit) |

#### Naming Validation Checklist
- [x] All event names: snake_case, <40 chars
- [x] All parameter names: snake_case, <40 chars
- [x] No reserved prefixes (ga_, firebase_, google_)
- [x] No duplicate names (checked against AnalyticsProvider.swift — no conflicts)
- [x] No PII in any parameter (no emails, names, user IDs)
- [x] ≤25 parameters per event (max 3 per event)
- [x] Total custom user properties still ≤25 (currently 6, adding 1 = 7)
- [x] Parameter values spec'd to max 100 chars
- [x] Conversion events identified — `tutorial_complete` already marked as conversion

#### Files to Update During Implementation
- [ ] `AnalyticsProvider.swift` — add 5 new events, 5 new params, 5 new screens, 1 user property
- [ ] `AnalyticsService.swift` — add typed convenience methods for onboarding events
- [ ] `docs/product/analytics-taxonomy.csv` — add rows to events, screens, and properties sections

### Review Cadence
- **First review:** 1 week post-launch
- **Ongoing:** Weekly for 4 weeks, then monthly

### Kill Criteria
- If onboarding completion rate <50% after 30 days → redesign flow (reduce screens or change content)
- If D1 retention does NOT improve for onboarding completers vs non-completers after 60 days → evaluate whether the flow provides value
- Guardrail: if crash-free rate drops below 99.5% → hotfix immediately

---

## Key Files

| File | Purpose |
|------|---------|
| `FitTracker/Views/Onboarding/OnboardingView.swift` | Main onboarding container + flow navigation |
| `FitTracker/Views/Onboarding/OnboardingWelcomeView.swift` | Screen 1: Welcome with logo |
| `FitTracker/Views/Onboarding/OnboardingGoalsView.swift` | Screen 2: Goal selection cards |
| `FitTracker/Views/Onboarding/OnboardingProfileView.swift` | Screen 3: Experience + frequency |
| `FitTracker/Views/Onboarding/OnboardingHealthKitView.swift` | Screen 4: HealthKit auth |
| `FitTracker/Views/Onboarding/OnboardingFirstActionView.swift` | Screen 5: Personalized CTA |
| `FitTracker/Views/Onboarding/OnboardingProgressBar.swift` | Reusable 5-segment progress bar |
| `FitTracker/Models/UserProfile.swift` | Updated with goal + experience fields |
| `FitTracker/FitTrackerApp.swift` | Onboarding gate before auth/home |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | New event/param/screen constants |
| `FitTracker/Services/Analytics/AnalyticsService.swift` | New convenience methods |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| HealthKit authorization is one-time — can't re-prompt if denied | Show compelling explanation before system prompt; provide Settings deep link as fallback |
| UserProfile model changes may affect sync | Verify SupabaseSyncService handles new fields gracefully |
| FitMeLogoLoader on Welcome screen may be slow on iPhone SE | Test on oldest supported device; use `.pulse` animation mode (lightest) |
| Onboarding gate in FitTrackerApp.swift touches high-risk file | Minimal change — single `if !hasCompletedOnboarding` guard |
| Goal/experience defaults for skipped screens may not match user | Defaults chosen to be "middle of the road" (General Fitness, Intermediate, 3 days) |

## Estimated Effort

- **Total:** ~1 week
- **Breakdown:** Research: 0.5d (done), PRD: 0.5d (this), UX: 0.5d, Implementation: 3d, Testing: 1d, Review+Merge: 0.5d

---

# v2 — UX Alignment

> **Owner:** Regev
> **Date:** 2026-04-07
> **Phase:** Phase 1 — PRD v2 (in progress)
> **Status:** Draft for approval
> **Parent:** v1 PRD above (approved 2026-04-05, implemented 2026-04-06)
> **Trigger:** v1 `ux_or_integration` phase was **skipped** ("UX defined inline in PRD and task descriptions"). No formal ux-spec, no Figma screens, no design compliance gate. v2 closes that gap as the first feature in the sequential UX alignment initiative.
> **Showcase doc:** [`docs/project/pm-workflow-showcase-onboarding.md`](../../../docs/project/pm-workflow-showcase-onboarding.md)

## v2 Purpose

Retroactively validate and align the shipped v1 onboarding flow against [`docs/design-system/ux-foundations.md`](../../../docs/design-system/ux-foundations.md) (1,533 lines, 10 parts) — the canonical UX + behavioral layer of the FitMe design system. The v1 functional requirements remain valid; v2 adjusts how the requirements are *expressed* in UI, flow, copy, motion, and accessibility so every principle in the foundations doc is visibly satisfied.

v2 also serves as the exemplar run for the enhanced `/pm-workflow` skill executing a retroactive alignment.

## v2 Scope (what changes vs v1)

| Dimension | v1 state | v2 target | Governed by |
|-----------|----------|-----------|-------------|
| **Screen count** | 5 (Welcome, Goals, Profile, HealthKit, First Action) | **6** — adds Consent screen (already integrated as step 5 in v1 code commit `d017a30`, but not in PRD v1) | Figma v2 prompt + v1 commit history |
| **Principles compliance** | Not formally validated | Full audit against 8 core heuristics + 5 FitMe-specific principles | `ux-foundations.md` §1 |
| **Information architecture** | Flat linear sequence | Same flat sequence, but progress bar reflects 6 steps; Consent has no progress bar (standalone decision) | `ux-foundations.md` §2 + Figma v2 prompt |
| **Interaction patterns** | Not formally validated | Push navigation + bottom CTA + quiet skip pattern audited against foundations | `ux-foundations.md` §3 |
| **Data viz** | N/A (no charts in onboarding) | N/A | — |
| **Permission & trust** | HealthKit 3-step priming + Consent card | Validated against 3-step priming pattern; Consent copy audited for trust signals | `ux-foundations.md` §5 |
| **State patterns** | Loading/error states not systematically documented | Empty, loading, error, success states defined per screen with copy formulas | `ux-foundations.md` §6 |
| **Accessibility** | Not formally validated | WCAG AA minimum; Dynamic Type; VoiceOver labels; 44pt tap targets verified per screen | `ux-foundations.md` §7 |
| **Motion** | Not formally validated | All animations via `AppMotion` presets; Reduce Motion compliance | `ux-foundations.md` §8 |
| **Content & copy** | Inline in views | Validated against copy guidelines; encouraging, never judgmental; consistent terminology | `ux-foundations.md` §9 + `ux-copy-guidelines.md` |
| **Platform patterns** | iPhone-first | iPhone primary; iPad layout validated; Watch/macOS out of scope | `ux-foundations.md` §10 |
| **Figma source of truth** | Figma has only v1 "I3.1 — Onboarding Slides" (5 feature-showcase slides, NOT matching v1 code) | New "I3.2 — Onboarding v2 (PRD-Aligned)" section with 6 real screens; v1 preserved as history | `figma-onboarding-v2-prompt.md` |
| **Design system compliance** | Not audited | All tokens map to `AppTheme.swift`; all components map to `AppComponents.swift` or documented as new primitives | Phase 3 compliance gateway |

## Changelog — v1 → v2

### Additions
- **Consent screen** formally added to PRD as screen 5 of 6 (v1 code added it inline, PRD was not updated)
- **`ux-research.md`** — new file, UX principles applicable to onboarding, iOS HIG references, research sources
- **`ux-spec.md`** — new file, screen list, flows, states, copy, a11y, motion per feature-development-gateway.md
- **Figma v2 section** — 6 screens in file `0Ai7s3fCFqR5JXDW8JvgmD`, page "Onboarding", section "I3.2 — Onboarding v2 (PRD-Aligned)"
- **Design compliance report** — recorded in state.json after Phase 3 gateway

### Changes (subject to audit findings in Phase 3)
- **Progress bar:** may change from 5-segment to 6-segment to accommodate Consent screen
- **Copy refinements:** any copy that violates `ux-copy-guidelines.md` will be adjusted
- **Tap target sizing:** any interactive element below 44pt adjusted
- **Motion:** any ad-hoc animations replaced with `AppMotion` presets
- **Token compliance:** any raw hex / font literal replaced with semantic token

### Manual Confirm Gate (mandatory per user directive)
Every single UI change from current code must be presented to user with before/after + foundations principle reference + rationale BEFORE the change is applied to Figma or code. No unilateral visual changes.

### Removals
- None planned. All v1 features retained.

## v2 Success Metrics (delta vs v1)

No changes to primary, secondary, guardrail, leading, or lagging metrics. v1 metrics remain valid.

**New v2-specific instrumentation-quality metrics** (to be reported alongside feature metrics):
| Metric | Target | Source |
|--------|--------|--------|
| UX foundations compliance score | 100% pass on all 10 dimensions | Phase 3 audit report |
| Design system token compliance | 100% (zero raw literals in onboarding views) | `/design audit onboarding` |
| A11y compliance | WCAG AA minimum on all 6 screens | Phase 3 accessibility check |
| Figma-to-code parity | Visual diff <5% per screen | Phase 5 testing |

## v2 Acceptance Criteria

In addition to v1 acceptance criteria:
- [ ] `.claude/features/onboarding/ux-research.md` created and references ≥5 foundations principles
- [ ] `.claude/features/onboarding/ux-spec.md` created with screen list, flows, states, copy, a11y, motion
- [x] Figma file `0Ai7s3fCFqR5JXDW8JvgmD` has section "I3.2 — Onboarding v2 (PRD-Aligned)" with 6 screens (built 2026-04-07, section node `688:2`; node IDs in `ux-spec.md`)
- [x] Existing Figma "I3.1 — Onboarding Slides" section is UNCHANGED (history preserved — verified post-build, `469:2` bounds + child count unchanged)
- [ ] Design compliance gateway report (5 checks) passes OR documented overrides with justification per CLAUDE.md evolution rules
- [ ] Every UI change from v1 was manually confirmed by user before being applied
- [ ] `.claude/features/onboarding/state.json` has `phases.ux_or_integration.status = "approved"` with timestamp
- [ ] PR description links to ux-research, ux-spec, Figma section, and this v2 section
- [ ] Showcase doc `docs/project/pm-workflow-showcase-onboarding.md` is updated with all phase outcomes

## v2 Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Phase 3 audit uncovers extensive gaps requiring >4 high-risk code files to change | Blocks merge, bloats scope | Kill criteria (see below); user may opt to defer gaps to enhancement tasks |
| Figma v2 build via MCP exceeds session budget | Phase 3 stalls | Prior art at `figma-onboarding-v2-prompt.md` accelerates; chunk by screen if needed |
| v1 code may have reasonable choices that conflict with foundations principles | Needs user judgment | Manual confirm gate surfaces each conflict for explicit decision |
| Manual confirm gate creates many micro-decisions slowing the run | User fatigue | Batch similar deltas into groups of 3-5 per confirmation round |
| FitTrackerApp.swift (high-risk) may need additional edits for v2 routing | Review risk ↑ | Keep changes minimal; wrap in feature flag if needed |

## v2 Kill Criteria

In addition to v1 kill criteria:
- If Phase 3 audit reveals >4 high-risk code files need modification beyond v1 footprint → escalate to user for go/no-go (risk of scope creep)
- If >8 manual confirm rounds are required → pause for user to review pattern of findings and decide scope cap
- If Figma v2 build cannot complete within 2 sessions → fall back to code-only alignment (document the Figma gap as a follow-up)

## v2 Review Cadence

- **Phase-gate reviews:** After each of Phases 1-8 per pm-workflow skill
- **Post-merge metrics review:** Unchanged from v1 (1 week post-launch, then weekly for 4 weeks, then monthly)
- **Alignment initiative checkpoint:** Showcase doc reviewed after merge to confirm exemplar quality before running the next feature in sequence

## v2 Inputs (references)

| File | Role |
|------|------|
| `docs/design-system/ux-foundations.md` | Compliance target (1,533 lines, 10 parts) |
| `docs/design-system/ux-copy-guidelines.md` | Copy validation |
| `docs/design-system/component-contracts.md` | Interaction behavior validation |
| `docs/design-system/feature-development-gateway.md` | Phase 3 procedure |
| `docs/design-system/feature-design-checklist.md` | Per-decision validation |
| `docs/project/figma-onboarding-v2-prompt.md` | Figma v2 build prompt (pre-authored) |
| `FitTracker/Services/AppTheme.swift` | Token source of truth |
| `FitTracker/DesignSystem/AppComponents.swift` | Component source of truth |
| v1 code on `feature/onboarding-ux-align` | Drift baseline |

## v2 Estimated Effort

- **Total:** ~2-3 sessions (audit-driven; upper bound if many manual confirm rounds)
- **Breakdown:** PRD v2 (this, 0.5s) → Tasks v2 (0.25s) → UX Research + Audit (0.5s) → UX Spec + Figma v2 (1-1.5s) → Implementation deltas (0.5s) → Test/Review/Merge (0.5s) → Docs (0.25s)
