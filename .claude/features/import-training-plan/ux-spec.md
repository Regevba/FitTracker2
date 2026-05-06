# Import Training Plan — UX Spec (v2 — extended 2026-05-06)

> Supersedes the 2026-04-15 v1 spec. v1 covered Picker + Preview only. v2 extends with the 3 new surfaces required by PRD v2: **Imported Plans List screen**, **day-assignment editor** (extension to ImportPreviewView), and the **active-plan badge** (wherever an imported plan is referenced).
>
> **PRD:** [`docs/product/prd/import-training-plan.md`](../../../docs/product/prd/import-training-plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Research:** [`research-persistence-2026-05-06.md`](research-persistence-2026-05-06.md)

## Carry-forward — v1 surfaces (unchanged)

### Import Source Picker (sheet — `ImportSourcePickerView.swift`)

4 options in a 2×2 grid:

- **Paste Text** (`doc.text` icon) — "Paste from AI chat, notes, or coach email"
- **Choose File** (`folder` icon) — "CSV, JSON, or text file"
- **Scan Document** (`doc.viewfinder` icon, P1) — "PDF or photo of a program"
- **Share from App** (`square.and.arrow.down` icon, P2) — "Hevy, Strong, Fitbod export"

Each option: 44pt icon in tinted circle + title (`AppText.callout`) + subtitle (`AppText.caption`). Tappable card with `AppRadius.card` corners. Cancel button in `.cancellationAction`.

### Paste Field View (within Picker)

- Large `TextEditor` (min 200pt height) with placeholder: "Paste your training plan here..."
- Supports: markdown tables, numbered lists, JSON, CSV, prose
- "Parse & Import" CTA at bottom (`AppSize.ctaHeight`, `AppColor.Accent.primary`)
- Example format hint below field (`AppText.caption`, collapsed by default)

### Import Preview View (`ImportPreviewView.swift` — `.preview` mode)

After parsing:

- **Plan name** field (editable, pre-filled from source — see §New: Day-Assignment Editor below for assignment row)
- **Day cards** in vertical scroll:
  - Header: "Day 1 — Push" (`AppText.sectionTitle`)
  - Exercise rows:
    - Green checkmark (✓) = auto-matched (confidence ≥ 0.95)
    - Orange pencil (✎) = needs review (0.70–0.94)
    - Red warning (⚠) = unmatched (< 0.70)
    - Each row: exercise name, mapped FitMe name, sets × reps, rest
- **Summary bar:** "{n} exercises, {matched} auto-matched, {review} need review"
- "Confirm & Import" CTA (green, full width)

### Exercise Mapping Review (sheet)

When tapping orange/red exercise:

- Search field at top (searches 87-exercise library)
- Top 5 suggested matches ranked by string similarity
- Each suggestion: exercise name + muscle groups + confidence %
- Tap to select → returns to preview with green check
- "Skip" option (keeps original name, creates note)

### Carry-forward states

- **Success:** "Plan imported! 🎉" + confetti animation + "{n} exercises mapped" + "Start Training" CTA
- **Error:** "Couldn't parse this format" + suggestions for reformatting + "Try Again" button
- **Partial:** "Imported with {n} unmatched exercises" + option to review or skip

---

## NEW v2 — Surface 1: Imported Plans List screen (`ImportedPlansListScreen.swift`)

Location: **Settings → Data & Sync → Imported Plans** (`SettingsSectionCard` row added under "Data Portability"). NavigationLink target. The list itself uses `SettingsDetailScaffold` for consistency with the rest of Settings v2.

### Anatomy (4 states)

#### State 1 — Empty state (no imported plans)

- Centered stack:
  - Icon `square.and.arrow.down.on.square` (~88pt, `AppColor.Text.tertiary`, semi-transparent)
  - Title: "No imported plans yet" (`AppText.sectionTitle`, `AppColor.Text.primary`)
  - Subtitle: "Bring training plans from Hevy, Strong, AI assistants, or coach docs." (`AppText.body`, `AppColor.Text.secondary`)
  - CTA: "Import a plan" — primary button (`AppSize.ctaHeight`, `AppColor.Accent.primary`)
- Tap CTA → presents `ImportSourcePickerView` as a sheet
- Toolbar: navbar `+` button in `.primaryAction` (mirrors the empty-state CTA — Fitts's Law for users who already understand the screen)

#### State 2 — List populated, no active plan

- Section title row: "Your imported plans · {n}"
- For each plan: a `SettingsActionLabel`-shaped row inside `SettingsSectionCard`:
  - Leading icon: source-specific (`doc.text` for paste, `tablecells` for CSV, `curlybraces` for JSON, etc.) inside a 36pt tinted circle (`AppColor.Accent.primary` at 0.15 opacity)
  - Title: plan name (`AppText.body`, `AppColor.Text.primary`)
  - Subtitle: "{n} days · {n} exercises · {relativeDate} · {sourceLabel}" (`AppText.caption`, `AppColor.Text.secondary`)
  - Trailing chevron (`chevron.right`, 12pt, `AppColor.Text.tertiary`)
  - Full row tap → push `ImportPreviewView` in `.detail` mode (Surface 2)
- Toolbar: `+` button → presents `ImportSourcePickerView` as sheet
- Swipe-trailing actions on each row:
  - **Delete** (destructive, `AppColor.Status.error`, `trash` icon)
  - **Activate** (primary, `AppColor.Accent.primary`, `play.circle` icon)
- Long-press / context menu (Apple HIG): Rename · Activate · Deactivate · Delete

#### State 3 — List populated, one plan active

- The active plan row gets:
  - "ACTIVE" pill badge to the right of the title (uppercase, `AppText.monoCaption`, `AppColor.Status.success` background, `AppColor.Text.inversePrimary` foreground, `AppRadius.pill`)
  - Border accent: `AppColor.Status.success` 2pt border (replaces the default card border)
- Swipe action shows **Deactivate** (where the inactive row shows Activate)

#### State 4 — Loading (after import → before persistToDisk completes)

- List remains visible; the new pending row shows a `ProgressView` spinner where the chevron normally is
- Disabled tap until persist completes (orchestrator state advances `.success`)

### Accessibility

- All rows: `accessibilityElement(children: .combine)` with combined label "{plan name}, {sourceLabel}, {n} days, {n} exercises, imported {relativeDate}{, active}"
- Swipe actions also exposed via VoiceOver `accessibilityCustomActions` (Apple HIG: swipe-only is a VoiceOver dead-end without this)
- Active badge has `accessibilityHint("Currently active training plan")`
- Empty-state CTA: 44pt × 280pt+ touch target (Fitts compliance)
- Dynamic Type: all text tokens are responsive; row min-height stays at 44pt minimum

### Motion

- Row tap → push detail view: standard NavigationStack transition (system, respects reduce-motion)
- Activate / deactivate: cross-fade the badge + border-color (200ms, `AppMotion.standardEase`)
- Delete: row slides out (200ms) then list reflows
- All animations use `MotionSafe` modifier per CLAUDE.md design system rule

---

## NEW v2 — Surface 2: ImportPreviewView in `.detail` mode + day-assignment editor

`ImportPreviewView.swift` is extended with a `mode` enum:

```swift
enum Mode {
    case preview(orchestrator: ImportOrchestrator)
    case detail(plan: ImportedTrainingPlan, dataStore: EncryptedDataStore)
}
```

### Carry-forward (`.preview` mode) — extended with day-assignment editor

The existing v1 preview gets one new section between the plan-name row and the day-card list: **"Day Assignment"**. This is the post-parse user step (per PRD §Persistence + Active-Plan Switching § Day-name → DayType heuristic):

- Section title: "Day Assignment" (`AppText.sectionTitle`)
- Eyebrow: "Map each imported day to your week" (`AppText.caption`, `AppColor.Text.secondary`)
- For each `ImportedDayAssignment`, a row:
  - Leading: `originalDayName` ("Day 1 — Push") — `AppText.body`
  - Trailing: a `Picker` (segmented or menu style) showing the heuristic-suggested `assignedDayType` with all 6 enum options (`Upper Push / Lower Body / Upper Pull / Full Body / Cardio / Rest`)
  - Heuristic-assigned default is highlighted with a small "(suggested)" tag in `AppColor.Text.tertiary`
- Collisions allowed: two imported days can both map to `.upperPush`. The screen surfaces collisions with an inline note: "2 days will share Upper Push. Both will appear when you switch to that day in the Training tab."

This editor satisfies PRD OQ-6: imported plans with day-count ≠ 6 use collision-allowed mapping; user has full control.

### NEW (`.detail` mode) — viewing a saved imported plan

Same overall layout as `.preview` but with these differences:

| Element | `.preview` mode | `.detail` mode |
| --- | --- | --- |
| Title | "Preview Import" | Plan name (editable inline tap → keyboard) |
| Plan name field | Above day list, prefilled from parser | Becomes the navigation title; tap-to-rename |
| Day Assignment section | Editable picker per day | Editable picker per day (same component) |
| Day cards | Editable | Read-only |
| Exercise mapping review sheet | Available on tap | Disabled (mappings frozen at confirm time; Phase 2 polish unlocks editing) |
| Toolbar | "Cancel" + "Confirm & Import" | "Activate" / "Deactivate" toggle (`.primaryAction`) + "Delete" (`.destructiveAction`, in overflow menu) |
| Bottom CTA | "Confirm & Import" (green, full width) | None (toolbar carries actions) |

### Activate/Deactivate UX

- **Activate** triggers `TrainingProgramStore.activate(planId:dataStore:)` → flips this plan's `isActive` to true, sets all others false, persists
  - Visual feedback: ACTIVE pill badge appears next to navigation title (200ms cross-fade)
  - Toast: "{plan name} is now your active training plan." (snackbar at bottom, 2.5s, dismissible)
  - Analytics: fires `import_plan_activated` with `was_first_activation: true` if no prior activation for this plan
- **Deactivate** sets `isActive: false`; falls back to bundled program in Training tab
  - Toast: "Switched back to FitMe's default plan."

### Accessibility

- Day-assignment picker: each row has `accessibilityLabel("{originalDayName}, currently assigned to {assignedDayType}")` and `accessibilityHint("Double-tap to change assignment")`
- Activate toolbar button: `accessibilityLabel("Activate this plan")` / inverted to "Deactivate this plan" when isActive
- Delete toolbar action: confirmation dialog (Apple HIG: destructive irreversible actions require confirmation) — "Delete '{plan name}'? This cannot be undone." → "Delete" (destructive) / "Cancel"
- Rename: standard navigation-title editable label (UIKit-equivalent NavigationStack pattern); auto-resigns on Done

### Motion

- Day-assignment picker: native iOS Picker (system motion)
- Activate/deactivate badge fade: 200ms `AppMotion.standardEase`
- Delete confirmation: standard `.alert` (no motion)
- Rename: navigation title typing animation (system)

---

## NEW v2 — Surface 3: Active-plan badge (Training tab)

When `programStore.activePlanId != nil` (i.e. an imported plan is the active program), the Training tab's existing `activitySwitcherCard` ([TrainingPlanView.swift:86](../../FitTracker/Views/Training/v2/TrainingPlanView.swift#L86)) gets a small status row at the top:

- "📋 Following: {plan name}" (`AppText.caption`, `AppColor.Text.secondary`)
- Tap → opens `ImportPreviewView` in `.detail` mode for that plan (deep-link convenience)
- Long-press → "Switch to FitMe default plan" action (deactivate)
- When `activePlanId == nil` (default state), this row is hidden — no impact on the bundled program flow

This badge solves the "user forgets which plan they're following" problem (Recognition over recall — Jakob/Norman heuristic).

### Accessibility

- Combined accessibility element: "Following imported plan: {plan name}. Double-tap to view; long-press for switch options."
- The badge does NOT replace any existing accessibility wiring on the Training tab; it adds one row above the activity switcher.

---

## UX Heuristic Self-Validation (Phase 3 / Step 3 — `/ux validate`)

Per `docs/design-system/ux-foundations.md` — the 13 principles from the project's UX foundations:

| Principle | Compliance | Notes |
|---|---|---|
| Fitts's Law (target size + distance) | ✅ | All tap targets ≥ 44pt; primary CTAs (`AppSize.ctaHeight`) span full row width; navbar `+` is in the natural top-right Fitts zone |
| Hick's Law (minimize choices) | ✅ | Source picker has 4 options (within Hick threshold); list rows have one primary tap + one swipe action set; no overflow menus that hide common actions |
| Jakob's Law (familiar patterns) | ✅ | List + swipe actions match iOS Mail/Notes/Reminders patterns; `+` toolbar button matches every other "create" pattern in iOS; activate/deactivate via `play.circle` matches Music app |
| Progressive disclosure | ✅ | Day-assignment editor surfaces complexity only at confirm time (after parse, when user is committed); `.detail` mode hides editing affordances that aren't yet wired |
| Recognition over recall | ✅ | Active-plan badge in Training tab solves "which plan am I on?"; ACTIVE pill in list view eliminates need to remember; source icons make plans visually distinct |
| Consistency (internal) | ✅ | Reuses `SettingsSectionCard`, `SettingsActionLabel`, `SettingsDetailScaffold` from the existing Settings v2 hub; matches the `ExportDataView` pattern on the same screen |
| Consistency (external / iOS) | ✅ | NavigationStack push/sheet idioms; standard swipe-trailing actions; system Picker for day-assignment |
| Feedback (every action gets a response) | ✅ | Spinner on persisting; toast on activate/deactivate; confetti on confirm; ACTIVE pill cross-fade |
| Error prevention | ✅ | Delete confirmation dialog (irreversible action gates); collision-allowed day mapping with inline warning; rename auto-validates non-empty |
| 44pt minimum touch targets | ✅ | All rows; CTAs ≥ 44pt; toolbar items native iOS sizing |
| WCAG AA contrast | ✅ | All text uses `AppColor.Text.*` semantic tokens which are AA-compliant by design system contract |
| Dynamic Type | ✅ | All `AppText.*` tokens are `@ScaledMetric`-backed |
| VoiceOver labels | ✅ | Every row has an accessibility label or `accessibilityElement(children: .combine)` with a coherent reading order |

**Heuristic verdict:** PASS — no unresolved P0 violations. One forward-looking note: the day-assignment picker for users with 4-day or 5-day imported plans may feel cramped on iPhone SE (small screen × 6 enum options × picker chrome). Mitigation: `.menu` style on small screens, segmented on regular. Phase 4 implementation choice.

---

## Design System Compliance Self-Audit (Phase 3 / Step 3 — `/design audit`)

Per `docs/design-system/feature-development-gateway.md` and CLAUDE.md design-system rules:

| Check | Status | Details |
|---|---|---|
| Token compliance | PASS | Every color/font/spacing/radius mapped to `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`. Zero raw hex/literal values. ACTIVE pill uses `AppColor.Status.success` / `AppColor.Text.inversePrimary` / `AppRadius.pill`. |
| Component reuse | PASS | List uses `SettingsSectionCard` + `SettingsActionLabel` + `SettingsDetailScaffold` (existing). Empty-state CTA uses standard primary-button pattern (see `ExportDataView`). Toolbar `+` is native `ToolbarItem`. Confirm dialogs use SwiftUI `.alert`. **No new components proposed.** |
| Pattern consistency | PASS | Settings → Data hub pattern (matches Account & Security, Health & Devices, Goals & Preferences, Training & Nutrition). NavigationStack push for detail (matches every other Settings sub-screen). Sheet for add (matches Account Security passkey-add flow). |
| Accessibility (a11y) | PASS | All listed in §UX Heuristic Self-Validation rows 10–13. |
| Motion | PASS | All animations specify `MotionSafe` modifier; durations from `AppMotion.standardEase`; system transitions otherwise. Reduce-motion observed via `@Environment(\.accessibilityReduceMotion)`. |
| New tokens proposed | NONE | No new tokens. |
| New components proposed | NONE | No new components. |
| Token-pipeline impact | NONE | `make tokens-check` should remain green. |
| `make ui-audit` impact | 0 P0 | All UI work uses semantic tokens; no DS-RAW-* violations expected; new files will pass DS-MISSING-ASSET (no new colorsets needed). |

**Compliance verdict:** PASS — no violations. No design-system evolution required for this feature. The feature consumes the design system as-is.

---

## V2 Refactor Checklist (per `docs/design-system/v2-refactor-checklist.md`)

The picker + preview were marked HISTORICAL in v1 audit; un-HISTORICAL'ing them is part of T17. The list view + day-assignment editor are NEW UI (no v1 to refactor against).

| Section | Applicable | Notes |
|---|---|---|
| A. Token compliance | ✅ | See above |
| B. Component reuse | ✅ | See above |
| C. State coverage | ✅ | All 4 list states (empty, populated-no-active, populated-with-active, loading) explicitly specified |
| D. Accessibility | ✅ | See above |
| E. Motion | ✅ | See above |
| F. Analytics | ✅ | All taps fire `import_plan_opened` (list row), `import_plan_activated` (activate action), `import_started` with `entry_point=settings_data` or `training_tab` |
| G. project.pbxproj hygiene | ✅ | `ImportedPlansListScreen.swift` will be added to Sources; existing extension to `ImportPreviewView.swift` doesn't need pbxproj changes |
| H. v1 → v2 file convention | N/A | Not a v2 refactor; new feature scope. (Picker + Preview existed pre-PM-workflow as HISTORICAL artifacts; they're being un-marked, not migrated to a `v2/` directory.) |

`state.json.phases.ux_or_integration.checklist_completed = true` will be set on Phase 3 approval.

---

## Phase 3 deliverables status

| Step | Output | Status |
|---|---|---|
| 3a (audit) | n/a (new UI scope, not v2 refactor; the structural research replaced this) | SKIPPED |
| 3b (research) | `research-persistence-2026-05-06.md` (already covers UX surfaces in §7) | DONE |
| 3c (spec) | This file (`ux-spec.md` v2) | DONE |
| 3d (validate) | §UX Heuristic Self-Validation above | DONE — verdict PASS |
| 3e (design audit) | §Design System Compliance Self-Audit above | DONE — verdict PASS |
| 3f (ux prompt) | `docs/prompts/2026-05-06-import-training-plan-ux-build.md` | NEXT |
| 3g (design prompt) | `docs/prompts/2026-05-06-import-training-plan-design-build.md` | NEXT |
| 3h (approval) | User approves Phase 3 → Phase 4 | PENDING |
