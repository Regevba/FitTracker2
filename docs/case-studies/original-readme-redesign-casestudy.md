> Originally the repo README. Moved 2026-04-02 when the public README was created.

# FitTracker — Redesign Case Study

FitTracker is an iPhone-first fitness command center designed to help a user understand today, act quickly, and stay consistent across training, nutrition, recovery, and body-composition goals.

This repository is both a product build and a redesign case study. It shows how the app evolved from a capable but visually inconsistent SwiftUI project into a more unified Apple-first experience with a real design system, screen-by-screen review process, and live Figma assets.

## Quick Links

- Figma design system and live app file: [FitTracker Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)
- Full project story: [FitTracker Evolution Walkthrough](docs/case-studies/fittracker-evolution-walkthrough.md)
- Milestone summary: [CHANGELOG.md](CHANGELOG.md)
- Merge brief: [UI Integration PR Draft](docs/master-plan/ui-integration-pr-draft.md)
- Design-system docs: [docs/design-system](docs/design-system)

## Project Snapshot

FitTracker combines five product jobs in one experience:
- daily status and next-best-action guidance
- active workout tracking
- adaptive nutrition planning and meal logging
- progress and body-composition review
- secure personal data handling with Apple-first sign-in and encryption

The current design direction is:
- iPhone first
- Apple-first visual language
- semantic design system in code and Figma
- live editable screen assets instead of static mockups

## Why This Project Exists

The app started with strong product ambition, but over time the team ran into a common problem: the product was getting better, yet the system around it was not keeping up.

There were three main issues:
- screens were evolving quickly but not always together
- styling and interaction patterns were too local and inconsistent
- Figma, runtime truth, and documentation were not tightly connected

The recent work in this repository was about solving that, not just polishing visuals.

## What Changed

The product evolved in a few major stages.

### 1. Core app foundation
The app established its SwiftUI shell, encrypted local data model, HealthKit connections, sync architecture, training logic, nutrition logging, and the base product flows.

### 2. Today-first product redesign
The user-facing experience was rebuilt around a clearer idea:
- `Home` became a focused Today screen
- `Training` became an active-session flow
- `Nutrition` became more adaptive and easier to log
- `Stats` became a more readable progress hub

### 3. Auth and settings overhaul
The trust and account side of the app was reworked:
- auth moved toward a cleaner Apple-first flow
- Apple Sign In and passkeys became central
- settings moved from a flat form into grouped categories

### 4. Design system and review workflow
The project then introduced:
- semantic tokens in code
- shared UI primitives
- design-system governance docs
- Figma library structure
- screen-by-screen approval workflow
- runtime-to-Figma reverse-sync

### 5. Apple-first integration phase
Approved screens were consolidated into one integration branch and synchronized into a shared, editable design system file so the app could be reviewed as one coherent product.

For the full phase-by-phase story, read [FitTracker Evolution Walkthrough](docs/case-studies/fittracker-evolution-walkthrough.md).

## Current Approved Product State

The current approved Apple-first screens are:
- Login
- Home
- Training
- Nutrition
- Stats
- grouped Settings

What is already in good shape:
- semantic Apple-first tokens and shared UI primitives
- integrated approved screen baselines in code
- synchronized Figma live assets for the approved screens
- guidance for color, typography, spacing, review standards, and UX copy

What is still part of the current phase closeout:
- final integrated runtime proof at the same standard for every approved screen
- the live iPhone prototype in Figma representing the full approved app state map
- final merge and handoff packaging for `main`

## Design System And Prototype

Primary file:
- [FitTracker Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)

That file is intended to be more than a design-system reference. It is the active design workspace for:
- foundations
- shared components
- product-area pages
- integrated runtime boards
- the live iPhone prototype for the app

Prototype status:
- an initial live iPhone prototype now exists in the same Figma file as the design system
- it is built from approved integrated runtime boards rather than screenshots
- it currently covers the main app flow plus representative grouped Settings detail states
- it remains part of the completion gate for the current Apple-first phase because final state expansion and polish are still in progress

This setup is intentional: it keeps product, design system, and prototype work connected in one place.

## Why This Repo Can Work As A Presentation Project

This repository is not only a codebase. It also shows a product-design process:
- where the product started
- how the UI and UX changed
- why the design system was introduced
- how screens were reviewed and approved
- how code and Figma were kept aligned

That makes it suitable as a portfolio or presentation project alongside the prototype, because it shows both outcome and process.

If you are sharing this project publicly, the best reading order is:
1. this README
2. the Figma file
3. the walkthrough doc
4. the changelog

## Repo Guide

The easiest way to understand the repository is by layer:

### Product code
- `FitTracker/`
- SwiftUI screens, services, models, app shell, and shared UI primitives

### Tests
- `FitTrackerTests/`
- regression and design-system guard coverage

### Design-system and review docs
- `docs/design-system/`
- governance, progress tracking, review rules, and platform notes

### Feature/spec docs
- `docs/superpowers/`
- planning and template artifacts

### Related legal repository
- `FitMe-GDPR-Docs/`
- separate legal/privacy work and not part of the main product redesign story

## Merge Status

The current Apple-first UI integration target is:
- source branch: `codex/ui-integration`
- target branch: `main`

The intent is to treat `codex/ui-integration` as the integrated Apple-first source of truth for this phase.

Important merge guidance:
- merge `codex/ui-integration` into `main`
- do not separately merge older per-screen UI branches if their approved work is already integrated here
- confirm runtime, Figma, and docs are aligned before calling the phase complete

For the full merge brief, read [UI Integration PR Draft](docs/master-plan/ui-integration-pr-draft.md).

## Build

Build with Xcode 15.2+ or use:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FitTrackerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Notes:
- HealthKit requires Apple-platform runtime permissions
- CloudKit is intentionally disabled on simulator builds
- simulator QA can still be flaky if local CoreSimulator services are unhealthy
- final device validation on iPhone 14 Pro remains part of the current phase closeout

## What Comes Next

After the Apple-first phase is fully closed, the next major work is:
- finish expanding and polishing the live iPhone prototype
- finalize the merge package
- merge the Apple-first baseline into `main`
- move into App Store asset production and Android / Pixel adaptation

## Additional Reading

- [FitTracker Evolution Walkthrough](docs/case-studies/fittracker-evolution-walkthrough.md)
- [CHANGELOG.md](CHANGELOG.md)
- [UI Integration PR Draft](docs/master-plan/ui-integration-pr-draft.md)
