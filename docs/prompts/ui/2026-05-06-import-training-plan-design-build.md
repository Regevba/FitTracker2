# Design Build Prompt: Import Training Plan (Phase 1 — persist + activate)

> **Generated:** 2026-05-06
> **Feature:** import-training-plan (resume Phase 1)
> **Source:** [`.claude/features/import-training-plan/ux-spec.md`](../../.claude/features/import-training-plan/ux-spec.md)
> **Companion:** [`2026-05-06-import-training-plan-ux-build.md`](2026-05-06-import-training-plan-ux-build.md) (the what-and-why)

---

## Visual specification

### Overall

- Three new surfaces. All consume the existing design system as-is — **no new tokens, no new components**
- Background on all surfaces: `AppGradient.screenBackground.ignoresSafeArea()` (matches Settings v2 + Training v2)
- Card containers: `SettingsSectionCard` (existing) for grouped content; standalone rows use `SettingsActionLabel` styling
- Card radius: `AppRadius.card`; pill radius: `AppRadius.pill`
- Spacing: `AppSpacing.medium` (16pt) horizontal margins, `AppSpacing.small` (8pt) vertical gaps between sub-elements, `AppSpacing.large` (24pt) between major sections
- Motion: `AppMotion.standardEase` for state crossfades; `MotionSafe` modifier for reduce-motion compliance

---

## Surface 1 — Imported Plans List screen

Location: `Settings → Data & Sync → Imported Plans` (NavigationLink target inside the new "Imported Plans" `SettingsSectionCard` row in `DataSyncSettingsScreen.swift`).

### Header (NavigationStack)

- Title: "Imported Plans" (large title, system-default for Settings v2 detail screens)
- Subtitle line via `SettingsDetailScaffold`: "All training plans you've imported from CSV, JSON, AI assistants, or coach docs."
- Toolbar `+` button on `.primaryAction` — system `Image(systemName: "plus")`, 44pt touch target, `AppColor.Accent.primary`

### Empty state

```
            ┌─────────────────────────────────┐
            │                                  │
            │       [icon 88pt, .tertiary]     │
            │   square.and.arrow.down.on.square │
            │                                  │
            │   No imported plans yet           │  ← AppText.sectionTitle
            │                                  │
            │   Bring training plans from Hevy, │  ← AppText.body, .secondary
            │   Strong, AI assistants, or       │
            │   coach docs.                     │
            │                                  │
            │   [  Import a plan  ]             │  ← AppSize.ctaHeight, AppColor.Accent.primary
            │                                  │
            └─────────────────────────────────┘
```

- Icon `square.and.arrow.down.on.square`, 88pt, `AppColor.Text.tertiary` at 0.6 opacity
- Title: `AppText.sectionTitle`, `AppColor.Text.primary`, centered
- Subtitle: `AppText.body`, `AppColor.Text.secondary`, max-width ~280pt, centered, 2-line wrap
- CTA: full-width primary button, `AppColor.Accent.primary` background, `AppColor.Text.inversePrimary` foreground, `AppRadius.button`

### Populated state — row anatomy

```
┌────────────────────────────────────────────────────────────────────┐
│  ┌─────┐  Plan Name                    [ACTIVE]                  ›  │
│  │ ⓘ   │  4 days · 32 exercises · 2 days ago · CSV                  │
│  └─────┘                                                            │
└────────────────────────────────────────────────────────────────────┘
```

- Leading icon circle: 36pt diameter, `AppColor.Accent.primary` at 0.15 opacity background, source-specific icon at 18pt:
  - CSV → `tablecells`
  - JSON → `curlybraces`
  - Markdown / Paste → `doc.text`
  - PDF → `doc.richtext`
  - Photo → `photo`
  - Share → `square.and.arrow.down`
- Title: plan name, `AppText.body`, `AppColor.Text.primary`, `lineLimit(1)`, truncating tail
- ACTIVE pill (only when `plan.isActive == true`):
  - Inline, right of title, before the chevron
  - Text: "ACTIVE", `AppText.monoCaption`, uppercase
  - Background: `AppColor.Status.success`
  - Foreground: `AppColor.Text.inversePrimary`
  - Padding: 6pt horizontal, 2pt vertical
  - Radius: `AppRadius.pill`
- Subtitle: `"{n} days · {n} exercises · {relativeDate} · {sourceLabel}"`, `AppText.caption`, `AppColor.Text.secondary`, `lineLimit(1)`
- Trailing chevron: `chevron.right`, 12pt, `AppColor.Text.tertiary`
- Active-row border: replaces default `Color.clear` with `AppColor.Status.success` 2pt stroke (cross-fade in/out 200ms)

### Section title row

When list is non-empty:

- "Your imported plans · {n}" — `AppText.eyebrow`, `AppColor.Text.tertiary`, top margin `AppSpacing.medium`

### Swipe-trailing actions per row

- Delete (destructive): system role `.destructive`, `trash` system icon, `AppColor.Status.error` background
- Activate (when inactive) OR Deactivate (when active): primary, `play.circle` system icon, `AppColor.Accent.primary` background

### Long-press / context menu

- Standard SwiftUI `.contextMenu`
- Items: Rename · Activate / Deactivate · Delete (destructive — divider above)

### Loading state (just-imported, persist in flight)

- New row visible at top of list with the parsed plan data
- Trailing element: `ProgressView()` system spinner instead of `chevron.right`
- Row tap disabled (`.disabled(true)` until `orchestrator.state == .success`)

---

## Surface 2 — ImportPreviewView day-assignment editor

Inserted between the existing plan-name field and the day-card list (visible in both `.preview` and `.detail` modes; rows are read-only in `.detail` if exercise mappings are frozen, but day assignment stays editable).

### Visual

```
Day Assignment                                ← AppText.sectionTitle
Map each imported day to your week            ← AppText.caption, .secondary

┌──────────────────────────────────────────────────────┐
│  Day 1 — Push                  [Upper Push (suggested)] ▽│
│  Day 2 — Legs                  [Lower Body (suggested)] ▽│
│  Day 3 — Pull                  [Upper Pull (suggested)] ▽│
│  Day 4 — Push                  [Upper Push (suggested)] ▽│   ← collision warning below
└──────────────────────────────────────────────────────┘

⚠ 2 days will share Upper Push. Both will appear when you   ← inline warning
  switch to that day in the Training tab.                     ← AppText.caption, AppColor.Status.warning
                                                                Background: AppColor.Status.warning at 0.10 opacity
                                                                Padding: AppSpacing.small. Radius: AppRadius.medium.
```

- Section uses `SettingsSectionCard` styling
- Each row: `HStack(spacing: AppSpacing.small)`, 44pt min height
- Original day name: `AppText.body`, `AppColor.Text.primary`
- Picker: `.menu` style on compact width class (iPhone SE), `.segmented` on regular
- Heuristic-suggested label: appended "(suggested)" in `AppColor.Text.tertiary` next to the option text
- Collision warning: rendered below the section card when 2+ assignments collide

---

## Surface 3 — ImportPreviewView in `.detail` mode

Same overall scaffold as `.preview` but with these visual deltas:

| Element | `.preview` | `.detail` |
| --- | --- | --- |
| Navigation title | "Preview Import" | Plan name (editable: tap to enter edit mode, Done resigns) |
| ACTIVE pill in nav bar | Hidden | Shown (next to title) when `plan.isActive == true`, with 200ms cross-fade on toggle |
| Plan name field (above day list) | Visible, editable | Hidden — title carries it |
| Day Assignment section | Editable picker per row | Editable picker per row (same component) |
| Day cards (exercise rows) | Tappable for mapping review | Read-only (mappings frozen at confirm time) |
| Toolbar | "Cancel" + "Confirm & Import" | `.primaryAction`: "Activate" or "Deactivate" toggle. Overflow menu (`ellipsis.circle`): "Delete" (destructive) |
| Bottom CTA | "Confirm & Import" full-width green | None |

### Activate/Deactivate toolbar button

- Icon: `play.circle` (when inactive, action=Activate) or `pause.circle` (when active, action=Deactivate)
- Color: `AppColor.Accent.primary`
- Tap → call `programStore.activate(...)` → toast appears at bottom

### Delete confirmation dialog

- `.alert("Delete '{plan name}'?", isPresented: ...)` with message: "This cannot be undone."
- Buttons: "Delete" (`.destructive`), "Cancel" (default)

### Toast (snackbar)

- Custom snackbar at the bottom (above tab bar safe area), 2.5s auto-dismiss
- Background: `AppColor.Surface.primary`
- Border: `AppColor.Status.success` 1pt (for activate) / `AppColor.Text.tertiary` (for deactivate / delete)
- Text: `AppText.callout`, `AppColor.Text.primary`
- Slide in from bottom 200ms `AppMotion.standardEase`; slide out same

---

## Surface 4 — Active-plan badge in Training tab

Inserted in `TrainingPlanView.swift` body, just inside the `VStack(spacing: 0)` and above `weekStrip`.

### Visual

```
┌───────────────────────────────────────────────────────────┐
│  📋  Following: My Strength Plan                       ›   │
└───────────────────────────────────────────────────────────┘
─────────────  weekStrip  ─────────────
```

- Container: `HStack(spacing: AppSpacing.small)`, 36pt height
- Padding: `.padding(.horizontal, AppSpacing.medium)`, `.padding(.vertical, AppSpacing.xSmall)`
- Background: `AppColor.Surface.primary`, no shadow, no border (subtle — does not compete with the activity switcher)
- Leading emoji "📋" (system rendering, no asset)
- "Following:" — `AppText.caption`, `AppColor.Text.secondary`
- Plan name — `AppText.caption`, `AppColor.Text.primary`, `lineLimit(1)`, truncating tail
- Trailing `chevron.right` — 10pt, `AppColor.Text.tertiary`
- Hidden entirely when `programStore.activePlanId == nil`
- Cross-fade in/out 200ms when active state toggles

---

## States summary

### Imported Plans List

| State | Empty | Populated, no active | Populated, active | Loading |
|---|---|---|---|---|
| Visible elements | icon + title + subtitle + CTA | section title + N rows | section title + N rows + ACTIVE pill on one row | section title + N rows incl. spinner row |
| Toolbar `+` | Yes | Yes | Yes | Yes |
| Background | screenBackground gradient | screenBackground gradient | screenBackground gradient | screenBackground gradient |

### ImportPreviewView (.preview mode)

Existing v1 success / error / partial states unchanged. Day-assignment editor always visible after parse.

### ImportPreviewView (.detail mode)

| State | Trigger | Visual |
|---|---|---|
| Inactive default | `plan.isActive == false` | No ACTIVE pill; toolbar shows Activate + overflow Delete |
| Active default | `plan.isActive == true` | ACTIVE pill in title row; toolbar shows Deactivate + overflow Delete |
| Renaming | User taps nav title | Standard SwiftUI editable nav title |
| Confirming delete | User taps Delete in overflow | `.alert` modal |

### Active-plan badge

| State | Trigger | Visual |
|---|---|---|
| Hidden | `activePlanId == nil` | Row not rendered |
| Visible | `activePlanId != nil` | 36pt status row above weekStrip |

---

## Tokens used (semantic only — zero raw literals)

### Colors

`AppColor.Accent.primary`, `AppColor.Status.success`, `AppColor.Status.error`, `AppColor.Status.warning`, `AppColor.Text.primary`, `AppColor.Text.secondary`, `AppColor.Text.tertiary`, `AppColor.Text.inversePrimary`, `AppColor.Surface.primary`

### Typography

`AppText.body`, `AppText.caption`, `AppText.callout`, `AppText.sectionTitle`, `AppText.eyebrow`, `AppText.monoCaption`

### Spacing

`AppSpacing.medium` (16pt), `AppSpacing.small` (8pt), `AppSpacing.xSmall`, `AppSpacing.micro`, `AppSpacing.large` (24pt)

### Radius

`AppRadius.card`, `AppRadius.button`, `AppRadius.medium`, `AppRadius.pill`

### Size

`AppSize.ctaHeight`

### Motion

`AppMotion.standardEase`

### Components reused

`SettingsDetailScaffold`, `SettingsSectionCard`, `SettingsActionLabel` (row layout reference), `MotionSafe` (animation wrapper)

### New tokens / components

**None.** This feature consumes the design system as-is.

---

## Compliance gateway expectations

When this lands, `make ui-audit` should report:

- 0 P0 findings against `ImportedPlansListScreen.swift` (new file)
- 0 P0 findings against the `ImportPreviewView.swift` extensions (mode enum + day editor)
- 0 P0 findings against the `TrainingPlanView.swift` toolbar + badge additions
- No new `DS-RAW-COLOR-*`, `DS-RAW-FONT-*`, or `DS-MAGIC-*` violations
- No new `DS-MISSING-ASSET` violations (no new colorsets needed)

`make tokens-check` should remain green (no token changes). `make ui-audit` baseline drift expected: +0 (or +1 for new file with no findings).

---

## Out of scope for design

- Phase 2: per-exercise mapping editor in `.detail` mode (mappings stay frozen at confirm)
- Phase 2: AI prompt regeneration UI
- Phase 2: CloudKit/Supabase sync indicator
- Phase 2: PDF / photo / share-extension import sources (icons reserved but flow not built)

## Definition of Done (design layer)

- All 4 list states render correctly with mock data on iPhone SE + iPhone 16 Pro
- ACTIVE pill cross-fade respects reduce-motion
- Picker style adapts to size class
- Empty-state CTA is centered both axes
- All swipe actions match iOS Mail/Notes/Reminders motion + color conventions
- Active-plan badge does not visually compete with the existing activity switcher
- All accessibility tags fire correctly under VoiceOver inspection
