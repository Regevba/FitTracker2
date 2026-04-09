# Home Today Screen v2 — UX Research

> **Phase:** 3b (UX Research)
> **Input:** v2-audit-report.md (27 findings), ux-foundations.md (13 principles), Decisions Log
> **Output:** Applicable principles and how each influenced the v2 design

---

## Applicable UX Principles

### 1. Fitts's Law — Target size and distance
**How it applies:** The v1 edit button was 34pt (< 44pt minimum). All CTAs on Home must be large, easily reachable in the thumb zone.
**v2 design response:**
- All tap targets ≥ 44pt (F17 fix)
- Start Workout + Log Meal CTAs are large, equal-sized buttons with 8pt gap (OQ-15)
- Metric tiles are sized to comfortable tap targets even though they're read-only in v2

### 2. Hick's Law — Minimize choices per screen
**How it applies:** v1 had ~19+ visual elements competing on one screen with no hierarchy (F10). Decision paralysis.
**v2 design response:**
- Target 10-12 elements above the fold (OQ-5, F10)
- ScrollView allows below-fold content to breathe instead of cramming everything in
- Training & Nutrition card reduces two separate concerns into one card with two clear CTAs
- Metric tiles are read-only (no decision required) — information, not choices

### 3. Jakob's Law — Users expect familiar patterns
**How it applies:** Home v1 was the only screen without scroll. Users expect swipe-to-scroll from every other iOS app and every other FitMe screen.
**v2 design response:**
- ScrollView with `scrollBounceBehavior(.basedOnSize)` — matches iOS conventions (F2)
- Card-based layout matches Nutrition, Training Plan, and Stats screens
- Side-by-side CTAs mirror the onboarding goal-choice pattern (OQ-15)

### 4. Progressive Disclosure — Headline first, detail on tap
**How it applies:** v1 showed everything at once — no drill-down, no "learn more" (F11). The no-scroll constraint forced all detail to be visible simultaneously.
**v2 design response:**
- ReadinessCard cycles pages on tap (existing component behavior, OQ-12)
- Status/Goal cards show summary; merged drill-down ships as sub-feature
- Metric tiles show value only; deep-link to Stats ships as sub-feature
- Context row collapses to single line: `"Lower Body · 45m · On plan"` (OQ-16)

### 5. Recognition Over Recall — Visible options vs memorized commands
**How it applies:** v1 macro progress was invisible on Home (F13). Users had to navigate to Nutrition to check.
**v2 design response:**
- Macro strip deferred (F13) but slot reserved in Status+Goal merged sub-feature
- All key metrics visible on Home: readiness, training status, body metrics, HRV/RHR/Sleep/Steps
- Day type visible in context row (not hidden in a menu)

### 6. Consistency — Internal (FitMe) and external (iOS)
**How it applies:** v1 used custom `BlendedSectionStyle` instead of the shared `AppCard` component (F4). Custom responsive sizing via `compact`/`tight` instead of Dynamic Type.
**v2 design response:**
- All cards use `AppCard` from `AppComponents.swift`
- All fonts use `AppText.*` tokens with Dynamic Type scaling
- All spacing uses `AppSpacing.*` tokens
- Motion uses `AppSpring.*`/`AppEasing.*` tokens
- Consistent with Onboarding v2 pattern (PR #59)

### 7. Feedback — Every action gets a response
**How it applies:** v1 haptics work correctly (F23 — positive finding). But animations were raw, not tokenized.
**v2 design response:**
- Haptics preserved verbatim (`performHomeAction()` carries over)
- All animations tokenized for consistent feel
- Empty state has clear recovery affordance (buttons, not dashes)

### 8. Error Prevention — Design to prevent mistakes
**How it applies:** v1 showed `—` dashes for missing data with no way to fix it (F16). Users couldn't tell if data was missing or just not available.
**v2 design response:**
- Empty metric tiles show tappable "Log" CTAs instead of dashes
- Empty state view has "Connect Health" + "Log manually" buttons (OQ-6)
- HealthKit denied → deep-link to Settings (iOS prevents re-prompting)

### 9. Readiness-First — Status (readiness) before action
**How it applies:** v1 violated this principle directly — Status Overview (weight/BF) came first, ReadinessCard component existed but wasn't used (F9).
**v2 design response:**
- ReadinessCard promoted to first card (hero position)
- Status demoted below Training & Nutrition
- Readiness context feeds the recommendation display

### 10. Zero-Friction Logging — Fastest path to record data
**How it applies:** v1 had no "Log meal" quick action on Home despite documentation in ux-foundations §1.10 (F12).
**v2 design response:**
- Log Meal CTA added as peer to Start Workout in Training & Nutrition card
- Side-by-side equal weight (OQ-15) — neither is privileged
- Empty metric tiles have direct "Log" CTAs

### 11. Privacy by Default
**How it applies:** Not directly relevant to Home v2 layout changes. Analytics events respect consent gating.
**v2 design response:** All `home_*` analytics events gated by consent manager.

### 12. Progressive Profiling
**How it applies:** Not directly relevant to Home v2. Profile data collected during onboarding.
**v2 design response:** No change.

### 13. Celebration Not Guilt — Encouraging, never judgmental
**How it applies:** v1 used guilt-adjacent copy like "items still need attention" (F14).
**v2 design response:**
- `HomeRecommendationProvider` outputs encouraging tone variants
- Copy rewritten: status language frames progress positively
- Streak display uses warmth (`🔥`) not pressure

---

## iOS Human Interface Guidelines — Applied Patterns

| HIG Pattern | Application in Home v2 |
|---|---|
| **Navigation: Tab bar** | Home remains a tab in `RootTabView` — no change |
| **Layout: ScrollView** | Replaces the constrained no-scroll layout (F2) |
| **Content: Cards** | `AppCard` wraps each section — matches iOS card patterns |
| **Input: Buttons** | Side-by-side CTAs use standard button styling via design tokens |
| **Feedback: Haptics** | Preserved from v1 (positive finding F23) |
| **Accessibility: Dynamic Type** | All fonts use `relativeTo:` for scaling; tested at AX5 |
| **Accessibility: VoiceOver** | Every element labeled; auto-rotation removed; static content |
| **Accessibility: Tap targets** | All ≥ 44pt (F17 fix) |
| **Accessibility: Reduce Motion** | Every animation wrapped in environment check (F22) |

---

## External UX Research — Home/Dashboard Patterns

| Source | Pattern | Applied? |
|---|---|---|
| Apple Health app | Readiness/health summary at top, metrics grid below, scrollable | Yes — ReadinessCard hero + metric tiles |
| Fitbod | Single primary CTA ("Start Workout") with context | Yes — Training & Nutrition card with context row |
| MyFitnessPal | Macro tracking visible on home dashboard | Deferred (macro strip → sub-feature) |
| Whoop | Readiness score as hero metric, recovery-first philosophy | Yes — ReadinessCard as first card |
| Strong app | Minimal home, single action focus | Partially — reduced from 19 to 10-12 elements |
| Nike Training Club | Encouraging, celebratory copy tone | Yes — Celebration Not Guilt principle (F14) |
