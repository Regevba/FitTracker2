> **Note:** This audit was conducted by Codex on 2026-04-19 and committed to the repo on 2026-04-20 for persistence. The original lives at `/Volumes/DevSSD/Projects/FitTracker2/FITTRACKER_SSD_AUDIT_2026-04-19.md`. See `docs/superpowers/plans/2026-04-20-full-sweep-remediation.md` for the remediation plan.

# FitTracker SSD Audit

Date: 2026-04-19
Audited by: Codex
Primary scope: `/Volumes/DevSSD/FitTracker2` plus related FitTracker/FitMe repos on `/Volumes/DevSSD`
Audit method: repo inventory, branch/remote inspection, README/docs review, targeted verification runs, link-integrity scan, and code-to-doc comparison

## Executive Summary

The active source-of-truth repo on the SSD is `/Volumes/DevSSD/FitTracker2`, not `/Volumes/DevSSD/Projects/FitTracker2` and not `/Volumes/DevSSD/Projects/FitTracker2-BACKUP-2026-04-06`.

The highest-confidence product issue is in the dashboard/control-room build path: shared PM data now allows case-study entries without `artifacts`, but the builder still assumes that field exists. That breaks both `npm test` and `npm run build` for the canonical web surface.

The highest-confidence documentation issue is that the root README and several index docs overstate verification status and still point at old `docs/project/...` paths that no longer exist. The docs surface is now large enough that drift is creating false confidence.

The most important process risk is SSD sprawl: there are multiple FitTracker roots, one incomplete shell, one stale backup repo 333 commits behind origin/main, and one active repo. That makes it too easy to audit or edit the wrong tree.

## Canonical Repo And Workspace Topology

### Active repo

- Path: `/Volumes/DevSSD/FitTracker2`
- Remote: `origin https://github.com/Regevba/FitTracker2.git`
- `main...origin/main`: `0 0`
- Current checked-out branch: `feature/m1a-settings-screens-extraction`
- Current branch tip equals `main` and `origin/main`, but the working tree is dirty
- Dirty working tree count: 16 paths from `git status --porcelain`

### Non-canonical or risky sibling trees

- `/Volumes/DevSSD/Projects/FitTracker2`
  - Not a git repo
  - Incomplete shell containing the Xcode project, not the full source
- `/Volumes/DevSSD/Projects/FitTracker2-BACKUP-2026-04-06`
  - Real git repo, but stale
  - `main` behind `origin/main` by 333 commits
  - Dirty worktree
- `/Volumes/DevSSD/fitme-showcase`
  - Separate documentation-only repo
  - Clean and synced
- `/Volumes/DevSSD/fitme-story`
  - Separate Next.js story/showcase repo
  - `main` ahead of `origin/main` by 1 commit
- `/Volumes/DevSSD/orchid`
  - Separate research repo
  - Clean and synced

### Branch hygiene findings

- Active repo still has local branches whose upstreams are gone:
  - `feature/home-status-goal-card`
  - `feature/home-today-screen-v2`
  - `feature/metric-tile-deep-linking`
  - `feature/training-plan-v2`
- `git fetch --all --prune` also removed many stale remote audit/remediation branches

### Recommendations

1. Declare `/Volumes/DevSSD/FitTracker2` as the only canonical local repo in the root README and setup docs.
2. Archive or clearly label the stale backup repo and incomplete shell so they cannot be mistaken for the active tree.
3. Prune or archive local branches whose upstreams are gone unless they are intentionally preserved.

## Project Type: Native App

### Area: Verification status vs documented status

Evidence:

- Root README claims:
  - `README.md:184` "iOS app builds with full Xcode, targeted XCTest coverage passes"
  - `README.md:244` "The current verified result is green end to end, including 197+ passing XCTest cases"
- Fresh audit result:
  - `xcodebuild -list` succeeds
  - targeted `xcodebuild test` resolves packages but did not complete within the audit window
  - earlier targeted test run on the same repo failed during SwiftPM/bootstrap with `swift-protobuf` submodule update failure

Assessment:

- The native path is not proven broken, but it is not honestly "verified green" from this machine during this audit.
- The README is stronger than the evidence currently supports.

Suggestions:

1. Downgrade the README claim from "passes" to "last known passing on <date>, rerun required" until a clean local run is captured.
2. Add a machine-generated verification artifact under `.build/` or `docs/master-plan/` with:
   - command
   - date
   - commit SHA
   - simulator/runtime
   - pass/fail
3. If SwiftPM bootstrap remains flaky, prewarm and pin the package cache in CI and in `make verify-ios`.

### Area: Settings / GDPR surface

Documentation state:

- `docs/product/backlog.md:136` says "Data export from Settings — no CSV/JSON export UI"
- Root README presents GDPR export as shipped functionality

Code state:

- Export code exists:
  - `FitTracker/Services/DataExportService.swift`
  - `FitTracker/Views/Settings/ExportDataView.swift`
  - `FitTracker/Views/Settings/SettingsView.swift`
  - `FitTracker/Views/Settings/v2/SettingsView.swift`
  - `FitTracker/Views/Settings/v2/Screens/DataSyncSettingsScreen.swift`
- Delete-account flow also exists in code

Assessment:

- This is a documentation contradiction, not a missing-code issue.
- The backlog item is stale or overly broad. If the intended gap is "runtime-validated export UX" or "CSV export", it should say that precisely.

Suggestions:

1. Rewrite the backlog item to reflect the real gap:
   - either "export UI exists, runtime validation still needed"
   - or "JSON export exists; CSV export does not"
2. Add a tiny integration test or UI smoke test for export entry-point reachability so this stops drifting back into ambiguity.

### Area: Notification settings

Documentation state:

- `docs/product/backlog.md:135` says no push-notification preferences in Settings

Code state:

- Preference store and enforcement exist:
  - `FitTracker/Services/Notifications/NotificationPreferencesStore.swift`
  - `FitTracker/Services/Notifications/NotificationService.swift`
- No evidence of a full Settings UI for editing those preferences was found in the current Settings views

Assessment:

- This looks like a real product gap: backend/service logic exists, but the user-facing configuration surface is incomplete or absent.

Suggestions:

1. Decide whether notification preferences are intentionally hidden or still unfinished.
2. If unfinished, add a Settings screen backed by `NotificationPreferencesStore`.
3. If intentionally hidden, remove or defer the backlog line with a rationale so docs stop implying a broken shipped feature.

## Project Type: Web Surfaces

### Area: Operations dashboard / control room

Severity: High

Evidence:

- `dashboard/src/scripts/builders/controlCenter.js:342`
  - `const artifactDoc = caseItem.artifacts.find(...)`
- `dashboard/tests/control-center-builders.test.js:12`
  - failing test exercises `buildDashboardData()`
- Shared data contains at least one case item without `artifacts`:
  - `.claude/shared/case-study-monitoring.json`
  - case id: `framework-measurement-v6-2026-04`
  - uses `related_artifacts` instead

Fresh verification:

- `cd dashboard && npm test`
  - 1 failed, 34 passed
- `cd dashboard && ASTRO_TELEMETRY_DISABLED=1 npm run build`
  - fails while rendering `/case-studies`
- Failure message:
  - `TypeError: Cannot read properties of undefined (reading 'find')`

Assessment:

- The canonical live web surface is currently not green.
- This is both a code bug and a data-contract bug.

Suggestions:

1. Make the builder schema-tolerant:
   - use `Array.isArray(caseItem.artifacts) ? caseItem.artifacts : caseItem.related_artifacts ?? []`
2. Normalize the shared schema:
   - either always emit `artifacts`
   - or explicitly support `related_artifacts` everywhere
3. Add a contract test for case-study entries with missing optional arrays.
4. Consider validating `.claude/shared/case-study-monitoring.json` against a JSON schema before dashboard build.

### Area: Marketing website

Evidence:

- `website/README.md` accurately says the site builds but still has launch blockers
- Fresh build passed:
  - `cd website && ASTRO_TELEMETRY_DISABLED=1 npm run build`

Assessment:

- The website docs are more honest than the root README verification section.
- No immediate code breakage found in the website during this audit.

Suggestions:

1. Keep the "not primary live surface yet" language.
2. Track the remaining launch blockers in one canonical checklist rather than scattering them across README and PRDs.

## Project Type: AI And Backend

### Area: AI engine

Evidence:

- `ai-engine/README.md` matches the observed test surface reasonably well
- Fresh tests passed:
  - `python3.12 -m pytest -q`
  - `5 passed, 1 warning`
- Warning was a pytest cache write-permission issue, not a test failure

Assessment:

- No major code-doc contradiction found here.
- This is one of the healthier project areas.

Suggestions:

1. Suppress or redirect pytest cache in audit/test commands to remove noise.
2. Add one line to the README clarifying the harmless cache warning if it is common in the SSD environment.

### Area: Backend

Evidence:

- `backend/README.md` is internally consistent and specific
- No verification run in this audit contradicted its migration/architecture claims

Assessment:

- Documentation quality is better here than in the root/product docs.
- No high-confidence backend code issue was surfaced in this pass.

Suggestions:

1. Use backend/AI README quality as the template for the root README.
2. Keep deployment preconditions explicit and versioned.

## Project Type: Documentation And Process Surface

### Area: Root README overstating repo health

Evidence:

- `README.md:184-186` claims iOS, token check, and dashboard tests pass
- `README.md:239-244` claims `make verify-local` is green end-to-end
- Fresh audit contradicted dashboard pass status and did not reproduce a clean iOS pass

Assessment:

- The README currently reads like a release note, not a live status document.
- This creates false confidence for anyone resuming work.

Suggestions:

1. Split root README into:
   - product/repo overview
   - current verification status
2. Move volatile health claims into a dated verification table generated from actual runs.
3. Never say "green end to end" without a date, commit SHA, and command set.

### Area: Broken links and stale path migration

High-confidence path drift:

- `README.md` still links to missing `docs/project/...` paths:
  - `docs/project/stabilization-report-2026-04-05.md`
  - `docs/project/firebase-setup-guide.md`
  - `docs/project/original-readme-redesign-casestudy.md`
- `docs/master-plan/README.md` still says setup guides stay in `docs/project/`
- Many historical docs still reference `docs/project/...` even though material moved into `docs/master-plan/`, `docs/setup/`, and `docs/prompts/`

Assessment:

- The doc tree was reorganized, but references were not fully migrated.
- This is now big enough to break onboarding and agent handoff quality.

Suggestions:

1. Run a repo-owned markdown link checker that excludes `.build/` and external package docs.
2. Do a one-time path migration sweep from `docs/project/...` to the current folders.
3. Add CI for markdown link integrity on project-owned docs only.

### Area: Stale version/index docs

Examples:

- `.claude/skills/pm-workflow/README.md:3` still says current framework version is `v5.1`
- `docs/product/prd/README.md:4` says maintained against PM-flow `v4.3`
- `docs/prompts/README.md:31` says there are no auto-generated prompts yet, but the folder already contains:
  - `docs/prompts/2026-04-09-home-today-screen-design-build.md`
  - `docs/prompts/2026-04-09-home-today-screen-ux-build.md`

Assessment:

- Index/readme documents are lagging behind the actual framework and folder contents.
- These are high-noise documents because people use them for orientation.

Suggestions:

1. Treat all folder-level READMEs as inventory files that must be updated whenever files are added or the framework version changes.
2. Add a small maintenance script that checks:
   - latest framework version mentions
   - current file counts/presence
   - stale "none yet" sections

### Area: Link-integrity scan results

Project-owned docs scan found many broken or stale local references after excluding `.build/` and similar generated directories.

Notable actionable examples:

- `.claude/features/onboarding/prd.md -> ../../../docs/project/pm-workflow-showcase-onboarding.md`
- `README.md -> docs/project/stabilization-report-2026-04-05.md`
- `docs/master-plan/resume-handoff-2026-03-29.md -> docs/project/ui-integration-pr-draft.md`
- `docs/master-plan/session-summary-2026-04-06.md` contains many stale `docs/project/...` references

Assessment:

- The problem is not one broken link. It is a systemic migration drift.

Suggestions:

1. Fix the root README first.
2. Then fix all folder-level README/index docs.
3. Then repair historical docs that are still used as handoff material.

## Project Type: Satellite Repos

### Area: fitme-story

Evidence:

- `/Volumes/DevSSD/fitme-story/README.md` is still the default `create-next-app` template
- The repo itself is real, active, and ahead of origin by 1 commit

Assessment:

- This repo looks materially more mature than its README suggests.
- The README currently hides what the project actually is.

Suggestions:

1. Replace the starter README with a purpose, architecture, content source, and deployment note.
2. Add relationship-to-showcase-repo and relationship-to-main-FitTracker-repo sections.

### Area: fitme-showcase

Assessment:

- README and repo purpose are aligned.
- No major contradiction found in this pass.

### Area: orchid

Assessment:

- README is specific and reasonably aligned with repo purpose.
- No major contradiction found in this pass.

## Priority Fix Plan

### P0

1. Fix dashboard case-study builder to handle missing `artifacts`.
2. Normalize `case-study-monitoring.json` schema and add validation.
3. Remove or downgrade false "green" claims in root README until reverified.
4. Repair root README links that still point at `docs/project/...`.

### P1

1. Sweep folder-level READMEs for stale framework versions and stale inventory text.
2. Clarify Settings export truth in `docs/product/backlog.md`.
3. Decide whether notification preferences are a true missing UI or an intentionally deferred feature.
4. Prune stale local branches and document the canonical repo path.

### P2

1. Add markdown link checking in CI for project-owned docs.
2. Generate verification snapshots from commands rather than editing them by hand.
3. Refresh `fitme-story` README so it stops reading like a scaffold.

## Execution Plan

This plan is intentionally ordered to restore trust in the repo before doing broader cleanup. It does not assume code changes begin immediately. It is the recommended sequence once implementation is approved.

### Phase 0: Freeze Truth And Define Canonical Sources

Goal:

- Stop further confusion about which repo, branch, and docs are authoritative.

Actions:

1. Declare `/Volumes/DevSSD/FitTracker2` as the canonical local repo in the root README and setup/orientation docs.
2. Mark `/Volumes/DevSSD/Projects/FitTracker2` as an incomplete shell and `/Volumes/DevSSD/Projects/FitTracker2-BACKUP-2026-04-06` as a stale backup.
3. Capture a dated "audit baseline" note with:
   - active commit SHA
   - active branch
   - dirty files
   - current verification results

Success criteria:

- A new contributor or model can identify the right repo in under 1 minute.
- No top-level orientation doc implies the stale backup or incomplete shell is a valid source of truth.

Risk if skipped:

- All later fixes can be applied or verified against the wrong tree.

### Phase 1: Restore The Canonical Web Surface

Goal:

- Make the dashboard/control-room test and production build pass again.

Actions:

1. Patch the dashboard builder to tolerate absent `artifacts`.
2. Decide and document the intended schema:
   - always `artifacts`
   - or `artifacts` plus `related_artifacts`
3. Normalize `.claude/shared/case-study-monitoring.json` generation or hand-maintained entries to match that schema.
4. Add a test for a case-study item with missing optional arrays.
5. Re-run:
   - `cd dashboard && npm test`
   - `cd dashboard && ASTRO_TELEMETRY_DISABLED=1 npm run build`

Success criteria:

- Dashboard tests are green.
- Dashboard build is green.
- `/case-studies` no longer fails in prerender.

Why this comes first:

- The dashboard is documented as the canonical live web surface. Its broken state is the most concrete product issue in the audit.

### Phase 2: Bring Verification Claims Back In Line With Reality

Goal:

- Make repo status claims trustworthy again.

Actions:

1. Rewrite the volatile verification section in the root README.
2. Replace unconditional claims like "passes" or "green end to end" with dated results.
3. Add a verification matrix containing:
   - area
   - command
   - last run date
   - commit SHA
   - result
   - environment caveats
4. Downgrade unverified iOS claims until a clean run is captured.

Success criteria:

- No README statement claims a green status that cannot be reproduced or traced to a dated run.
- A reviewer can distinguish "implemented", "compile-verified", and "runtime-verified".

Risk if skipped:

- Team members will continue trusting stale health claims and making bad planning decisions.

### Phase 3: Repair Documentation Path Drift

Goal:

- Remove the stale `docs/project/...` migration footprint from live docs.

Actions:

1. Fix the root README links first.
2. Fix all folder-level README and index files next.
3. Sweep live orientation and handoff docs for `docs/project/...` references.
4. Decide which historical docs are still actively used and repair only those; archive or leave untouched the rest with explicit "historical only" labeling.
5. Add a project-owned markdown link check that excludes generated/vendor directories.

Success criteria:

- Root README has zero broken local links.
- Folder-level README/index docs have zero broken local links.
- Historical docs that remain in active use no longer send readers to dead paths.

Why this is separate from Phase 2:

- Verification honesty and path integrity are related but distinct. One is about truthfulness; the other is about navigability.

### Phase 4: Refresh Folder-Level Index Docs

Goal:

- Make the docs surface usable for orientation again.

Actions:

1. Update all folder-level READMEs that act as inventories.
2. Correct stale framework-version references:
   - `.claude/skills/pm-workflow/README.md`
   - `docs/product/prd/README.md`
   - any similar index docs
3. Remove stale "none yet" inventory statements where files now exist.
4. Standardize each index doc to include:
   - what belongs here
   - what does not
   - current contents
   - canonical related docs
   - last updated date

Success criteria:

- Folder-level READMEs accurately describe the current file set and current framework version.
- Orientation docs stop contradicting the repo layout.

### Phase 5: Resolve Product/Doc Contradictions

Goal:

- Distinguish real missing features from stale backlog entries.

Actions:

1. Reconcile the Settings export contradiction:
   - code exists
   - backlog says missing
2. Decide whether the true gap is:
   - missing CSV export
   - missing runtime verification
   - stale backlog text
3. Reconcile notification-settings status:
   - service/store exists
   - unclear whether user-facing settings UI exists
4. Update backlog/PRD/master-plan language to reflect the real state.

Success criteria:

- No backlog item claims a feature is absent when the UI or service already exists.
- Remaining gaps are phrased precisely enough to drive implementation work.

### Phase 6: Re-establish Verification Discipline

Goal:

- Make future status reporting harder to fake accidentally.

Actions:

1. Add markdown link checking for project-owned docs.
2. Add schema validation for shared PM JSON inputs used by the dashboard.
3. Add a repeatable verification snapshot workflow for:
   - dashboard
   - website
   - ai-engine
   - iOS build/test
4. Ensure docs use explicit labels:
   - implemented
   - compile-verified
   - runtime-verified
   - last-known-green

Success criteria:

- A future stale claim is caught by process or CI, not by another manual audit.

### Phase 7: Clean Satellite Repos And SSD Hygiene

Goal:

- Reduce workspace confusion and improve repository professionalism.

Actions:

1. Replace the scaffold README in `/Volumes/DevSSD/fitme-story`.
2. Decide whether the stale FitTracker backup repo should be archived, renamed more aggressively, or removed from normal workflows.
3. Prune local branches with gone upstreams if they are no longer needed.
4. Document how the main repo, showcase repo, story repo, and orchid repo relate to each other.

Success criteria:

- Repo relationships are explicit.
- SSD layout no longer creates avoidable audit or onboarding mistakes.

## Recommended Implementation Order

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 4
6. Phase 5
7. Phase 6
8. Phase 7

## Decision Gates Before Implementation

These decisions should be confirmed before code/doc fixes begin:

1. Should the backup repo remain on the SSD as-is, or should it be explicitly archived/labeled?
2. For case-study monitoring, is `artifacts` the canonical field name, or should both `artifacts` and `related_artifacts` remain supported?
3. Should the root README remain a mixed product-plus-status document, or should live verification move into a dedicated status file?
4. Should historical docs with stale links be repaired broadly, or only when they are still used as live handoff material?

## Suggested Approval Strategy

If you want to minimize risk, approve implementation in this order:

1. Approve Phase 1 plus Phase 2 together.
2. Review the updated verification state.
3. Then approve Phases 3 through 5 for docs reconciliation.
4. Then approve Phases 6 through 7 for guardrails and cleanup.

## Most Important Honest Bottom Line

The codebase is not in catastrophic shape, but the documentation layer is currently more optimistic and more fragmented than the code deserves. The biggest real product defect is the broken dashboard/control-room build. The biggest repo-health issue is that the docs overstate verification and still contain a broad stale-path migration from `docs/project/...`. The biggest operational risk is the SSD layout itself, because it still contains multiple FitTracker roots with different truth values.
