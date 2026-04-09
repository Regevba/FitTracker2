# home-today-screen — v2 UX Foundations Audit Report

> **Phase:** 0 (Research) — output drives Phases 1-4
> **Target file (v1):** `FitTracker/Views/Main/MainScreenView.swift` (1029 lines)
> **Target file (v2, planned):** `FitTracker/Views/Main/v2/MainScreenView.swift`
> **Branch:** `feature/home-today-screen-v2`
> **Tracking:** [regevba/fittracker2#60](https://github.com/Regevba/FitTracker2/issues/60)
> **Pilot precedent:** Onboarding v2 (PR #59) — this is the second feature to run the `/ux audit` → v2 refactor loop, and the **first** to follow the `v2/` subdirectory convention + `v2-refactor-checklist.md`.
> **Skill invoked:** `/ux audit` (see [`docs/skills/ux.md`](../../../docs/skills/ux.md))

---

## Executive summary

The current `MainScreenView` shipped pre-PM-workflow as an undocumented, un-audited implementation. It's a 1029-line monolith with:

- **5 cards** crammed above the fold with no-scroll constraint — greeting header, status overview, goal progress, start training, metrics
- **Custom responsive sizing** via two `compact` / `tight` props threaded through every private function
- **`GeometryReader` at the root** (SwiftUI anti-pattern — causes layout-invalidation cascades)
- **12 raw `.font(.system(size: ...))` calls**, 7 raw numeric paddings, 11 raw numeric frames (mostly justified with `// responsive — no AppText equivalent` comments)
- **4 accessibility labels total** in 1029 lines (vs ~30+ interactive elements)
- **Missing the Readiness-First principle** — status (weight/body fat) comes first, not readiness. `ReadinessCard` component exists in the codebase but isn't used here
- **No explicit empty/loading/error states** — relies on `—` dashes and `Missing` capsules
- **No "Log meal" quick action** on home despite being documented in `ux-foundations.md` §1.10
- **Raw animation easing** (`.spring(response: 0.32, ...)`, `.easeOut(duration: 0.22)`) with no `motionSafe` reduce-motion support
- **Partial v2 alignment already applied** on a different branch: the background gradient swap from orange→blue `appBlue1→appBlue2` on `claude/fix-ios-signin-compilation-6kxKG` (commit `d09cd61`) — will land via the iOS hardening PR, not this one. Not counted as a finding here.

**Findings count:** 27 numbered findings across 8 sections, severity-graded.

| Severity | Count | Definition |
|---|---|---|
| **P0** | 9 | Blocks v2 ship (foundational principle violation, broken a11y baseline, missing critical state, DS anti-pattern) |
| **P1** | 13 | Should fix in v2 (token drift, minor principle miss, inconsistent pattern with other screens, missing a11y hint) |
| **P2** | 5 | Nice-to-have, can defer (polish, edge cases, optional enhancements) |

**Tractability breakdown:**

| Tractability | Count | Meaning |
|---|---|---|
| **auto-applicable** | 18 | Can be fixed mechanically (raw literal → token, add missing label, swap raw ease for `AppMotion`) |
| **needs-decision** | 6 | Requires user call (remove "above-the-fold" constraint? add "Log meal" quick action? drop goal-progress ring? use `ReadinessCard` component?) |
| **needs-new-token** | 2 | Responsive metric hero needs a Dynamic Type-scaling AppText variant |
| **needs-new-component** | 1 | `StatusValueColumn` + `MetricTile` should promote from private helpers to shared components |

**Recommended approach:** build a new `FitTracker/Views/Main/v2/MainScreenView.swift` from scratch, bottom-up from `ux-foundations.md`. Do NOT patch v1 in place per the [V2 Rule in `CLAUDE.md`](../../../CLAUDE.md).

**Design system evolution queue:** All proposed new tokens and component promotions from this audit are tracked in [`docs/design-system/feature-memory.md` → Pending Evolution Queue](../../../docs/design-system/feature-memory.md). Future screen audits (Training Plan v2, Nutrition v2, Stats v2) should check the queue **first** and reference queued items instead of re-proposing the same primitives. When Phase 4 of this feature lands, the queued items move from "Pending" to the shipped memory entry for home-today-screen v2.

---

## Section A — Architecture & layout findings

### F1 — `GeometryReader` at the root of the screen

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** Section B7 (architecture hygiene), §10.1 iPhone platform adaptations
- **Location:** `MainScreenView.swift:100-119` (body → `ZStack { backgroundLayer; GeometryReader { proxy in VStack { ... } } }`)
- **Description:** The entire card stack is rendered inside a root `GeometryReader` that measures `proxy.size.height` to compute `compact` (< 860) and `tight` (< 760) breakpoints. `GeometryReader` at the root is a known SwiftUI anti-pattern — it forces the parent layout to reserve unlimited space for its child and triggers invalidation cascades on every size class change. It also makes the view incompatible with `.safeAreaInset`, `ScrollView` auto-sizing, and `.presentationDetents`.
- **Recommendation (v2):** Use `@Environment(\.horizontalSizeClass)` + `@Environment(\.verticalSizeClass)` to detect device class, and let AppSpacing tokens + Dynamic Type handle the rest. If truly-responsive sizing is still needed for one specific metric hero, use a container-relative frame with `ContainerRelativeShape` or a custom `PreferenceKey`. See ux-foundations §10.1 for the iPhone platform conventions.

### F2 — "Above the fold, no scroll on iPhone" is a hard constraint

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** §1.4 Progressive Disclosure, §2.3 Content Hierarchy
- **Location:** `MainScreenView.swift:1-2` (file header comment: "Action-first Today screen — kept above the fold with no scroll on iPhone.")
- **Description:** The no-scroll constraint forces all 5 cards to compete for vertical space. On iPhone 17 Pro Max (852pt) it's tight; on iPhone SE (568pt) everything compresses via the `compact`/`tight` props. The constraint conflicts with **progressive disclosure** (§1.4) — instead of "headline first, detail one tap away", every detail is always visible.
- **Recommendation (v2):** Drop the no-scroll constraint. Use a `ScrollView` with `scrollBounceBehavior(.basedOnSize)` so small content doesn't bounce and long content scrolls naturally. This is what Nutrition, Training Plan, and Stats already do — Home is the outlier.

### F3 — `compact` / `tight` props threaded through every private helper

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section B (architecture hygiene)
- **Location:** `MainScreenView.swift:104-113` (props computed), used by every `greetingHeader(tight:)`, `statusOverviewCard(compact:tight:)`, etc.
- **Description:** Every card function takes `compact: Bool, tight: Bool` parameters. This couples 8+ helpers to the same ad-hoc responsive model. Adding a new card requires threading the props through. Changing the breakpoint means hunting through 400+ lines of layout code.
- **Recommendation (v2):** Delete the props. Use Dynamic Type + `AppSpacing.*` tokens that already scale with accessibility settings. If a compact variant is truly needed, use `@ScaledMetric` with a Dynamic Type-aware token.

### F4 — Custom `BlendedSectionStyle` ViewModifier instead of shared component

- **Severity:** P2
- **Tractability:** needs-new-component
- **Principle / checklist:** Section D1 (component reuse)
- **Location:** `MainScreenView.swift:782-796`
- **Description:** `BlendedSectionStyle` is a private ViewModifier that applies a divider overlay to all 5 cards. It's not reused elsewhere. The design system has `AppComponents.swift` with reusable card components (`AppCard`, `AppSheetShell`, etc.) that already handle this.
- **Recommendation (v2):** Use `AppCard` from `DesignSystem/AppComponents.swift`. Delete `BlendedSectionStyle`. If Home needs a special divider, add a new `AppCard.Variant.divided` variant on the component and document it in `feature-memory.md`.

---

## Section B — Token compliance findings

### F5 — 12 raw `.font(.system(size: ...))` calls

- **Severity:** P1
- **Tractability:** auto-applicable (9 of 12) + needs-new-token (3 of 12)
- **Principle / checklist:** Section C1, C2 (token compliance)
- **Locations:**
  - L219: `.font(.system(size: tight ? 14 : 16.5, weight: .medium, design: .rounded))` (greeting date)
  - L225: `.font(.system(size: tight ? 12 : 13, weight: .bold, design: .rounded))` (Day count)
  - L228: `.font(.system(size: tight ? 11 : 12, weight: .semibold, design: .rounded))` (phase badge)
  - L356: `.font(.system(size: tight ? 22 : (compact ? 24 : 28), weight: .bold, design: .rounded))` (goal %)
  - L403: `.font(.system(size: tight ? 22 : (compact ? 26 : 32), weight: .bold))` (primary action icon)
  - L415: `.font(.system(size: tight ? 17 : 19.5, weight: .bold, design: .rounded))` (primary action title)
  - L432: `.font(.system(size: tight ? 14 : 15.5, weight: .medium, design: .rounded))` (day type menu)
  - L498: `.font(.system(size: compact ? 21 : 25, weight: .bold, design: .rounded))` (status value)
  - L517: `.font(.system(size: compact ? 14 : 16, weight: .medium, design: .rounded))` (progress title)
  - L521: `.font(.system(size: compact ? 14 : 16, weight: .medium, design: .rounded))` (progress %)
  - L541: `.font(.system(size: compact ? 15 : 18, weight: .semibold))` (metric tile icon) — marked `// DS-exception: responsive sizing`
  - L544: `.font(.system(size: compact ? 17 : 19, weight: .bold, design: .rounded))` (metric tile value)
- **Description:** Most are tagged `// responsive — no AppText equivalent`. The comment is honest but the real fix is to introduce Dynamic Type-scaling variants of `AppText.metricHero` / `AppText.metricDisplay` / `AppText.metricCompact` that the screen can use instead of manually picking pt sizes.
- **Recommendation (v2):** Map 9 of 12 to existing `AppText.*` tokens (date → `AppText.subheading`, Day count → `AppText.captionStrong`, phase badge → `AppText.eyebrow`, day type menu → `AppText.callout`). The 3 metric-hero sizes need new `AppText.metricXL` / `metricL` / `metricM` tokens — propose them in Phase 3 `ux-spec.md` and land them in `AppTheme.swift` as part of this feature branch.

### F6 — 7 raw numeric paddings

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C3 (token compliance)
- **Locations:** L229 (`tight ? 9 : 11`), L230 (`tight ? 5 : 6`), L554 (`.padding(.vertical, compact ? 7 : 9)`), L566 (`width <= 390 ? 18 : 20`), plus ~3 more in helpers
- **Description:** All of these are pt-sized literals that the `compact`/`tight` responsive logic chose between. None map to `AppSpacing` tokens.
- **Recommendation (v2):** Replace with `AppSpacing.xxSmall` (6), `AppSpacing.xSmall` (8), `AppSpacing.small` (12), `AppSpacing.medium` (16), `AppSpacing.large` (20). If the exact 11pt / 9pt values matter visually, propose new tokens `AppSpacing.xxs2` or similar.

### F7 — 11 raw numeric `.frame()` calls

- **Severity:** P1
- **Tractability:** auto-applicable (9 of 11) + needs-decision (2 of 11)
- **Locations:**
  - L280: `.frame(width: 8, height: 8)` (status dot) — propose `AppSize.statusDot`
  - L327: `.frame(width: 34, height: 34)` (edit button — **P0 a11y violation, see F17**)
  - L363: `.frame(width: tight ? 86 : (compact ? 100 : 116), height: ...)` (goal ring)
  - L401: `.frame(width: tight ? 64 : (compact ? 76 : 88), height: ...)` (primary action button)
  - L534: `.frame(height: 8)` (progress line bar)
- **Description:** Most are responsive to the `tight`/`compact` props. The ring/primary-action sizes are genuinely responsive and would need a new token family. The status dot (8pt) is small enough to belong in a new `AppSize.indicatorDot` token.
- **Recommendation (v2):** 9 land on existing/new `AppSize.*` tokens. The goal ring + primary action button sizes are **needs-decision** — they're hero metric controls, and the right move in v2 is to let `AppText.metricHero` size them via `@ScaledMetric` so they scale with Dynamic Type instead of with the custom `compact`/`tight` props.

### F8 — Raw `Color(red:green:blue:)` not present, but raw `Color.blue` / `Color.brown` / `Color.purple` used in 4 places

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C1
- **Locations:** L291 (`tint: .blue` for Weight), L458-461 (metric tile tints: `.gray`, `.brown`, `.purple`, `.blue`)
- **Description:** SwiftUI system colors (`.blue`, `.brown`, etc.) bypass the semantic token layer. They won't respect dark-mode variants, accessibility adjustments, or brand updates.
- **Recommendation (v2):** Map each to `AppColor.Accent.*` or `AppColor.Chart.*`. Weight → `AppColor.Chart.weight`; HRV → `AppColor.Chart.hrv`; RHR → `AppColor.Chart.heartRate`; Sleep → `AppColor.Accent.sleep`; Steps → `AppColor.Chart.steps`. Add missing chart tokens if needed.

---

## Section C — UX Principle findings (the 13 principles from ux-foundations.md)

### F9 — 1.9 Readiness-First is violated — status card comes before readiness

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** §1.9 Readiness-First (FitMe-specific), Section E9 of checklist
- **Location:** `MainScreenView.swift:108-114` (card order in body VStack)
- **Description:** ux-foundations.md §1.9 is explicit: *"Home screen layout: ReadinessCard is the first card, before today's workout"*. The current order is:
  1. `greetingHeader` (includes readiness as one of 3 rotating slides in `LiveInfoStrip`)
  2. `statusOverviewCard` (weight + body fat + small readiness dot in top-right)
  3. `goalProgressCard`
  4. `startTrainingCard`
  5. `metricsCard`
  Readiness only appears as (a) one of 3 rotating slides in the greeting and (b) a tiny 8pt dot + label in the top-right of the status card. It is **not** the lead.
- **Critical related finding:** `FitTracker/Views/Shared/ReadinessCard.swift` component exists in the codebase but is **not used at all** in `MainScreenView`. The design system already built a 6-page rotating readiness card (HRV, sleep, RHR, recovery trend, training load, stress) and the home screen doesn't reference it.
- **Recommendation (v2):** Use `ReadinessCard` as the first card in the VStack. Status (weight/body fat) becomes the second card. The greeting LiveInfoStrip keeps the time-of-day greeting but drops the readiness slide (it's now redundant with the card). **Decision for user:** is `ReadinessCard` the right component, or should v2 build a new simpler readiness hero tuned for Home specifically?

### F10 — 1.2 Hick's Law: ~19+ visual elements competing on one screen

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** §1.2 Hick's Law, §7.3 Cognitive Accessibility
- **Location:** every card — cumulative count
- **Description:** Hick's Law + ux-foundations §7.3 cap actionable items at **5-7 per screen**. Current Home count:
  - Greeting header: `LiveInfoStrip` (3 rotating slides = 3 "states"), today's date, Day N, phase badge → 4+ elements
  - Status overview: title, status dot+label, 2 metric columns (weight + body fat each with value/unit/target/missing state), recommendation text, edit button → ~8 elements
  - Goal progress: section eyebrow, percentage ring, 2 progress lines, essentials summary → 5 elements
  - Start training: section eyebrow, primary action button, day type menu, session length, recommendation tone, recommendation subtitle → 6 elements
  - Metrics: 4 metric tiles → 4 elements
  - **Total: ~27 visual elements**, ~8 tappable (edit button, primary action, day type menu, 4 quick-action areas, account hamburger)
- **Recommendation (v2):** Reduce via progressive disclosure (F14). Keep the primary actions visible (Start Workout, Log meal, Log biometric) but move the detail behind taps. Target 10-12 visual elements at default state.

### F11 — 1.4 Progressive Disclosure: no "headline first, detail on tap" pattern

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** §1.4 Progressive Disclosure, Section E4
- **Location:** `statusOverviewCard` + `goalProgressCard` + `metricsCard`
- **Description:** §1.4 is explicit: *"ReadinessCard shows ONE number (readiness score) by default. Tap to reveal the 6-page breakdown"* and *"MetricCard shows headline value + trend arrow. Tap to drill into chart with full history."* Current Home shows ALL values for ALL metrics simultaneously. There's no drill-down. `metricTile` values show `—` when data is missing instead of an empty-state CTA.
- **Recommendation (v2):** Each metric tile becomes tappable → pushes to the Stats detail view for that metric. Goal progress ring becomes tappable → opens the Goal detail sheet (needs to exist — currently there is none). Status card becomes tappable → opens the biometric entry sheet (currently this is only reachable via the 34pt edit button, see F17).

### F12 — 1.10 Zero-Friction Logging: "Log meal" quick action is missing

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** §1.10 Zero-Friction Logging (FitMe-specific)
- **Location:** There is no "Log meal" button anywhere in `MainScreenView.swift`. The only quick actions are Start Workout (the primary action) and the tiny biometric edit button.
- **Description:** ux-foundations §1.10 lists three home-screen quick actions: *"home screen has one-tap access to 'Log meal' and 'Start workout'"*. Home has Start Workout but is missing Log meal entirely. Users have to tab over to Nutrition → tap "+" → choose entry method.
- **Recommendation (v2):** Add a secondary action next to the primary Start Workout button: "Log meal" → opens `MealEntrySheet` directly on the smart-capture tab. Should be the same size class (or one level down) as Start Workout. Candidate location: as a second button in the `startTrainingCard` HStack, or as a dedicated `quickActionsRow` below the training card.

### F13 — 1.5 Recognition over Recall: macro progress is invisible on Home

- **Severity:** P2
- **Tractability:** needs-decision
- **Principle / checklist:** §1.5 Recognition over Recall, §2.7 Cross-Domain Connections
- **Location:** No macro data on `MainScreenView`; macro progress lives only on `NutritionView`
- **Description:** §1.5 says *"Macro progress bars on NutritionView show current vs. target — users don't need to remember their daily protein goal"*. But the Home screen is the "today surface" — a user who opens the app mid-day wants to see at a glance: readiness, macros remaining, today's workout. Currently they have to tap to Nutrition to know if they're on track.
- **Recommendation (v2):** Add a compact macro strip to Home (collapsed 1-line summary: "Protein 87/150g • Calories 1,450/2,200") that's tappable to open NutritionView. This is a §2.7 Cross-Domain Connection — Nutrition owns the canonical macro data; Home references it.

### F14 — 1.13 Celebration Not Guilt: status language is guilt-adjacent

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** §1.13 Celebration Not Guilt (FitMe-specific), Content Strategy §9.5
- **Location:**
  - L712: `"\(essentialMissingCount) core \(essentialMissingCount == 1 ? "item still needs" : "items still need") attention."`
  - L486: `"Missing"` capsule shown when weight/body fat values are empty
  - L641: `"Treat today as a lighter practice day and protect recovery."` (this one is fine)
- **Description:** The "X core items still need attention" phrasing reads as guilt. "Missing" as a red-adjacent capsule label on empty metric fields implies failure. Per §1.13: *"Macro under-target: shows remaining, not 'you missed your goal'"*.
- **Recommendation (v2):** Replace "items still need attention" with "Log weight, meal, and supplements to complete today's picture." Replace "Missing" capsule with "Tap to log" hint or just leave the value as `—` with a subtle "Log" chevron.

---

## Section D — State coverage findings (Part 6 of ux-foundations.md)

### F15 — Missing explicit empty / loading / error states

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** §6.1-6.5 State Patterns, Section F of v2-refactor-checklist.md
- **Location:** `MainScreenView.swift` — no explicit state branches, relies on optional unwraps + `—` dashes
- **Description:** The checklist requires all 5 states (Default / Loading / Empty / Error / Success) for every screen. Current Home:
  - **Default:** ✅ rendered when data is present
  - **Loading:** ❌ — `dataStore.loadFromDisk()` happens in `FitTrackerApp` not Home. Home has no skeleton.
  - **Empty:** ⚠️ partial — shows `—` in metric tiles, "Missing" capsules on status, `0%` in goal ring. No explicit empty-state with onboarding copy or CTAs.
  - **Error:** ❌ — `dataStore.loadError` is handled by `RootTabView` with an alert, not on Home itself. If the error is transient (e.g. HealthKit observer stuck), Home just shows `—` with no way for the user to retry.
  - **Success:** ⚠️ partial — `statusPulse` animation when `essentialMissingCount` decreases is a success gesture, but there's no toast / persistent confirmation after a biometric entry.
- **Recommendation (v2):** Explicit state handling per screen:
  - **Loading:** First launch before `dataStore` loads → skeleton shimmer matching the 5-card layout for < 500ms; after that → default view
  - **Empty (new user):** If no daily logs + no biometrics + no HealthKit → use `EmptyStateView` component with CTA "Connect Health to auto-track recovery, or log your first biometrics manually"
  - **Error:** If HealthKit sync fails → inline banner "Couldn't sync Health. Tap to retry." using §6.4 error copy formula
  - **Success:** After biometric entry, toast "Weight saved" for 2s (already have haptic, just needs the label)

### F16 — Missing values show ambiguous `—` without affordance

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** §6.3 Empty States, Section F3
- **Location:** `MainScreenView.swift:292, 307, 716-738` — `currentWeight.map { ... } ?? "—"` pattern repeated
- **Description:** Per §6.3, empty states should follow the formula: *what is missing → what to do next → optional benefit*. The `—` dash provides zero information and zero action. Per §1.5 Recognition over Recall, users shouldn't have to guess "what do I do with this dash?"
- **Recommendation (v2):** When a metric tile has no value, show a "Log" chevron + tappable state. When the entire biometric card is empty, show a one-line CTA: "Log weight to start tracking your goal."

---

## Section E — Accessibility findings (Part 7 of ux-foundations.md)

### F17 — Edit button tap target is 34pt — **violates 44pt minimum**

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** §7.2 Motor Accessibility, Section G5 of checklist
- **Location:** `MainScreenView.swift:327` — `.frame(width: 34, height: 34)` on the edit button in `statusOverviewCard`
- **Description:** Apple HIG minimum is 44×44pt. This is a **hard a11y violation** — users with motor impairment or sweaty gym hands will mis-tap.
- **Recommendation (v2):** Use `AppButton.iconOnly(.secondary)` from `AppComponents.swift` which enforces 44pt minimum. Or expand the frame to 44×44 and use `.contentShape(Rectangle())` to make the hit area match.

### F18 — Only 4 accessibility labels in 1029 lines (for ~30+ interactive elements)

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** §7.4 VoiceOver Strategy, Section G1/G2 of checklist
- **Location:** `grep -c "accessibilityLabel\|accessibilityHint" MainScreenView.swift` returns 4
- **Description:** Per §7.4: *"Every interactive element MUST have an `accessibilityLabel`. Every non-trivial component MUST have an `accessibilityHint` for the action it performs."* Current coverage:
  - ✅ Line 331-332: biometric edit button (has label + hint — good)
  - ✅ Line 410-411: primary action button (has label + hint — good)
  - ❌ `LiveInfoStrip` — no label; VoiceOver reads "Good morning, Regev 🌤️" but the 6-second auto-cycling means a VoiceOver user can't finish reading before it changes
  - ❌ Day-type menu — no label
  - ❌ Goal ring — no `accessibilityValue` for "65% of goal"
  - ❌ 4 metric tiles — no labels, no values (VoiceOver reads only "—" or "42")
  - ❌ 2 status value columns (weight, body fat) — no labels
  - ❌ Status dot + text on status card — decorative but needs `.accessibilityHidden(true)` or combined label
  - ❌ Day count + phase capsule — no combined label "Day 12, Recovery phase"
  - ❌ `sectionEyebrow` Text elements — decorative headers, need `.accessibilityAddTraits(.isHeader)` for navigation
- **Recommendation (v2):** Every metric tile gets `.accessibilityElement(children: .combine)` + `.accessibilityLabel("{metric name}")` + `.accessibilityValue(value + " " + unit)`. `LiveInfoStrip` gets `.accessibilityElement(children: .combine)` + a combined label that concatenates all slides + custom actions for "Next slide" / "Previous slide". Goal ring gets `.accessibilityValue("\(Int(goalProgress * 100)) percent")`.

### F19 — Responsive fonts use fixed `.font(.system(size: N))` — breaks Dynamic Type

- **Severity:** P0
- **Tractability:** needs-new-token (see F5)
- **Principle / checklist:** §7.1 Dynamic Type, Section G7
- **Location:** All 12 locations in F5
- **Description:** `.font(.system(size: 25, weight: .bold, design: .rounded))` does **not** scale with Dynamic Type. Users at accessibility text size AX5 will see the same 25pt as users at default. The `// responsive — no AppText equivalent` comments explicitly acknowledge this gap but the gap has never been filled.
- **Recommendation (v2):** Either (a) map to existing `AppText.*` which already uses `Font.system(.<style>)` and scales, or (b) propose new `AppText.metricXL` / `metricL` / `metricM` tokens that use `Font.custom("SF Pro Rounded", size: N, relativeTo: .largeTitle)` for Dynamic Type scaling. Test at AX5 before Phase 5 approval.

### F20 — `LiveInfoStrip` auto-cycles every 5 seconds — hostile to VoiceOver / cognitive a11y

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** §7.2 Motor "No time-limited interactions", §7.4 VoiceOver, §8.2 Reduce Motion
- **Location:** `MainScreenView.swift:216` — `LiveInfoStrip(slides: greetingSlides, cycleDuration: 5)`
- **Description:** §7.2 says: *"No time-limited interactions in FitMe except: Rest timer, Toast notifications (auto-dismiss after 2s, but content is also accessible elsewhere)."* The 5-second cycling info strip is a hidden time-limited interaction — content rotates whether the user wants it or not. VoiceOver may be mid-read when the content changes. Users with Reduce Motion still see the rotation.
- **Recommendation (v2):** Either (a) pause auto-cycling when VoiceOver is running (`UIAccessibility.isVoiceOverRunning`) and Reduce Motion is enabled, (b) add a static fallback that concatenates all slides into one line, or (c) replace the rotation with a static strip showing the most important slide by priority (readiness > streak > greeting).

---

## Section F — Motion findings (Part 8 of ux-foundations.md)

### F21 — Raw `.spring()` and `.easeOut()` calls — not using `AppSpring` / `AppEasing` tokens

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** §8.1 Animation principles, Section H2/H3 of checklist
- **Location:**
  - L143-144: `withAnimation(.spring(response: 0.32, dampingFraction: 0.82))` (statusPulse)
  - L147: `withAnimation(.easeOut(duration: 0.22))` (statusPulse release)
  - L757: `withAnimation(.spring(response: 0.24, dampingFraction: 0.8))` (highlightedActionID on tap)
  - L762: `withAnimation(.easeOut(duration: 0.18))` (highlightedActionID release)
  - L202: `.animation(.easeOut(duration: 0.6), value: goalProgress)` — wait, this is in the backgroundLayer that's being replaced on the other branch. Out of scope for this audit.
- **Description:** `ux-foundations.md` §8.1 explicitly requires `AppSpring.*` / `AppEasing.*` / `AppDuration.*` tokens. Raw springs mean designers can't tune the feel globally, and there's no documentation of what "response: 0.24" is supposed to feel like.
- **Recommendation (v2):** Map each to the correct token:
  - statusPulse spring → `AppSpring.snappy` (quick, no overshoot — matches a state-change acknowledgment)
  - statusPulse release → `AppEasing.short`
  - primary-action highlight spring → `AppSpring.snappy`
  - primary-action release → `AppEasing.short`

### F22 — No reduce-motion support on any animation

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** §8.2 Reduce Motion, Section H4 of checklist
- **Location:** Every `withAnimation` call (4 of them) + `scaleEffect` on statusPulse + primary action
- **Description:** §8.2: *"iOS users can enable 'Reduce Motion' system-wide. FitMe MUST respect this."* Current Home has zero `.motionSafe(...)` modifiers, zero `@Environment(\.accessibilityReduceMotion)` checks. Users with reduce-motion enabled still see the pulse animations, scale bounces, and LiveInfoStrip cycling.
- **Recommendation (v2):** Every animation wraps in `@Environment(\.accessibilityReduceMotion) private var reduceMotion` + conditional. Use the `MotionSafe` view modifier pattern from `AppMotion.swift`. Replace scale effects with opacity fades when reduce motion is on. Stop `LiveInfoStrip` auto-cycling entirely when reduce motion is on.

### F23 — Haptics work correctly (positive finding)

- **Severity:** — (not a finding, noting it)
- **Location:** `performHomeAction()` helper at L748, haptics at L755, L128-136, L141-149
- **Description:** The haptic patterns are actually **correct** per §8.3:
  - `.light` impact on button press (F1 correct)
  - `.success` notification on readiness score improvement
  - `.success/.warning` notification on essentials change
  - `.impactOccurred()` on tab change
  All generators call `.prepare()` before `.impactOccurred()` as required.
- **Recommendation (v2):** **Preserve this pattern.** Do not regress haptic quality in the refactor. Carry over `performHomeAction()` as a helper in the v2 file.

---

## Section G — Analytics findings

### F24 — No screen tracking modifier on MainScreenView

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section I4 of checklist, `analytics-taxonomy.csv`
- **Location:** `RootTabView.swift:210` — `.analyticsScreen(AnalyticsScreen.home)` is applied by the parent, not inside `MainScreenView`
- **Description:** Current setup works but means the screen tracking is coupled to `RootTabView`. If someone embeds `MainScreenView` somewhere else (e.g. a future "Today widget" or an iPad sidebar), it won't self-report. Per `ux.md` integration contract, every view should self-instrument.
- **Recommendation (v2):** Move `.analyticsScreen(AnalyticsScreen.home)` to the root of v2's body. Keep `RootTabView` clean.

### F25 — No `home_*` events for quick action engagement

- **Severity:** P2
- **Tractability:** auto-applicable
- **Principle / checklist:** Section I1 of checklist
- **Location:** `MainScreenView.swift:748-768` — `performHomeAction` tracks internally via `highlightedActionID` but fires no analytics events
- **Description:** Primary action tap, manual biometric entry tap, day type override, goal ring tap, metric tile tap — none emit analytics events. We can't measure engagement with home-screen actions beyond screen_view.
- **Recommendation (v2):** Add `home_action_tap` event with param `action_type: "start_workout" | "log_meal" | "log_biometric" | "change_day_type" | "metric_tile" | "goal_ring"`. Add `home_action_completed` for the result (e.g. biometric saved, workout started). This goes into the Phase 1 PRD addendum's Analytics Spec, not the audit itself — but it surfaced here.

---

## Section H — Composition / component findings

### F26 — `statusValueColumn` and `metricTile` should promote to shared components

- **Severity:** P2
- **Tractability:** needs-new-component
- **Principle / checklist:** Section D1/D2 of checklist
- **Location:** `MainScreenView.swift:468-512` (statusValueColumn) + L538-555 (metricTile)
- **Description:** Both are private helpers that would be useful on other screens. `statusValueColumn` is a weight/body-fat column pattern that belongs on Stats too. `metricTile` is a generic metric display that belongs on StatsView, Settings → Health, and the Recovery Studio.
- **Recommendation (v2):** Promote both to `FitTracker/DesignSystem/AppComponents.swift` as `AppMetricColumn` and `AppMetricTile`. Document them in `component-contracts.md`. v2 MainScreenView then imports them instead of duplicating. Onboarding v2 retroactive refactor (scheduled after Home v2 ships) should also adopt these.

### F27 — `recommendationAccent`, `recommendationTitle`, etc. are recommendation logic embedded in a view

- **Severity:** P2
- **Tractability:** needs-decision
- **Principle / checklist:** Architecture — separation of concerns
- **Location:** `MainScreenView.swift:617-669` — ~8 computed properties that map `readinessScore` → color / title / subtitle / tone
- **Description:** These properties contain product logic (the "what does readiness 65 mean → suggest trim volume" rules). This logic also exists on the domain side (`ReadinessService`, `RecoveryRoutineLibrary.recommend`). Duplicated product decisions between views and services drift over time.
- **Recommendation (v2):** Extract the recommendation mapping into a `HomeRecommendationProvider` service (or expand `ReadinessService.readinessCopy(for:)`) so the view only consumes strings + colors. The v2 view should be thin — only layout + binding, no product logic.

---

## Section I — Priority-ordered action list

Summary of all P0 findings (must fix in v2 before ship):

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F1 | `GeometryReader` at root | Arch | Delete it; use environment size classes + Dynamic Type | 0.5 day |
| F9 | Readiness-First principle violated (missing ReadinessCard) | Principles | Promote `ReadinessCard` to first card; status becomes second | 1 day (decision + wiring) |
| F12 | "Log meal" quick action missing | Principles | Add Log Meal button next to Start Workout | 0.25 day |
| F15 | Missing loading / empty / error state branches | States | Add explicit state handling + EmptyStateView | 0.75 day |
| F17 | Edit button 34pt < 44pt minimum | a11y | Frame to 44pt; use `AppButton.iconOnly` | 0.1 day |
| F18 | 4 a11y labels total vs ~30+ interactive elements | a11y | Label every interactive element + combined accessibility for rotating strip | 1 day |
| F19 | `.font(.system(size: N))` doesn't Dynamic Type | a11y | Propose new `AppText.metricXL/L/M` tokens; map all 12 raw fonts | 0.75 day |
| F22 | Zero reduce-motion support on animations | Motion | Wrap every animation in `motionSafe` or env check | 0.25 day |

**P0 total effort:** ~4.6 days

P1 findings:

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F2 | "Above the fold, no scroll" hard constraint | Arch | Decision — probably drop | 0.1 day |
| F3 | `compact`/`tight` props threaded everywhere | Arch | Delete; Dynamic Type handles it | 0.25 day |
| F5 | 12 raw fonts (9 mappable to existing tokens) | Tokens | Mechanical replacement | 0.5 day |
| F6 | 7 raw paddings | Tokens | Mechanical replacement | 0.25 day |
| F7 | 11 raw frames | Tokens | Map to `AppSize.*` or propose new | 0.5 day |
| F8 | Raw `Color.blue/brown/purple` for metric tints | Tokens | Map to `AppColor.Chart.*` / `AppColor.Accent.*` | 0.1 day |
| F10 | Hick's Law: 27 visual elements | Principles | Reduce via progressive disclosure | 0.5 day |
| F11 | No drill-down progressive disclosure | Principles | Make metric tiles + goal ring tappable | 0.5 day |
| F14 | Guilt-adjacent copy ("items still need attention") | Principles | Rewrite per §1.13 Celebration not Guilt | 0.1 day |
| F16 | `—` dashes without "Log" affordance | States | Add tappable empty state per tile | 0.25 day |
| F20 | `LiveInfoStrip` auto-cycle hostile to VoiceOver | a11y | Pause on VoiceOver + reduce-motion | 0.25 day |
| F21 | Raw `.spring()` / `.easeOut()` | Motion | Map to `AppSpring.*` / `AppEasing.*` | 0.25 day |
| F24 | No screen tracking inside view | Analytics | Move `.analyticsScreen` from parent to v2 root | 0.05 day |

**P1 total effort:** ~3.6 days

P2 findings:

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F4 | `BlendedSectionStyle` instead of `AppCard` | Arch | Use shared component | 0.25 day |
| F13 | Macro progress not on Home | Principles | Add compact macro strip | 0.5 day |
| F25 | No `home_action_tap` analytics events | Analytics | Add events + taxonomy CSV rows | 0.25 day |
| F26 | Private helpers should promote to components | Composition | Extract to `AppComponents.swift` | 0.5 day |
| F27 | Recommendation logic embedded in view | Composition | Extract to `ReadinessService` | 0.5 day |

**P2 total effort:** ~2 days

### Total estimated effort

**P0 + P1:** ~8.2 days (mandatory for v2 ship)
**P0 + P1 + P2:** ~10.2 days (ideal scope)

Recommend scoping v2 to **P0 + P1 only** (~8 days) with P2 items deferred to a v2.1 follow-up if needed. This matches the Onboarding v2 pattern where 4 P2 items (P2-01 component consolidation, P2-05 a11y hints, P2-06 contrast bump, P2-07 pillar text size) were explicitly deferred to post-merge.

---

## Section J — Open questions for the user

These are the **needs-decision** findings that cannot be resolved auto-mechanically. The audit cannot move to Phase 1 (PRD addendum) until these are answered.

1. **F2 — Drop the "above the fold, no scroll" constraint?** Recommend yes.
2. **F9 — Use existing `ReadinessCard` component or build a new simpler readiness hero?** Recommend `ReadinessCard` as-is (it's already 6-page and handles loading/empty states).
3. **F10 — Target element count after Hick's Law reduction?** Recommend 10-12 visual elements at default state.
4. **F11 — Which metric tiles get drill-down first?** Recommend all 4 (HRV, RHR, Sleep, Steps) push to StatsView filtered to that metric.
5. **F12 — Where does "Log meal" live?** Recommend: second button in `startTrainingCard` HStack, same size as the day-type menu.
6. **F13 — Include compact macro strip on Home?** Recommend yes but flag as P2 (can ship v2 without it and add in v2.1).

---

## Next steps (if the audit is approved)

1. **Phase 0 → Phase 1:** Write `prd.md` addendum for home-today-screen v2 covering:
   - V2 scope summary (what's changing, what's preserved)
   - Success metrics (primary: session_per_day target, secondary: home_action_tap engagement, guardrails: no regression in crash-free or cold start)
   - Analytics spec for the new `home_action_tap` + `home_action_completed` events (per F25)
   - Kill criteria
2. **Phase 1 → Phase 2:** Break the P0 + P1 findings into implementable tasks with dependency graph
3. **Phase 2 → Phase 3:** `/ux research` pass (consolidate the 13 principles application) → `/ux spec` (screens, components, tokens, a11y contract) → `/ux validate` → `/design audit` (compliance gateway) → `/ux prompt` + `/design prompt` (auto-generate handoff prompts in `docs/prompts/`)
4. **Phase 3 → Phase 4:** Create `FitTracker/Views/Main/v2/MainScreenView.swift`, update `project.pbxproj` (add v2, remove v1 from Sources), mark v1 historical with header comment
5. **Phase 5-8:** Test → Review → Merge → Docs, walking through `docs/design-system/v2-refactor-checklist.md` Sections A-K

---

## Decisions Log (Phase 0 closure — 2026-04-08)

> Recorded after the user reviewed all 6 audit segments and answered every open question (OQ-1 through OQ-22 + Q9/Q10/Q11). This log is the canonical "why does Home v2 look the way it looks" reference and feeds Phase 1 PRD scope.

### Layout decisions

| # | Source | Decision |
|---|---|---|
| OQ-1 | F12, F25 | Card renamed from "Start Training" to **"Training & Nutrition"**. Same v1 card structure preserved. Card sits between stack items 3 (ReadinessCard) and 4 (Status). |
| OQ-2 | F12 | Log Meal becomes a peer CTA inside Training & Nutrition card. |
| OQ-15 | F12 | Two CTAs (Start Workout + Log Meal) lay out **side-by-side horizontally**, equal weight, 8pt gap. Mirrors onboarding goal-choice equality. |
| OQ-16 | — | Context row above the buttons collapses to a **single inline line**: `"Lower Body · 45m · On plan"` (day type · estimated session · recommendation tone). |
| OQ-5 | F2 | **Above-the-fold scroll constraint dropped.** Home v2 scrolls naturally. The 10-12 element target (F10) applies above the fold; rest scrolls. |

### Stack order (final)

```
1. Toolbar
2. Greeting line (static LiveInfoStrip)
3. ReadinessCard
4. Training & Nutrition
5. Status (separate card, temporary — merged sub-feature ships later)
6. Goal (separate card, temporary — merged sub-feature ships later)
7. Metrics (4 tiles, read-only — deep-link sub-feature ships later)
```

### LiveInfoStrip behavior

| # | Source | Decision |
|---|---|---|
| OQ-10 | — | Greeting includes user name: `"Good morning, Regev ☀️"` |
| OQ-11 | — | Streak threshold stays at v1's `≥3 days` (warmth over milestone). |
| Q9 | — | When both signals apply, **concatenate**: `"Good morning, Regev · 3-day streak 🔥"`. Single line, fits LiveInfoStrip width on iPhone 15+, gracefully truncates on smaller widths. |
| F20 | — | **No auto-rotation** (replaces v1's 5-second cycling). Static line resolved by priority: greeting + streak (concat) > greeting alone > streak alone. |

### ReadinessCard

| # | Source | Decision |
|---|---|---|
| F9 | F9 | **Promote existing `ReadinessCard` to first card** (was unused before, lives at `FitTracker/Views/Shared/ReadinessCard.swift`). Status card demoted from hero position. |
| OQ-12 | — | On tap = **cycle pages** (existing component behavior). No new view, no new sheet. |

### Training & Nutrition card content

Card structure:
```
┌──────────────────────────────────────────┐
│ Lower Body · 45m · On plan                │   ← single inline context (OQ-16)
│                                            │
│  ┌────────────────┐  ┌────────────────┐  │
│  │ Start Workout  │  │   Log Meal     │  │   ← side-by-side equal CTAs (OQ-15)
│  └────────────────┘  └────────────────┘  │
└──────────────────────────────────────────┘
```

### Status + Goal handling (temporary in Home v2)

| # | Source | Decision |
|---|---|---|
| Q4-C | — | Home v2 ships with Status and Goal as **separate v1-style cards** (ports v1 layout, applies new tokens + accessibility fixes). |
| OQ-3 (i) | — | Status+Goal merged card becomes its **own sub-feature** with full PM cycle. Runs **after Home v2 ships** (sequential, not parallel on the same branch). |
| Q12 | — | The merged sub-feature is part of the overall Home v2 workstream. Reuses every learning from this audit + the Pending DS Evolution Queue in `feature-memory.md` to speed its dev cycle. |

### Goal drill-down (separate from merged card)

| # | Source | Decision |
|---|---|---|
| F11 | — | Goal drill-down (tap goal ring → goal detail view) is **deferred entirely from Home v2**. Becomes its own feature, defined and built independently before being added to Home or Stats. |
| OQ-7-folded | — | Goal drill-down folds into the Status+Goal merged sub-feature (same PM cycle handles both merge + drill-down). |

### Macro strip

| # | Source | Decision |
|---|---|---|
| F13 | — | Not in Home v2. Pending design details. |
| OQ-4 | — | When implemented, placement decided **semantically** (not arbitrary slot). Lands with the Status+Goal merged sub-feature, positioned based on body-data context. |

### Metrics card

| # | Source | Decision |
|---|---|---|
| F11-partial | — | 4 tiles always visible per Q3 = (a). Each tile is **read-only display** in Home v2 — no deep-link in this branch. |
| OQ-13 | — | **New sub-feature spun off:** "Metric Tile Deep Linking" runs its own full PM cycle. Adds tap handlers + Stats `selectedMetric` filter parameter + navigation push. Ships after Home v2 + Stats screens have the necessary plumbing. Can run in parallel with the Status+Goal merged sub-feature since it touches different files. |

### Token compliance (Section B / F5-F8)

| # | Source | Decision |
|---|---|---|
| F5 | C1/C2 | All 12 raw `.font(.system(size: N))` calls map to existing `AppText.*` tokens (9 of 12) or to new tokens (3 of 12). New tokens already queued in `feature-memory.md` Pending Evolution Queue: `AppText.metricL`, `AppText.metricM`, `AppText.iconXL`. |
| F6 | C3 | All 7 raw padding literals map to existing `AppSpacing.*` tokens. |
| F7 | C/F17 | 9 of 11 raw frame literals map to tokens; the 2 hero sizes (goal ring, primary action) use Dynamic Type via `@ScaledMetric`. New token: `AppSize.indicatorDot` (8pt). |
| F8 | C1/§4.3 | 4 raw `.blue/.brown/.purple/.gray` colors map to chart tokens. New tokens: `AppColor.Chart.weight`, `Chart.hrv`, `Chart.heartRate`, `Chart.activity`. |

### Accessibility (Section E / F17-F20)

| # | Source | Decision |
|---|---|---|
| F17 | G5 | 34pt edit button → **44pt** via `AppButton.iconOnly(.secondary)` or frame expansion + `.contentShape(Rectangle())`. |
| F18 | G1/G2/G4 | Every interactive element gets `.accessibilityLabel`. Every non-trivial action gets `.accessibilityHint`. Every metric tile gets `.accessibilityValue` with units. Every section eyebrow gets `.accessibilityAddTraits(.isHeader)`. ~30 elements need labels added in Phase 4. |
| F19 | G7 | New `AppText.metricL/M` + `iconXL` tokens use `Font.custom("SF Pro Rounded", size: N, relativeTo: .largeTitle)` so they scale with Dynamic Type. Tested at AX5 in Phase 5. |
| F20 | §7.2 | LiveInfoStrip auto-rotation removed (see LiveInfoStrip section above). |

### State coverage (Section D / F15-F16)

| # | Source | Decision |
|---|---|---|
| F15 | F1-F5 | All 5 states implemented. |
| OQ-6 | F3 | **Single empty state message** with two buttons: "Connect Health" + "Log manually". When HealthKit is denied, the Connect button deep-links to **Settings → Privacy → Health → FitMe** (iOS rules block re-prompting from in-app). |
| F16 | F3 | Replace `—` dashes with tappable "Log" CTAs on empty metric tiles. |

### Motion (Section F / F21-F23)

| # | Source | Decision |
|---|---|---|
| F21 | H2/H3 | All 4 raw `.spring(...)` and `.easeOut(...)` calls map to `AppSpring.snappy` and `AppEasing.short` tokens. |
| F22 | H4 | Every animation wrapped in `@Environment(\.accessibilityReduceMotion)` check. Scale effects degrade to opacity fades. LiveInfoStrip rotation removed entirely (was already addressed by F20). |
| F23 | H5 | Haptics preserved verbatim. `performHomeAction()` helper carries over to v2 unchanged. |

### Analytics (Section G / F24-F25)

| # | Source | Decision |
|---|---|---|
| F24 | I4 | `.analyticsScreen(AnalyticsScreen.home)` modifier moves into the v2 view body. Removed from `RootTabView.swift:210` in the same commit. |
| F25 | I1 | New events: `home_action_tap`, `home_action_completed`, `home_empty_state_shown`, `home_metric_tile_tap` (the last one fires when the Metric Tile Deep Linking sub-feature ships). All conform to the screen-prefix convention from OQ-9. Full schemas + GA4 validation defined in Phase 1 PRD addendum Analytics Spec. |
| OQ-9 | F25 | **New project rule:** every analytics event tied to a specific screen MUST include the screen name as a prefix (`home_*`, `nutrition_*`, `training_*`, etc.). Documented in CLAUDE.md, analytics SKILL.md, and analytics-taxonomy.csv. |
| OQ-20 | — | Analytics events ship **together** with the v2 layout. Baseline = day Home v2 ships. No 7-day pre-collection. |

### Composition / architecture (Section H / F26-F27)

| # | Source | Decision |
|---|---|---|
| F26 | D1/D2 | **Promote `statusValueColumn` and `metricTile`** from private helpers to `FitTracker/DesignSystem/AppComponents.swift` as `AppMetricColumn` and `AppMetricTile`. Done in Home v2 Phase 4 (Q10 confirmed). Already in the Pending DS Evolution Queue. |
| F27 | — | **Extract recommendation logic** to a new `HomeRecommendationProvider` service file (OQ-14 = (b)). Cleaner boundaries than extending `ReadinessService`. Holds the readiness → copy/color/tone mapping. View consumes a single struct. |
| F1, F3 | A1/A2 | Root `GeometryReader` removed. `compact`/`tight` props deleted from every helper. Dynamic Type handles sizing throughout. |
| F4 | — | Custom `BlendedSectionStyle` ViewModifier replaced with existing `AppCard` from `AppComponents.swift`. |

### Testing strategy

| # | Source | Decision |
|---|---|---|
| OQ-19 | J | (c) — write **behavior tests for `HomeRecommendationProvider`** (the new service from F27) PLUS **snapshot tests for the v2 view's 5 states** (default / loading / empty / error / success). Service tests verify the readiness → recommendation mapping in isolation; snapshot tests catch view regressions across the state matrix. |

### Branch + sequencing

| # | Source | Decision |
|---|---|---|
| OQ-7 | — | v1 file fate: keep in repo with the standard CLAUDE.md "HISTORICAL" header comment template. Removed from Sources build phase (project.pbxproj surgery in Phase 4) but PBXFileReference stays. References to shared components (`LiveInfoStrip`, `ReadinessCard`, `ManualBiometricEntry`, etc.) stay unchanged in v1. |
| OQ-8 | — | (iii) Whichever branch is ready first merges first. No hard ordering between Home v2 and the iOS hardening branch (`claude/fix-ios-signin-compilation-6kxKG`). Both are independent and don't share files. |

### Kill criteria + review cadence (school-project context)

| # | Source | Decision |
|---|---|---|
| OQ-21 | — | (d) — define a degradation threshold in PRD kill criteria. Below threshold → hotfix on the v2 file. Above threshold → swap project.pbxproj back to v1 (one-commit revert per V2 Rule). Project is a **schooling project** with no production users, so threshold can be loose — purpose is to learn the rollback mechanics, not protect revenue. |
| OQ-22 | — | Review cadence: **1 week post-merge** matches Onboarding v2 pilot pattern. School-project context means this is a learning exercise — relax to 30-day or skip entirely if no signal. |

### Items deferred to Phase 3 (UX spec)

- **OQ-17** Figma node + file key for v2 build prompt — answered when `/design figma` runs in Phase 3
- **OQ-18** Status+Goal merged sub-feature naming + GitHub issue + state.json folder — created when sub-feature work starts

### Items deferred to follow-up sub-features

- **F11** Goal drill-down → folds into Status+Goal merged sub-feature
- **F13** Macro strip → Status+Goal merged sub-feature (semantically placed)
- **F25 partial** `home_metric_tile_tap` event → Metric Tile Deep Linking sub-feature
- **F26-followup** Onboarding v2 retroactive refactor will adopt the same `AppMetricColumn`/`AppMetricTile` (Q11 confirmed)

### Sub-feature queue (post-Home-v2)

In execution order:

1. **Onboarding v2 retroactive refactor** — moves existing onboarding files into `v2/` subdirectory per the new V2 Rule. Reuses Pending DS Evolution Queue items where applicable.
2. **Status+Goal merged card** — own PM cycle, slug TBD (proposal: `home-status-goal-card`). Includes goal drill-down + macro strip placement.
3. **Metric Tile Deep Linking** — own PM cycle, slug TBD (proposal: `metric-tile-deep-linking`). Can run in parallel with #2 since they touch different files.
4. **Training Plan v2** — next per-screen alignment after Onboarding retroactive completes.

---

*Phase 0 complete. Audit + decisions captured. Ready to advance to Phase 1 (PRD addendum).*
