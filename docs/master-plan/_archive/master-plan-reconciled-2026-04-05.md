> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# FitTracker2 Reconciled Master Plan

> Date: 2026-04-05
> Purpose: replace fragmented planning with one execution plan grounded in the current repo, build state, tests, and roadmap docs.
> Inputs: `docs/master-plan/master-backlog-roadmap.md`, `docs/superpowers/specs/2026-03-30-fittracker-master-plan-design.md`, `docs/product/PRD.md`, `docs/project/branch-review-2026-04-05.md`, current `main`, and fresh local verification.

---

## Executive Summary

The stored master plan is directionally strong but operationally optimistic. The repo now has a richer product surface than the original plan assumed, but the current implementation does not yet satisfy the implied readiness of several "shipped" areas.

The highest-priority work is not new feature delivery. It is stabilizing the foundation so the existing app can build, sync safely, delete user data correctly, and pass repeatable verification.

This plan keeps the original phase structure, but inserts a mandatory stabilization track ahead of all new product expansion.

---

## What Changed Since The Original Plans

The roadmap and design master plan correctly established:

- phase-gated execution
- design-system-first development
- backend and design work as parallel tracks
- delayed Android until the iOS foundation is stable
- documentation as a first-class deliverable

However, current repo verification shows gaps the older plans do not account for:

1. The iOS app initially did not build on a clean machine because `FirebaseCore` was imported in [`FitTrackerApp.swift`](../../FitTracker/FitTrackerApp.swift) without matching target linkage. That recovery work is now complete, but it was a real planning blocker at the start of this pass.
2. The sync schema in [`000005_sync_records.sql`](../../backend/supabase/migrations/000005_sync_records.sql) prevents more than one `daily_log` or `weekly_snapshot` row per user because of an over-broad unique constraint.
3. GDPR/account deletion is incomplete in code even though docs and changelog describe it as shipped.
4. Sign-out and session restore behavior are inconsistent with the intended auth model.
5. AI engine tests are failing, partly because of test expectations and partly because the current settings model hard-requires Supabase env vars.
6. The branch-review doc assumes branches that are not currently visible on the remote from a fresh clone. Current remote state shows only `main` and `claude/project-status-analysis-kaRO7`.

These are not minor cleanup items. They are plan-shaping constraints.

---

## Corrected Current Status

### Program Status

| Area | Stored Status | Corrected Status |
|---|---|---|
| Phase 0 foundation docs | Complete | Complete |
| README / product docs | Active or shipped | Shipped, but some claims are ahead of implementation |
| Design system direction | Active | Active, but should not outrun build and correctness fixes |
| Google Analytics | Shipped | Firebase linkage recovered and app now builds; runtime verification still needed because Firebase config files are not present in this clone |
| GDPR compliance | Shipped | Deletion flow is now wired for truthful local + Supabase + CloudKit deletion attempts, but still needs device/runtime verification and doc cleanup |
| Data sync | Shipped | Architecture exists, schema fix is staged in migration `000008`, and focused merge coverage is now in place; remaining gap is live signed-in end-to-end verification |
| AI engine | Shipped | Buildable and tests now pass with a self-contained harness; next need is CI hardening and broader coverage |
| Dashboard | Shipped | Buildable, tests passing, and source-health mismatch fix applied |
| Marketing website | Shipped | Buildable; not the current blocker |
| Android exploration | Partially shipped | Keep deferred until iOS foundation is green |

### Verification Snapshot

Fresh verification completed on 2026-04-06:

- `xcodebuild -list` succeeds with full Xcode
- `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS'` now passes after project, plist, and source-target recovery
- `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -only-testing:FitTrackerTests/FitTrackerCoreTests` now passes on simulator
- root token check passes
- dashboard tests pass
- dashboard production build passes
- marketing website production build passes
- AI engine tests pass
- `make verify-local` now passes end to end
- Python and Node environments can be provisioned successfully

### 2026-04-05 Execution Update

Work completed after the initial reconciliation:

- Firebase packages were linked into the Xcode target and the missing analytics/GDPR source files were added to the project.
- A replacement `Info.plist` was restored so the app can build again on a clean machine.
- Firebase bootstrap is now config-aware, so missing local `GoogleService-Info.plist` no longer crashes XCTest or clean builds.
- The exporter was reconciled with the current domain model shape.
- `restoreSession()` can now promote a valid stored session back to active auth state when biometric reopen is disabled.
- `signOut()` now revokes the local Supabase auth session instead of only clearing app-local state.
- Supabase deletion support was added for `sync_records`, `cardio_assets`, and private cardio image blobs.
- CloudKit deletion support was added for the private record types used by the app.
- Local encrypted `.ftenc` blobs and encryption keys now have explicit deletion paths.
- A new migration, [`000008_fix_sync_records_uniqueness.sql`](../../backend/supabase/migrations/000008_fix_sync_records_uniqueness.sql), stages the singleton-constraint repair for dated sync rows.
- Targeted `FitTrackerCoreTests` coverage now exercises local sign-out/session clearing, encrypted-file deletion, and deletion grace-period restore/cancel behavior.
- Focused `SyncMergeTests` coverage now verifies multiple dated daily logs and weekly snapshots coexist after merge, and it caught a real `mergeDailyLog` bug where optional `logicDayKey` comparison could collapse distinct dated rows.

Remaining stabilization gaps:

- verify full signed-in push/pull sync behavior against a real Supabase-backed runtime
- re-verify deletion and export execution on a real signed-in device/runtime
- validate consent-gated Firebase analytics in DebugView with a local plist

---

## Planning Principles

1. No new feature expansion before the current app is buildable and testable on a clean machine.
2. Privacy, sync correctness, and deletion guarantees outrank roadmap breadth.
3. Documentation must describe implemented reality, not branch intent.
4. Design system work should continue, but only after the foundation can safely ship and regressions are measurable.
5. Android, blood tests, DEXA, and broader growth work remain deferred until the iOS core is operationally stable.

---

## Reconciled Execution Plan

## Phase 0A - Stabilize The Existing Product

This is the new mandatory gate before continuing the prior roadmap.

### 0A.1 Build And Dependency Recovery

Goal: make a clean-machine iOS build pass.

Work:

- Add and link Firebase packages required by [`FitTrackerApp.swift`](../../FitTracker/FitTrackerApp.swift).
- Verify whether Firebase is meant to be SPM-managed or intentionally excluded on `main`.
- Ensure the Xcode project contains the package references and target linkage, not just source imports.
- Re-run `xcodebuild build` against `FitTracker.xcodeproj` until green.
- Capture the minimal bootstrap sequence for Node, Python, and Xcode in README or a dedicated setup doc.

Exit criteria:

- `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS'` passes
- targeted simulator XCTest coverage passes
- no manual package fiddling required after clone

Status update (`2026-04-05`):

- `xcodebuild build` is green
- `xcodebuild test -only-testing:FitTrackerTests/FitTrackerCoreTests` is green on simulator
- remaining work is runtime verification with local config, not basic app launchability

### 0A.2 Data Sync Correctness

Goal: make encrypted multi-record sync actually work.

Work:

- Replace the current `uq_sync_singleton` constraint with a design that only applies singleton uniqueness to singleton record types.
- Prefer partial unique indexes for:
  - `daily_log` on `(user_id, record_type, logic_date)`
  - `weekly_snapshot` on `(user_id, record_type, week_start)`
  - singleton types on `(user_id, record_type)` only when both date keys are null and the type is singleton
- Add migration-level validation or SQL tests to prove multiple daily logs can coexist.
- Add app-level regression tests covering push and pull of multiple dated rows.

Exit criteria:

- one user can sync multiple `daily_log` rows and multiple `weekly_snapshot` rows
- schema and client assumptions align

### 0A.3 Auth And Session Integrity

Goal: align sign-in, sign-out, restore, and lock behavior with the intended security model.

Work:

- Update `signOut()` to revoke the Supabase auth session, not just clear local app state.
- Fix `restoreSession()` so users who disable biometric reopen still restore into an authenticated app state when a valid backend session exists.
- Re-test review mode, simulator auto-login, biometric unlock, and explicit sign-out separately.
- Add tests for:
  - restore with biometric lock enabled
  - restore with biometric lock disabled
  - sign-out revoking backend auth

Exit criteria:

- app auth state and Supabase auth state never drift
- relaunch behavior matches settings

Status update (`2026-04-05`):

- core restore/sign-out behavior has been fixed in app code
- targeted XCTest coverage now verifies local sign-out/session clearing
- remaining work is broader integration coverage for biometric-on/off restore and live auth-boundary validation

### 0A.4 GDPR And Local Data Erasure

Goal: make deletion claims true.

Work:

- Implement actual Supabase deletion for `sync_records` and `cardio_assets`.
- Implement CloudKit deletion or downgrade docs and UI claims until it exists.
- Add deletion of local encrypted `.ftenc` files, not just in-memory clearing.
- Add explicit encryption-key deletion if the product claims keychain wipe.
- Ensure deletion analytics only report stores actually deleted.
- Rewrite README and changelog language where behavior is still partial.

Exit criteria:

- deletion service does what docs claim
- remote data, local blobs, and auth/session residue are removed or clearly documented as deferred

Status update (`2026-04-05`):

- local encrypted blobs, encryption keys, Supabase deletes, and CloudKit deletes now have explicit code paths
- targeted XCTest coverage now verifies local encrypted-file deletion, deletion grace-period request/cancel/restore behavior, and JSON export generation
- focused sync merge coverage now verifies multiple dated rows coexist and no longer collapse because of missing `logicDayKey` values on merge input
- remaining work is signed-in runtime verification plus stronger partial-failure integration coverage and real export/share execution validation

### 0A.5 AI Engine Testability

Goal: turn the AI service into a repeatable CI target.

Work:

- Fix `tests/test_training.py` to match actual auth behavior where appropriate.
- Decouple tests from real Supabase env requirements by using test defaults, dependency overrides, or a settings fixture.
- Preserve production strictness while making unit and integration tests self-contained.
- Add coverage for the remaining segments if not already present.

Exit criteria:

- `pytest` passes locally in a fresh virtualenv
- CI can run AI engine tests without production secrets

Status update (`2026-04-05`):

- local `pytest` now passes in a fresh Python 3.12 virtualenv using test-owned settings overrides
- remaining work is CI hardening and expanding coverage, not basic local testability

### 0A.6 Dashboard Integrity

Goal: make project-health reporting trustworthy.

Work:

- Fix the missing GitHub issue reconciliation path so `sources.github.healthy` reflects alerts.
- Add a test asserting unhealthy source state when PM workflow state exists without a GitHub issue.

Exit criteria:

- dashboard source health matches alert truth

Status update (`2026-04-05`):

- source-health mismatch fix applied
- regression test updated so missing PM workflow issues now mark GitHub unhealthy

**Phase 0A gate:** all above items green, and docs updated to match actual behavior.

---

## Phase 0B - Truth Alignment And Documentation Repair

Once the codebase is stable enough to trust, repair the planning and product docs.

Work:

- Update [`README.md`](../../README.md) to distinguish:
  - shipped in UI
  - implemented in backend
  - fully verified
- Update [`CHANGELOG.md`](../../CHANGELOG.md) so GDPR and analytics entries reflect code reality.
- Amend or supersede [`branch-review-2026-04-05.md`](./branch-review-2026-04-05.md) because the currently visible remote state does not match the branch inventory described there.
- Add a setup section that includes:
  - Xcode requirement
  - Node install commands
  - Python virtualenv flow for `ai-engine`
  - required env vars for local AI engine

Exit criteria:

- planning docs are usable as operational truth

---

## Phase 1 - Design System And Figma Continuation

Keep the intent from the original master design plan, but start from the current repo, not from stale branch assumptions.

### 1.1 Token Pipeline And Build Discipline

Carry forward:

- Figma Variables -> `design-tokens/tokens.json` -> generated `DesignTokens.swift`
- CI drift detection
- semantic tiering (`AppPalette`, `AppTheme`, component layer)

Add:

- build-gate verification on every token-pipeline change
- explicit ownership of generated vs hand-authored files

### 1.2 Foundation Hardening

Carry forward:

- contrast validator
- 4pt spacing alignment
- radius normalization
- motion token centralization
- Dynamic Type and accessibility coverage

Add:

- prioritize removal of raw literals only after build/auth/sync are green
- ensure every design-system pass includes runtime verification, not just token alignment

### 1.3 Figma Coverage

Carry forward:

- lock every major screen in Figma
- define component pages, state coverage, and repository pages
- preserve B8 dark mode deferral until the light-mode inventory is stable

Correct sequencing:

- do not spend another full cycle on pixel refinement while foundation issues are still blocking build or correctness
- perform Figma/code parity work in batches, starting with auth, home, training, nutrition, stats, settings

Exit criteria:

- every major screen has a locked Figma frame
- no new raw style literals are introduced
- dark mode remains a post-light-mode stabilization pass

---

## Phase 2 - Product Operating System And Measurement

This phase stays important, but only after the product can build, pass core regression checks, and complete runtime analytics verification with local config.

### 2.1 Analytics Recovery

Work:

- validate the config-aware Firebase bootstrap on real runtime builds with a local plist
- validate consent-gated event flow at runtime
- add or restore the analytics tests that docs claim exist
- document the exact required plist and environment setup

### 2.2 Skills Operating System

Work:

- treat `docs/project/skills-ecosystem.md` as the design reference
- merge only the genuinely new skills-system content, not stale duplicate branch work
- ensure file references point to current repo paths
- keep this as an enablement track, not as a blocker ahead of product correctness

### 2.3 CX System

Keep from roadmap:

- review monitoring
- NPS/CSAT
- roadmap publishing
- live user dashboard
- review sentiment loops

But defer execution until:

- analytics is actually running
- backend and privacy guarantees are trustworthy

---

## Phase 3 - Backend Completion

Preserve the structure from the March 30 master plan.

### 3.1 Supabase Backend

- complete RLS and migration validation
- verify all sync record types end-to-end
- validate retention jobs
- test realtime subscription lifecycle with real device flows

### 3.2 AI Engine

- fix current test suite
- complete segment coverage
- deploy and verify production environment contracts

### 3.3 Multi-Repo CI

- ensure each repo has green CI on its own terms
- remove secret leakage risk
- add environment bootstrap docs per repo

Exit criteria:

- physical-device end-to-end path works:
  sign in -> sync restore -> mutate local data -> push -> pull -> AI recommendation

---

## Phase 4 - Marketing And Launch Readiness

Marketing work should continue, but with stricter dependency rules than the current docs imply.

### 4.1 Marketing Website

Status:

- website code exists, dependencies install, and local production builds pass

Next steps:

- verify production deploy health
- connect final screenshots and testimonials only once the core product is stable enough to showcase accurately

### 4.2 Growth Strategy

Keep the original scope:

- SEO
- paid acquisition
- ASO
- referral loops
- attribution

Dependency:

- no aggressive acquisition before the product foundation is stable and the analytics/retention measurement path is trustworthy

---

## Phase 5 - Deferred Platform Expansion

No change in direction:

- Android remains deferred
- advanced health integrations remain deferred
- DEXA and blood-test interpretation remain deferred
- in-app Skills feature remains lower priority than shipping a reliable core app

This is still the right call.

---

## Branch And Repo Strategy

The stored branch review should no longer be treated as ground truth without revalidation.

Current observed remote state from a fresh clone:

- `origin/main`
- `origin/claude/project-status-analysis-kaRO7`

Plan:

1. Re-run branch inventory directly from GitHub before making merge decisions based on `branch-review-2026-04-05.md`.
2. Treat that document as a historical analysis, not an operational branch map.
3. Do not plan work around branches that are not currently visible.
4. If the missing branches still exist in another remote context, fetch and verify them explicitly before using them in roadmap decisions.

---

## Revised Phase Gates

### Gate A

Before any new roadmap execution:

- iOS build green
- sync schema corrected
- auth/session behavior corrected
- deletion flow truthful
- AI tests green
- dashboard test gap fixed

### Gate B

Before deep design-system expansion:

- Gate A complete
- docs updated to truthful state
- token pipeline verified and owned

### Gate C

Before CX/growth expansion:

- Firebase linked and runtime verified
- analytics tests present
- deletion and privacy claims accurate

### Gate D

Before Android or advanced health features:

- iOS core product stable
- backend green
- measurement live
- launch messaging and support flows ready

---

## Immediate Next 10 Tasks

1. Verify signed-in Supabase sync end to end on a real runtime.
2. Verify signed-in deletion and export execution on a real runtime.
3. Supply a local `GoogleService-Info.plist` and verify consent-gated analytics in Firebase DebugView.
4. Revalidate remote branch inventory directly from GitHub.
5. Decide whether design-system branch work should be resumed from `main` or re-imported from verified branches.
6. Harden CI around the now-green iOS, dashboard, website, token, and AI verification paths.
7. Wire `make verify-local` into CI or a documented release-check flow.
8. Continue truth-aligning product docs only after runtime verification confirms the remaining claims.
9. Verify production deploy health for dashboard and website.
10. Resume design-system and product-expansion work only after the runtime and analytics gates above are closed.

---

## Definition Of Done For The Current Planning Cycle

This planning cycle is complete when the repo has:

- one buildable iOS app on `main`
- one truthful master plan
- one truthful README
- green dashboard tests
- green token verification
- green AI engine tests
- corrected privacy/deletion behavior
- a verified branch strategy for any remaining feature work

At that point, the original roadmap becomes executable again in a disciplined way.
