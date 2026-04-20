# Import Training Plan — Case Study

**Date written:** 2026-04-20

> **Subtitle:** The v5.1 parallel-stress-test feature that shipped a working parser + mapper + 23 unit tests in one sprint — then had its UI archived as dead code three days later when the audit proved it was never wired in.

| Field | Value |
|---|---|
| Feature | import-training-plan |
| Work type | feature |
| Framework version | v5.1 (parallel stress test) |
| State | `phase=complete` as of 2026-04-16T05:30:00Z |
| Branch | none (direct commits to `main`) |
| PRs | none (merged as commits: `b62b659`, `0a10a4a`, `33b4e72`, `c928b9c`, `aab67fb`, `0831f60`) |
| Wall time | ~8 hours across 2 days (2026-04-15 PRD → 2026-04-16 complete) |
| Files shipped | 5 production Swift files (607 lines) + 2 test files (316 lines) |
| Tests | 23 unit tests (15 core + 8 edge cases) — all passing under BUILD SUCCEEDED |
| UI status | Archived as HISTORICAL on 2026-04-17 (audit UI-015) — never wired into the app |
| Analytics | 6 event constants defined in `AnalyticsProvider.swift`; not yet fired at call sites |

---

## 1. Why This Case Study Exists

Import Training Plan is the project's clearest case of a feature **completing the PM funnel on paper while the shipped UI never reached a user**. Per the 2026-04-13 project rule, every feature gets a case study — and this one documents an uncomfortable but useful pattern:

- The parser layer (CSV / JSON / Markdown) shipped, is exercised by 23 unit tests, and lives in the build target as reachable code.
- The `ImportOrchestrator` state machine shipped and is tested end-to-end.
- The `ExerciseMapper` shipped with 37 alias entries covering the core of the 87-exercise library.
- The two entry-point views (`ImportSourcePickerView`, `ImportPreviewView`) shipped but were **never instantiated** by any tab, sheet, or navigation destination in the app. Three days after merge, a UI audit (finding UI-015 in Sprint D, 2026-04-17) flagged them as dead code and they were annotated `HISTORICAL —` in their file headers.

The feature is therefore a split outcome: a working, tested parser stack sitting on `main`, behind a UI that was archived before it reached production. The case study exists to record why that happened, what remains salvageable, and what revival looks like.

---

## 2. Summary Card

| Concern | What shipped | Evidence |
|---|---|---|
| Parser protocol | `ImportParser` protocol with `canParse(_:)` + `parse(_:) throws -> ImportedPlan` | `FitTracker/Services/Import/ImportParser.swift` (174 lines) |
| File formats supported | CSV (Strong/Hevy style), JSON (direct `ImportedPlan` or `[ImportedExercise]`), Markdown (tables + numbered lists) | Same file — `CSVImportParser`, `JSONImportParser`, `MarkdownImportParser` |
| Schema validation | `canParse(_:)` gates each parser; `ImportError.emptyInput` / `.unsupportedFormat` / `.parsingFailed(String)` for negative paths | `ImportParser.swift` lines 156-168 |
| Partial-import behavior | Non-numeric `sets` falls back to default of 3; missing `reps` defaults to `"8"`; missing `rest` stays `nil`; short rows (single column) silently skipped; unknown extra columns ignored | `ImportEdgeCaseTests.swift` lines 49-103 |
| Exercise mapping | 3-tier confidence: exact (1.0) / substring contain (0.85) / word-overlap (>=0.5) / unmatched (0.0). 37 aliases seeded for 87-exercise library | `ExerciseMapper.swift` (88 lines) |
| Confidence tiers | `autoAcceptThreshold = 0.95` / `reviewThreshold = 0.70` — matches PRD IT-4 spec | `ExerciseMapper.swift` lines 5-9 |
| Orchestrator state machine | `.idle → .parsing → .mapping → .preview(plan) → .success(plan)` with `.error(String)` branch | `ImportOrchestrator.swift` (60 lines) |
| Tests | 15 in `ImportTests.swift` (parser + mapper + orchestrator) + 8 in `ImportEdgeCaseTests.swift` (CSV malformed input) | Both in `FitTrackerTests/` |
| Analytics event constants | `import_started`, `import_source_selected`, `import_parsed`, `import_mapping_confirmed`, `import_completed`, `import_failed` | `AnalyticsProvider.swift` lines 232-242 |

---

## 3. PRD Summary

`docs/product/prd/import-training-plan.md` (Approved 2026-04-15, 234 lines):

- **Problem.** New users with an existing plan (Hevy / Strong CSV, coach PDFs, AI-generated programs) have no path to bring that structure into FitMe short of manual re-entry. Import removes that migration barrier.
- **Success metrics.** Import success rate >= 80%, exercise mapping accuracy >= 90%, time-to-first-imported-workout < 5 min, plan adoption within 7 days >= 60% of importers, user satisfaction >= 4/5. Kill criteria: <30% success rate or <70% mapping accuracy.
- **P0 requirements (IT-1 to IT-8).** CSV parser, JSON parser, `ExerciseMapper` with alias dictionary, confirmation UI with auto-accept at >=0.9 confidence, plan-structure preservation (days + sets + reps + rest), unmatched handling, import preview with edit, analytics instrumentation.
- **P1 requirements (IT-9 to IT-15).** Markdown/structured-text parser, paste-to-parse entry point, prompt preservation, progressive alias learning, PDF text extraction, protocol-based parser architecture, unit tests.
- **P2 (IT-16 to IT-20).** Photo OCR, iOS Share Extension, AI prompt re-run via `AIOrchestrator`, phase/mesocycle structure import, RPE-based progression.
- **North star.** Import-attributed WAU trending up; mapping accuracy stable or improving as alias dictionary grows.

---

## 4. Phase Walkthrough

The feature was one of four selected for the **v5.1 parallel stress test** (see `v5.1-parallel-stress-test-case-study.md`) — four PM workflows advanced concurrently to stress the v5.1 framework under load.

**Phase 0 — Research (2026-04-12 → 2026-04-15).** Scope expanded on 2026-04-11 (commit `719d652`) from "CSV/JSON import" to include AI-conversation parsing after recognition that ChatGPT/Claude/Gemini outputs were becoming a common user source. Research approved 2026-04-15T17:35Z.

**Phase 1 — PRD (2026-04-15, commit `0a10a4a`).** Written in the stress-test batch. Locked down multi-source parser architecture, 3-tier confidence tiers, analytics spec (6 events under `import_` prefix per the 2026-04-08 analytics naming rule), and deferred P2 AI prompt re-run to a separate cycle.

**Phase 2 — Tasks (2026-04-15T17:50Z).** 13 tasks on critical path T1 → T4 → T5 → T6 → T8 → T9 → T13. Effort estimate: 8 days.

**Phase 3 — UX spec (2026-04-15T17:58Z).** 2x2 source picker grid, TextEditor paste field, preview with confidence icons (green check / orange pencil / red warning), mapping review sheet.

**Phase 4 — Implementation (2026-04-15 → 2026-04-16).** Landed across three stress-test phases:
- Phase 5 (commit `c261594`, 2026-04-15): 7 Swift files via 3 parallel agents — parser + mapper + analytics wiring.
- Phase 6 (commit `33b4e72`, 2026-04-15): `ImportOrchestrator` + `ImportSourcePickerView` — "3rd consecutive clean build under parallel load".
- Phase 8 (commit `aab67fb`, 2026-04-16): 35 new tests across 3 parallel agents — "ALL PASSED".

**Phase 5-9 — Testing / Review / Merge / Docs.** Marked `pending` in `state.json`. The feature transitioned directly from `implementation` to `complete` on 2026-04-16T05:30Z with note *"All tasks implemented. BUILD SUCCEEDED. Feature complete."* No branch, no PR — commits landed on `main`.

**Post-merge audit (2026-04-17, commit `0831f60`).** Sprint D of the meta-analysis audit flagged finding UI-015: the two import views were unreachable from any view hierarchy. The fix was to annotate them with `HISTORICAL —` headers rather than delete them, preserving the code as a revival anchor.

---

## 5. What Shipped vs What Deferred

### Shipped (in build target, in `main`)

- `FitTracker/Services/Import/ImportParser.swift` — protocol, 3 parser structs, `ImportError` enum, `ImportedPlan`/`ImportedDay`/`ImportedExercise` Codable models.
- `FitTracker/Services/Import/ExerciseMapper.swift` — 3-tier confidence scoring, 37 aliases.
- `FitTracker/Services/Import/ImportOrchestrator.swift` — `@MainActor` `ObservableObject` state machine.
- `FitTrackerTests/ImportTests.swift` — 15 tests covering parser detection, JSON/CSV happy paths, mapper exact/fuzzy/no-match, orchestrator state transitions.
- `FitTrackerTests/ImportEdgeCaseTests.swift` — 8 tests for CSV malformed input per TEST-024.
- Analytics event constants in `AnalyticsProvider.swift` (6 events, `import_` prefix).

### Archived as HISTORICAL (in build target but unreachable)

- `FitTracker/Views/Import/ImportSourcePickerView.swift` — source picker sheet with 2x2 grid + paste field.
- `FitTracker/Views/Import/ImportPreviewView.swift` — preview screen with confidence icons and summary bar.

Both annotated on 2026-04-17 per audit finding UI-015. Quote from the file header: *"the production import flow (if revived) should use ImportOrchestrator from a new entry point built on current design system."*

### Deferred from PRD

- **IT-9 / IT-10 (Markdown paste)** — parser code landed (see `MarkdownImportParser`), paste-to-parse entry point did not (view was archived before wiring).
- **IT-11 (prompt preservation)** — not implemented; no field on `ImportedPlan` for the original AI prompt.
- **IT-12 (progressive alias learning)** — `ExerciseMapper.aliases` is `let`, not `var`; no `learn(alias:for:)` method as specified in the PRD architecture.
- **IT-13 (PDF text extraction)** — deferred to P1 follow-up; not implemented.
- **IT-14 (protocol + distinct types)** — shipped.
- **IT-15 (unit tests)** — shipped (23 tests total).
- **Analytics call sites** — event constants defined but `AnalyticsService.track(...)` not called from the orchestrator or views. The 6 events exist in the taxonomy but do not fire yet.
- **Commit to `TrainingProgramData`** — `ImportOrchestrator.confirmImport()` transitions to `.success(plan)` but does not persist to the training-program store. The ORCHESTRATOR.md-spec step "commit writes to existing TrainingProgramData" is a no-op today.
- **P2 items (IT-16 to IT-20)** — all deferred as planned.

---

## 6. Lessons

**1. "Phase complete" is not "feature live".** The state machine said `phase=complete` on 2026-04-16. The user could not import a training plan on 2026-04-16 — or today. The phase gate fired on "tasks implemented + BUILD SUCCEEDED" rather than "reachable from a tab". Later M-series features (M-1 through M-4) were more conservative about this — their completion required a merged PR with a visible entry point.

**2. The parser layer is durable; the UI layer was premature.** The parser + mapper + orchestrator stack is well-tested (23 tests), decoupled from SwiftUI, and reusable. When an actual entry point is designed (likely inside Training tab or Onboarding), it can instantiate `ImportOrchestrator()` directly and get a working state machine. The two archived views become UI reference material for that future work.

**3. Parallel stress-test dispatch works; validation-on-land doesn't come for free.** The v5.1 stress test executed 4 features' PRD + implementation in parallel and produced "3 consecutive clean builds under parallel load". That is a framework win. What it did not produce is integration: the views that landed weren't reachable, and no post-build step flagged that gap. The later v6.0 measurement framework added eval-coverage gates partly in response to this pattern.

**4. Audit-driven archival is cheaper than audit-driven deletion.** UI-015 chose to annotate the dead views rather than delete them. That choice paid off for this case study — the files still tell the story of what was attempted, and they still compile. A revival attempt does not need to reconstruct the view code from the PRD; it only needs a new parent view that instantiates `ImportSourcePickerView()` and wires a concrete `TrainingProgramData` write on confirm.

**5. Analytics constants without call sites is a taxonomy-only milestone.** The 6 `import_` events are a useful reservation — the names are locked, the prefix convention is honored — but the funnel is empty until the views are wired and the orchestrator calls `AnalyticsService.track(.importStarted, ...)` at transition points. Future revival should treat the call-site wiring as part of the first PR, not a follow-up.

---

## 7. Revival Path (if the feature is ever picked up again)

The cheapest revival is three changes:
1. Remove the `HISTORICAL —` headers from `ImportSourcePickerView.swift` and `ImportPreviewView.swift`.
2. Add a new entry point in the Training tab (e.g. a menu item "Import plan...") that presents `ImportSourcePickerView()`.
3. Wire `ImportOrchestrator.confirmImport()` to actually persist to `TrainingProgramData` (currently it only transitions state).

The parser + mapper + orchestrator + tests all still work. The 6 analytics events are already reserved. Design-system compliance was already enforced at the v1 view (tokens, spacing, typography all in place). The gap is entirely in wiring.

---

## 8. Links

- State: `.claude/features/import-training-plan/state.json`
- PRD: `docs/product/prd/import-training-plan.md`
- Research: `.claude/features/import-training-plan/research.md`
- Tasks: `.claude/features/import-training-plan/tasks.md`
- UX spec: `.claude/features/import-training-plan/ux-spec.md`
- Code — parsers: `FitTracker/Services/Import/ImportParser.swift`
- Code — mapper: `FitTracker/Services/Import/ExerciseMapper.swift`
- Code — orchestrator: `FitTracker/Services/Import/ImportOrchestrator.swift`
- Code — views (archived): `FitTracker/Views/Import/ImportSourcePickerView.swift`, `FitTracker/Views/Import/ImportPreviewView.swift`
- Tests: `FitTrackerTests/ImportTests.swift`, `FitTrackerTests/ImportEdgeCaseTests.swift`
- Analytics: `FitTracker/Services/Analytics/AnalyticsProvider.swift` (lines 232-242)
- Companion case study: `docs/case-studies/v5.1-parallel-stress-test-case-study.md` (the stress-test run that shipped this feature's code)
- Sprint D (UI-015 archival): commit `0831f60` — "fix(auth+ds+ui): Sprint D — type-safe sessions + scrim token + dead view archival"
