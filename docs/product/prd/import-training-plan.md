# PRD: Import Training Plan

> **ID:** import-training-plan | **Status:** Approved | **Priority:** HIGH
> **Last Updated:** 2026-04-15 | **Branch:** feature/import-training-plan (pending)

---

## Purpose

Allow users to bring training plans from external sources — CSV/JSON exports, spreadsheets, coach PDFs, AI-generated programs, and pasted text — into FitMe as native plans, eliminating migration friction and removing a major adoption barrier.

## Problem Statement

FitMe has a strong training experience, but it assumes users start fresh. The reality is that a large portion of motivated fitness users already have a plan:

- Athletes migrating from Hevy or Strong have CSV/JSON exports they cannot use
- Coach clients receive plans as spreadsheets, PDFs, or WhatsApp messages
- AI-native users generate training programs via ChatGPT, Claude, or Gemini and want to run them in a tracking app
- Manual re-entry is so tedious that many users choose to stay in the app they know rather than migrate to a better one

The gap is not missing exercises or features — it is that every new FitMe user with an existing plan has to throw it away. Import removes that barrier.

## Business Objective

Reduce new-user churn caused by plan re-entry friction. Convert users who already have a coach or AI-generated plan into active FitMe plan followers within their first session. A user who imports a plan on day one has an existing commitment to that structure; converting that commitment into FitMe adoption is high-leverage.

---

## Success Metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Import success rate (produces usable plan, no manual fix required) | 0% (no system today) | ≥ 80% | < 30% after 30 days → simplify to CSV-only |
| Exercise mapping accuracy (auto-match to 87-exercise library) | 0% | ≥ 90% | < 70% (trust broken) |
| Time to first usable imported workout | N/A | < 5 min end-to-end | > 15 min median |
| Plan adoption rate (imported plan used within 7 days) | 0% | ≥ 60% of importers | < 25% at 30 days |
| User satisfaction rating on import experience | N/A | ≥ 4/5 in-app rating | ≤ 3/5 median |

**North Star:** import-attributed WAU trending up; mapping accuracy stable or improving over time as alias dictionary grows.

**Post-launch review cadence:** 2 weeks after first 50 imports, then monthly.

---

## Requirements

### P0 — Must Ship

| ID | Requirement | Notes |
|---|---|---|
| IT-1 | CSV parser: accept Hevy/Strong export format + generic `exercise, sets, reps, rest` columns | Auto-detect column headers; fail gracefully on unknown schemas |
| IT-2 | JSON parser: accept structured workout JSON (nested day/exercise/sets objects) | Schema-tolerant — required fields only: exercise name, sets, reps |
| IT-3 | Exercise name mapper: fuzzy-match imported exercise names to FitMe's 87-exercise library via alias dictionary | Alias dictionary seeded with common variants (e.g. "Bench" → "Barbell Bench Press") |
| IT-4 | Confirmation UI: display all mapped and unmapped exercises before committing the import | Auto-accept high-confidence matches (≥ 0.9); surface ambiguous matches for user review |
| IT-5 | Plan structure import: preserve day splits, sets, reps, rest periods, and day names (Push/Pull/Legs/Upper/Lower etc.) | Map to existing TrainingDay/ExerciseSet models |
| IT-6 | Unmatched exercise handling: allow user to manually select from library or skip | Skipped exercises excluded from final plan |
| IT-7 | Import preview screen: show full imported structure before save, with edit capability | User must tap "Save Plan" to commit |
| IT-8 | Analytics instrumentation for all import events (see Analytics section) | Consent-gated via existing ConsentManager |

### P1 — Target Sprint

| ID | Requirement | Notes |
|---|---|---|
| IT-9 | Markdown/structured text parser: parse numbered lists, markdown tables, and day-header prose blocks | Covers ChatGPT, Claude, Gemini, and coach-formatted outputs |
| IT-10 | AI conversation paste flow: dedicated paste-to-parse entry point with format auto-detection | Detect markdown table vs. numbered list vs. prose block |
| IT-11 | Prompt preservation: optional field to save the original AI prompt used to generate the plan | Stored alongside plan; surfaced in plan detail for regeneration |
| IT-12 | Progressive mapping: auto-improve alias dictionary when user manually corrects a mapping | Persisted per-user via UserDefaults; included in export for debugging |
| IT-13 | PDF text extraction: extract plain text from a PDF and pass to existing parser pipeline | Reuse OCR infrastructure from nutrition feature if available |
| IT-14 | ImportParser protocol + CSV/JSON/Markdown implementations as distinct conforming types | Each parser is independently testable |
| IT-15 | Unit tests: CSV parser, JSON parser, ExerciseMapper alias resolution, ambiguous match detection | |

### P2 — Later / Stretch

| ID | Requirement | Notes |
|---|---|---|
| IT-16 | Photo OCR: parse handwritten or printed workout sheets from camera/photo library | Requires Vision framework integration |
| IT-17 | iOS Share Extension: import from any app (Hevy, Notes, Files) via the iOS share sheet | Separate extension target; significant scope |
| IT-18 | AI prompt re-run: regenerate variations of the imported plan using FitMe's AIOrchestrator | "Same plan but dumbbell substitutions" → requires AIOrchestrator integration |
| IT-19 | Phase/mesocycle structure import: accumulation, intensification, deload week flagging | Requires extending TrainingPlan model |
| IT-20 | RPE-based progression import: parse and store RPE targets alongside set prescriptions | Requires RPE field in ExerciseSet model |

---

## Supported Import Sources

| Source | Phase | Parser | Entry Point |
|---|---|---|---|
| Strong / Hevy CSV export | P0 | CSVImportParser | Files picker / share sheet |
| Generic spreadsheet CSV | P0 | CSVImportParser | Files picker |
| Structured workout JSON | P0 | JSONImportParser | Files picker |
| ChatGPT / Claude / Gemini output (paste) | P1 | MarkdownImportParser | Paste-to-parse flow |
| Coach text / numbered list | P1 | MarkdownImportParser | Paste-to-parse flow |
| Notion fitness template (markdown table) | P1 | MarkdownImportParser | Paste-to-parse flow |
| PDF (text-based) | P1 | PDFTextExtractor → parser pipeline | Files picker |
| Photo / handwritten whiteboard | P2 | VisionOCR → parser pipeline | Camera / photo library |
| iOS Share Extension | P2 | All parsers | Native share sheet |

---

## Exercise Mapping

### Alias Dictionary

The `ExerciseMapper` holds a flat alias dictionary mapping common name variants to canonical FitMe exercise IDs. Example entries:

```
"Bench" → "barbell_bench_press"
"Flat Bench Press" → "barbell_bench_press"
"Incline DB Press" → "dumbbell_incline_bench_press"
"Pull-up" → "pull_up"
"Chin Up" → "chin_up"
"OHP" → "overhead_press_barbell"
"Squat" → "barbell_back_squat"
"RDL" → "romanian_deadlift"
```

Phase 1 target: ≥ 150 aliases covering all 87 library exercises with 1–3 variants each.

### Match Confidence Tiers

| Tier | Confidence | Action |
|---|---|---|
| Exact / alias match | ≥ 0.95 | Auto-accept, shown as confirmed in preview |
| Fuzzy match (Levenshtein / token overlap) | 0.70–0.94 | Shown in preview with suggested match; user taps to confirm or change |
| No match | < 0.70 | Flagged as unresolved; user must pick from library or skip |

---

## Technical Approach

### Architecture

```
ImportParser (protocol)
  ├── CSVImportParser: ImportParser
  ├── JSONImportParser: ImportParser
  └── MarkdownImportParser: ImportParser

ExerciseMapper
  ├── aliasDict: [String: ExerciseID]         // seeded + user-extended
  ├── resolve(_ name: String) → MappingResult  // .exact / .fuzzy(score) / .unmatched
  └── learn(alias: String, for: ExerciseID)    // progressive improvement

ImportOrchestrator
  ├── detect(input:) → ImportFormat            // auto-detect CSV / JSON / Markdown
  ├── parse(input:format:) → RawImportedPlan
  ├── map(plan:) → MappedImportResult          // runs ExerciseMapper on all exercises
  └── commit(result:) → TrainingPlan           // writes to existing TrainingProgramData

ImportPreviewView (SwiftUI)
  ├── Confirmed exercises list (auto-matched)
  ├── Review section (ambiguous matches — user confirms or changes)
  ├── Unresolved section (user picks from library or skips)
  └── "Save Plan" CTA → ImportOrchestrator.commit()

ImportSourcePickerView (SwiftUI)
  ├── "From Files" (CSV / JSON / PDF)
  ├── "Paste Text" (markdown / AI conversation)
  └── "Camera" (P2, photo OCR)
```

### Key Files (to be created)

| File | Purpose |
|---|---|
| `FitTracker/Services/Import/ImportParser.swift` | Protocol + shared types (RawImportedPlan, MappingResult) |
| `FitTracker/Services/Import/CSVImportParser.swift` | CSV parser implementation |
| `FitTracker/Services/Import/JSONImportParser.swift` | JSON parser implementation |
| `FitTracker/Services/Import/MarkdownImportParser.swift` | AI/text parser implementation (P1) |
| `FitTracker/Services/Import/ExerciseMapper.swift` | Alias dictionary + fuzzy matching |
| `FitTracker/Services/Import/ImportOrchestrator.swift` | Orchestrates detect → parse → map → commit |
| `FitTracker/Views/Import/ImportSourcePickerView.swift` | Entry point: source selection sheet |
| `FitTracker/Views/Import/ImportPreviewView.swift` | Confirmation UI: review + commit |
| `FitTracker/Tests/ImportParserTests.swift` | CSV, JSON, Markdown parser unit tests |
| `FitTracker/Tests/ExerciseMapperTests.swift` | Alias resolution + fuzzy match tests |

### Integration Point

`ImportOrchestrator.commit()` writes to `TrainingProgramData`, the existing training plan store. Imported plans are tagged with `source: .imported` to distinguish them from built-in plans. Original import payload (raw string or file reference) is stored alongside the plan for debugging and P2 AI regeneration.

---

## Analytics Events

All events use the `import_` prefix per the project analytics naming convention.

| Event | Trigger | Key Parameters |
|---|---|---|
| `import_started` | User opens import entry point | `entry_point` (training_tab / onboarding / settings) |
| `import_source_selected` | User picks an import source | `source` (csv / json / pdf / paste / camera) |
| `import_parsed` | Parser completes successfully | `source`, `exercise_count`, `day_count`, `parse_duration_ms` |
| `import_parse_failed` | Parser fails or returns empty result | `source`, `error_reason` |
| `import_mapping_confirmed` | User taps confirm on the preview screen | `auto_matched_count`, `manual_confirmed_count`, `skipped_count`, `unresolved_count` |
| `import_completed` | Plan saved to TrainingProgramData | `source`, `total_exercises`, `skipped_exercises`, `time_to_complete_ms` |
| `import_failed` | Import aborted (user cancelled or unrecoverable error) | `source`, `step` (parse / mapping / save), `reason` |
| `import_plan_opened` | User opens an imported plan within 7 days of import | `days_since_import`, `source` |

> `import_completed` is the primary conversion signal. Plan adoption rate = `import_plan_opened` (within 7 days) / `import_completed`.

---

## Dependencies

| Dependency | Status | Notes |
|---|---|---|
| `TrainingProgramData.swift` | Shipped | Exercise library (87 exercises) + plan storage; ImportOrchestrator writes to this |
| `AnalyticsService` | Shipped | ConsentManager gates all events |
| `AppTheme` design tokens | Shipped | ImportPreviewView uses existing semantic tokens |
| OCR infrastructure (nutrition feature) | Shipped | PDF text extraction (P1) reuses this path |
| `AIOrchestrator` / `FoundationModelService` | Shipped | Required for P2 prompt re-run only |
| Vision framework (Apple) | Available | Required for P2 photo OCR only |

---

## Privacy & Data

- Imported files are parsed in-memory; file contents are not sent to any server
- Original import payload (raw text or file reference) is stored on-device only
- `import_*` analytics events are consent-gated via `ConsentManager`
- No exercise or plan data is included in analytics payloads — only counts and durations
- AI prompt preservation (P1) is opt-in; stored in UserDefaults on-device

---

## Open Questions

| # | Question | Owner | Resolution |
|---|---|---|---|
| OQ-1 | Should imported plans replace the active plan or be added alongside it? | PM | Default: add alongside; user picks active plan separately |
| OQ-2 | What is the max import file size to accept before showing a warning? | Eng | Propose 1 MB for Phase 1 (covers all realistic CSV/JSON exports) |
| OQ-3 | Should the alias dictionary be seeded from a remote source or bundled? | Eng | Bundle in Phase 1; remote update path deferred to P2 |
| OQ-4 | If a PDF has both text and images (e.g. exercise illustrations), do we parse the text only? | Eng | Text only in P1; image-based exercise detection deferred to P2 OCR pass |
| OQ-5 | Should AI prompt preservation be shown as a visible field in plan detail, or hidden in metadata? | Design | Requires UX spec decision in Phase 3 |
