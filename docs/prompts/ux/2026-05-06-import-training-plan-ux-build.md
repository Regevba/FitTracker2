# UX Build Prompt: Import Training Plan (Phase 1 — persist + activate)

> **Generated:** 2026-05-06
> **Feature:** import-training-plan (resume Phase 1)
> **Source:** [`.claude/features/import-training-plan/ux-spec.md`](../../.claude/features/import-training-plan/ux-spec.md)
> **PRD:** [`docs/product/prd/import-training-plan.md`](../product/prd/import-training-plan.md)
> **Branch:** `feature/import-training-plan-resume`

---

## What to build

Three new UX surfaces + small wiring:

1. **`ImportedPlansListScreen.swift`** at `FitTracker/Views/Settings/v2/Screens/`. Settings → Data → Imported Plans hub. 4 states (empty, populated-no-active, populated-with-active, loading).
2. **Day-Assignment Editor** — extend `ImportPreviewView.swift` with a "Day Assignment" section between the plan-name field and the day-card list. One row per imported day; each row shows the parser-output day name + a Picker for the 6 `DayType` enum values, with a heuristic-suggested default highlighted as "(suggested)".
3. **Active-plan badge in Training tab** — extend `TrainingPlanView.swift` with a status row above the existing `activitySwitcherCard`: "📋 Following: {plan name}" (`AppText.caption`). Visible only when `programStore.activePlanId != nil`. Tap → push `ImportPreviewView` in `.detail` mode. Long-press → "Switch to FitMe default plan" action.

Plus `ImportPreviewView` gets a `mode` enum (`.preview` / `.detail`). `.detail` mode adds: editable navigation title (rename), Activate/Deactivate toolbar action, Delete (destructive, with confirm dialog), no Confirm CTA.

## Why

PRD v2 architecture: imported plans persist via `EncryptedDataStore.importedTrainingPlans`; `TrainingProgramStore.activePlanId: UUID?` is the routing flag for the Training tab read fan-out. The list screen is the user-facing surface for "I imported a plan, now what?" — without it, `import_plan_opened` and `import_plan_activated` analytics signals are unreachable. Without the day-assignment editor, the heuristic day-name → `DayType` mapping has no override path. Without the active-plan badge, the user has no recognition signal for "which plan am I following right now?" (Jakob/Norman heuristic).

## Stack order — Imported Plans List screen (top to bottom)

1. **Navigation title:** "Imported Plans"
2. **Toolbar:** `+` button in `.primaryAction` → presents `ImportSourcePickerView` as sheet
3. **Body:** `SettingsDetailScaffold` with one `SettingsSectionCard`
   - **Empty state:** centered icon (`square.and.arrow.down.on.square`, 88pt, `AppColor.Text.tertiary` semi-transparent) + title "No imported plans yet" + subtitle "Bring training plans from Hevy, Strong, AI assistants, or coach docs." + "Import a plan" primary CTA (`AppSize.ctaHeight`, `AppColor.Accent.primary`)
   - **Populated state:** section-title row "Your imported plans · {n}" + one row per plan
4. **Plan row layout** (each):
   - Leading: 36pt source-icon circle (`AppColor.Accent.primary` at 0.15 opacity)
   - Title: plan name (`AppText.body`, `AppColor.Text.primary`)
   - Inline pill (only for active): "ACTIVE" (uppercase, `AppText.monoCaption`, `AppColor.Status.success` background, `AppColor.Text.inversePrimary` foreground, `AppRadius.pill`)
   - Subtitle: "{n} days · {n} exercises · {relativeDate} · {sourceLabel}"
   - Trailing: `chevron.right` (12pt, `AppColor.Text.tertiary`)
   - Active row gets a 2pt `AppColor.Status.success` border replacing the default
5. **Swipe-trailing actions per row:** Delete (destructive, `trash`, `AppColor.Status.error`) + Activate or Deactivate (primary, `play.circle`, `AppColor.Accent.primary`)
6. **Context menu / long press:** Rename · Activate / Deactivate · Delete

## Key behaviors

- Tap row → `NavigationLink` push to `ImportPreviewView(mode: .detail(plan: plan, dataStore: dataStore))`
- Tap `+` toolbar button OR Tap "Import a plan" CTA in empty state → `.sheet` of `ImportSourcePickerView`
- Activate action: call `programStore.activate(planId: plan.id, dataStore: dataStore)` → toast "{plan name} is now your active training plan." (snackbar, 2.5s)
- Deactivate action: call `programStore.activate(planId: nil, dataStore: dataStore)` → toast "Switched back to FitMe's default plan."
- Delete: `.alert("Delete '{plan name}'? This cannot be undone.", role: .destructive)` → on confirm: remove from `dataStore.importedTrainingPlans`; if it was active, also clear `programStore.activePlanId`; persist
- After persist completes (success): refresh list ordering by `lastModified` desc

## Day-Assignment Editor (extension to ImportPreviewView .preview mode)

Insert between plan-name field and day-card list:

- Section title: "Day Assignment" (`AppText.sectionTitle`)
- Eyebrow: "Map each imported day to your week" (`AppText.caption`, `AppColor.Text.secondary`)
- For each `ImportedDayAssignment` in the imported plan:
  - Row: original day name (`AppText.body`) + trailing Picker
  - Picker style: `.menu` on iPhone SE (compact), `.segmented` on regular width — switch via `@Environment(\.horizontalSizeClass)`
  - Picker options: 6 `DayType` enum values + display labels ("Upper Push", "Lower Body", "Upper Pull", "Full Body", "Cardio", "Rest")
  - Heuristic-default has small "(suggested)" tag in `AppColor.Text.tertiary` next to the option label
- Collision banner (when 2+ imported days map to the same `DayType`): inline note "{n} days will share {DayType.label}. Both will appear when you switch to that day in the Training tab." in `AppColor.Status.warning` 0.10 opacity background

## Active-plan badge (Training tab insertion)

In `TrainingPlanView.swift`, just inside the existing `VStack(spacing: 0)` body, above the `weekStrip`:

- A `HStack` (only rendered when `programStore.activePlanId != nil`):
  - "📋 Following:" label in `AppText.caption`, `AppColor.Text.secondary`
  - Plan name (looked up via `dataStore.importedTrainingPlans.first(where: { $0.isActive })?.name ?? ""`) in `AppText.caption`, `AppColor.Text.primary`
  - Trailing `chevron.right` (10pt, `AppColor.Text.tertiary`)
- Tap → push `ImportPreviewView(mode: .detail(plan: plan, dataStore: dataStore))` via the existing `NavigationStack` on the Training tab
- Long-press → ContextMenu with single action "Switch to FitMe default plan" → calls `programStore.activate(planId: nil, dataStore: dataStore)`
- Background: `AppColor.Surface.primary` thin row, 36pt height, `.padding(.horizontal, AppSpacing.medium)`

## States to cover (per surface)

### Imported Plans List

| State | Trigger | Visual |
|---|---|---|
| Empty | `dataStore.importedTrainingPlans.isEmpty` | Centered icon + title + subtitle + "Import a plan" CTA |
| Populated, no active | Plans exist, none has `isActive: true` | List rows, no ACTIVE badge anywhere |
| Populated, active | One plan has `isActive: true` | That row gets ACTIVE pill + green border accent |
| Loading | Just-imported plan, `persistToDisk()` in flight | New row visible with spinner where chevron normally is |

### ImportPreviewView (.preview mode — extended)

Existing v1 states (Success / Error / Partial) carry forward unchanged. Day-assignment editor is always visible after parse.

### ImportPreviewView (.detail mode — new)

| State | Trigger | Visual |
|---|---|---|
| Default (active) | `plan.isActive == true` | ACTIVE pill in nav title row; toolbar shows Deactivate + Delete |
| Default (inactive) | `plan.isActive == false` | No pill; toolbar shows Activate + Delete |
| Renaming | User taps nav title | Standard SwiftUI editable nav title; auto-saves on Done |
| Confirming delete | User taps Delete | `.alert(...)` with destructive Confirm + Cancel |

### Training tab badge

| State | Trigger | Visual |
|---|---|---|
| Hidden | `programStore.activePlanId == nil` | No row rendered |
| Visible | `programStore.activePlanId != nil` | Status row above `weekStrip` |

## Accessibility

- All rows: `accessibilityElement(children: .combine)` with combined label including plan name, source, day/exercise counts, relative date, active/inactive
- Swipe actions also exposed via `accessibilityCustomActions` (VoiceOver dead-end mitigation)
- ACTIVE pill: `accessibilityHint("Currently active training plan")`
- Day-assignment picker: each row labeled "{originalDayName}, currently assigned to {assignedDayType}"; hint "Double-tap to change assignment"
- Delete: confirmation dialog (Apple HIG mandate for irreversible actions)
- Active-plan badge: combined element "Following imported plan: {plan name}. Double-tap to view; long-press for switch options."

## Motion

- Row tap → push detail: standard `NavigationStack` (system; respects reduce-motion)
- Activate/deactivate: 200ms `AppMotion.standardEase` cross-fade on the ACTIVE pill + border color
- Delete: row slides out 200ms then list reflows
- All wraps: `MotionSafe` modifier per CLAUDE.md design-system rule
- Reduce-motion observed via `@Environment(\.accessibilityReduceMotion)` for all custom transitions

## Analytics events to fire

- `import_started` — `entry_point: "settings_data"` on list-screen `+` tap or empty CTA tap; `entry_point: "training_tab"` on Training-tab toolbar tap
- `import_plan_opened` — list-row tap (parameters: `days_since_import`, `source`)
- `import_plan_activated` — successful activate (parameters: `source`, `days_since_import`, `was_first_activation: bool`)
- All wired through `analytics.log{Event}(...)` calls; never directly to the provider — consent gate must apply

## Tokens, components, files

| Layer | What |
|---|---|
| Tokens | `AppColor.Accent.primary`, `AppColor.Status.success / .error / .warning`, `AppColor.Text.primary / .secondary / .tertiary / .inversePrimary`, `AppColor.Surface.primary`, `AppText.body / .caption / .sectionTitle / .monoCaption`, `AppSpacing.medium / .small / .micro`, `AppRadius.card / .pill / .medium`, `AppMotion.standardEase`, `AppSize.ctaHeight` |
| Components reused | `SettingsDetailScaffold`, `SettingsSectionCard`, `SettingsActionLabel` (in list rows), `MotionSafe` |
| New components | None |
| New files | `FitTracker/Views/Settings/v2/Screens/ImportedPlansListScreen.swift`, `FitTracker/Models/ImportedTrainingPlan.swift` (model only, separate from UI but listed here for completeness) |
| Extended files | `FitTracker/Views/Import/ImportPreviewView.swift` (mode enum + day-assignment editor + .detail mode toolbar), `FitTracker/Views/Settings/v2/Screens/DataSyncSettingsScreen.swift` (NavigationLink to list), `FitTracker/Views/Training/v2/TrainingPlanView.swift` (toolbar button + active-plan badge) |

## Out of scope (defer to Phase 2)

- Per-day editor for unmapped exercises (Phase 1 surfaces unmapped via warning + raw name)
- AI prompt regeneration UI
- CloudKit/Supabase sync
- PDF/photo/share-extension import sources

## Definition of Done (per UX surface)

- All 4 list states render correctly with mock data
- Day-assignment editor: Picker style adapts to size class (menu on compact, segmented on regular)
- Active-plan badge appears/disappears in real time as `programStore.activePlanId` changes
- All 9 analytics events fire at the right call sites with the right parameters
- All accessibility labels + hints + custom actions in place
- `make ui-audit` reports 0 P0 against new files
- Reduce-motion alternative exists for all custom transitions
