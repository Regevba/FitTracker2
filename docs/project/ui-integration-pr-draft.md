# UI Integration PR Draft

Draft PR target:
- source: `codex/ui-integration`
- target: `main`

Status:
- ready as a local draft brief
- remote PR creation is currently blocked because local `gh` authentication is invalid

Suggested PR title:
- `Apple-first UI integration: approved screens, design system sync, and merge package`

---

## Why this phase happened

FitTracker had made meaningful product progress, but the UI, design review flow, and documentation were still too fragmented.

This phase happened to:
- bring the approved Apple-first screens together into one branch
- treat the design system as a real implementation layer
- synchronize runtime truth and Figma
- make the current UI understandable and mergeable

## Where the project started

The app started as a capable SwiftUI product with training, nutrition, recovery, stats, sync, and secure data work already in place.

Over time, the core product improved quickly, but three problems appeared:
- visual inconsistency between screens
- too much local styling and branch drift
- weak traceability between code, design, and review

This PR is the result of the work done to solve those problems.

## What changed in this phase

### Product integration
- approved Apple-first screens were consolidated into `codex/ui-integration`
- Home, Training, Nutrition, Stats, Login, and grouped Settings now live under one integrated UI baseline

### Design system
- semantic tokens and shared UI primitives were established and documented
- Foundations guidance was expanded for color, typography, spacing, review standards, and UX copy
- exact token values were added for stronger design/code handoff

### Review workflow
- screen-by-screen approval replaced uncontrolled mixed-branch UI iteration
- integrated runtime review mode was added for simulator verification
- Figma was reverse-synced with editable integrated runtime boards instead of static visual references

### Documentation
- the repo now includes clearer design-system memory, progress, review standards, and merge guidance
- README and project-history documentation were rewritten to make the current state easier to understand

## Approved screens and system work

Approved screens:
- Login
- Home
- Training
- Nutrition
- Stats
- grouped Settings

Approved system work:
- semantic Apple-first color and type foundation
- shared reusable UI primitives
- integrated review workflow
- live Figma design-system library with editable approved boards

## Figma design system and live prototype

Primary file:
- [FitTracker Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)

What is in the file now:
- Foundations
- Components
- Patterns
- product-area pages
- integrated runtime boards for approved screens

Prototype note:
- a first live iPhone prototype now exists in the same Figma file as the design system
- it is built from approved integrated runtime boards rather than screenshots
- it currently covers the main app flow plus representative grouped Settings detail states
- this section should still be refreshed before merge once the prototype reaches final state coverage and polish

## Verification and runtime review

This phase used:
- dedicated screen branches for approval
- integrated simulator review mode on `codex/ui-integration`
- runtime-to-Figma reverse-sync
- design-system acceptance docs

Recommended final pre-merge verification:
- Xcode build on `codex/ui-integration`
- unified simulator review across approved screens
- iPhone 14 Pro device QA
- Figma link and board validation
- README and design-system doc validation

## What to merge

Merge:
- `codex/ui-integration` into `main`

Treat `codex/ui-integration` as:
- the integrated Apple-first UI baseline
- the main source of truth for the approved screens and their supporting design-system work

## What not to merge separately

Do not separately merge older per-screen branches if their approved work is already represented in `codex/ui-integration`, including:
- `codex/ui-foundation`
- `codex/ui-auth`
- `codex/ui-home`
- `codex/ui-training`
- `codex/ui-nutrition`
- `codex/ui-stats`
- `codex/ui-settings`

If a later audit finds an approved change in one of those branches that is still missing from `codex/ui-integration`, that gap should be merged into `codex/ui-integration` first rather than merged independently into `main`.

## Remaining follow-ups

Before calling the Apple-first phase fully closed:
- finish the last uniform runtime-proof pass across all approved screens
- complete and document the live iPhone prototype in Figma
- refresh this PR body if the prototype or final runtime evidence changes

After merge:
- begin App Store production-asset preparation
- continue device QA
- start Android / Pixel adaptation from the same semantic design system
