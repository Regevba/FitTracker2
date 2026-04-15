# Import Training Plan — Task Breakdown

**PRD:** `docs/product/prd/import-training-plan.md`
**Estimated effort:** 8.0 days
**Critical path:** T1 → T4 → T5 → T6 → T8 → T9 → T13

## Tasks

| ID | Title | Type | Skill | Effort | Depends On | Status |
|---|---|---|---|---|---|---|
| T1 | ImportParser protocol + CSVImportParser | model/service | dev | 1.0d | — | pending |
| T2 | JSONImportParser | service | dev | 0.5d | T1 | pending |
| T3 | MarkdownImportParser (AI conversation paste) | service | dev | 1.0d | T1 | pending |
| T4 | ExerciseMapper with alias dictionary (87 exercises) | model | dev | 1.0d | — | pending |
| T5 | 3-tier confidence scoring (auto ≥0.95, review 0.70-0.94, manual <0.70) | model | dev | 0.5d | T4 | pending |
| T6 | ImportOrchestrator (detect → parse → map → preview → commit) | service | dev | 0.5d | T1, T4 | pending |
| T7 | ImportSourcePickerView (file picker + paste field) | ui | dev | 0.5d | — | pending |
| T8 | ImportPreviewView (mapped exercises + confirm/edit) | ui | dev | 1.0d | T5, T6 | pending |
| T9 | Wire imported plan into TrainingProgramStore | service | dev | 0.5d | T6 | pending |
| T10 | 6 analytics events (import_ prefix) | analytics | analytics | 0.25d | — | pending |
| T11 | Unit tests for parsers + mapper | test | qa | 1.0d | T1-T5 | pending |
| T12 | PDF text extraction (P1) | service | dev | 0.5d | T1 | pending |
| T13 | Build verification + pbxproj | test | dev | 0.25d | all | pending |
