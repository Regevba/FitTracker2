# V2 Refactor Checklist

> Walk every UI v2 refactor through this checklist. The checklist exists to
> speed up the work and to make sure nothing falls through the cracks.
> Reference this file from `ux-spec.md` and tick the boxes there as you
> complete each item. Set
> `state.json.phases.implementation.checklist_completed = true` when all
> applicable boxes are ticked.
>
> The rule that drives this checklist is documented in `CLAUDE.md` →
> "UI Refactoring & V2 Rule". The pm-workflow skill enforces it in Phase 3
> (UX) and Phase 4 (Implement).

---

## Section A — Audit & spec (Phase 3)

- [ ] **A1.** `v2-audit-report.md` exists at `.claude/features/{name}/`
  with one numbered finding per UX Foundations principle violation, each
  rated **P0 / P1 / P2** and tagged with tractability:
  `auto-applicable` (no decision needed),
  `needs-decision` (asks the user),
  `needs-new-token`,
  `needs-new-component`.
- [ ] **A2.** `ux-research.md` exists at `.claude/features/{name}/` —
  identifies which of the 13 ux-foundations principles apply to this
  surface and how each one is honored in v2.
- [ ] **A3.** `ux-spec.md` exists at `.claude/features/{name}/` — covers
  screens, components, tokens, a11y requirements, motion requirements,
  state coverage, and a Principle Application Table.
- [ ] **A4.** Design system compliance gateway run — every token, component,
  motion, accessibility, and pattern check is recorded with Pass/Fail in
  the spec. Fails are explicitly resolved (fix / evolve DS / override).
- [ ] **A5.** `state.json.work_subtype = "v2_refactor"` and
  `state.json.v2_file_path` is set using the `v2/` subdirectory convention
  (`{originalDir}/v2/{SameFileName}.swift`).

---

## Section B — File convention (Phase 4)

- [ ] **B1.** `v2/` subdirectory exists at the same level as the v1 file
  (e.g. `FitTracker/Views/Main/v2/`). One subdirectory per feature group
  — do **not** put multiple features into a single global `v2/` folder.
- [ ] **B2.** v2 Swift file is at the planned `state.json.v2_file_path`
  and uses the **same Swift type name** as v1 (e.g. both files declare
  `struct MainScreenView: View`). Type identity is what makes the
  parent-view swap zero-cost.
- [ ] **B3.** v2 file imports only from the design system layer
  (`FitTracker/DesignSystem/`, `FitTracker/Services/AppTheme.swift`)
  and the existing component library — no new ad-hoc components inside
  the v2 file unless they're declared as private types.
- [ ] **B4.** v2 file has zero raw literals (`.font(.system(size: ...))`,
  `.padding(20)`, `.frame(width: 88)`, hardcoded hex colors). Every
  visual value resolves to a token in `AppTheme.swift` /
  `AppComponents.swift`. Run `make tokens-check` to verify nothing
  drifts the token pipeline.
- [ ] **B5.** v1 file has a header comment marking it as historical,
  pointing at the v2 file path and the audit report.
- [ ] **B6.** `FitTracker.xcodeproj/project.pbxproj` is updated:
  - new PBXGroup for the `v2/` directory
  - PBXFileReference for the v2 file under that group
  - PBXBuildFile referencing the v2 file
  - v2 PBXBuildFile added to the Sources build phase
  - v1 PBXBuildFile **removed** from the Sources build phase
  - v1 PBXFileReference and group entry are kept (so the file shows in
    the navigator and git history)
- [ ] **B7.** `git diff main..HEAD -- FitTracker.xcodeproj/project.pbxproj`
  shows exactly the four edits above and nothing else (no UUID
  reshuffles, no unrelated build settings changes).

---

## Section C — Token compliance

- [ ] **C1.** All colors come from `AppColor.*` (Brand, Status, Surface,
  Text, Border, Background, Accent, Chart). No `Color(red:green:blue:)`
  literals, no `Color.red`, no string-literal asset names.
- [ ] **C2.** All typography comes from `AppText.*`. Exceptions are
  documented inline with a `// DS-exception:` comment explaining why
  (e.g. responsive size that AppText doesn't cover).
- [ ] **C3.** All spacing comes from `AppSpacing.*`. No
  `.padding(20)` / `.padding(.horizontal, 14)` / explicit `Spacer().frame(height: 32)`.
- [ ] **C4.** All radii come from `AppRadius.*`. No
  `RoundedRectangle(cornerRadius: 12)`.
- [ ] **C5.** All shadows come from `AppShadow.*` tokens.
- [ ] **C6.** Any new token added to `AppTheme.swift` is documented in
  `feature-memory.md` under the v2 refactor entry.

---

## Section D — Component reuse

- [ ] **D1.** Every reusable UI element maps to an existing component in
  `FitTracker/DesignSystem/AppComponents.swift` or
  `FitTracker/DesignSystem/`.
- [ ] **D2.** Any new component proposed by the v2 file is justified in
  the audit report (`needs-new-component` tractability) and lives in
  `FitTracker/DesignSystem/`, **not** as a private type inside the v2
  file. Private types are reserved for screen-local layout helpers.
- [ ] **D3.** No copy-pasted SwiftUI snippets from v1. If v2 needs the
  same layout pattern, that pattern becomes a component.
- [ ] **D4.** Removing a private type from v1 that's now a component does
  not affect v1's compilation (since v1 is no longer in the build target,
  this is automatic — but verify the v1 file still parses for git
  reviewability).

---

## Section E — UX principles (from ux-foundations.md)

For each principle that applies to this surface, tick the box and note
how v2 honors it. Skip principles that don't apply.

- [ ] **E1. Fitts's Law** — primary CTAs are ≥44pt with ≥8pt spacing.
  Buttons are full-row tappable where the row is the action.
- [ ] **E2. Hick's Law** — max 5–7 actionable items per view (excluding
  navigation). Multi-choice controls are grouped, not flat lists.
- [ ] **E3. Jakob's Law** — navigation, gestures, and modals match iOS
  conventions. No invented patterns.
- [ ] **E4. Progressive Disclosure** — leads with the headline; detail is
  one tap away. No screen crams every available field.
- [ ] **E5. Recognition over Recall** — critical state is visible (badges,
  progress bars, indicators); users never have to "go check".
- [ ] **E6. Consistency** — uses shared components; doesn't restyle
  patterns that already exist elsewhere.
- [ ] **E7. Feedback** — every action has an immediate response within
  100ms (haptic, animation, toast). No silent operations.
- [ ] **E8. Error Prevention** — destructive actions are reversible or
  confirmed. Validation is inline, not on submit.
- [ ] **E9. Readiness-First** (FitMe-specific) — "how am I doing today?"
  comes before "what should I do?" on any home/today surface.
- [ ] **E10. Zero-Friction Logging** (FitMe-specific) — every data entry
  in scope is completable in under 10 seconds.
- [ ] **E11. Privacy by Default** (FitMe-specific) — no raw health values
  in analytics events; encryption is implicit, not asked for.
- [ ] **E12. Progressive Profiling** (FitMe-specific) — no upfront
  profiling forms; behavior teaches the system.
- [ ] **E13. Celebration Not Guilt** (FitMe-specific) — missed days are
  silent; rest is "Recovery Day"; PRs get celebration animations.

---

## Section F — State coverage (Part 6 of ux-foundations.md)

For every screen in scope, all 5 states are defined and rendered:

- [ ] **F1.** Default state — primary content.
- [ ] **F2.** Loading state — skeleton, `FitMeLogoLoader`, or inline
  spinner per the loading state table in `ux-foundations.md`.
- [ ] **F3.** Empty state — uses `EmptyStateView` or equivalent. Copy
  follows the formula: what is missing → what to do next → optional
  benefit.
- [ ] **F4.** Error state — uses the error copy formula: state the issue
  → state the consequence → state the next action. Never raw errors.
- [ ] **F5.** Success state — transient toast for routine saves,
  celebration animation for achievements, persistent for state changes.

---

## Section G — Accessibility (Part 7 of ux-foundations.md)

- [ ] **G1.** Every interactive element has `accessibilityLabel`. Decorative
  images have `.accessibilityHidden(true)`.
- [ ] **G2.** Every non-trivial action has `accessibilityHint` describing
  what tapping does.
- [ ] **G3.** Charts have a text summary via `.accessibilityValue`.
- [ ] **G4.** Custom components (rotating cards, segmented controls) have
  custom accessibility actions for VoiceOver Switch Control.
- [ ] **G5.** Tap targets are ≥44×44pt (use `.contentShape(Rectangle())`
  + frame expansion if the visual is smaller).
- [ ] **G6.** Touch targets have ≥8pt spacing (`AppSpacing.xSmall`) between
  adjacent elements.
- [ ] **G7.** All text uses `AppText.*` Dynamic Type tokens. Tested at AX5
  (largest accessibility size) — no clipping, no truncation past 1 line
  for body content.
- [ ] **G8.** Colors meet contrast: ≥4.5:1 for body text, ≥3:1 for large
  text and UI components. Use `AppColor.Text.*` (already validated in
  DEBUG by `ColorContrastValidator`).
- [ ] **G9.** Color is never the only indicator — paired with shape, label,
  or position.

---

## Section H — Motion (Part 8 of ux-foundations.md)

- [ ] **H1.** Every animation maps to one of: state change, spatial
  transition, feedback, attention, celebration. Decorative animations
  removed.
- [ ] **H2.** Durations come from `AppDuration` / `AppMotion` tokens
  (`instant`, `micro`, `short`, `standard`, `long`, `xLong`).
- [ ] **H3.** Springs use `AppSpring.*` tokens, not raw `.spring(...)` calls.
- [ ] **H4.** Reduce Motion is honored — animations use `.motionSafe(...)`
  modifier or check `@Environment(\.accessibilityReduceMotion)`.
- [ ] **H5.** Haptics use the right generator: `UIImpactFeedbackGenerator`
  for tactile, `UINotificationFeedbackGenerator` for outcomes,
  `UISelectionFeedbackGenerator` for picker-style.
- [ ] **H6.** No animation is the only feedback path — every animation is
  paired with a haptic or label change so VoiceOver users get the
  signal too.

---

## Section I — Analytics (if `requires_analytics = true`)

- [ ] **I1.** Every measurable interaction in v2 has a corresponding event
  in `AnalyticsEvent` enum and a row in `analytics-taxonomy.csv`.
- [ ] **I2.** New events follow GA4 naming rules: snake_case, ≤40 chars,
  no reserved prefixes (`ga_`, `firebase_`, `google_`).
- [ ] **I3.** No PII in any parameter — no emails, names, IDs, raw health
  values. Categorical bands only.
- [ ] **I4.** Screen tracking is wired via the `.analyticsScreen()`
  modifier on the v2 view's root. Screen name is in `AnalyticsScreen`
  enum.
- [ ] **I5.** Consent gating verified — denied consent → no event fires.
  Test in `FitTrackerTests/AnalyticsTests.swift`.

---

## Section J — Build & test (Phase 5)

- [ ] **J1.** `xcodebuild build` clean on iOS Simulator.
- [ ] **J2.** `xcodebuild test` — full XCTest suite green, including any
  new tests added in Phase 5.
- [ ] **J3.** `make tokens-check` clean.
- [ ] **J4.** Manual test on iPhone 17 Pro Max simulator: every state
  (default / loading / empty / error / success) reachable, no clipping,
  no console warnings.
- [ ] **J5.** Manual test at AX5 Dynamic Type — readable, no overlap.
- [ ] **J6.** Manual test with Reduce Motion enabled — animations
  degrade gracefully.
- [ ] **J7.** Manual test with VoiceOver — every interactive element
  navigable and labeled.
- [ ] **J8.** v1 file still parses (open in Xcode, no syntax errors).
  v1 is no longer compiled, but it should remain a readable historical
  reference.

---

## Section K — Documentation (Phase 8)

- [ ] **K1.** PRD updated with v2 implementation notes (file path,
  audit-driven changes, metrics).
- [ ] **K2.** `feature-memory.md` updated with the v2 entry: what changed,
  what tokens/components were added, what was deferred.
- [ ] **K3.** `backlog.md` Done table updated.
- [ ] **K4.** `CHANGELOG.md` entry under the relevant date.
- [ ] **K5.** `state.json.transitions` reflects the full v2 lifecycle
  (research → prd → tasks → ux → implement → testing → review → merge
  → docs → complete).

---

## How to use this file

1. **Phase 3 (UX):** Reference this file from `ux-spec.md`. Pre-tick any
   sections that don't apply to this surface (e.g. Section I if
   `requires_analytics = false`).
2. **Phase 4 (Implement):** Tick boxes as you complete the work. The file
   is the definition-of-done — Phase 4 cannot move to Phase 5 with
   unticked applicable boxes.
3. **Phase 5 (Test):** Section J is the verification gate. Section J
   failures block Phase 5 approval.
4. **Phase 8 (Docs):** Section K closes out the lifecycle.

If a box is intentionally skipped, document why in `state.json` under
`phases.implementation.checklist_skips[]`. No silent skips.
