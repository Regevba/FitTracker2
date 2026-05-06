# Import Training Plan — Persistence + Active-Plan Architecture (Research, 2026-05-06)

> Companion to `research.md` (2026-04-12). The original research note covered
> the user-facing problem (parsers, exercise mapping, AI paste support).
> This note covers the **persistence + active-plan + sync + GDPR + read
> fan-out architecture** that the original PRD claimed but never grounded.
>
> **Trigger:** Audit UI-015 (2026-04-20) flagged the feature as a partial
> ship. Resume attempt 2026-05-06 surfaced a structural gap: the PRD
> claimed `ImportOrchestrator` writes to `TrainingProgramData`, but
> `TrainingProgramData` is a `struct` with only `static let` fields
> (`Models/TrainingProgramData.swift:6`). It has no write path. Same for
> `TrainingProgramStore` (`Services/TrainingProgramStore.swift:13`) — it
> is a read-only delegate over the static lookup. There was no design for
> where imported plans live, how they replace the active program, how
> they sync, or how they integrate with GDPR Article 17/20.
>
> User decision (2026-05-06): pursue full Option C (persist + activate)
> via the proper PM lifecycle. Roll back to research; redesign first.

---

## 1. Persistence target: `EncryptedDataStore`

The canonical local-data store is `EncryptedDataStore`
(`Services/Encryption/EncryptionService.swift:777`). It owns 5
`@Published` collections, persisted as 5 encrypted `.ftenc` files via a
two-phase atomic commit (`logs`, `snaps`, `profile`, `mealTemplates`,
`userPreferences`).

**Decision:** add a 6th collection `importedTrainingPlans:
[ImportedTrainingPlan]` and a 6th file `importedTrainingPlans.ftenc`,
following the existing pattern verbatim. Touch points:

| File | Change |
|---|---|
| `EncryptionService.swift:779-792` (`@Published` block) | + `@Published var importedTrainingPlans: [ImportedTrainingPlan] = []` |
| `EncryptionService.swift:803-812` (`clearInMemory()`) | + `importedTrainingPlans = []` |
| `EncryptionService.swift:814-827` (`deletePersistedData()`) | + `"importedTrainingPlans"` to the file sweep list |
| `EncryptionService.swift:971-1025` (`attemptPersist()`) | + encrypt + write `importedTrainingPlans` (extends the `writes:` array; rest of two-phase commit unchanged) |
| `EncryptionService.swift:1027-1062` (`loadFromDisk()`) | + decrypt + restore `importedTrainingPlans` |

**Rationale:** consistency with the existing pattern. Anything else
(separate store, UserDefaults stub, ad-hoc file) creates a parallel
persistence path that drifts under refactors and duplicates
two-phase-commit complexity.

## 2. Domain model

The on-disk type is **not** `ImportedPlan` directly. `ImportedPlan` is the
parser-output transient that flows through `ImportOrchestrator`. The
on-disk type is a richer wrapper that carries identity, provenance, and
the user's day-assignment decision:

```swift
struct ImportedTrainingPlan: Identifiable, Codable, Equatable {
    let id: UUID                              // stable identity
    var name: String                          // user-editable
    let createdAt: Date
    var lastModified: Date
    let source: ImportSource                  // .csv / .json / .markdownPaste / .pdf (P2)
    let sourceText: String?                   // raw input — for audit + regenerate
    var days: [ImportedDayAssignment]         // see below
    var isActive: Bool                        // exactly one plan can be active at a time
    var needsSync: Bool                       // CloudKit/Supabase sync flag (Phase 2)
}

struct ImportedDayAssignment: Codable, Equatable {
    let originalDayName: String               // "Day 1 — Push" from parser
    var assignedDayType: DayType              // .upperPush / .lowerBody / etc.
    var exercises: [ImportedExerciseEntry]
}

struct ImportedExerciseEntry: Codable, Equatable {
    let rawName: String                       // user-typed
    var mappedExerciseId: String?             // FitMe 87-exercise lib match (≥ reviewThreshold)
    var mappingConfidence: Double?            // 0.0–1.0 from ExerciseMapper
    var sets: Int
    var reps: String
    var restSeconds: Int?
    var displayName: String {                 // computed: prefer mapped library entry
        if let id = mappedExerciseId,
           let def = TrainingProgramData.allExercises.first(where: { $0.id == id }) {
            return def.name
        }
        return rawName
    }
}

enum ImportSource: String, Codable {
    case csv, json, markdownPaste, pdf, photo, share
}
```

**Why a separate on-disk type, not just `ImportedPlan` directly:**

1. **Day assignment is post-parse user input.** The parser produces
   `ImportedDay { name: "Day 1 — Push" }`. The user's confirm step
   assigns each parser-day to a `DayType` enum. That assignment is part
   of the saved record.
2. **Identity matters.** Multiple imports of the same plan need stable
   IDs so analytics (`import_plan_opened`) and active-plan switching can
   distinguish them.
3. **`isActive` is a per-plan flag, not a global setting.** This makes
   "deactivate" trivial (set false; no other plan auto-activates).
4. **Provenance for audit.** Storing `sourceText` lets the AI prompt
   regenerate flow (P2) work without re-asking the user for the text.
   Optional — user can decline at import time per privacy section.

## 3. Active-plan switching (Training tab read fan-out)

Currently `TrainingPlanView.exercisesForSelectedDay`
(`Views/Training/v2/TrainingPlanView.swift:34`) calls
`TrainingProgramData.exercises(for: selectedDay)` directly, bypassing
`TrainingProgramStore`.

**Refactor:**

| Layer | Change |
|---|---|
| `TrainingProgramStore` | Becomes the routing layer. Gains `@Published var activePlanId: UUID?`. Existing API `exercises(for: day)` checks `activePlanId`: nil → bundled (current behavior); non-nil → look up plan in `EncryptedDataStore.importedTrainingPlans`, find the `ImportedDayAssignment` matching `day`, convert each `ImportedExerciseEntry` to an `ExerciseDefinition` view, return. |
| `TrainingProgramStore.activatePlan(_ id: UUID?)` | Setter; persists via `EncryptedDataStore` write. Mutually exclusive: setting active flips all `isActive=true` to false, then sets the chosen one. nil = restore bundled default. |
| `TrainingPlanView.exercisesForSelectedDay` | Switch to `programStore.exercises(for: selectedDay)` (already injected as `@EnvironmentObject`). |

**`ImportedExerciseEntry → ExerciseDefinition` adapter:** for entries
where `mappedExerciseId != nil`, lookup is direct (use the bundled
exercise's full metadata: equipment type, muscle groups, instruction
text). For unmapped entries, synthesize a `userImported` exercise
definition with the raw name + sets/reps + rest, blank instruction
text, equipment type `.unknown`, muscle groups `[.unknown]`. The user
can later edit these via the imported-plans editor (Phase 2 polish, not
this resume's scope).

**Day-name → DayType heuristic:**

```
"push", "chest", "shoulder press"   → .upperPush
"pull", "back", "row"               → .upperPull
"leg", "squat", "deadlift"          → .lowerBody
"full body", "total body"           → .fullBody
"cardio", "run", "bike"             → .cardioOnly
"rest", "off"                       → .restDay
otherwise                           → round-robin assignment
```

User reviews + edits the assignment in the import preview screen before
confirming. Heuristic is a starting point, not authoritative.

## 4. Sync semantics (Phase 1 vs Phase 2)

**Phase 1: on-device only.** `needsSync` flag exists on the model but
no sync wiring runs. `CloudKitSyncService` and `SupabaseSyncService`
are not modified. This matches how `mealTemplates` ships today (BE-012
shows it has digest-based singleton sync but NOT per-record record sync
on the same path as `dailyLogs` / `weeklySnapshots`).

**Phase 2 (deferred to a follow-up feature):** add CloudKit per-record
record + Supabase `imported_training_plans` table + reconciliation
logic. Tracked as a known gap in this feature's case study, opened as a
separate PRD when prioritized.

**Why defer:** sync semantics for imported plans are non-trivial. If
device A and device B both import a plan, are they two plans or one?
What if names match but content differs? These questions are worth a
separate PRD. Phase 1 doesn't depend on the answer.

## 5. GDPR Article 17 (deletion) + Article 20 (export) integration

**Article 17 (right to erasure)** — already covered for free once
`importedTrainingPlans.ftenc` is added to
`EncryptedDataStore.deletePersistedData()` and `clearInMemory()`. The
existing `AccountDeletionService.swift:151` calls
`dataStore.deletePersistedData()`, which transitively wipes the new
file.

**Article 20 (data portability)** — requires updates to
`DataExportService.swift`:

| Location | Change |
|---|---|
| `DataExportService.swift:34` (counts list) | + `("Imported Plans", dataStore.importedTrainingPlans.count)` |
| `DataExportService.swift:62` (JSON encoder dict) | + `"importedTrainingPlans": encodeImportedTrainingPlans()` |
| New helper method | `encodeImportedTrainingPlans() -> [[String: Any]]` mirroring `encodeDailyLogs()` shape |

Both Articles are in-scope for Phase 1. They're a simple delta on top
of the persistence wiring.

## 6. Analytics: 8 PRD events vs 6 code constants

The PRD's Analytics Spec defines 8 events; `AnalyticsProvider.swift`
defines 6 constants
(`AnalyticsProvider.swift:254-264`). The 2 missing constants are:

- `import_parse_failed` — fires on parser failure (distinct from
  `import_failed`, which is the user-cancelled / unrecoverable umbrella)
- `import_plan_opened` — fires when user opens an imported plan within
  7 days of import; this is the primary plan-adoption signal

Decision: add both constants to `AnalyticsProvider.swift` in Phase 4 +
fire them at the right call sites (parser-throw path, imported-plan
list-tap path). The 7-day-since-import attribution lives in the event
payload (`days_since_import` parameter), computed at fire time from
`createdAt`.

## 7. UI surfaces (input to Phase 3 UX spec)

Two **entry points** (per user direction 2026-05-06: "both"):

1. **Settings → Data & Sync → Imported Plans** — list view + sheet to
   open `ImportSourcePickerView`. Shows imported plans (name, source,
   created date, "Active" badge). Tap → preview view with edit/activate/
   delete actions.
2. **Training tab toolbar** — `square.and.arrow.down` icon button next
   to the existing focus-mode eye. Opens `ImportSourcePickerView` as a
   sheet directly.

One **list surface** (new screen):

- **Imported Plans List** at `Settings → Data & Sync → Imported Plans`.
  Empty state: "No imported plans yet" + "Import a plan" CTA. Active
  plan shown with badge. Each row: name, source icon, day count,
  exercise count, "Active" badge if applicable.

One **detail surface** (new screen):

- **Imported Plan Detail** — repurposes `ImportPreviewView` in a "view"
  mode (no Confirm CTA). Adds: rename, activate/deactivate, delete.

These surface decisions are **inputs** to Phase 3 UX spec; the spec is
where they get fully detailed (states, accessibility, motion).

## 8. Identified gaps in the existing PRD

These will be filled in the rewritten PRD (Phase 1):

| # | Existing PRD says | Reality |
|---|---|---|
| 1 | "ImportOrchestrator writes to TrainingProgramData" | Structurally impossible — TrainingProgramData is a static struct. Must be `EncryptedDataStore.importedTrainingPlans`. |
| 2 | OQ-1: "add alongside; user picks active plan separately" | "Where does the imported list live, what activates it, how does the read path swap" was unaddressed. New section: §Persistence + Active-Plan Switching. |
| 3 | OQ-2: max import file size 1 MB | Reasonable; carry forward. |
| 4 | "All `import_*` analytics events are consent-gated" + 8 events listed | Code only has 6 constants. New section: §Analytics — adds the 2 missing constants. |
| 5 | "import_plan_opened: User opens an imported plan within 7 days" | No surface in app to open an imported plan from. New surface: Imported Plans list view (Settings → Data). |
| 6 | "Privacy & Data: Imported files are parsed in-memory; file contents are not sent to any server" | Carry forward. Add: encryption-at-rest is automatic via EncryptedDataStore (no separate plumbing). |
| 7 | "GDPR Article 17/20: imported_* events are consent-gated" | True for events, but PRD did not address Article 17/20 for the persisted plans themselves. New section: §GDPR Integration. |
| 8 | "Plan adoption rate = `import_plan_opened` / `import_completed`" | Requires the Imported Plans list view to exist. New surface added; metric becomes computable. |

## 9. Decision summary (carry into PRD)

| Decision | Resolution |
|---|---|
| Persistence target | `EncryptedDataStore.importedTrainingPlans` + new `.ftenc` file |
| Domain model | `ImportedTrainingPlan` (Identifiable, Codable) wrapping `[ImportedDayAssignment]` |
| Active-plan switching | `TrainingProgramStore.activePlanId: UUID?`; `exercises(for:)` becomes the routing layer; `TrainingPlanView` reads from store, not static |
| Day mapping | Heuristic at parse time, user-editable in preview, persisted as `assignedDayType` |
| CloudKit/Supabase sync | Deferred to Phase 2 follow-up. `needsSync` flag exists on model; no wiring. |
| GDPR Article 17 | Free via `EncryptedDataStore.deletePersistedData()` once 6th file added |
| GDPR Article 20 | Add 1 row to count list + 1 entry to JSON dict + 1 helper method in `DataExportService.swift` |
| Analytics events | Add 2 missing constants (`import_parse_failed`, `import_plan_opened`); wire all 8 |
| Entry points | (1) Settings → Data → Imported Plans (with list view); (2) Training tab toolbar |
| New surfaces | Imported Plans List + Imported Plan Detail (the existing `ImportPreviewView` reused in view-mode) |
| Phase 1 scope | Persist + Activate + GDPR + analytics + read fan-out + 2 entry points + 1 list view + 1 detail view |
| Deferred to Phase 2 | CloudKit/Supabase sync; per-day editor for unmapped exercises; AI prompt regeneration; PDF / photo / share-extension import sources |

## 10. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Adding a 6th `.ftenc` file breaks two-phase commit semantics | Low | Pattern is loop-driven; adding a 6th entry to the `writes:` array is isomorphic to existing 5. Add unit test covering 6-collection persistence round-trip. |
| `TrainingProgramStore.exercises(for:)` becomes a hot path with the new conditional | Low | Conditional is `activePlanId == nil` check; bundled path is identical. Imported path is `O(days)` lookup. Negligible. |
| `ImportedExerciseEntry` with no `mappedExerciseId` shows as a synthesized "user-defined" entry that has no instruction text or muscle metadata | Medium | Phase 1: surface as bare entries; user warned at confirm time. Phase 2: per-day editor lets user fix mappings post-import. |
| User imports plan with wildly different day structure (e.g. 4-day split) than the bundled 6-day | Medium | The bundled `DayType` enum has 6 values. Multi-day imported plans get day-name → DayType mapping; collisions are allowed (e.g. two days both map to `.upperPush`). User reviews assignment in preview. |
| GDPR delete leaves orphaned `importedTrainingPlans.ftenc` if added to `attemptPersist` but forgotten in `deletePersistedData` | High if forgotten | Pre-merge checklist: every new collection touches both. Unit test verifies deletion sweep is exhaustive. |
| Silent-pass on phase resume (this very feature's history!) | High if not careful | This is exactly the PRD-vs-reality gap that audit UI-015 caught. Fix: rewritten PRD must reference this research note + each touch-point file:line, and Phase 6 review must spot-check that the implementation matches the PRD claims. |

## 11. Phase 1 PRD outline (pre-written)

The Phase 1 PRD will replace the existing
`docs/product/prd/import-training-plan.md` with these sections:

1. Problem & user need (carry forward, condensed)
2. Scope: Phase 1 (this resume) vs Phase 2 (sync + AI regenerate + non-text sources) — explicit
3. **§Persistence + Active-Plan Switching** (new — sources §1, §2, §3 of this research)
4. **§GDPR Integration** (new — sources §5)
5. **§Sync semantics: deferred** (new — sources §4)
6. **§Analytics Spec** (rewritten — 8 events + 2 new constants + 7-day-window attribution)
7. **§UI surfaces + entry points** (new — sources §7)
8. Success metrics + kill criteria (carry forward, retune target if needed once persistence-cost data lands)
9. Test & eval requirements (new — must include 6-collection persistence round-trip + GDPR-delete-sweep coverage + active-plan-switch read-fan-out)
10. Risk register (sources §10)
11. Open questions (any remaining; expect 1–2 small ones)

---

## 12. Resolution

This research note closes the architectural gap that the original
research + PRD left open. The structural error in the original PRD
(persistence target = `TrainingProgramData`) is a documented honesty
finding — recorded both here and in the rewritten PRD's "Lessons"
section.

Phase 0 (Research) ready for user approval. On approval → Phase 1
(rewrite PRD per §11 outline) → Phase 2 (re-decompose tasks) → Phase 3
(re-validate UX spec; the existing one covers the source picker +
preview but doesn't cover the Imported Plans List view).
