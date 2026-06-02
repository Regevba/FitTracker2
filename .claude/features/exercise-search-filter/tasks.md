# C3 — Exercise Search/Filter — Phase 2 Task Breakdown

> **Status:** Phase 2 (Tasks) — in flight
> **PRD source:** [`docs/product/prd/exercise-search-filter.md`](../../docs/product/prd/exercise-search-filter.md)
> **Branch:** `feature/exercise-search-filter`

10 discrete tasks, ordered by dependency. Estimates are LoC (≈ size of NEW or NET-CHANGED code; existing-code mutation counted as 1× lines touched).

---

## Task graph (dependency)

```
T1 (AnalyticsProvider constants + Service methods)
   ↓
T2 (ExerciseLibraryFilter pure helpers)
   ↓
T3 (ExerciseLibraryRow view)
   ↓
T4 (ExerciseDetailView view)
   ↓
T5 (ExerciseLibraryView sheet — composes T2/T3 + analytics)
   ↓
   ├──→ T6 (TrainingPlanView toolbar button)
   ├──→ T7 (Settings → Training & Nutrition row)
   ↓
T8 (project.pbxproj wiring for 4 new source files)
   ↓
T9 (Test suite — 4 new test files, ~15 tests)
   ↓
T10 (Final verify-local + case study)
```

T1, T2 can begin in parallel (independent infrastructure). T3 depends on T2 (filter output shape). T4 + T5 depend on T3. T6 + T7 depend on T5. T8 wires all new files. T9 lands last after T1-T8 green. T10 wraps verification + case study.

---

## T1 — `AnalyticsProvider` constants + `AnalyticsService` methods

**Files:**
- `FitTracker/Services/Analytics/AnalyticsProvider.swift` (modify)
- `FitTracker/Services/Analytics/AnalyticsService.swift` (modify)

**Change:** Add 4 new event constants under `AnalyticsEvent` (screen-prefixed `training_exercise_*`) + 3 new param constants under `AnalyticsParam` (`dimension`, `query_length`, `via_search` / `via_filter` — note: `via_search` reused for both bool params via name) + 4 new `logTrainingExercise*` methods on `AnalyticsService`.

Pattern mirrors C5's 2026-06-02 commit `6a00984` (T11) for `home_ai_feedback_*` events.

```swift
// AnalyticsProvider
enum AnalyticsEvent {
    // ── C3 Exercise Library (screen-prefixed: training_) ──
    static let trainingExerciseLibraryOpened   = "training_exercise_library_opened"
    static let trainingExerciseSearchQuery     = "training_exercise_search_query"
    static let trainingExerciseFilterTapped    = "training_exercise_filter_tapped"
    static let trainingExerciseDetailOpened    = "training_exercise_detail_opened"
}

enum AnalyticsParam {
    // C3 params
    static let dimension      = "dimension"        // muscle/equipment/category
    static let queryLength    = "query_length"     // int — chars typed at commit
    static let viaSearch      = "via_search"       // bool — query non-empty at tap
    static let viaFilter      = "via_filter"       // bool — any chip non-default at tap
    // exerciseId reuses existing per AnalyticsTaxonomy (no new constant needed if it exists; otherwise add)
}

// AnalyticsService
func logTrainingExerciseLibraryOpened(source: String) {...}
func logTrainingExerciseSearchQuery(queryLength: Int) {...}
func logTrainingExerciseFilterTapped(dimension: String, value: String) {...}
func logTrainingExerciseDetailOpened(exerciseId: String, viaSearch: Bool, viaFilter: Bool) {...}
```

**LoC:** ~55 (15 in Provider + 40 in Service)
**Tests:** T9.A — 1 test confirming all 4 events fire with correct param shape (via `MockAnalyticsService`)
**Risk:** Low. Pattern mirrors C5.

---

## T2 — `ExerciseLibraryFilter` pure helpers

**File:** `FitTracker/Models/ExerciseLibraryFilter.swift` (NEW)

**Purpose:** Pure-function filter chain. No state. Public API:

```swift
enum ExerciseLibraryFilter {
    /// Filter the catalog by query + chip selections.
    static func filteredExercises(
        query: String,
        muscle: MuscleGroup?,
        equipment: Equipment?,
        category: ExerciseCategory?,
        catalog: [ExerciseDefinition] = TrainingProgramData.allExercises
    ) -> [ExerciseDefinition] {
        catalog.filter { ex in
            let queryMatch = query.isEmpty
                || ex.name.localizedCaseInsensitiveContains(query)
                || ex.muscleGroups.contains { $0.displayName.localizedCaseInsensitiveContains(query) }
            let muscleMatch = muscle.map { ex.muscleGroups.contains($0) } ?? true
            let equipmentMatch = equipment.map { ex.equipment == $0 } ?? true
            let categoryMatch = category.map { matchesCategory(ex.category, $0) } ?? true
            return queryMatch && muscleMatch && equipmentMatch && categoryMatch
        }
    }

    /// Strength = machine ∪ freeWeight ∪ calisthenics rollup per PRD §"Chip dimension taxonomy"
    static func matchesCategory(_ raw: ExerciseCategory, _ filter: ExerciseCategory) -> Bool {
        switch filter {
        case .strength: return raw == .machine || raw == .freeWeight || raw == .calisthenics
        case .cardio:   return raw == .cardio
        case .core:     return raw == .core
        default:        return raw == filter
        }
    }
}
```

`catalog` parameter defaults to `TrainingProgramData.allExercises` but is injectable for tests (deterministic + small fixtures).

**LoC:** ~50
**Tests:** T9.B — 6 tests:
- empty query + no chips → all 50
- query "chest" → matches Chest Press Machine + Pec Deck etc.
- muscle filter alone → only that muscle
- equipment filter alone → only that equipment
- category filter "strength" → excludes cardio/core
- combined query + 2 chips → AND-gated

**Risk:** Low. Pure function, no UI.

---

## T3 — `ExerciseLibraryRow` view

**File:** `FitTracker/Views/Training/v2/ExerciseLibraryRow.swift` (NEW)

**Purpose:** Single result row with name + muscle/equipment/sets-reps badges. Tappable.

```swift
struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(exercise.name)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                    HStack(spacing: AppSpacing.xSmall) {
                        Text(exercise.muscleGroups.first?.displayName ?? "—")
                        Text("·")
                        Text(exercise.equipment.displayName)
                        Text("·")
                        Text("\(exercise.targetSets)×\(exercise.targetReps)")
                    }
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                Image(systemName: AppIcon.chevronRight)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(.vertical, AppSpacing.xSmall)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.muscleGroups.first?.displayName ?? ""), \(exercise.equipment.displayName)")
    }
}
```

**LoC:** ~70
**Tests:** none directly (UI-level; covered via T9.C integration test).
**Risk:** Low. Existing AppComponents tokens.

---

## T4 — `ExerciseDetailView` push view

**File:** `FitTracker/Views/Training/v2/ExerciseDetailView.swift` (NEW)

**Purpose:** Detail screen pushed when user taps a row (in read-only mode — NOT in picker mode). Shows:
- Full exercise name + day-type chip
- Sets × reps × rest seconds
- Coaching cue paragraph
- Progression note (if any)
- Muscle group badges + equipment badge

```swift
struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @EnvironmentObject private var analytics: AnalyticsService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                header
                programSlot
                coachingCue
                if !exercise.progressionNote.isEmpty { progression }
                badges
            }
            .padding(AppSpacing.medium)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View { /* day-type chip + sets×reps×rest */ }
    private var programSlot: some View { /* day-type assignment label */ }
    private var coachingCue: some View { /* Text block */ }
    private var progression: some View { /* Text block */ }
    private var badges: some View { /* HStack of muscle + equipment chips */ }
}
```

NO "add to plan" affordance — C6 surface only.

**LoC:** ~120
**Tests:** none directly (UI-level; covered by T9.C integration test on push).
**Risk:** Low.

---

## T5 — `ExerciseLibraryView` sheet (the headline component)

**File:** `FitTracker/Views/Training/v2/ExerciseLibraryView.swift` (NEW)

**Purpose:** The main sheet. Composes T2 (filter) + T3 (rows) + T4 (detail push) + analytics. Implements picker-mode dual init per PRD §"FROZEN constants" → C6 dependency contract:

```swift
struct ExerciseLibraryView: View {
    let picker: ((ExerciseDefinition) -> Void)?
    let source: String  // "training_toolbar" / "settings_row" — for analytics

    @EnvironmentObject private var analytics: AnalyticsService
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var selectedMuscle: MuscleGroup? = nil
    @State private var selectedEquipment: Equipment? = nil
    @State private var selectedCategory: ExerciseCategory? = nil

    /// Convenience init for read-only mode (default).
    init(source: String) {
        self.source = source
        self.picker = nil
    }

    /// Picker-mode init — C6 dependency contract per PRD §"FROZEN constants".
    init(source: String, picker: @escaping (ExerciseDefinition) -> Void) {
        self.source = source
        self.picker = picker
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                filterChipRows
                resultList
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { /* close button */ }
        }
        .presentationDetents([.large])
        .onAppear {
            analytics.logTrainingExerciseLibraryOpened(source: source)
        }
    }

    private var filteredResults: [ExerciseDefinition] {
        ExerciseLibraryFilter.filteredExercises(
            query: query,
            muscle: selectedMuscle,
            equipment: selectedEquipment,
            category: selectedCategory
        )
    }

    private func handleTap(_ exercise: ExerciseDefinition) {
        analytics.logTrainingExerciseDetailOpened(
            exerciseId: exercise.id,
            viaSearch: !query.isEmpty,
            viaFilter: hasAnyChip
        )
        if let picker {
            picker(exercise)
            dismiss()  // picker-mode dismisses on selection
        } else {
            // read-only mode → push detail (handled via NavigationLink in row builder)
        }
    }

    private var hasAnyChip: Bool {
        selectedMuscle != nil || selectedEquipment != nil || selectedCategory != nil
    }
    
    private var resultList: some View {
        Group {
            if filteredResults.isEmpty {
                emptyState
            } else {
                List(filteredResults, id: \.id) { exercise in
                    if picker != nil {
                        ExerciseLibraryRow(exercise: exercise) {
                            handleTap(exercise)
                        }
                    } else {
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                                .onAppear { handleTap(exercise) }
                        } label: {
                            ExerciseLibraryRow(exercise: exercise) {}
                        }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.medium) {
            Text("No exercises match \(query.isEmpty ? "your filters" : "\"\(query)\""). Tap All in any row to clear that filter.")
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.secondary)
            Button("Clear all filters") {
                query = ""
                selectedMuscle = nil
                selectedEquipment = nil
                selectedCategory = nil
            }
            .buttonStyle(.bordered)
        }
        .padding(AppSpacing.large)
    }

    private var searchField: some View { /* TextField + magnifying glass icon */ }

    private var filterChipRows: some View {
        VStack(spacing: AppSpacing.small) {
            AppFilterBar(/* muscle dimension */)
            AppFilterBar(/* equipment dimension */)
            AppFilterBar(/* category dimension */)
        }
    }
}
```

Analytics fires:
- `training_exercise_library_opened` in `.onAppear` (read once per sheet present)
- `training_exercise_search_query` on text-field commit when `query.count >= 2` (NOT per-keypress)
- `training_exercise_filter_tapped` when a chip is tapped (dimension + value derived from binding)
- `training_exercise_detail_opened` in `handleTap`

**LoC:** ~180
**Tests:** T9.C — 4 tests:
- Read-only init → row tap pushes detail
- Picker init → row tap calls picker + dismisses sheet
- Empty-result state surfaces clear-all CTA
- Filter chip tap fires analytics with correct dimension+value

**Risk:** Medium — most logic. Phase 5 (Test) verifies sheet presentation + filter behavior on iPhone 17 simulator.

---

## T6 — `TrainingPlanView` toolbar button entry point

**Files:**
- `FitTracker/Views/Training/v2/TrainingPlanView.swift` (modify)
- `FitTracker/Views/Training/TrainingPlanView.swift` (modify — v1 historical surface, only if v1 still in build target)

**Change:** Add a "Library" toolbar button at top-right of the Training screen. Tap presents `ExerciseLibraryView` sheet.

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showLibrary = true
        } label: {
            Image(systemName: AppIcon.exerciseLibrary)
        }
        .accessibilityLabel("Browse exercise library")
    }
}
.sheet(isPresented: $showLibrary) {
    ExerciseLibraryView(source: "training_toolbar")
}
```

State holder `@State private var showLibrary = false` declared on the view.

**LoC:** ~15 (5 on v2 + 5 on v1 + 5 wiring)
**Tests:** none directly (covered by T9.D integration test).
**Risk:** Low. Existing toolbar pattern.

---

## T7 — Settings → Training & Nutrition row entry point

**File:** `FitTracker/Views/Settings/v2/Screens/TrainingNutritionSettingsScreen.swift` (modify)

**Change:** Add a `NavigationLink`-style row "Browse Exercise Library" pushing the sheet (sheet adapts to navigation context within Settings).

```swift
Button {
    showLibrary = true
} label: {
    SettingsRow(
        title: "Browse Exercise Library",
        subtitle: "Search and filter all \(TrainingProgramData.allExercises.count) exercises",
        icon: AppIcon.exerciseLibrary,
        chevron: true
    )
}
.sheet(isPresented: $showLibrary) {
    ExerciseLibraryView(source: "settings_row")
}
```

State holder `@State private var showLibrary = false`.

**LoC:** ~15
**Tests:** none directly (covered by T9.D integration test).
**Risk:** Low.

---

## T8 — `project.pbxproj` wiring

**File:** `FitTracker.xcodeproj/project.pbxproj` (modify)

**Change:** Register the 4 new source files (T2/T3/T4/T5) in Sources phase + group + file references. Mirror C5's commit `f95e85b` (DismissReasonPicker) + `438e02c` (AIFeedbackSettingsScreen) patterns.

4 new entries each: PBXBuildFile + PBXFileReference + group entry + Sources phase entry. ~30 LoC total.

**LoC:** ~30
**Tests:** xcodebuild build verifies wiring (Phase 4 commit's CI gate).
**Risk:** Low. Mechanical edit; verified by build.

---

## T9 — Test suite

**Files (NEW — 4 test files):**

- `FitTrackerTests/AnalyticsTrainingExerciseEventsTests.swift` (T9.A — 1 test)
- `FitTrackerTests/ExerciseLibraryFilterTests.swift` (T9.B — 6 tests)
- `FitTrackerTests/Views/ExerciseLibraryViewModeTests.swift` (T9.C — 4 tests; covers picker vs read-only via closure injection)
- `FitTrackerTests/Views/ExerciseLibraryEntryPointTests.swift` (T9.D — 4 tests; verifies toolbar + Settings row present + fire correct `source` param)

**Total:** 15 tests across 4 new files. All use mock `AnalyticsService` for event-capture; `ExerciseLibraryFilter` tests inject a fixture catalog (small + deterministic).

**LoC:** ~250

**Coverage target:** ≥ 90% on new production files (T2/T3/T4/T5).

Also adds the 4 test files to `project.pbxproj` (subsumed under T8 if landed in the same commit).

---

## T10 — Final verify-local + case study

**Files:**
- `docs/case-studies/exercise-search-filter-case-study.md` (NEW)
- `.claude/features/exercise-search-filter/state.json` (modify — advance `current_phase: testing`)
- `.claude/logs/exercise-search-filter.log.json` (auto-append via `scripts/append-feature-log.py`)

**Checks:**
- `xcodebuild build -scheme FitTracker -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED
- `xcodebuild test -only-testing:FitTrackerTests/ExerciseLibraryFilterTests -only-testing:FitTrackerTests/AnalyticsTrainingExerciseEventsTests -only-testing:FitTrackerTests/Views/ExerciseLibraryViewModeTests -only-testing:FitTrackerTests/Views/ExerciseLibraryEntryPointTests` → 15/15 PASS
- `make ui-audit` → P0=0 maintained
- `python3 scripts/check-state-schema.py` → 82/82 pass
- Tier 2.2 log: phase_transition event for `testing`

**Case study:** mirrors C5 pattern (`docs/case-studies/ai-user-feedback-loop-case-study.md`) with 7 required frontmatter fields + T1/T2/T3 tier-tagged metrics + frozen constants + cross-references.

**LoC:** ~160 case study + ~10 state.json edit

---

## Out-of-scope guards (from PRD §"Out of scope")

Explicit do-not-implement in C3 v1:
- "Add to plan" affordance → C6 surface (C3 ships picker-mode signature; C6 calls it)
- Custom UGC exercises → post-launch
- Image/video demos → asset pipeline future
- AI-suggested alternatives → D1
- Favourites / sort options / multi-select chips / recently-viewed → all future

If any task discovers a need for these, file a backlog row + flag in PR description. Don't expand scope mid-Phase 4.

---

## Phase 4 (Implement) ordering

Recommended landing order (each commit standalone + buildable):

1. **T1 + T2** — Analytics infra + filter helpers (no view churn). Single commit. ~105 LoC.
2. **T3 + T4** — Row + detail views. Single commit. ~190 LoC.
3. **T5** — `ExerciseLibraryView` sheet (the headline + most logic). Standalone commit. ~180 LoC.
4. **T6 + T7** — Entry-point wires (toolbar + Settings row). Single commit. ~30 LoC.
5. **T8** — `project.pbxproj` wiring (subsumed into the commit landing the file each entry references, OR final landing commit).
6. **T9** — Test suite + pbxproj test entries. Single commit. ~250 LoC.
7. **T10** — Final verify-local + case study + state.json → `testing`. Single commit. ~170 LoC.

Estimated total LoC: **~875** (PRD §"Technical Approach" est ~600; tasks.md re-estimate accounts for pbxproj overhead + case study).

**Estimated wall time:** ~3-4 hours (matches C5 Phase 4 pattern of 7 standalone commits in ~67 minutes after Phases 0-2 land in ~100 minutes).

---

## Phase transition criteria

| From → To | Criterion |
|---|---|
| tasks → implement | Operator approves this Phase 2 tasks.md (scope frozen + ordering OK) |
| implement → test | All 10 tasks complete; project.pbxproj wires all 4 new source files + 4 test files; `xcodebuild build -scheme FitTracker` exits 0 |
| test → review | All 15 tests pass; coverage ≥ 90% on new files; `make ui-audit` P0=0; `make tokens-check` green |
| review → merge | `/ux pre-merge-review` + `/design pre-merge-review` both pass + PR description includes Figma node IDs (none — no new Figma surfaces, all reuse existing tokens/components) |
| merge → complete | PR merged; backlog L347 + Planned RICE row 8.0 struck; FEATURE_CLOSURE_COMPLETENESS gate passes |

---

## Cross-references

- PRD: `docs/product/prd/exercise-search-filter.md`
- Research: `.claude/features/exercise-search-filter/research.md`
- State.json: `.claude/features/exercise-search-filter/state.json`
- Catalog: `FitTracker/Models/TrainingProgramData.swift`
- Existing chip primitives: `FitTracker/DesignSystem/AppComponents.swift` (AppPickerChip + AppFilterBar)
- Sibling C5 commit pattern reference: PR #572 `ec5dff9` — 7 standalone-buildable commits in Phase 4
- C6 dependency contract: picker-mode init signature in `T5`'s code block above
