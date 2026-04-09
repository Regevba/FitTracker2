# training-plan — v2 UX Foundations Audit Report

> **Phase:** 0 (Research) — output drives Phases 1-4
> **Target file (v1):** `FitTracker/Views/Training/TrainingPlanView.swift` (2,135 lines)
> **Target file (v2, planned):** `FitTracker/Views/Training/v2/TrainingPlanView.swift`
> **Branch:** `feature/home-today-screen-v2` (audit piggybacks on current branch; implementation gets its own)
> **Pilot precedent:** Home v2 audit (`.claude/features/home-today-screen/v2-audit-report.md`) — this is the third feature to run the `/ux audit` -> v2 refactor loop, and the **second** to follow the `v2/` subdirectory convention.
> **Skill invoked:** `/ux audit` (see [`docs/skills/ux.md`](../../../docs/skills/ux.md))

---

## Executive summary

`TrainingPlanView.swift` is a 2,135-line monolith containing **13 types** (1 root view + 12 nested/fileprivate types) in a single file. It shipped pre-PM-workflow and has never been audited against `ux-foundations.md`. The file covers:

- Week strip day picker (Mon-Sun)
- Session type picker (3x2 grid)
- Session overview with rest timer, exercise queue, focus mode
- Exercise section blocks grouped by category
- Per-exercise rows with status dropdown, lift log panels, cardio log panels
- Set-level logging with weight/reps/RPE/notes
- Cardio logging with photo capture (camera + library)
- RPE tap bar
- Session completion sheet with PR detection + milestone modal
- Notes editor sheet
- Focus mode (full-screen distraction-free logging)
- Camera UIKit wrapper
- Shared small components (CardioField, RPETapBar, StatusDropdown)

**Overall health:** The file is functional and well-structured internally (good use of `MARK` sections, semantic naming). Token compliance is significantly better than the Home v1 audit — most spacing, radius, and typography references use `AppSpacing.*`, `AppRadius.*`, and `AppText.*` tokens. However, the file has serious problems with architecture (13 types in one file), accessibility coverage, raw font/animation literals, missing state patterns, and zero analytics instrumentation.

**Findings count:** 32 numbered findings across 8 sections, severity-graded.

| Severity | Count | Definition |
|---|---|---|
| **P0** | 8 | Blocks v2 ship (foundational principle violation, broken a11y baseline, missing critical state, DS anti-pattern) |
| **P1** | 16 | Should fix in v2 (token drift, minor principle miss, inconsistent pattern, missing a11y hint) |
| **P2** | 8 | Nice-to-have, can defer (polish, edge cases, optional enhancements) |

**Tractability breakdown:**

| Tractability | Count | Meaning |
|---|---|---|
| **auto-applicable** | 20 | Can be fixed mechanically (raw literal -> token, add missing label, swap raw ease for `AppMotion`) |
| **needs-decision** | 7 | Requires user call (file decomposition strategy, rest day empty state copy, Focus Mode redesign scope) |
| **needs-new-token** | 3 | New AppText/AppSize tokens required for raw font/frame literals |
| **needs-new-component** | 2 | Private helpers should promote to shared components |

**Recommended approach:** Build a new `FitTracker/Views/Training/v2/TrainingPlanView.swift` from scratch, bottom-up from `ux-foundations.md`. Extract nested types into dedicated files. Do NOT patch v1 in place per the [V2 Rule in `CLAUDE.md`](../../../CLAUDE.md).

---

## Section A -- Architecture & layout findings

### F1 -- 2,135-line monolith with 13 types in one file

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** Architecture hygiene, single-responsibility
- **Location:** `TrainingPlanView.swift:1-2135` (entire file)
- **Description:** The file contains 13 distinct types: `TrainingPlanView`, `SessionTypeButton` (fileprivate), `ExerciseSectionBlock`, `ExerciseRowView`, `LiftLogPanel`, `SetRowView`, `CardioLogPanel`, `CameraView`, `CardioField`, `RPETapBar`, `StatusDropdown`, `SessionCompletionSheet`, `NotesEditorSheet`, `FocusModeView`, `MilestoneModal`. Several of these (`LiftLogPanel`, `CardioLogPanel`, `SetRowView`, `SessionCompletionSheet`, `FocusModeView`) are 100-200+ lines each and are independent views. This makes the file extremely difficult to navigate, review, and test. It also makes the Xcode preview workflow impractical.
- **Recommendation (v2):** Decompose into at minimum 7 files:
  1. `TrainingPlanView.swift` -- root view + week strip + session picker + session overview
  2. `ExerciseSectionBlock.swift` -- section block + exercise row
  3. `LiftLogPanel.swift` -- lift logging + set row
  4. `CardioLogPanel.swift` -- cardio logging + camera wrapper
  5. `SessionCompletionSheet.swift` -- completion sheet + milestone modal
  6. `FocusModeView.swift` -- focus mode
  7. `TrainingComponents.swift` -- small shared components (CardioField, RPETapBar, StatusDropdown, SessionTypeButton)

### F2 -- `GeometryReader` used for floating rest timer positioning

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section B7 (architecture hygiene), SwiftUI layout anti-patterns
- **Location:** `TrainingPlanView.swift:53-64`
- **Description:** A `GeometryReader` wraps the floating rest timer to read `geo.safeAreaInsets.bottom + 56` for positioning. While less severe than the Home v1 root-level GeometryReader (this one is scoped and only reads safe area insets), it still causes the parent `ZStack` to offer unlimited space to the GeometryReader child. The `56` magic number presumably represents the tab bar height.
- **Recommendation (v2):** Replace with `.safeAreaInset(edge: .bottom)` or use an overlay with `.ignoresSafeArea(.keyboard)` + `.padding(.bottom)` using a semantic token for tab bar clearance. Alternatively, use `@Environment(\.safeAreaInsets)` if available, or simply use `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)` on the overlay.

### F3 -- Private `ExGroup` struct defined inline

- **Severity:** P2
- **Tractability:** auto-applicable
- **Principle / checklist:** Architecture hygiene
- **Location:** `TrainingPlanView.swift:507`
- **Description:** `private struct ExGroup { let title: String; let exercises: [ExerciseDefinition] }` is a one-liner data struct embedded in the view. Minor but should live alongside the grouping function in a helpers file.
- **Recommendation (v2):** Move to a `TrainingPlanHelpers.swift` or make it a named tuple.

### F4 -- Magic number `56` for tab bar offset

- **Severity:** P1
- **Tractability:** needs-new-token
- **Principle / checklist:** Token compliance (Section C3)
- **Location:** `TrainingPlanView.swift:61` -- `geo.safeAreaInsets.bottom + 56`
- **Description:** The `56` is presumably the tab bar height. This is a raw numeric literal that should be a semantic token. If the tab bar height changes or is hidden, this breaks.
- **Recommendation (v2):** Propose `AppSize.tabBarClearance: CGFloat = 56` or use the system safe area inset approach that automatically accounts for tab bar presence.

---

## Section B -- Token compliance findings

### F5 -- Raw `.font(.caption2.monospaced())` and `.font(.caption2)` calls (not using `AppText.*`)

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C1, C2 (token compliance)
- **Locations (17 occurrences):**
  - L251: `.font(.caption2.monospaced())` -- "Current Focus" label
  - L324: `.font(.caption2)` -- rest timer "remaining" label
  - L408: `.font(.caption2)` -- exercise queue status text
  - L664: `.font(.caption2.weight(.semibold))` -- SessionTypeButton day label
  - L708-709: `.font(.caption.monospaced())` -- ExerciseSectionBlock title
  - L826: `.font(.subheadline.weight(.semibold))` -- exercise name
  - L840: `.font(.caption2)` -- muscle groups text
  - L849-850: `.font(.caption2.italic())` -- coaching cue
  - L907-908: `.font(.caption2.weight(.medium))` -- exercise meta pill
  - L949-951: `.font(.caption2.monospaced())` -- "LIVE SET LOG" / "SET LOG"
  - L957: `.font(.caption2.monospaced())` -- total volume text
  - L1147-1148: `.font(.caption2)` -- previous set hint
  - L1269: `.font(.caption2.weight(.medium))` -- "Last {value}" button
  - L1317-1318: `.font(.caption2.monospaced())` -- "ROWING LOG" / "ELLIPTICAL LOG"
  - L1323-1324: `.font(.caption2.monospaced())` -- zone status
  - L1394: `.font(.caption2)` -- photo caption
  - L1475: `.font(.largeTitle)` -- close button in expanded photo view
  - L1702: `.font(.subheadline)` -- day type in completion sheet
  - L1709: `.font(.subheadline)` -- completion message
  - L1905: `.font(.caption2)` -- stat tile label
  - L1987-1988: `.font(.caption.monospaced())` -- Focus Mode heading
- **Description:** These are raw SwiftUI font modifiers instead of `AppText.*` tokens. While many use appropriate styles, they bypass the semantic token layer. This means a global typography change (e.g., changing caption2 weight across the app) won't propagate here.
- **Recommendation (v2):** Map each to the closest `AppText.*` token:
  - `.caption2.monospaced()` -> `AppText.monoLabel` (caption2, monospaced, semibold -- already exists)
  - `.caption2` -> `AppText.footnote` or a new `AppText.caption2` token (caption2, rounded, regular)
  - `.caption2.weight(.semibold)` -> `AppText.monoLabel` (if monospaced context) or `AppText.captionStrong` (if rounded context)
  - `.caption2.weight(.medium)` -> propose new `AppText.caption2Medium` or use `AppText.footnote`
  - `.caption2.italic()` -> no token exists; propose `AppText.captionItalic` for coaching cues
  - `.subheadline.weight(.semibold)` -> `AppText.sectionTitle` or `AppText.callout`
  - `.subheadline` -> `AppText.subheading`
  - `.largeTitle` -> `AppText.hero`
  - `.caption.monospaced()` -> `AppText.monoLabel` with tracking

### F6 -- Raw `Color.black` used in RPE bar and Focus Mode

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C1 (token compliance)
- **Locations:**
  - L1615: `.foregroundStyle(Color.black)` -- RPE selected segment text
  - L1767: `.foregroundStyle(.black)` -- "Done" button text in completion sheet
  - L1966: `Color.black.ignoresSafeArea()` -- Focus Mode background
- **Description:** Raw `Color.black` bypasses the semantic token layer. In dark mode, black-on-dark backgrounds become invisible. For Focus Mode the intent is deliberate (always-dark), but it should still use a semantic token.
- **Recommendation (v2):**
  - RPE selected text: use `AppColor.Text.inversePrimary` (white text on warm background may actually be the intent -- verify design)
  - Completion sheet "Done" text: use `AppColor.Text.inversePrimary`
  - Focus Mode background: use `AppColor.Surface.inverse` (already used in `MilestoneModal` at L2097)

### F7 -- Raw `.foregroundStyle(.white)` used in 5 places

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C1 (token compliance)
- **Locations:**
  - L1409: `.foregroundStyle(.white)` -- photo remove button
  - L1475: `.foregroundStyle(.white)` -- close button in expanded photo
  - L1992: `.foregroundStyle(.white)` -- Focus Mode exercise name
  - L2005: `.foregroundStyle(.white)` -- Focus Mode target reps
  - L2105: `.foregroundStyle(.white)` -- MilestoneModal title
- **Description:** Raw `.white` won't adapt to future theming changes.
- **Recommendation (v2):** Replace with `AppColor.Text.inversePrimary` for text on dark surfaces.

### F8 -- Raw padding literal `.padding(40)` in expanded photo view

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C3 (token compliance)
- **Location:** `TrainingPlanView.swift:1478` -- `.padding(40)`
- **Description:** Raw `40` padding. This is `AppSpacing.xxLarge` (40pt).
- **Recommendation (v2):** Replace with `.padding(AppSpacing.xxLarge)`.

### F9 -- Raw padding literal `.padding(.vertical, 2)` in session overview

- **Severity:** P2
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C3 (token compliance)
- **Location:** `TrainingPlanView.swift:313` -- `.padding(.vertical, 2)`
- **Description:** Raw `2` padding. This is `AppSpacing.micro` (2pt).
- **Recommendation (v2):** Replace with `.padding(.vertical, AppSpacing.micro)`.

### F10 -- Raw padding literal `.padding(.leading, 14)` used twice

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C3 (token compliance)
- **Locations:**
  - L784: `.padding(.leading, 14)`
  - L795: `.padding(.leading, 14)`
- **Description:** `14` does not map to any `AppSpacing` token. Closest are `AppSpacing.xSmall` (12) and `AppSpacing.small` (16).
- **Recommendation (v2):** Use `AppSpacing.xSmall` (12) or `AppSpacing.small` (16). If 14 is visually critical (aligning divider with status stripe width + padding), document the exception.

### F11 -- Raw frame dimensions scattered across file

- **Severity:** P1
- **Tractability:** auto-applicable (most) + needs-new-token (3)
- **Locations:**
  - L162, L166: `.frame(width: 28, height: 28)` -- week strip day circles
  - L176: `.frame(width: 5, height: 5)` -- completion dot
  - L401: `.frame(width: 7, height: 7)` -- exercise queue status dot
  - L413: `.frame(width: 146, alignment: .leading)` -- exercise queue card fixed width
  - L469: `Circle().stroke(..., lineWidth: 5).frame(width: 44, height: 44)` -- completion ring
  - L655: `Circle().fill(color).frame(width: 6, height: 6)` -- StatusDropdown dot
  - L706: `.frame(width: 22, height: 1)` -- section divider accent
  - L817: `.frame(width: 4)` -- status stripe
  - L1199: `fixedWidth: 86` -- reps entry field
  - L1400: `.frame(maxHeight: 180)` -- photo preview height
  - L1420: `.frame(height: 80)` -- photo placeholder height
- **Description:** Most of these are small indicator/dot sizes or fixed widths that should have semantic tokens. The 44x44 completion ring is fine (matches `AppSize.touchTargetLarge` range). The 146pt exercise queue width, 86pt reps field, 180pt/80pt photo heights are layout magic numbers.
- **Recommendation (v2):**
  - 5pt/6pt/7pt dots -> propose `AppSize.indicatorDotSmall: CGFloat = 6` (standardize on one size)
  - 28pt day circle -> propose `AppSize.dayCircle: CGFloat = 28` or use existing convention
  - 4pt status stripe -> `AppSize.progressBarHeight` (4pt, already exists)
  - 146pt/86pt/180pt/80pt -> keep as local layout constants with comments, or propose contextual tokens

### F12 -- `lineWidth: 1` and `lineWidth: 1.2` raw stroke widths

- **Severity:** P2
- **Tractability:** auto-applicable
- **Principle / checklist:** Section C3 (token compliance)
- **Locations:**
  - L420-421: `.stroke(... lineWidth: isFocused ? 1.2 : 1)` -- exercise queue border
  - L1628: `.stroke(... lineWidth: 1)` -- RPE bar segment border
- **Description:** Raw stroke widths. These should be tokens if border widths vary by state.
- **Recommendation (v2):** Propose `AppBorder.standard: CGFloat = 1` and `AppBorder.focused: CGFloat = 1.5` (round to grid), or use existing `AppColor.Border.*` convention with standardized widths.

---

## Section C -- UX Principle findings

### F13 -- 1.1 Fitts's Law: Exercise queue strip cards have narrow tap targets

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 1.1 Fitts's Law, 7.2 Motor Accessibility
- **Location:** `TrainingPlanView.swift:388-431` -- `exerciseQueueStrip`
- **Description:** Exercise queue cards are 146pt wide but vertically compact (xxSmall padding = 8pt top + bottom). With caption-size text inside, the effective tap target height is approximately 36-40pt, which is below the 44pt minimum. Users with sweaty gym hands will mis-tap between adjacent queue items.
- **Recommendation (v2):** Increase vertical padding to `AppSpacing.xSmall` (12pt) to bring total height above 44pt. Add `.contentShape(Rectangle())` to ensure the entire card area is tappable.

### F14 -- 1.2 Hick's Law: Session overview block presents too many simultaneous actions

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** 1.2 Hick's Law, 7.3 Cognitive Accessibility
- **Location:** `TrainingPlanView.swift:221-312` -- `sessionOverviewBlock`
- **Description:** The session overview block presents simultaneously: day title, summary text, completion ring, rest timer card (with stepper), current focus section (exercise name, subtitle, 3 meta pills), 3 action buttons (Jump To Next, Start Rest, Focus Mode), and 2 dividers. That's approximately 12-15 interactive/informational elements in a single block. Hick's Law recommends 5-7 actionable items per view.
- **Recommendation (v2):** Apply progressive disclosure. The rest timer card could collapse to an icon that expands on tap. Meta pills are read-only context that could be part of the exercise row instead. Consider merging "Jump To Next" with the exercise queue strip (tapping an exercise already focuses it).

### F15 -- 1.4 Progressive Disclosure: Completed/partial exercises expand immediately inline

- **Severity:** P2
- **Tractability:** needs-decision
- **Principle / checklist:** 1.4 Progressive Disclosure
- **Location:** `TrainingPlanView.swift:781-789` -- status-based expansion in `ExerciseRowView`
- **Description:** When an exercise's status changes to `.completed` or `.partial`, the entire lift/cardio log panel expands inline. This is good for the currently-focused exercise, but for completed exercises it means the exercise list becomes very long (each completed exercise shows its full set log). On a 6-exercise session, scrolling past completed exercises to reach the next pending one requires significant scrolling.
- **Recommendation (v2):** Keep auto-expansion only for the focused exercise. Completed exercises should show a collapsed summary (e.g., "3 sets, 3,600 kg total") with a disclosure chevron to expand the full log on demand.

### F16 -- 1.7 Feedback: No toast or visual confirmation after set completion

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 1.7 Feedback
- **Location:** `TrainingPlanView.swift:1048-1053` -- `onCompleteSet` in `SetRowView`
- **Description:** When a set is completed, there's a haptic (`.medium` impact) and a brief green flash (`flashGreen` state). But the flash lasts only ~0.35s and there's no text confirmation. Per ux-foundations 1.7, *"Set completion: `.medium` haptic + checkmark animation + row slides to 'completed' state"*. The green flash is present but there's no checkmark animation or persistent completed-state visual change on the individual set row.
- **Recommendation (v2):** Add a persistent checkmark icon on completed set rows (not just the transient flash). The row background should remain lightly tinted green for completed sets (already partially done via `setIsComplete` check at L1230, but the visual difference between `Color.status.success.opacity(0.08)` and `AppColor.Surface.materialLight` is very subtle).

### F17 -- 1.10 Zero-Friction Logging: Auto-population from previous session is excellent (positive finding)

- **Severity:** -- (positive finding)
- **Location:** `TrainingPlanView.swift:961-972, 993-1006` -- previous performance tiles, "Copy Last" button
- **Description:** The "Copy Last" button pre-fills all sets from the previous session. Previous performance tiles show "Last Best" and "Last Volume". The entry fields show "Last {value}" hints. This is a textbook implementation of 1.10 Zero-Friction Logging. The overload suggestion at L1077-1097 ("Try X kg today (+2.5)") is also excellent progressive overload coaching.
- **Recommendation (v2):** Preserve this pattern. Carry over the "Copy Last" + overload suggestion + previous performance tiles exactly.

### F18 -- 1.13 Celebration Not Guilt: Rest day shows minimal content with no positive framing

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 1.13 Celebration Not Guilt
- **Location:** `TrainingPlanView.swift:225` -- `"Active rest - walk, yoga, recover"` and L269-273 -- rest day pills
- **Description:** When a rest day is selected, the session overview shows "Active rest - walk, yoga, recover" and two pills ("Walk or yoga" + "Recovery notes"). This is minimal but acceptable. However, there's no positive framing about *why* rest matters. Per 1.13: *"Rest days are explicitly 'Recovery Day' -- not 'Day Off' or 'No Workout'"*. The current text says "Active rest" which is good, but the lack of any recovery context (e.g., muscle repair, nervous system recovery) misses an opportunity to celebrate rest as part of training.
- **Recommendation (v2):** Add a brief encouraging line: "Recovery is when your body adapts and gets stronger." Or rotate through recovery-focused messages. Use `AppColor.Accent.recovery` tint for the rest-day state.

---

## Section D -- State coverage findings

### F19 -- Missing explicit loading state

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** 6.1-6.5 State Patterns
- **Location:** `TrainingPlanView.swift:70-73` -- `onAppear` loads log synchronously
- **Description:** The `loadLog(for:preferredDay:)` function accesses `dataStore.log(for:)` which reads from the in-memory array. This is fast (no async), but there's no handling for the case where `dataStore` hasn't finished loading from disk yet. If the user navigates to Training before the encrypted data store finishes decryption, they'll see an empty state with no explanation. No skeleton, no spinner, no loading indicator.
- **Recommendation (v2):** Add a loading state check: if `dataStore.isLoading` (or equivalent), show a skeleton shimmer matching the session layout. This should resolve within 200-500ms on app launch.

### F20 -- Missing explicit error state

- **Severity:** P0
- **Tractability:** needs-decision
- **Principle / checklist:** 6.4 Error States
- **Location:** Entire file -- no error handling UI
- **Description:** If `dataStore.upsertLog()` fails (disk full, encryption error), the user gets no feedback. If `loadLog()` returns nil unexpectedly, the view creates a blank log silently. There's no retry mechanism, no error banner, no "your data might not be saved" warning. Per 6.4: error states must *"reassure the user their work is safe"* and *"offer a clear recovery path"*.
- **Recommendation (v2):** Add an inline error banner at the top of the scroll view if the last save failed. Show "Couldn't save your workout. Your data is stored locally. Tap to retry." Use the standard error copy formula from ux-foundations 6.4.

### F21 -- Rest day empty state is functional but not designed

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 6.3 Empty States
- **Location:** `TrainingPlanView.swift:225, 269-273` -- rest day content
- **Description:** When rest day is selected, the exercise sections are empty (no exercises), the completion ring shows 0/0, and only the overview block has content. There's no dedicated empty state with an illustration or CTA. Per 6.3, empty states should follow the formula: *what is missing -> what to do next -> optional benefit*.
- **Recommendation (v2):** Show a dedicated rest-day card with: recovery illustration/icon, positive copy ("Your muscles rebuild on rest days"), optional CTAs ("Log a walk" / "Add recovery notes" / "Check your readiness score").

### F22 -- No empty state for "Add Set" (first-time exercise logging)

- **Severity:** P2
- **Tractability:** auto-applicable
- **Principle / checklist:** 6.3 Empty States
- **Location:** `TrainingPlanView.swift:1030-1038` -- empty set log placeholder
- **Description:** The empty state exists and is decent: a plus icon + "Tap 'Add Set' to log your first set". However, when there's previous session data available, the "Copy Last" button appears but the empty-state message doesn't mention it. New users who don't notice "Copy Last" will manually enter everything.
- **Recommendation (v2):** When previous session data exists, change the empty-state copy to: "Tap 'Copy Last' to pre-fill from your previous session, or 'Add Set' to start fresh."

---

## Section E -- Accessibility findings

### F23 -- Sparse accessibility labels across 2,135 lines

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** 7.4 VoiceOver Strategy
- **Location:** Entire file -- approximately 12 accessibility labels/hints across 50+ interactive elements
- **Description:** A `grep` for `accessibilityLabel` and `accessibilityHint` reveals coverage on:
  - L333-334: rest duration stepper (label + value)
  - L359: floating rest timer (label + hint)
  - L424-426: exercise queue button (label + value + hint)
  - L1411-1412: photo remove button (label + hint)
  - L1477: expanded photo close button (label)
  - L1632-1634: RPE tap bar segments (label + value + hint per segment)
  - L1637-1638: RPE container (element + label)

  **Missing labels on interactive elements:**
  - Week strip day buttons (~7 buttons, no labels)
  - Session type picker buttons (~6 buttons, no labels)
  - "Jump To Next" / "Start Rest" / "Focus Mode" action buttons
  - Exercise row tap gesture (no label for the focus action)
  - Status dropdown menu (no label)
  - "Add Set" / "Copy Last" / "Start Rest" buttons in LiftLogPanel
  - "Done" / "Log" set completion buttons
  - Delete set button (xmark)
  - Weight/Reps text fields (no labels, VoiceOver reads placeholder only)
  - Cardio fields (no individual labels)
  - Photo picker / camera buttons
  - All completion sheet elements
  - Focus Mode elements
  - Notes editor
- **Recommendation (v2):** Every interactive element gets `.accessibilityLabel()`. Every non-obvious action gets `.accessibilityHint()`. Metric displays get `.accessibilityValue()`. Decorative elements get `.accessibilityHidden(true)`. Estimated: 40+ labels to add.

### F24 -- Week strip day buttons lack accessibility labels

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** 7.4 VoiceOver Strategy
- **Location:** `TrainingPlanView.swift:143-189` -- weekStrip `ForEach` with `onTapGesture`
- **Description:** Each day in the week strip uses `onTapGesture` on a `VStack` with no accessibility label. VoiceOver will attempt to read the child text elements individually ("Mon", "7", then the dot), but won't communicate the semantic meaning ("Monday April 7, Push day, has log" vs "Tuesday April 8, today, selected"). The `onTapGesture` modifier doesn't create an accessible action by default.
- **Recommendation (v2):** Replace `onTapGesture` with a `Button` for each day. Add `.accessibilityLabel("Monday, April 7")` + `.accessibilityValue("Push day. Workout logged.")` or `"Rest day. No workout."` + `.accessibilityHint("Switch to this day")`. Use `.accessibilityElement(children: .combine)` on each day VStack.

### F25 -- Session type picker buttons have no accessibility context

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 7.4 VoiceOver Strategy
- **Location:** `TrainingPlanView.swift:652-686` -- `SessionTypeButton`
- **Description:** The `SessionTypeButton` has a `Button` (good for VoiceOver discoverability) but no `.accessibilityLabel` or `.accessibilityValue`. VoiceOver will read "Push Day, button" from the icon + text, but won't communicate whether it's selected, suggested, or the number of exercises.
- **Recommendation (v2):** Add `.accessibilityLabel(dayType.rawValue)` + `.accessibilityValue(isSelected ? "Selected" : isSuggested ? "Suggested for today" : "")` + `.accessibilityHint("Switch to \(dayType.rawValue) session")`.

### F26 -- Tap targets on delete button (xmark) and various small buttons

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** 7.2 Motor Accessibility -- 44pt minimum
- **Location:**
  - L1173-1177: Delete set button -- `Image(systemName: "xmark.circle.fill")` with only `.font(AppText.caption)` sizing (~14pt visible, no frame expansion)
  - L1655: StatusDropdown dot -- `Circle().fill(color).frame(width: 6, height: 6)` (dot is decorative but the Menu wrapping it may have a small hit area)
  - L176: Completion dot -- `Circle()...frame(width: 5, height: 5)` (decorative, but if tappable by accident it's a problem)
- **Description:** The delete set button (`xmark.circle.fill`) renders at caption size (~14pt) with no explicit frame or contentShape expansion. The actual tap target is approximately 20x20pt, well below the 44pt minimum. Users with sweaty gym hands or motor impairment will struggle to hit this target. Per ux-foundations 7.2: *"Hit slop pattern: Visual icon may be 24x24, but the tap area extends to 44x44 via `.contentShape(Rectangle())` and frame expansion."*
- **Recommendation (v2):** Add `.frame(minWidth: 44, minHeight: 44)` + `.contentShape(Rectangle())` to the delete button. Also add `.accessibilityLabel("Delete set \(setNum)")`.

### F27 -- No Dynamic Type testing evidence; some fixed-size elements

- **Severity:** P1
- **Tractability:** needs-decision
- **Principle / checklist:** 7.1 Dynamic Type
- **Location:** Various -- L413 `width: 146`, L1199 `fixedWidth: 86`, L706 `width: 22, height: 1`
- **Description:** While most text uses `AppText.*` tokens (which scale with Dynamic Type), several layout elements use fixed widths (146pt exercise queue cards, 86pt reps field). At AX5 text size, the text will grow but the containers won't, causing truncation or overflow. The exercise queue strip's 146pt cards will truncate exercise names that are already single-line-limited.
- **Recommendation (v2):** Replace fixed widths with `minWidth` or make the horizontal scroll view use dynamic sizing. Test at AX5 before Phase 5 approval.

---

## Section F -- Motion findings

### F28 -- Raw `.easeInOut(duration: 0.2)` and `.easeInOut(duration: 0.25)` animations

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** 8.1 Animation principles, AppMotion.swift tokens
- **Locations:**
  - L66: `.animation(.spring(response: 0.35), value: restTimerEnd != nil)` -- floating timer entrance
  - L186: `withAnimation(.easeInOut(duration: 0.2))` -- week strip day switch
  - L637: `withAnimation(.easeInOut(duration: 0.2))` -- session picker switch
  - L809: `.animation(.easeInOut(duration: 0.25), value: status)` -- exercise row status change
  - L810: `.animation(.easeInOut(duration: 0.2), value: isFocused)` -- exercise row focus change
  - L1156: `withAnimation(.easeOut(duration: 0.1))` -- set flash green on
  - L1158: `withAnimation(.easeIn(duration: 0.25))` -- set flash green off
- **Description:** 7 raw animation literals instead of `AppSpring.*` / `AppEasing.*` / `AppDuration.*` tokens. These won't propagate if the motion design language is tuned globally.
- **Recommendation (v2):** Map each to tokens:
  - `.spring(response: 0.35)` -> `AppSpring.snappy` (response: 0.30, similar feel)
  - `.easeInOut(duration: 0.2)` -> `AppEasing.short` (easeInOut, 0.20s -- exact match)
  - `.easeInOut(duration: 0.25)` -> `AppEasing.short` or propose `AppEasing.medium` at 0.25s
  - `.easeOut(duration: 0.1)` -> `AppEasing.instant` (easeOut, 0.10s -- exact match)
  - `.easeIn(duration: 0.25)` -> `AppEasing.short` (0.20s, close enough)

### F29 -- Zero reduce-motion support on all 7 animations

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** 8.2 Reduce Motion
- **Location:** All 7 animation locations from F28, plus the `DispatchQueue.main.asyncAfter` delayed animation at L1157
- **Description:** None of the 7 animations check `@Environment(\.accessibilityReduceMotion)` or use the `motionSafe(_:value:)` modifier from `AppMotion.swift`. Users with reduce-motion enabled still see all transitions, spring bounces, and flash effects. Per ux-foundations 8.2: *"iOS users can enable 'Reduce Motion' system-wide. FitMe MUST respect this."*
- **Recommendation (v2):** Replace all `.animation(...)` modifiers with `.motionSafe(AppEasing.short, value: ...)`. Replace all `withAnimation(...)` calls with a helper that checks `UIAccessibility.isReduceMotionEnabled` and skips the animation. The `DispatchQueue.main.asyncAfter` pattern for the flash should be replaced with a `Task` that checks reduce-motion before animating.

### F30 -- Haptics are well-implemented (positive finding)

- **Severity:** -- (positive finding)
- **Location:** L373-383 (floating timer haptics at 10s and 0s), L1052 (set completion), L1791-1797 (session completion + PR), L2035 (Focus Mode set done)
- **Description:** Haptic patterns follow ux-foundations 3.3:
  - `.light` impact at 10s remaining (warning)
  - `.success` notification at 0s (timer done)
  - `.medium` impact on set completion (standard action)
  - `.success` notification on session completion
  - `.medium` impact on PR detection
  All generators call `.prepare()` before `.impactOccurred()`.
- **Recommendation (v2):** Preserve all haptic patterns. Consider wrapping in a `HapticService` if not already centralized, so haptics can be disabled in Settings.

---

## Section G -- Analytics findings

### F31 -- Zero analytics events in the entire file

- **Severity:** P0
- **Tractability:** auto-applicable
- **Principle / checklist:** Analytics naming convention (CLAUDE.md), screen tracking
- **Location:** Entire file -- `grep -c "analytics\|Analytics\|trackEvent\|logEvent" TrainingPlanView.swift` returns 0
- **Description:** The Training Plan screen is one of the four primary tabs and contains the core workout logging flow. There are zero analytics events. No screen view tracking, no exercise completion events, no set logging events, no rest timer usage, no focus mode engagement, no session completion tracking. This is a critical blind spot for understanding user behavior during workouts.

  Per the analytics naming convention in CLAUDE.md, all events on this screen must use the `training_` prefix. Missing events include:
  - `training_screen_viewed` -- screen appearance
  - `training_day_selected` -- week strip or session picker interaction
  - `training_exercise_focused` -- exercise queue or row tap
  - `training_set_logged` -- set completion with params (exercise_id, set_number, weight_kg, reps)
  - `training_set_copied` -- "Copy Last" usage
  - `training_rest_timer_started` -- rest timer activation
  - `training_rest_timer_completed` -- timer ran to 0
  - `training_focus_mode_entered` / `training_focus_mode_exited`
  - `training_session_completed` -- all exercises done
  - `training_pr_detected` -- personal record in completion sheet
  - `training_photo_captured` -- cardio photo taken/selected
  - `training_notes_logged` -- exercise or session notes entered
- **Recommendation (v2):** Add `.analyticsScreen(AnalyticsScreen.training)` to the root view body. Define all events in the Phase 1 PRD analytics spec and add them to `docs/product/analytics-taxonomy.csv` with `screen_scope: training`.

---

## Section H -- Composition / component findings

### F32 -- `SetRowView`, `CardioField`, `RPETapBar`, `StatusDropdown` should promote to shared components

- **Severity:** P2
- **Tractability:** needs-new-component
- **Principle / checklist:** Component reuse, design system governance
- **Location:**
  - `SetRowView` (L1115-1295) -- 180 lines, self-contained set logging row
  - `CardioField` (L1575-1601) -- generic labeled text field for numeric entry
  - `RPETapBar` (L1603-1640) -- discrete numeric selector (RPE 6-10)
  - `StatusDropdown` (L1642-1670) -- status menu with color-coded options
- **Description:** These are well-encapsulated components that would be useful across the app:
  - `CardioField` is a generic labeled numeric input that could be used in any data entry context (biometrics, nutrition manual entry)
  - `RPETapBar` is a discrete-value selector that could generalize to any bounded integer selection (pain scale, mood rating, difficulty)
  - `StatusDropdown` could apply to any multi-state entity (meal status, supplement status)
  - `SetRowView` is training-specific but could be useful in workout templates or history views
- **Recommendation (v2):** Promote `CardioField` to `AppComponents.swift` as `AppNumericField`. Promote `RPETapBar` to `AppComponents.swift` as `AppDiscreteSelector`. Keep `StatusDropdown` and `SetRowView` in the Training domain but extract to their own files.

### F33 -- `SessionCompletionSheet` + `MilestoneModal` are self-contained and should be separate files

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Architecture -- single responsibility
- **Location:** `SessionCompletionSheet` (L1676-1920, 244 lines), `MilestoneModal` (L2088-2134, 46 lines)
- **Description:** The completion sheet alone is 244 lines with its own helpers, stat computation, and milestone detection logic. It's a complete feature (session summary, PR detection, streak display, milestone celebration) embedded in the training plan file. The `MilestoneModal` is a reusable celebration component that could serve other features (nutrition milestones, consistency achievements).
- **Recommendation (v2):** Extract to `SessionCompletionSheet.swift` and `MilestoneModal.swift` (or promote `MilestoneModal` to `AppComponents.swift` as `AppCelebrationModal`).

### F34 -- `FocusModeView` is 90+ lines and a distinct feature

- **Severity:** P1
- **Tractability:** auto-applicable
- **Principle / checklist:** Architecture -- single responsibility
- **Location:** `FocusModeView` (L1950-2084, 134 lines)
- **Description:** Focus Mode is a full-screen experience with its own state management, input handling, and exit logic. It's conceptually a separate feature (distraction-free workout logging) that happens to be defined in the training plan file.
- **Recommendation (v2):** Extract to `FocusModeView.swift` in the Training v2 directory.

---

## Section I -- Priority-ordered action list

### P0 findings (must fix in v2 before ship):

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F1 | 2,135-line monolith, 13 types | Arch | Decompose into 7+ files | 1 day |
| F19 | Missing loading state | States | Add skeleton/loading check | 0.25 day |
| F20 | Missing error state | States | Add inline error banner for save failures | 0.5 day |
| F23 | ~12 a11y labels vs 50+ interactive elements | a11y | Label every interactive element | 1.5 days |
| F24 | Week strip days have no a11y labels + use onTapGesture | a11y | Convert to Buttons + add labels | 0.25 day |
| F26 | Delete button tap target ~20pt < 44pt minimum | a11y | Expand frame to 44pt + contentShape | 0.1 day |
| F29 | Zero reduce-motion support on 7 animations | Motion | Wrap all animations in motionSafe | 0.25 day |
| F31 | Zero analytics events in 2,135 lines | Analytics | Add screen tracking + 12 event types | 0.75 day |

**P0 total effort:** ~4.6 days

### P1 findings (should fix in v2):

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F2 | GeometryReader for floating timer | Arch | Replace with overlay + safe area | 0.25 day |
| F4 | Magic number 56 for tab bar | Arch | Propose AppSize.tabBarClearance token | 0.1 day |
| F5 | 17+ raw font literals | Tokens | Map to AppText.* tokens | 0.5 day |
| F6 | Raw Color.black in 3 places | Tokens | Replace with AppColor.Text.inversePrimary | 0.1 day |
| F7 | Raw .white in 5 places | Tokens | Replace with AppColor.Text.inversePrimary | 0.1 day |
| F8 | Raw padding(40) | Tokens | Replace with AppSpacing.xxLarge | 0.05 day |
| F10 | Raw padding(.leading, 14) x2 | Tokens | Use AppSpacing.xSmall or .small | 0.05 day |
| F11 | 11+ raw frame dimensions | Tokens | Map to AppSize.* or document | 0.25 day |
| F13 | Exercise queue cards < 44pt tap height | Principles | Increase vertical padding | 0.1 day |
| F14 | Session overview too many simultaneous actions | Principles | Progressive disclosure for rest timer | 0.5 day |
| F16 | No visual confirmation after set completion | Principles | Add persistent checkmark on completed sets | 0.25 day |
| F18 | Rest day lacks positive framing | Principles | Add recovery messaging | 0.1 day |
| F21 | Rest day empty state not designed | States | Add dedicated rest-day card | 0.25 day |
| F25 | Session type picker no a11y context | a11y | Add labels + values | 0.1 day |
| F27 | Fixed-width elements break Dynamic Type | a11y | Test at AX5, replace fixed widths | 0.5 day |
| F28 | 7 raw animation literals | Motion | Map to AppSpring/AppEasing tokens | 0.25 day |
| F33 | SessionCompletionSheet 244 lines in main file | Composition | Extract to own file | 0.1 day |
| F34 | FocusModeView 134 lines in main file | Composition | Extract to own file | 0.1 day |

**P1 total effort:** ~3.65 days

### P2 findings (nice-to-have, can defer):

| # | Finding | Section | Action | Effort |
|---|---|---|---|---|
| F3 | Private ExGroup struct inline | Arch | Move to helpers | 0.05 day |
| F9 | Raw padding(.vertical, 2) | Tokens | Replace with AppSpacing.micro | 0.05 day |
| F12 | Raw stroke lineWidths | Tokens | Propose border width tokens | 0.1 day |
| F15 | Completed exercises auto-expand fully | Principles | Collapse completed to summary | 0.5 day |
| F22 | Empty set log doesn't mention "Copy Last" | States | Update copy when prev data exists | 0.1 day |
| F32 | CardioField/RPETapBar should promote to shared | Composition | Extract to AppComponents.swift | 0.5 day |

**P2 total effort:** ~1.3 days

### Total estimated effort

**P0 + P1:** ~8.25 days (mandatory for v2 ship)
**P0 + P1 + P2:** ~9.55 days (ideal scope)

Recommend scoping v2 to **P0 + P1 only** (~8 days) with P2 items deferred to a v2.1 follow-up. This matches the Home v2 pattern.

---

## Section J -- Open questions for the user

These are the **needs-decision** findings that cannot be resolved auto-mechanically. The audit cannot move to Phase 1 (PRD addendum) until these are answered.

1. **F1 -- File decomposition strategy:** The proposed 7-file split (root, section block, lift panel, cardio panel, completion sheet, focus mode, shared components) -- is this the right granularity? Should Focus Mode be a separate feature with its own PRD, or stay bundled with Training Plan v2?

2. **F14 -- Session overview action density:** Should the rest timer stepper collapse by default and expand on tap? Or should it stay always-visible since it's used between every set?

3. **F15 -- Completed exercise expansion:** Should completed exercises collapse to a one-line summary, or stay fully expanded? Collapsing saves scroll distance but hides the set log (which users might want to reference for the next exercise's weight selection).

4. **F19/F20 -- Loading and error state scope:** How much investment in loading/error states for Training? The data store is local (fast loads, rare errors). Is a skeleton shimmer worth the effort, or is a simple spinner sufficient?

5. **F21/F18 -- Rest day experience:** Should rest days get a fully designed card with recovery content, or is the current minimal approach ("Active rest - walk, yoga, recover") sufficient? Could rest days link to a future Recovery feature?

6. **F27 -- Dynamic Type at AX5:** What's the strategy for the exercise queue strip at large text sizes? Options: (a) let cards grow and accept longer horizontal scroll, (b) switch to a vertical list at AX5, (c) keep fixed width and accept truncation.

7. **F31 -- Analytics event granularity:** Should we track every set logged (`training_set_logged` with weight/reps params), or only session-level events (`training_session_completed`)? Set-level tracking gives richer data but higher event volume.

---

## Next steps (if the audit is approved)

1. **Phase 0 -> Phase 1:** Write `prd.md` for training-plan v2 covering:
   - V2 scope summary (file decomposition + UX alignment)
   - Success metrics (primary: sets_logged_per_session, secondary: training_focus_mode_usage, guardrails: no regression in logging speed)
   - Analytics spec for all `training_*` events (per F31)
   - Kill criteria
2. **Phase 1 -> Phase 2:** Break P0 + P1 findings into implementable tasks with dependency graph
3. **Phase 2 -> Phase 3:** `/ux spec` -> `/design audit` (compliance gateway) -> `/ux prompt` + `/design prompt`
4. **Phase 3 -> Phase 4:** Create `FitTracker/Views/Training/v2/TrainingPlanView.swift` + extracted component files, update `project.pbxproj`, mark v1 historical
5. **Phase 5-8:** Test -> Review -> Merge -> Docs
