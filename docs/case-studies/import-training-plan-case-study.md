---
case_id: import-training-plan
case_study_type: feature
work_type: feature
framework_version: v7.8
slug: import-training-plan
title: "Import Training Plan — Resume from Audit-Flagged Partial Ship to Full Phase 1 Ship in 14 Hours"
date: '2026-05-06'
shipped_window: '2026-05-06 (single-session resume)'
external_audit_status: pending
upstream_path: docs/case-studies/import-training-plan-case-study.md
key_numbers:
  - label: "PRs landed"
    value: "4"
    tier: T1
    note: "FT2 #234 (feature) + #235 (skill upgrade) + #236 (backlog cleanup) + fitme-story #48 (skill reflection)"
  - label: "Tasks done"
    value: "18 / 18"
    tier: T1
    note: "15 E-core + 3 P-core, all green; tracked in state.json::tasks[]"
  - label: "Tests added"
    value: "33"
    tier: T1
    note: "T4 (persistence) + T6 (routing) + T8 (orchestrator) + T10 (GDPR) + 11 analytics tests; 49/49 import-related suites pass"
  - label: "P0 spec errors caught"
    value: "4"
    tier: T1
    note: "By the user-ordered pre-Phase-4 audit BEFORE any code was written; saved 2-4h of compile-error rework"
  - label: "Wall-clock time"
    value: "~14 hours"
    tier: T2
    note: "Single resume session 2026-05-06; original Phase 1 attempt ran ~12h on 2026-04-15 and shipped a partial-ship that audit UI-015 flagged"
  - label: "Figma surfaces auto-built"
    value: "4"
    tier: T1
    note: "First-ever v4.X /design build auto-dispatch run; page 916:2 + 4 frames in design system library 0Ai7s3fCFqR5JXDW8JvgmD"
---

# Import Training Plan — Resume from Audit-Flagged Partial Ship to Full Phase 1 Ship in 14 Hours

## TL;DR

The import-training-plan feature originally shipped 2026-04-16 as a partial-ship: parser + mapper + orchestrator + 23 unit tests landed cleanly, but the source-picker and preview views were never wired into navigation and `confirmImport()` was a no-op stub. Audit UI-015 (2026-04-20) caught it. Resume attempt 2026-05-06 then surfaced a deeper structural error: the original PRD claimed `ImportOrchestrator` writes to `TrainingProgramData` — structurally impossible because `TrainingProgramData` is a `struct` with only `static let` fields. The honest path was a mid-flight rollback to research, a rewritten PRD against the actual persistence target (`EncryptedDataStore.importedTrainingPlans`), and a re-decomposed task list.

The same session also produced a v4.X skill-layer upgrade as a meta-byproduct: a user-ordered pre-Phase-4 audit caught 4 P0 spec errors that would have hit "no such symbol" at compile time (`AppRadius.pill`, `AppMotion.standardEase`, `SettingsActionLabel` with custom badge slot, toast component — all referenced by the spec, none in the codebase). The user requested promoting that audit pattern to a mechanical PM-workflow gate. The result is `/ux preflight` + `/design preflight` + `/ux pre-merge-review` + `/design pre-merge-review` + `/design build` auto-dispatch, all shipped in PR #235 and adopted by this feature on first run via Figma Option C.

**End state:** 4 PRs landed (FT2 #234 feature + #235 skill upgrade + #236 backlog + fitme-story #48 mirror), 18/18 tasks done, 33 new tests, 4 Figma frames auto-built into the FitMe Design System Library (the v4.X auto-dispatch flow's first production output), zero P0 in `make ui-audit`, all gates green.

## Architecture (locked, not re-litigated)

1. **Persistence target = `EncryptedDataStore.importedTrainingPlans`** — sixth `@Published` collection in the encrypted store, persisted via the existing 2-phase commit pattern. New file `importedTrainingPlans.ftenc`. Closes the structural PRD gap.
2. **Routing layer = `TrainingProgramStore`** — gains `activePlanId: UUID?`. `exercises(for:in:)` checks the flag; `nil` returns bundled program (existing behavior), non-`nil` returns synthesized `ExerciseDefinition`s from the active `ImportedTrainingPlan`. `activate(planId:dataStore:)` enforces mutual exclusion.
3. **Domain model = `ImportedTrainingPlan` (Identifiable, Codable)** — separate from the parser-transient `ImportedPlan`. Wraps `[ImportedDayAssignment]` (each carries `originalDayName`, user-editable `assignedDayType`, `[ImportedExerciseEntry]`). Provenance fields: `id` UUID, `name`, `createdAt`, `lastModified`, `source` enum, opt-in `sourceText`, `isActive`, `needsSync`.
4. **GDPR coverage** — Article 17 (delete) free transitively via `EncryptedDataStore.deletePersistedData()` extension. Article 20 (export) via 3 touch points in `DataExportService.swift`. Sync semantics deferred to Phase 2 (CloudKit/Supabase out of scope; `needsSync` flag exists on the model from day one).
5. **Two entry points** — Settings → Data → Imported Plans (NavigationLink card) + Training tab toolbar (`square.and.arrow.down` on `.topBarLeading`). Both present `ImportSourcePickerView` as a sheet.
6. **Three new UX surfaces** — `ImportedPlansListScreen` (4 states), day-assignment editor (extension to `ImportPreviewView` `.preview` mode), active-plan badge (Training tab insertion).

## What shipped

| Surface | Code file | Figma node | State |
| --- | --- | --- | --- |
| Domain model | `Models/ImportedTrainingPlan.swift` (new) | — | Live |
| Persistence | `Services/Encryption/EncryptionService.swift` (5 touch points) | — | Live |
| Active-plan routing | `Services/TrainingProgramStore.swift` (4 touch points incl. adapter) | — | Live |
| Orchestrator persistence | `Services/Import/ImportOrchestrator.swift` (heuristic + `confirmImport(into:)`) | — | Live |
| GDPR Art-20 export | `Services/DataExportService.swift` (3 touch points) | — | Live |
| 9 analytics events | `Services/Analytics/AnalyticsProvider.swift` + `AnalyticsService.swift` (8 new methods) | — | Live |
| Imported Plans List screen | `Views/Settings/v2/Screens/ImportedPlansListScreen.swift` (new) | [`919:2`](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=919-2) (populated active) + [`920:2`](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=920-2) (empty) | Live |
| `ImportedPlanRow` component | `Views/Settings/v2/Components/ImportedPlanRow.swift` (new) | — | Live |
| Day-Assignment Editor | `Views/Import/ImportPreviewView.swift` (`.preview` mode extension) | [`921:2`](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=921-2) | Live |
| Active-plan badge + toolbar Import | `Views/Training/v2/TrainingPlanView.swift` | [`922:2`](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD/FitTracker-Design-System-Library?node-id=922-2) | Live |

## Outcomes (tier-tagged)

| Dimension | Pre-resume | Post-resume | Tier |
| --- | --- | --- | --- |
| Audit UI-015 status | Open (partial ship) | Closed | T1 |
| Persistence path | None (`TrainingProgramData` is static; `confirmImport()` was no-op) | `EncryptedDataStore.importedTrainingPlans` (encrypted at rest, GDPR-compliant) | T1 |
| Active-plan switching | Impossible (Training tab read path was hardcoded against bundled lookup) | `TrainingProgramStore.activePlanId` is the routing flag | T1 |
| Entry points | 0 (views existed but unwired) | 2 (Settings list + Training toolbar) | T1 |
| Analytics | 6 constants, 0 wired | 9 events (3 new constants), 100% wired through consent gate | T1 |
| Test coverage | 23 unit tests on infra | 33 new tests across persistence + routing + orchestrator + GDPR + 11 analytics | T1 |
| Figma↔code sync | Never built | 4 frames auto-built via v4.X `/design build` | T1 |
| `make ui-audit` impact | n/a | 0 P0; +1 P1 (frame maxWidth: 280) on the new ImportedPlansListScreen | T1 |
| Net-new app patterns introduced | n/a | 3 (`.swipeActions`, `.contextMenu`, `ImportedPlanRow` bespoke row component) | T1 |

## Five honest disclosures

1. **The original PRD's persistence claim was structurally impossible.** v1 PRD said "ImportOrchestrator writes to TrainingProgramData" — but `TrainingProgramData` is a `struct` with only `static let` fields. No write path. The audit caught the partial ship; the resume caught the architectural gap. The fix was a full mid-flight rollback to research → rewritten PRD → re-decomposed tasks. Cost: ~1 day of wall-clock that wouldn't have been needed if the original PRD had referenced file:line touch points instead of just type names. The rewritten PRD now does, and Phase 6 review explicitly spot-checks them.

2. **The user-ordered pre-Phase-4 audit caught 4 P0 spec errors before any code was written.** `AppRadius.pill` (doesn't exist; real pattern is `Capsule()` shape), `AppMotion.standardEase` (doesn't exist; real container is `AppEasing`), `SettingsActionLabel` with custom badge slot (component is fixed-trailing, can't host inline badges), toast/snackbar component (doesn't exist in the codebase). Audit cost ~20 min; Phase 4 rework cost would have been ~2-4h. This pattern is now mechanical via `/ux preflight` + `/design preflight` (shipped in PR #235).

3. **The `/design build` Figma auto-dispatch was the v4.X chain's first production run.** The flow worked end-to-end on first invocation: preflight → MCP liveness check → page creation → 4 mobile-screen frames → node ID write-back → state.json + figma-code-sync-status.md updates → PR description gate satisfaction. One iteration was needed (Frame 3's `dayCard` had `primaryAxisSizingMode: "FIXED"` without explicit height, clipping rows 3-4; fixed by switching to `AUTO`). Final screenshot verified all 4 frames render correctly with semantic tokens — zero raw colors.

4. **Three patterns net-new to the codebase.** `.swipeActions`, `.contextMenu`, and a bespoke `ImportedPlanRow` component were never used in FitMe before this feature. They're now documented in `docs/design-system/feature-memory.md` as design-system evolutions. The audit identified them; they were kept (not invented arbitrarily — Jakob's Law for swipe actions, VoiceOver redundancy for context menu, badge-slot requirement for the row).

5. **Phase 2 sync is deferred.** CloudKit and Supabase per-record sync for imported plans is out of Phase 1 scope. The `needsSync: Bool` field exists on the model from day one so Phase 2 can opt records in without a schema migration. Documented as a known gap; tracked in the PRD's "Scope: Phase 1 vs Phase 2" section.

## Lessons for future features

1. **PRDs that name persistence targets must reference the actual write path (file:line), not just the type name.** v1 PRD said "writes to TrainingProgramData"; v2 says "writes to `EncryptedDataStore.importedTrainingPlans` via the existing 2-phase commit pattern, touch points: `EncryptionService.swift:779-1062` (5 locations)". The latter is verifiable by Phase 6 review; the former isn't.

2. **Pre-flight existence checks should be mechanical, not manual.** A spec that invokes `AppRadius.pill` without grep'ing the codebase is a silent-pass hazard. The `/ux preflight` + `/design preflight` gates added in v4.X (2026-05-06) catch this class of error before Phase 4 begins.

3. **Figma sync is part of Phase 3, not a "deferred follow-up".** Smart Reminders shipped 2026-04-29 with code-first; Figma followed manually weeks later. Push Notifications still pending. Import-Training-Plan was missed entirely until the user flagged it post-Phase-5. Auto-dispatching `/design build` at Phase 3.j (with a portable prompt fallback when MCP is down) makes Figma sync part of the contract.

4. **Honest scope rejection beats expanding ambition mid-resume.** When the persistence-layer architectural gap surfaced, three options were on the table: stub persistence (UserDefaults), encrypted persistence + read-only list, full Phase 1 (persist + activate). The user picked C. The honest path was to roll back to research and rewrite the PRD — not to expand ambition silently inside Phase 4. The 1-day rollback cost was net positive.

5. **`deferred` task status is honest, not failure.** Phase 2 sync is deferred with rationale and tracking — same pattern as UCC's T2.5 baseline upgrade (deferred for data-availability reasons). Better than (a) faking Phase 1 done with a sync stub, or (b) expanding scope mid-resume.

## Cross-cutting framework signals

- **v7.5 Data Integrity Framework (2026-04-24)** — All write-time gates fired correctly during the resume. PHASE_TRANSITION_NO_LOG + PHASE_TRANSITION_NO_TIMING gates flagged my early state.json edits before I had appended the corresponding log entries. Recovered by ordering: `append-feature-log.py` first, then state.json edit, then commit.
- **v7.6 Mechanical Enforcement (2026-04-25)** — Pre-commit hooks fired on every reconcile commit. Zero gate skirts.
- **v7.7 Validity Closure (2026-04-27)** — `cu_v2` schema was present from the original 2026-04-15 state.json; carried through. STATE_NO_CASE_STUDY_LINK satisfied by `case_study_showcase` field.
- **v7.8 Bridge (2026-05-02 → 2026-05-04)** — Session attribution via `.claude/active-feature` lockfile worked; PostToolUse:Read events accumulated into `.claude/logs/_session-*.events.jsonl`.
- **v4.X Skill-Layer Upgrade (2026-05-06 — this session)** — Shipped as a meta-byproduct. Promoted 4 audit patterns to mechanical gates. Phase 3 chain extended 7→11 steps; Phase 6 chain 4→5 steps. Phase 7 BLOCKED unless both pre-merge reviews pass. See [`docs/skills/evolution.md`](../skills/evolution.md) §26.

## Numbers in 2 sentences

4 PRs landed across 2 repos in a single ~14-hour session: FT2 #234 (Phase 1 ship), FT2 #235 (v4.X skill upgrade), fitme-story #48 (skill mirror), FT2 #236 (backlog cleanup). 18/18 tasks done, 33 new tests, 4 Figma frames auto-built (first v4.X production run), 0 P0 in ui-audit, 4 P0 spec errors caught before code was written.

## Where things go from here

- **Phase 2 follow-up PRD** (out of Phase 1 scope) — CloudKit per-record sync for imported plans + Supabase `imported_training_plans` table + per-day editor for unmapped exercises + AI prompt regeneration via `AIOrchestrator` + PDF / photo / share-extension import sources.
- **First post-launch metrics review** scheduled for 2026-05-13 (T+7d) — query GA4 for `import_started` → `import_completed` → `import_plan_activated` funnel; compute activation rate; verify the kill criteria thresholds aren't tripped.
- **Backfill `figma_node_ids` for already-shipped features** (Home v2, Onboarding, Smart Reminders, etc.) is now a normal part of the framework and will happen as features get touched.

## Closing

This feature is two case studies in one. The surface case study is the persistence + active-plan + GDPR architecture closing audit UI-015. The deeper one is how the framework caught a structural PRD error mid-flight, demanded honest rework, and emerged with a v4.X skill-layer upgrade that promotes 4 audit patterns to mechanical gates so the next feature doesn't relearn the same lesson. The trigger event (4 P0 spec errors) became the test case for the new gates within the same session — `/ux preflight` + `/design preflight` ran on this feature's spec the moment they shipped.

Full source case study + per-task notes + audit trail: [`.claude/features/import-training-plan/`](../../.claude/features/import-training-plan/). Showcase MDX: [`fitme-story/content/04-case-studies/23b-import-training-plan.mdx`](https://github.com/Regevba/fitme-story/blob/main/content/04-case-studies/23b-import-training-plan.mdx).
