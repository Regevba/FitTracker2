# Changelog

All notable FitTracker milestones are summarized here in human-readable form.

This changelog is intentionally lightweight. It is not a commit dump and it is not a replacement for the README or the full walkthrough.

## 2026-03-29 — Apple-first integration phase

### Added
- integrated Apple-first UI baseline on `codex/ui-integration`
- unified simulator review mode for integrated screen verification
- synchronized Figma integrated runtime boards for approved screens
- stronger Foundations guidance for color, typography, spacing, review standards, and UX copy
- initial live iPhone prototype pages in Figma, including the main app flow and representative grouped Settings detail screens

### Changed
- the UI review process now runs through screen approval, runtime proof, and Figma reverse-sync instead of ad hoc branch drift
- approved screens now live together as one integrated branch rather than as isolated design experiments
- documentation now treats the design system and Figma file as part of the product source of truth

### Fixed
- multiple runtime-to-Figma mismatches across approved screens
- incomplete color guidance by adding exact hex and RGBA token values
- inconsistent review standards between screens

### Docs
- expanded design-system governance and memory docs
- added integration acceptance criteria
- started the merge-ready documentation package for the Apple-first phase

## 2026-03-28 — UI foundation and screen locking

### Added
- shared UI foundation branch and per-screen UI branches
- approved baselines for auth, home, training, nutrition, stats, and grouped settings
- design-system docs, catalog view, and semantic token guidance

### Changed
- moved from one large mixed UI branch to a clearer branch-per-screen process
- began treating Figma as an editable review surface instead of a disconnected mockup

### Fixed
- reduced design drift between branches and screens
- isolated reusable system work from screen-specific changes

### Docs
- documented screen lock state, branch structure, and Figma progress

## 2026-03-25 to 2026-03-26 — Auth and settings overhaul

### Added
- trust-first auth hub with login and create-account modes
- passkey and Apple Sign In improvements
- grouped Settings architecture with clearer category structure

### Changed
- auth moved toward a lighter Apple-first direction
- settings moved away from one long flat form

### Fixed
- contrast, hierarchy, and flow issues in auth and settings

### Docs
- README updates reflecting the auth and settings redesign direction

## 2026-03-15 — Today-first app overhaul

### Added
- focused Home experience
- redesigned Training session flow
- adaptive Nutrition planning and smarter logging
- stronger Stats storytelling and metric organization

### Changed
- the product shifted from a more fragmented set of screens to a clearer `Today`-first command center

### Fixed
- multiple sync and reliability issues around auth, stats refresh, and simulator behavior

### Docs
- README refreshed to reflect the major product overhaul

## 2026-03-12 to 2026-03-13 — Design-system and v2 redesign groundwork

### Added
- early semantic design-system tokens and shared UI primitives
- v2 redesign documentation and feature specs

### Changed
- the codebase started moving away from local styling toward reusable tokens and components

### Fixed
- several SwiftUI and CI issues discovered during the redesign push

### Docs
- early redesign documentation and updated README structure

## 2026-02-28 — Initial project baseline

### Added
- first project commit
- initial app shell, core product direction, and repository baseline

### Changed
- established the codebase that later redesign and integration work built on top of

### Docs
- initial repository setup
