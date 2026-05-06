# Import Training Plan — UX/UI Pre-Flight Audit (2026-05-06)

> **Purpose:** Verify every token, component, and pattern referenced in [`ux-spec.md`](ux-spec.md) actually exists in the codebase **before** Phase 4 implementation begins. Surfaces gaps as P0 (must fix in spec), P1 (spec misuses scale), or P2 (pattern not present in app — needs deliberate invention or substitution).
>
> **Trigger:** User-ordered pre-Phase-4 review (2026-05-06). Surfaced as the canonical example justifying the new backlog task: ["**`/ux` + `/design` skills: pre-flight existence check before drafting specs**"](../../docs/product/backlog.md). Future `/ux spec` and `/design audit` invocations should produce this artifact automatically.
>
> **Method:** grep'd `FitTracker/Services/AppTheme.swift`, `FitTracker/DesignSystem/`, and `FitTracker/Views/` for every token/component/pattern named in the v2 ux-spec.

---

## 1. Tokens audit

### ✅ EXISTS — confirmed callable as written

| Token | Verified |
|---|---|
| `AppText.body / .caption / .callout / .button / .sectionTitle / .eyebrow / .monoCaption / .iconSmall / .subheading / .chip / .captionStrong` | `AppTheme.swift:234-264` |
| `AppRadius.xSmall (12) / .small (16) / .medium (20) / .large (24) / .button (20) / .card (16)` | `AppTheme.swift:158-165` |
| `AppColor.Status.success / .warning / .error` | `AppTheme.swift:73-75` |
| `AppColor.Surface.primary / .elevated / .materialStrong / .materialLight` | `AppTheme.swift:30-40` (verified) |
| `AppColor.Border.subtle` | `AppTheme.swift:59` |
| `AppColor.Accent.primary / .recovery / .achievement / .sleep` | `AppTheme.swift` (Settings v2 uses these) |
| `AppColor.Text.primary / .secondary / .tertiary / .inversePrimary` | `AppTheme.swift` |
| `AppSpacing.micro (2) / xxxSmall (4) / xxSmall (8) / xSmall (12) / small (16) / medium (20) / large (24)` | `AppTheme.swift:106-113` |
| `AppSize.ctaHeight (52) / tabBarClearance (56)` | `AppTheme.swift:191, 201` |
| `MotionSafe` modifier + `.motionSafe(_:value:)` extension | `DesignSystem/AppMotion.swift:62-79` |
| `AppEasing.short / .standard / .instant` | `DesignSystem/AppMotion.swift:44-51` |
| `AppDuration.short (0.20) / .standard (0.30)` | `DesignSystem/AppMotion.swift:8-21` |
| `AppSpring.snappy / .smooth / .stiff` | `DesignSystem/AppMotion.swift:24-41` |

### ❌ DOES NOT EXIST — spec referenced, must replace

| Spec referenced | Reality | Replacement |
|---|---|---|
| **`AppRadius.pill`** | Not defined. App's pill pattern uses `Capsule()` shape literal (per `SettingsView.swift:945`, `SettingsHomeViews.swift:111`, `AccountPanelView.swift:259`, `TrainingPlanView.swift:242`). | Use `Capsule()` shape directly: `.background(color, in: Capsule())` |
| **`AppMotion.standardEase`** | Not defined. Real container is `AppEasing` (not `AppMotion`); 200ms easing is `AppEasing.short`. | Use `AppEasing.short` for all 200ms cross-fades |

### ⚠️ Pattern semantic mismatch (P1)

| Spec usage | Real Settings v2 convention | Recommendation |
|---|---|---|
| Row title: `AppText.body` | `SettingsActionLabel` uses `AppText.button` (heavier weight, semibold) | Use `AppText.button` — visual consistency with rest of Settings v2 |
| Row subtitle: `AppText.caption` | `SettingsActionLabel` uses `AppText.subheading` (slightly larger) | Use `AppText.subheading` |
| Icon container: `36pt circle` (`Circle()`) | `SettingsActionLabel` uses `26pt × 26pt` `RoundedRectangle(cornerRadius: AppRadius.xSmall)` with `tint.opacity(0.14)` background | Mirror existing convention — 26pt rounded square, not 36pt circle. (Section card icons elsewhere also use this pattern.) |

---

## 2. Component constraint audit

### `SettingsActionLabel` is **fixed-trailing** — does not accept inline badges

Real signature ([`SettingsFormComponents.swift:12-50`](../../FitTracker/Views/Settings/v2/Components/SettingsFormComponents.swift#L12-L50)):

```swift
struct SettingsActionLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var trailing: SettingsActionTrailing = .chevron  // .chevron OR .progress only
}
```

**My UX spec** assumed I could put the ACTIVE pill inline between title and chevron. That's not possible without forking the component.

**Two honest paths:**

- **Path A (recommended):** Build a new bespoke row component `ImportedPlanRow` (file: `FitTracker/Views/Settings/v2/Components/ImportedPlanRow.swift`) that:
  - Mirrors `SettingsActionLabel` visual conventions (26pt icon square, `AppText.button` title, `AppText.subheading` subtitle, chevron trailing)
  - Adds a slot for the `Capsule()` ACTIVE pill, positioned between title and chevron
  - Reuses the same icon-square + tint pattern
  - Does NOT generalize — it's specific to imported-plan rows
  - Adds the new component to `docs/design-system/feature-memory.md` (per CLAUDE.md design-system evolution rule)
- **Path B (lower scope):** Use vanilla `SettingsActionLabel` and put "ACTIVE" as a prefix in the title or as a `.eyebrow` line above the title. Less visual polish but no new component.

**Recommendation:** Path A. The list-of-items pattern is genuinely new for Settings v2 (see §3) and warrants a real component. The new component remains scoped to this feature; future list-of-items features can adopt or extend it.

### `SettingsSectionCard` requires both `title` AND `eyebrow`

```swift
struct SettingsSectionCard<Content: View>: View {
    let title: String
    let eyebrow: String  // required, non-optional
    @ViewBuilder var content: Content
}
```

My spec assumed I could omit `eyebrow` for the list rows. Must provide both. For the empty state: `eyebrow: "Imports"`, `title: "No imported plans yet"`. For populated: `eyebrow: "Imports"`, `title: "Your imported plans"`.

---

## 3. Pattern presence audit

### ❌ `.swipeActions` NOT used anywhere in the app

`grep -rn "swipeActions" FitTracker/Views/` returns ZERO matches. My UX spec invokes swipe-trailing actions (Delete, Activate/Deactivate). This is a NEW pattern for the codebase.

**Decision needed:** invent the pattern (it's standard SwiftUI; `.swipeActions(edge: .trailing) { ... }`), OR replace with an alternative. Standard iOS Mail/Notes/Reminders idiom argues *for* keeping swipe — Jakob's Law. **Recommended:** keep, document as the first list-with-swipe-actions in the app, add it to `docs/design-system/feature-memory.md`.

### ❌ `.contextMenu` NOT used anywhere in Settings v2

`grep -rn "\.contextMenu" FitTracker/Views/Settings/v2/` returns ZERO matches. My UX spec invokes long-press → context menu (Rename / Activate / Deactivate / Delete).

**Decision needed:** invent OR drop. Long-press context menu provides redundancy for VoiceOver and gives users a non-swipe path. **Recommended:** keep — it's redundancy, not novelty (other parts of iOS have it; users expect it). Document as the first context-menu in Settings v2.

### ❌ Toast/Snackbar component does NOT exist

`grep -rnE "Snackbar|Toast" FitTracker/DesignSystem/ FitTracker/Views/` returns ZERO matches. The existing feedback pattern in import flow (`ImportSourcePickerView.statusView`, `ImportPreviewView` summary bar) is **inline `Label("...", systemImage: "checkmark.circle.fill")`** — not toast.

**My spec invoked a toast snackbar** for "Plan activated" / "Switched back to FitMe default". That's inventing a new component. **Recommended:** mirror the existing inline-Label pattern. After tap on Activate:

- The page already has an ACTIVE pill that animates in — that IS the feedback signal
- An inline confirmation `Label("Now active", systemImage: "checkmark.circle.fill")` could appear briefly above the toolbar as fade-in/fade-out (1.5s, `MotionSafe`-wrapped, `AppEasing.short`)
- For deactivate / delete: standard `.alert` flow with destructive role already provides the user dialog acknowledgement; no follow-up toast needed

This keeps the feature scope tight — no new toast component, no new motion category. Phase 2 polish can ship a real toast if needed for other features.

### ✅ Sheet pattern: both `.sheet(isPresented:)` and NavigationLink push are well-established

`TrainingPlanView` uses `.sheet(isPresented:)` for `showActivityPicker`, `showCompletionSheet`, `showFocusMode` — same pattern can host `showImportSheet`. NavigationLink push from a SettingsSectionCard (per `DataSyncSettingsScreen` line 86) is the canonical Settings v2 detail-screen entry. Both patterns are battle-tested.

---

## 4. Existing screen integration check

### Settings → Data & Sync → where does "Imported Plans" slot in?

Current `DataSyncSettingsScreen` order:

1. Sync Status (Sync Now + Fetch from iCloud)
2. Local Storage (counts)
3. Analytics (consent toggle)
4. **Data Portability** (Export My Data — NavigationLink → ExportDataView)
5. Danger Zone (Delete All Local Data)

Best slot for "Imported Plans": **between Local Storage (#2) and Analytics (#3)** — semantically a "your data" peer to logs/snapshots, not a portability action. Or alternatively **as a new section between Data Portability and Danger Zone**, framed as "Plans you've imported" — still inside the Data Portability mental model.

**Recommended:** new section between Data Portability and Danger Zone with `eyebrow: "Imports"`, `title: "Imported Training Plans"`, single `NavigationLink` to the list screen. Mirrors the Export My Data pattern visually.

### Training tab → toolbar + active-plan badge integration

Current `TrainingPlanView.toolbarContent` has ONE item: `.primaryAction` Focus Mode (eye.fill). My spec adds a second: `.primaryAction` Import (square.and.arrow.down).

- Risk: two `.primaryAction` items on the same toolbar lands them both on the right; which is "more primary"? iOS HIG says primary should be the most-used action. Focus mode is for in-workout users; import is for setup users. Different audiences.
- **Recommended:** put Import on `.topBarLeading` (top-left, navigation-natural for "configure my data") OR keep both on `.primaryAction` accepting that both will sit right.

For the **active-plan badge**: my spec says "above weekStrip". Looking at `TrainingPlanView` body order:

```
weekStrip
activitySwitcherCard
ScrollView { exerciseList }
```

Inserting before `weekStrip` puts the badge in the most-prominent position. This is correct — recognition over recall (Jakob/Norman) requires the active-plan signal to be persistently visible, not buried below the activity switcher.

### HISTORICAL files — current actual state vs spec assumptions

[`ImportSourcePickerView.swift:1-4`](../../FitTracker/Views/Import/ImportSourcePickerView.swift#L1-L4) HISTORICAL banner (4 lines) at top of file. Removal in T17 is straightforward.

[`ImportPreviewView.swift:1-2`](../../FitTracker/Views/Import/ImportPreviewView.swift#L1-L2) HISTORICAL banner (2 lines) at top. Removal in T17 straightforward.

The existing views' internal `body` is largely intact and reusable. My day-assignment-editor extension to `ImportPreviewView` will add a new section between the existing `summaryBar` and `dayCard ForEach`. Mode-switching between `.preview` and `.detail` will be conditional on the new `mode` enum.

### `ImportOrchestrator` integration — current persistence stub

[`ImportOrchestrator.swift:51-54`](../../FitTracker/Services/Import/ImportOrchestrator.swift#L51-L54) current state:

```swift
func confirmImport() {
    guard let plan = currentPlan else { return }
    state = .success(plan)
}
```

This is a no-op stub — `state = .success(plan)` is just a UI state change; nothing actually persists. T7 replaces this with a real persistence write to `EncryptedDataStore.importedTrainingPlans`. Confirms the v1 PRD's persistence claim was accurate at the type level but not the action level — the confirm function existed, it just didn't do anything.

---

## 5. Spec corrections (P0 + P1 — must apply before Phase 4)

| # | Change | Severity | Spec section |
|---|---|---|---|
| C1 | `AppRadius.pill` → `Capsule()` shape | P0 | Surface 1 row anatomy + Surface 2 ACTIVE pill |
| C2 | `AppMotion.standardEase` → `AppEasing.short` | P0 | All cross-fade animations (badge, border, status row) |
| C3 | List rows cannot use `SettingsActionLabel` for badge slot — need new `ImportedPlanRow` component | P0 | Surface 1 |
| C4 | `SettingsSectionCard` requires `eyebrow: String` (non-optional) | P0 | Surface 1 list-screen container |
| C5 | Title font for rows: `AppText.body` → `AppText.button` | P1 | Row anatomy |
| C6 | Subtitle font for rows: `AppText.caption` → `AppText.subheading` | P1 | Row anatomy |
| C7 | Icon container: `36pt circle` → `26pt × 26pt rounded square` (`AppRadius.xSmall` corner) with `tint.opacity(0.14)` | P1 | Row anatomy |
| C8 | Toast/snackbar feedback → inline `Label` badge fade (existing app pattern) OR rely on ACTIVE pill animation as the activation signal | P0 | Activate/Deactivate UX |
| C9 | Two `.primaryAction` toolbar items in TrainingPlanView — decide whether to move Import to `.topBarLeading` | P1 | Surface 3 / T16 |
| C10 | New patterns to add to `docs/design-system/feature-memory.md` upon Phase 4 land: `.swipeActions`, `.contextMenu`, `ImportedPlanRow` component | P0 | Phase 8 documentation |

## 6. Phase 4 task adjustments (none structural — all internal corrections)

Tasks T13 and T14 absorb the corrections internally:

- **T13** (`ImportedPlansListScreen`): also creates `ImportedPlanRow` as a new component file. Effort estimate stays 0.75d (the row component is part of the screen's natural scope).
- **T14** (`ImportPreviewView` extension): no scope change.
- **T11** (analytics constants): no scope change.
- **T16** (Training tab toolbar): may need a `.topBarLeading` placement decision; effort stays 0.25d.

A new sub-task is implicit but doesn't warrant a new T-ID:

- T13.1 (within T13): add `ImportedPlanRow` to `docs/design-system/feature-memory.md` per CLAUDE.md design-system evolution rule

---

## 7. Verdict

**APPROVED with corrections.** The structural architecture in the PRD + UX spec is sound. The corrections above are visual/component-naming alignments, not architectural rethinks. Phase 3 can advance to Phase 4 *after* the user reviews these corrections and approves them as a delta to the spec.

**Net effect on timeline:** zero. The corrections happen at code-write time, not at spec-write time. Phase 4 absorbs them as part of T13's scope.

**Net effect on case study:** one extra honest disclosure — "v2 ux-spec.md was drafted referencing 4 non-existent tokens/patterns; pre-flight audit caught them before Phase 4 began. Cost: 30 min audit; benefit: zero compile-error iterations during Phase 4." This is the canonical example for the new `/ux` + `/design` pre-flight gate framework task.

---

## 8. Lessons (for backlog framework task + future spec drafting)

1. **Specs that name tokens must reference the actual token file.** Going forward: every `/ux spec` should include a "Tokens & components used" appendix that grep's the codebase for each name. Surfaced as P0 if missing.
2. **Patterns absent from the app are inventions, not assumptions.** Swipe actions, context menus, toast/snackbar — three patterns my spec assumed without checking. The new framework task will gate on this.
3. **Component constraints matter as much as component existence.** `SettingsActionLabel` exists, but its trailing slot accepts only `.chevron` or `.progress` — not arbitrary content. Specs must verify *both* existence AND fit.
4. **The user's pre-flight check request was the right move.** Without it, Phase 4 would have started, hit "no such symbol" on `AppRadius.pill`, paused for diagnosis, and resumed with rework. The audit cost ~20 minutes; the rework would have cost ~2-4 hours plus a context-switch.
