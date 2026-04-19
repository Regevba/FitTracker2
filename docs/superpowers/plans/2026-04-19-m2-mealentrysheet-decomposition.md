# M-2 — MealEntrySheet Decomposition

> **Audit finding**: UI-004 — MealEntrySheet.swift (1104 lines, 17 @State, 4 tabs)
> **Type**: Multi-session feature — case study tracking ON from start (per the M-3/M-1 precedent)
> **Predecessor plan**: `docs/superpowers/plans/2026-04-19-m1-settings-v3-decomposition.md`
> **Date**: 2026-04-19

## Goal

Decompose `FitTracker/Views/Nutrition/MealEntrySheet.swift` (1104 lines) following the pattern proven by M-1. Phased approach: leaf extractions first (low risk), then per-tab sub-views (medium risk), then ViewModel extraction (medium-high risk because of binding rewiring), then case study.

## Source structure (read-only inventory)

| Lines | Section | Type | Decomposition target |
|---|---|---|---|
| 1-29 | imports + MealEntryTab enum | header + small enum | Stay |
| 30-702 | `MealEntrySheet` (the main view) | struct | M-2b/c (split tabs + ViewModel) |
| 703-787 | OFF API DTOs (OFFSearchResponse, OFFProductResponse, OFFProduct, FoodProduct) | structs | **M-2a → Models/OpenFoodFactsModels.swift** |
| 788-904 | NutritionLabelParser machinery (ParsedNutritionLanguageHint, ParsedNutritionLabel, NutritionLabelParser) | enum + struct + enum | **M-2a → Parsing/NutritionLabelParser.swift** |
| 905-940 | NutritionCameraSheet (UIViewControllerRepresentable wrapper) | struct | **M-2a → Camera/NutritionCameraSheet.swift** |
| 941-1103 | BarcodeScannerSheet + BarcodeScannerView + BarcodeScannerVC + delegate extension | struct + struct + class + extension | **M-2a → Camera/BarcodeScanner.swift** |

After M-2a: MealEntrySheet.swift = ~700 lines (the giant View struct alone).

## Phases

### Phase M-2a — Leaf-Type Extractions (this sprint)

Move the 4 standalone leaf types out of MealEntrySheet.swift. These don't depend on `MealEntrySheet`'s state — they're either pure data models (OFF DTOs), pure parsing (NutritionLabelParser), or framework-glue UIViewControllerRepresentable wrappers (NutritionCameraSheet, BarcodeScanner).

| New file | Lines moved | Original location |
|---|---|---|
| `Models/OpenFoodFactsModels.swift` | ~85 | 703-787 |
| `Parsing/NutritionLabelParser.swift` | ~117 | 788-904 |
| `Camera/NutritionCameraSheet.swift` | ~36 | 905-940 |
| `Camera/BarcodeScanner.swift` | ~163 | 941-1103 |
| **Total moved** | **~401 lines** | |

After M-2a: MealEntrySheet.swift = ~703 lines.

**Risk**: low. None of these types reference `MealEntrySheet`'s state — they're already self-contained. Some types are private (`ParsedNutritionLanguageHint`, `ParsedNutritionLabel`, `NutritionLabelParser`) and need visibility bumps, but only within the new file (the parser is referenced from `MealEntrySheet.parseSmartLabel()` in the main file, so `NutritionLabelParser` and `ParsedNutritionLabel` need to be internal).

**Pbxproj updates**: 4 new file references + Sources entries + 3 new PBXGroups (Models, Parsing, Camera) under `Nutrition/`.

### Phase M-2b — Per-Tab Sub-Views (next sprint)

Each of the 4 tabs (`smartTab`, `manualTab`, `templateTab`, `searchTab`) is a `private var: some View` ViewBuilder method on the MealEntrySheet struct. To extract them into sub-structs, the @State they reference needs to flow down via @Binding (or a shared @ObservableObject if M-2c lands first).

This phase has 2 possible orderings:
- **M-2b first**: Extract tabs as sub-structs taking many @Binding params (cosmetic split, lots of param-passing).
- **M-2c first**: Extract ViewModel first, then tabs reference the shared @ObservableObject (cleaner, but a bigger first move).

**Decision**: do M-2c before M-2b for the cleaner data-flow story.

### Phase M-2c — ViewModel Extraction (after M-2a)

The 17 @State vars on `MealEntrySheet` are doing the work of a view model. Extract them into `MealEntryViewModel: ObservableObject` so:
- The 4 tabs can share state via `@EnvironmentObject` or `@ObservedObject`
- Test surface area becomes available for the smart-label parsing flow + search debounce + photo loading
- The view itself drops to ~150-200 lines (just layout + tab switch + side-effect bridges)

**Risk**: medium-high — requires careful @Binding migration. Each `@State private var x` becomes `viewModel.x` with `Binding($viewModel.x)` at use sites. SwiftUI rerendering semantics for @ObservedObject differ subtly from @State — needs build + visual verification per binding.

### Phase M-2d — Case Study + Monitoring Entry

Per the rule, M-2 gets its own case study. Following M-3/M-1 precedent (concurrent tracking, schema-conformant from inception).

## Out of scope

- **Behaviour changes** — pure structural decomposition. Every tab renders identically before and after.
- **Parser logic changes** — NutritionLabelParser keeps its current language hint heuristics + scaling logic.
- **OFF API contract changes** — DTOs move file, not shape.
- **New tests** — view doesn't have unit tests; M-4 (XCUITest infra) is the right vehicle for coverage here.

## Success criteria

- After Phase M-2a: MealEntrySheet.swift drops from 1104 → ~703 lines, build green, all 4 tabs render correctly.
- After Phase M-2b: each tab is its own file, MealEntrySheet drops to ~250 lines (mostly tab-switch + state + side-effects).
- After Phase M-2c: 17 @State vars consolidated into MealEntryViewModel; view drops to ~150-200 lines.
- After Phase M-2d: case study + monitoring entry shipped per the rule, UI-004 closed.

## Estimated effort

| Phase | Effort | Risk |
|---|---|---|
| M-2a (this PR) | 45-60 min | low (4 file extractions + pbxproj updates) |
| M-2c | 90-120 min | medium-high (binding rewiring) |
| M-2b | 60-90 min | low (per-tab view extraction with shared VM) |
| M-2d | 60-90 min | low |
| **Total** | **~4-5 hours** | |

## Rollback plan

Each phase ships as its own PR. If a phase introduces a regression (visual or behavioural), revert the PR. The leaf extractions in M-2a are net positive — even if M-2b/c are reverted later, M-2a stays.
