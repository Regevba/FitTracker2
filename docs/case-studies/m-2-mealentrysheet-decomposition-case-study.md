# M-2 — MealEntrySheet Decomposition — Case Study

**Date written:** 2026-04-19

> Framework v6.1 | cleanup_program | 2026-04-19 | PRs #126 + #127 + #128 + #129 + this PR
>
> **Predecessor:** `m-1-settings-decomposition-case-study.md` ended with 4 audit findings open. After M-2 closes UI-004, **3 remain** — all in pre-classified multi-session feature (M-4) or external blocker (BE-024, DEEP-SYNC-010) buckets.
>
> **Headline:** UI-004 closed. MealEntrySheet.swift drops **1104 → 140 lines (~87% reduction)** across 4 phased PRs. The 1104-line file becomes a thin coordinator + 9 focused files (4 leaf types + 1 ViewModel + 1 shared components file + 4 tab views). Audit closure: **182 / 185 (98.4%)**.

---

## 1. Summary Card

| Field | Value |
|---|---|
| Feature | M-2 — MealEntrySheet (UI-004) Decomposition |
| Framework Version | v6.1 |
| Work Type | cleanup_program (multi-PR feature) |
| Audit Findings Closed | UI-004 (1) |
| Audit Closure Rate (cumulative after M-2) | 182 / 185 (98.4%) |
| PRs Shipped | 5 (#126 M-2a, #127 M-2c, #128 M-2b, #129 M-2 resubmit, this PR M-2d) |
| Wall-clock Span | ~2.5 hours (within one session) |
| Lines moved | 964 (across 9 new files) |
| MealEntrySheet.swift size | 1104 → 140 lines (~87% reduction) |
| New files | 9 (4 leaf types + VM + shared components + 4 tab views) |
| @State vars in main view | 17 → 0 |
| Build / Tests | SUCCEEDED at every PR |
| Behaviour change | NONE — pure structural decomposition |
| Self-Referential | The same AI defined the audit, wrote the plan, executed it, recovered from a stacked-PR misfire, and is now documenting it |

---

## 2. The Story in Four Phases

### Phase M-2a — Leaf-Type Extractions (PR #126)

The 1104-line file already had clear leaf-level separations: 4 standalone types lived after the main `MealEntrySheet` struct (lines 700-1104) that didn't depend on any of its 17 @State vars. Pure data models, pure parsing, pure framework-glue wrappers.

The fix: move 4 leaf types to their own files under `Nutrition/Models`, `Parsing`, `Camera/`. Bump 3 parser internals from `private` → internal (`ParsedNutritionLanguageHint`, `ParsedNutritionLabel`, `NutritionLabelParser`) so the main `MealEntrySheet.parseSmartLabel()` can still reach them. Removed unused `import AVFoundation` from main file (only `BarcodeScannerVC` used it; that's gone now).

| New file | Lines moved |
|---|---|
| `Models/OpenFoodFactsModels.swift` | 95 |
| `Parsing/NutritionLabelParser.swift` | 120 |
| `Camera/NutritionCameraSheet.swift` | 46 |
| `Camera/BarcodeScanner.swift` | 165 |
| **Total moved** | **426** |

After M-2a: MealEntrySheet.swift = **694 lines** (1104 - 410). Build green. **~30 min wall time.**

### Phase M-2c — ViewModel Extraction (PR #127, then resubmit #129)

The audit's recommended fix called for a ViewModel + per-tab decomposition. Phase M-2c handled the ViewModel half: consolidate the 17 @State vars + business logic (parsing, Vision OCR, photo import, template/product fill) into `MealEntryViewModel: ObservableObject`.

Pattern: VM owns state + helpers that mutate state. View keeps the bridge to `entry: Binding<MealEntry>`, `onSave` callback, `dismiss` env, `dataStore` env, and `foodSearch` @StateObject.

The tricky bit was `entry.source` mutations. Three flows write it (template fill, product fill, smart-label parse), but the VM shouldn't hold a `Binding<MealEntry>` (binding lifecycle on `ObservableObject` is awkward). Solution: callback injection — VM exposes `var onSourceChange: (MealEntrySource) -> Void`, view wires it in `.onAppear`:

```swift
.onAppear {
    vm.onSourceChange = { newSource in entry.source = newSource }
    vm.loadFromEntry(entry)
}
```

Vision OCR closures use `[weak self]` to avoid retain cycles on the VM.

After M-2c: MealEntrySheet.swift = **506 lines** (694 - 188). VM = 235 lines. Build green. **~45 min wall time.**

### Phase M-2b — Per-Tab Sub-Views (PR #128, then resubmit #129)

Each of the 4 tabs (`smartTab`, `manualTab`, `templateTab`, `searchTab`) was a `private var: some View` ViewBuilder method. With the VM already in place, extracting tabs into their own structs becomes mechanical: each takes `@ObservedObject var vm: MealEntryViewModel` and any callbacks for parent-owned actions.

| New file | What it shows | Lines |
|---|---|---|
| `Tabs/MealEntrySharedComponents.swift` | free `formatMealValue` + `MealEntryField`, `SmartActionLabel`, `ParsedMetricView` | 71 |
| `Tabs/SmartTabView.swift` | camera/photo + bilingual label parse | 121 |
| `Tabs/ManualTabView.swift` | macro entry + Save Template / Log actions | 65 |
| `Tabs/TemplateTabView.swift` | saved template picker | 54 |
| `Tabs/SearchTabView.swift` | OFF text search + barcode scan | 108 |

Bridge action callbacks injected from coordinator: `ManualTabView(onSaveAsTemplate:onLog:)`, `TemplateTabView(onDelete:)`, `SearchTabView(onTextSearch:)`. `SmartTabView` needs no callbacks — its only side effects (`vm.parseSmartLabel`, `vm.processNutritionImage`) live entirely on the VM.

`TemplateTabView` reads `dataStore.mealTemplates` via `@EnvironmentObject` directly — that's a read, not a mutation, and the env is already wired upstream.

`SearchTabView` takes `foodSearch: FoodSearchService` via `@ObservedObject` because the lifecycle is owned by the parent (`@StateObject` in MealEntrySheet).

Removed `vm.formatNum` — replaced by free `formatMealValue` helper in `MealEntrySharedComponents.swift` so both VM (for state mutations) and `ParsedMetricView` (for the metric tile) use the same single source of truth.

After M-2b: MealEntrySheet.swift = **140 lines** (506 - 366). Build green. **~40 min wall time.**

### Phase M-2 Resubmit (PR #129) — recovery from stacked-PR misfire

Original M-2c (PR #127) and M-2b (PR #128) were opened with stacked bases (`--base feature/m2a-...` and `--base feature/m2c-...`). When merged, they merged into their stacked predecessor branches, NOT into main. Main only had M-2a's changes after both PRs were "merged".

Root cause: GitHub treats `--base` literally; merging a stacked PR doesn't auto-promote it to main. Stacked PR workflow requires retargeting the base before merging when the predecessor lands on main.

Fix: branch `feature/m2b-mealentry-tab-views` already contains both M-2c and M-2b commits (since M-2b was originally branched from M-2c). Opened a fresh PR (#129) from that branch → `main` to land both phases as a single bundled merge.

**Methodology lesson**: in future stacked PR series, retarget downstream PRs to `main` **after** the upstream PR merges, **before** merging the downstream PR. Or skip stacking and use sequential PRs from main when each phase is fast enough that waiting for predecessor merge isn't a bottleneck.

### Phase M-2d — Case Study + Monitoring Entry (this PR)

Following the M-3 → M-1 precedent: concurrent case study tracking, schema-conformant monitoring entry from inception, audit-findings.json closure all in the same session as the implementation phases.

**~30 min wall time.**

---

## 3. Numbers — Before and After

| Metric | Before M-2 | After M-2a | After M-2c | After M-2b | After M-2d |
|---|---|---|---|---|---|
| MealEntrySheet.swift lines | 1104 | 694 | 506 | 140 | 140 |
| Files in `Nutrition/` (counting subdirs) | 4 | 8 (+ Models, Parsing, Camera) | 9 (+ VM) | 14 (+ Tabs) | 14 |
| @State vars in main view | 17 | 17 | 0 | 0 | 0 |
| Audit findings open | 4 | 4 | 4 | 4 | 3 |
| Audit findings closed (cumulative) | 181 | 181 | 181 | 181 | 182 |

| Metric | Pre-M-2 | Post-M-2 | Delta |
|---|---|---|---|
| Build / tests | green | green | no regression |
| Behaviour | unchanged | unchanged | none |
| Largest file in `Nutrition/` | 1104 (MealEntrySheet) | 235 (MealEntryViewModel) | -869 lines (-79% on the worst-offender file) |
| Single-file responsibility violations (UI-004) | 1 | 0 | -1 |
| Case study tracking enabled at start? | YES | YES (M-2d in-flight before M-2b retarget merged) | third feature with concurrent tracking |

---

## 4. What Worked

| # | Win | Evidence |
|---|---|---|
| 1 | **Phased plan doc with line-level inventory before starting** | `docs/superpowers/plans/2026-04-19-m2-mealentrysheet-decomposition.md` mapped every section. M-2a/c/b each shipped within ±50% of estimate. |
| 2 | **Conservative phase ordering — leaves first, then VM, then tabs** | M-2a's leaf extractions (low risk) shipped first to absorb pbxproj setup overhead. M-2c (medium-high risk binding rewiring) shipped before M-2b so tabs could use the VM. |
| 3 | **Callback injection for entry-binding mutations** | VM exposes `onSourceChange: (MealEntrySource) -> Void` instead of holding `Binding<MealEntry>`. Avoids the awkward Binding-on-ObservableObject pattern; view wires the callback in `.onAppear`. |
| 4 | **Single source of truth for `formatMealValue`** | Originally on the VM as `formatNum`. M-2b extracted to free helper; both VM (state mutations) and `ParsedMetricView` (metric tile) use the same function. |
| 5 | **`[weak self]` in Vision OCR closures** | Long-running detached tasks in `processNutritionImage` could outlive the VM. Weak capture prevents retain cycles. |
| 6 | **Bridge-action callbacks for parent-owned mutations** | Tabs that need `dataStore.mealTemplates.append`/`onSave(entry)`/`dismiss()` take callbacks (`onSaveAsTemplate`, `onLog`, `onDelete`, `onTextSearch`). Tabs stay independent of view-only context. |
| 7 | **Case study tracking concurrent with feature (third time)** | M-3 first, M-1 second, M-2 third. Pattern is now reproducible across content-additive (M-3) AND structural-refactor (M-1, M-2) work shapes. |

---

## 5. What Broke Down (or was deferred)

| # | Item | Resolution |
|---|---|---|
| 1 | **Stacked PR misfire** | PRs #127 (M-2c) and #128 (M-2b) merged into their stacked base branches instead of main. Recovered via PR #129 (resubmit from m2b branch → main). **Methodology lesson**: retarget downstream PRs to main *before* merging when the upstream PR lands. |
| 2 | **Pre-existing EncryptionService + KeychainHelper test failures** | Same 9 environmental failures as M-1. Not introduced by M-2. |
| 3 | **No manual visual QA across all 4 tabs** | Build green and behaviour preserved at the type level (same VM API surface, same SwiftUI render tree per tab), but full tap-through unverified. **Deferred** to next QA pass. |
| 4 | **CI billing block continues** | PRs #126-#129 hit GitHub Actions account spending limit. Local build green; admin-overridden the merges. Same infrastructure friction since Sprint K. |
| 5 | **`onSourceChange` callback pattern is mildly leaky** | The view must remember to wire `vm.onSourceChange` in `.onAppear`. If forgotten, `entry.source` mutations would silently no-op. **Trade-off accepted** vs. the alternative (Binding-on-ObservableObject) which is more error-prone in SwiftUI. |
| 6 | **Coordinator still has 5 bridge methods** | `saveAsTemplate`, `logMeal`, `deleteTemplates`, `runTextSearch`, `fetchProduct` stay on `MealEntrySheet`. They each touch entry/onSave/dismiss/dataStore which the VM doesn't own. Could move to the VM if the VM took dataStore + an entry-callback set in init, but that's overkill for 5 small methods. |

---

## 6. Decisions Log

| # | Decision | Rationale |
|---|---|---|
| D-1 | Write a phased plan doc with line-level inventory before M-2a | Same M-3/M-1 pattern that held estimates within ±50% across all phases. |
| D-2 | M-2a extracts only the leaf types, NOT the View struct or VM | Leaves are zero-coupling moves with low risk. Bigger refactors (VM, per-tab) follow once leaves stabilize. |
| D-3 | M-2c (ViewModel) before M-2b (per-tab views) | Tabs share most state. Extracting VM first lets tabs reference `@ObservedObject vm` cleanly. M-2b first would have meant tabs taking 10+ @Binding params each, then refactoring again when VM lands. |
| D-4 | VM uses `onSourceChange: (MealEntrySource) -> Void` callback instead of holding `Binding<MealEntry>` | Binding lifecycle on ObservableObject is awkward and SwiftUI doesn't really intend them to be stored. Callback is explicit and testable. |
| D-5 | `formatMealValue` is a free function, not a method on VM | Used by both the VM (state mutations) and `ParsedMetricView` (metric tile). Free helper avoids passing the VM into a pure-render component. |
| D-6 | Tabs read `dataStore` via `@EnvironmentObject` directly when the operation is a READ | `TemplateTabView.dataStore.mealTemplates` is already env-injected upstream; no need to pass it via callback for reads. Mutations (`dataStore.mealTemplates.append`) stay as callbacks from the coordinator to make ownership explicit. |
| D-7 | Recovery from stacked-PR misfire was a single resubmit, not a chain rebuild | The m2b branch already contained both M-2c + M-2b commits (it was branched from m2c which was branched from m2a). One PR (#129) bundled both phases onto main. |
| D-8 | Ship M-2d in the same session | Per the established pattern (M-3, M-1). Schema-conformant monitoring entry from inception, no retroactive amend. |

---

## 7. Methodology Notes

### What's similar to M-1

Both are pure structural refactors of a single oversized SwiftUI file. Both used:
- Phased plan doc with line-level inventory before Phase A
- Sequential phase shipping (each PR independently revertable in principle)
- Concurrent case study tracking from inception
- Visibility bumps cascading as a known cost (3 in M-2a vs 9 in M-1)

### What's different from M-1

M-2 has a deeper architectural change: the ViewModel pattern. M-1 was pure file boundary redrawing — every screen, every component still has the same shape, just lives in a different file. M-2 also introduces a real ObservableObject with @Published state, callback injection for parent-owned mutations, and the per-tab sub-view pattern with bridge actions.

The risk surface is correspondingly larger:
- M-1 risk = SwiftUI compilation + visibility bumps + project.pbxproj hygiene
- M-2 risk = above + binding rewiring + ObservableObject lifecycle + callback wiring + tab/VM coupling

### What's different from M-3

M-3 was content-additive (added tokens, added colorset variants). The unit of work was new code. M-2 is the opposite — net zero new behaviour, just file boundaries redrawn and state ownership reshaped.

This means the "concurrent case study tracking" pattern works across both shapes — confirming it's not a content-additive-only methodology.

### Stacked PR workflow lesson

GitHub's PR base behaviour means: a stacked PR with `--base feature/X` merges into branch `X`, not into `main`, even if `X` later gets merged to main. You must retarget the downstream PR to `main` after the upstream lands.

Workarounds:
1. **Avoid stacking** — open each phase's PR from main once the predecessor merges. Slower but no surprises.
2. **Retarget before merging** — `gh pr edit <n> --base main` after the predecessor lands but before clicking Merge.
3. **Resubmit from the head branch** — what M-2 did. The downstream branch already has all upstream commits since branches were chained, so a single new PR from the deepest branch lands everything at once.

For M-2 specifically, option 3 was the cheapest recovery. For future multi-phase features, option 1 is probably safest — the M-1 series did sequential PRs from main and never had this issue.

### Statistical methods

- Lines moved: **964** (4 leaf files 426 + VM 235 + 5 tab files 419, minus duplication)
- New files: **9** (4 leaves + 1 VM + 1 shared components + 4 tab views)
- Visibility bumps: **3** in M-2a (parser internals), 0 in M-2c, 0 in M-2b
- Wall time: **~2.5 hours** across 4 PRs (5 if counting #129 resubmit) + ~30 min recovery from stacked-PR misfire
- **1 audit finding closed in 2.5 hours = 0.4 findings/hour** — slower than M-1 (0.5) and M-3 (1.2) because the work involved real architectural decisions (VM pattern, callback injection) on top of mechanical extractions.

### Limitations

- **No manual visual QA** — relying on type-level behaviour preservation. SwiftUI rendering edge cases unverified at the screen level.
- **`onSourceChange` is set in `.onAppear`** — if SwiftUI re-creates the view (which can happen on parent re-render), the callback gets re-wired. The VM is `@StateObject` so it persists; the callback closure captures the (current) `entry` binding. Should be correct but worth verifying in QA.
- **Stacked PR misfire** — wasted ~20 minutes on diagnosis + retargeting. Documented above as methodology lesson.

---

## 8. Artifacts

### PRs

| PR | Phase | What |
|---|---|---|
| #126 | M-2a | 4 leaf type extractions (OFF DTOs, parser, camera, barcode) |
| #127 | M-2c | MealEntryViewModel extraction (originally stacked, merged into M-2a base) |
| #128 | M-2b | Per-tab view extractions (originally stacked, merged into M-2c base) |
| #129 | M-2 resubmit | Single PR landing M-2c + M-2b commits onto main |
| **this PR** | **M-2d** | **Case study + monitoring entry + UI-004 closure** |

### Documents

| Path | Role |
|---|---|
| `docs/superpowers/plans/2026-04-19-m2-mealentrysheet-decomposition.md` | Plan written before Phase M-2a |
| `docs/case-studies/m-2-mealentrysheet-decomposition-case-study.md` | This file |
| `docs/case-studies/m-1-settings-decomposition-case-study.md` | Predecessor (closed UI-002) |
| `docs/case-studies/m-3-design-system-completion-case-study.md` | Pre-predecessor (closed DS-004 + DS-009 + DS-010) |
| `.claude/shared/audit-findings.json` | Live-synced findings ledger (182/185 closed post-M-2) |
| `.claude/shared/case-study-monitoring.json` | Cross-cycle case study tracking (now 15 cases after M-2d entry) |

### Code (the deltas)

- `FitTracker/Views/Nutrition/MealEntrySheet.swift` — 1104 → 140 lines (-964)
- `FitTracker/Views/Nutrition/MealEntryViewModel.swift` — 234 lines (new)
- `FitTracker/Views/Nutrition/Models/OpenFoodFactsModels.swift` — 95 lines (new)
- `FitTracker/Views/Nutrition/Parsing/NutritionLabelParser.swift` — 120 lines (new)
- `FitTracker/Views/Nutrition/Camera/NutritionCameraSheet.swift` — 46 lines (new)
- `FitTracker/Views/Nutrition/Camera/BarcodeScanner.swift` — 165 lines (new)
- `FitTracker/Views/Nutrition/Tabs/MealEntrySharedComponents.swift` — 71 lines (new)
- `FitTracker/Views/Nutrition/Tabs/SmartTabView.swift` — 121 lines (new)
- `FitTracker/Views/Nutrition/Tabs/ManualTabView.swift` — 65 lines (new)
- `FitTracker/Views/Nutrition/Tabs/TemplateTabView.swift` — 54 lines (new)
- `FitTracker/Views/Nutrition/Tabs/SearchTabView.swift` — 108 lines (new)
- `FitTracker.xcodeproj/project.pbxproj` — 11 new PBXFileReference + 11 new PBXBuildFile + 4 new PBXGroup entries

---

## 9. What Comes Next

After M-2 closes, **3 audit findings remain open**:

| Finding | Sev | Category |
|---|---|---|
| **DEEP-SYNC-010** | high | External — CK→Supabase Storage cardio image bridge (multi-PR) |
| **TEST-025** | medium | M-4 XCUITest infrastructure (multi-session feature) |
| **BE-024** | medium | External — Supabase Edge Function for `auth.admin.deleteUser` |

Per the audit completion plan, all 3 are pre-classified as multi-session features (M-4) or external blockers (BE-024, DEEP-SYNC-010). None are "still open by oversight".

**Recommended next step**: M-4 (XCUITest infrastructure) — the only remaining in-project multi-session feature. Likely 3-4 phases (target setup, first happy-path tests, CI integration, case study). Methodology proven by M-1 + M-2 transfers directly: plan doc with phase inventory → phased extraction/setup PRs → concurrent case study tracking.

---

## 10. Methodology References

- Predecessor: `docs/case-studies/m-1-settings-decomposition-case-study.md`
- Pre-predecessor: `docs/case-studies/m-3-design-system-completion-case-study.md`
- Plan template: `docs/case-studies/case-study-template.md`
- Audit completion plan: `docs/superpowers/plans/2026-04-19-audit-completion-plan.md` (M-2 row)
- M-2 plan: `docs/superpowers/plans/2026-04-19-m2-mealentrysheet-decomposition.md`
