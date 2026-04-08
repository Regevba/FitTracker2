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

1. **Create a new V2 Swift file** as a sibling of the existing one. Naming:
   `{ScreenName}.swift` (v1, historical) → `{ScreenName}V2.swift` (v2,
   the new source of truth). Example: `MainScreenView.swift` →
   `MainScreenViewV2.swift`.
2. **Build the V2 file bottom-up** from the design system foundations
   (tokens, components, ux-foundations principles) — do **not** patch the
   v1 file in place. v1 is read-only during the refactor.
3. **Wire the V2 file in** at its parent (e.g. `RootTabView.swift` switches
   from `MainScreenView()` to `MainScreenViewV2()`) once V2 is functionally
   complete and passes the design system compliance gateway.
4. **Keep the v1 file in the repository** with a header comment marking it
   as historical (`// HISTORICAL — superseded by {ScreenName}V2.swift on
   {date} per UX Foundations alignment pass.`). v1 stays in the Xcode build
   target as compiled-but-unreferenced reference code so the diff is
   reviewable. If a future change foundationally breaks v1, the choice at
   that moment is "fix v1 to keep it compiling" or "remove v1 from build
   target", recorded in `feature-memory.md`.
5. **One V2 file per refactor pass.** A second alignment pass on the same
   screen does not become V3 in this repo — it patches V2 in place. The
   v1 → v2 split exists exactly to capture the *first* deliberate
   foundations-aligned rewrite of a pre-PM-workflow surface.

**For new UI features built from scratch** (no v1 to refactor):
- The Phase 3 (UX) gateway is **non-skippable** — every new UI feature
  must produce a `ux-spec.md` and pass the design system compliance
  gateway before any view code is written.
- Phase 4 (Implement) starts with the `ux-foundations.md` checklist
  applied to the spec, then the view code. No "build first, audit later".

**Backward compatibility note:** Onboarding v2 (PR #59) was the pilot
alignment pass and shipped *before* this rule existed. It used the older
"patch v1 in place" approach. It is intentionally inconsistent with this
rule and is documented as a pre-rule v2 pass in
`docs/design-system/feature-memory.md`. The rule applies prospectively
from `home-today-screen` v2 onward.

## Key Paths

- PRD: `docs/product/PRD.md`
- Metrics: `docs/product/metrics-framework.md`
- Backlog: `docs/product/backlog.md`
- Roadmap: `docs/project/master-backlog-roadmap.md`
- Feature state: `.claude/features/{name}/state.json`
- PM skill: `.claude/skills/pm-workflow/SKILL.md`
