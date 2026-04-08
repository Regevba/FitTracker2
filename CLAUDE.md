# FitMe (FitTracker2) — Project Rules

## Product Management Lifecycle

Every new feature MUST follow the PM workflow. Invoke with `/pm-workflow {feature-name}`.

**Phases:** Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs

**Non-negotiable rules:**
1. No phase is skipped. Every phase requires explicit user approval.
2. No PRD without success metrics. Every feature defines: primary metric, baseline, target, kill criteria.
3. No merge without CI. Both feature branch AND main must be green.
4. Data drives decisions. Research, metrics, and kill criteria guide the lifecycle.
5. Post-launch metrics review is mandatory at the cadence defined in the PRD.
6. Phase transitions auto-sync to GitHub Issue labels (dashboard updates automatically).
7. Manual overrides allowed — user can move features forward (skip) or backward (rollback) at any time. Skipped phases are recorded in the audit trail.
8. Conflicts between state.json and GitHub Issues are resolved by asking the user.

## Work Item Types

Not everything needs the full 9-phase funnel:
- **Feature** — Full lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs). New capabilities requiring research, PRD, design.
- **Enhancement** — 4-phase (Tasks → Implement → Test → Merge). Improvements to shipped features. Parent feature must already have a PRD.
- **Fix** — 2-phase (Implement → Test). Bug fixes, error handling, security patches.
- **Chore** — 1-phase (Implement). Docs, config, refactoring, dependency updates.

Use `/pm-workflow {name}` and select the work type. Skipped phases are recorded in the audit trail with reason `work_type:{type}`.

## Branching Strategy

- **Large features** (>5 files changed OR new models/services) → `feature/{name}` branch
- **Small fixes** (<5 files, no new models) → direct task branch
- **Before merge:** parallel code review — diff feature vs main, identify risk areas
- **CI requirement:** both branches must pass before merge is approved
- **High-risk areas** that require extra review: DomainModels.swift, EncryptionService.swift, SupabaseSyncService.swift, CloudKitSyncService.swift, SignInService.swift, AuthManager.swift, AIOrchestrator.swift

## CI Pipeline

- Token check: `make tokens-check` (design system drift detection)
- Build: `xcodebuild build` (iOS Simulator, no code signing)
- Test: `xcodebuild test` (XCTest suite)
- All three must pass before any merge to main.

## Data-Driven Development

This app is data-driven at every level:
- **System-wide guardrails** (must not degrade for any feature):
  - Crash-free rate > 99.5%
  - Cold start < 2s
  - Sync success rate > 99%
  - CI pass rate > 95%
  - Cross-feature WAU (North Star) trending up or flat
- **Every feature** has a metrics section in its PRD with kill criteria
- **Post-launch** reviews happen at the cadence defined in the PRD

## Design System (Living Framework)

The design system is a **living, evolving framework** — not a static constraint. It should serve the product.

- ~125 semantic tokens in `FitTracker/Services/AppTheme.swift`
- 13 reusable components in `FitTracker/DesignSystem/`
- Token pipeline: `design-tokens/tokens.json` → Style Dictionary → `DesignTokens.swift`
- CI gate: `make tokens-check` prevents token drift
- Always use semantic tokens (AppColor, AppText, AppSpacing) — never raw literals

**Evolution rules:**
- New tokens/components are proposed on feature branches, never directly on main
- Phase 3 compliance gateway validates every UI feature against the design system
- If a feature needs to deviate, the user chooses: fix, evolve the system, or override with justification
- Approved changes merge to main with the feature and become part of the system
- All changes documented in `docs/design-system/feature-memory.md`

## UI Refactoring & V2 Rule

When a UI screen or feature needs a UX Foundations alignment pass (or any
substantial refactor against `docs/design-system/ux-foundations.md`):

1. **Create a `v2/` subdirectory next to the v1 file.** Each feature's v2
   work lives in its own `v2/` subdirectory under the same parent group.
   File names stay the same — only the directory differs:
   - `FitTracker/Views/Main/MainScreenView.swift` (v1, historical)
   - `FitTracker/Views/Main/v2/MainScreenView.swift` (v2, source of truth)
   - `FitTracker/Views/Onboarding/OnboardingWelcomeView.swift` (v1)
   - `FitTracker/Views/Onboarding/v2/OnboardingWelcomeView.swift` (v2)

   This keeps v1 and v2 next to each other for diffing while preserving
   the original file names so imports/types don't collide. Both files
   define the same Swift type (e.g. `MainScreenView`) — the build target
   only references one of them at a time.

2. **Update `FitTracker.xcodeproj/project.pbxproj`** in the same commit
   that creates the first v2 file in a new `v2/` subdirectory. The v2
   directory becomes a new PBXGroup, the v2 file becomes a PBXFileReference
   + PBXBuildFile, and the v1 file is REMOVED from the Sources build phase
   (but stays as a PBXFileReference so it shows in the file navigator and
   git history). v1 lives on as a reviewable historical artifact, not as
   compiled dead code.

3. **Build the v2 file bottom-up** from the design system foundations
   (tokens, components, ux-foundations principles) — do **not** patch the
   v1 file in place. v1 is read-only during the refactor. Use the
   `docs/design-system/v2-refactor-checklist.md` to track what's been
   verified.

4. **Wire the v2 file in** at its parent (e.g. `RootTabView.swift` keeps
   instantiating `MainScreenView()` — same type name — but the symbol now
   resolves to the v2 file because v1 has been removed from the build
   sources). No call-site change needed in parent views since the type
   name is identical; the swap happens at the project.pbxproj layer.

5. **Mark v1 as historical** with a header comment when the swap lands:
   ```swift
   // HISTORICAL — superseded by v2/{ScreenName}.swift on {date} per
   // UX Foundations alignment pass. See
   // .claude/features/{name}/v2-audit-report.md for the gap analysis.
   // This file is no longer in the build target; it stays in the repo
   // as a reviewable reference for the v1 → v2 diff.
   ```

6. **One v2 split per surface.** A second alignment pass on the same
   screen does not become a `v3/` directory — it patches v2 in place.
   The v1 → v2 split exists exactly to capture the *first* deliberate
   foundations-aligned rewrite of a pre-PM-workflow surface. v3+ would
   indicate the refactor methodology itself failed.

**For new UI features built from scratch** (no v1 to refactor):
- File lives at the canonical path (no `v2/` subdirectory — there's
  nothing to refactor against).
- The Phase 3 (UX) gateway is **non-skippable** — every new UI feature
  must produce a `ux-spec.md` and pass the design system compliance
  gateway before any view code is written.
- Phase 4 (Implement) starts with the `ux-foundations.md` checklist
  applied to the spec, then the view code. No "build first, audit later".

**Verification checklist:** Every v2 refactor walks through
`docs/design-system/v2-refactor-checklist.md` before requesting Phase 5
(Test) approval. The checklist covers token compliance, component reuse,
state coverage, accessibility, motion, analytics, and project.pbxproj
hygiene. State.json `phases.ux_or_integration.checklist_completed` must
be `true` before Phase 4 advances.

**Backward compatibility note:** Onboarding v2 (PR #59) was the pilot
alignment pass and shipped *before* this rule existed. It used the older
"patch v1 in place" approach. It will be retroactively refactored into
the `v2/` subdirectory convention as a follow-up to the Home v2 pass,
mostly to validate that the rule scales to a feature with multiple
screens. Tracked in the per-screen UX alignment plan in `backlog.md`.

## Key Paths

- PRD: `docs/product/PRD.md`
- Metrics: `docs/product/metrics-framework.md`
- Backlog: `docs/product/backlog.md`
- Roadmap: `docs/project/master-backlog-roadmap.md`
- Feature state: `.claude/features/{name}/state.json`
- PM skill: `.claude/skills/pm-workflow/SKILL.md`
