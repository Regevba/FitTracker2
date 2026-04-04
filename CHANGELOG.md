# Changelog

All notable FitTracker milestones are summarized here in human-readable form.

This changelog is intentionally lightweight. It is not a commit dump and it is not a replacement for the README or the full walkthrough.

## 2026-04-04 — GDPR Compliance + Google Analytics

### Added (GDPR)
- **AccountDeletionService** — 10-step deletion cascade across 9 data stores with 30-day grace period
- **DataExportService** — JSON export of all user data via iOS share sheet
- **DeleteAccountView** — account deletion UI with biometric re-auth, "I understand" toggle, grace period countdown
- **ExportDataView** — data summary + one-tap JSON export
- **Settings integration** — "Delete Account" in Account & Security, "Export My Data" in Data & Sync
- **5 GDPR analytics events** (delete requested/completed/cancelled, export requested/completed)
- **6 new tests** (23 total analytics tests)
- **Missing back buttons fixed** — SettingsView sheet + RecoveryRoutineSheet now have dismiss buttons

---

## 2026-04-04 — Google Analytics (GA4) Integration

### Added
- **Firebase Analytics SDK** integrated via SPM (FirebaseAnalytics package)
- **AnalyticsProvider protocol** with adapter pattern (Firebase + Mock for testing)
- **ConsentManager** — GDPR consent + ATT authorization, UserDefaults persistence
- **AnalyticsService** — consent-gated orchestrator with 20 typed convenience methods
- **ConsentView** — GDPR consent screen on first launch (Accept & Continue / Continue Without)
- **Settings analytics toggle** — enable/disable in Data & Sync settings
- **Screen tracking** on 9 primary views via `.analyticsScreen()` ViewModifier
- **17 unit tests** — event firing, consent gating, taxonomy validation
- **Analytics taxonomy CSV** — 20 events, 24 screens, 6 user properties, 5 conversions
- **Firebase setup guide** — 20-step guide from zero to working analytics
- **PM Skill v1.2** — Analytics Instrumentation Gate (pre-code spec, testing, post-merge regression)
- **Marketing & Growth Strategy** (Task 19) added to roadmap with 7 areas

### Changed
- **Metrics framework** — 11 metrics marked as instrumented (14/40 = 35% coverage)
- **FitTrackerApp** — Firebase initialization, AnalyticsService as EnvironmentObject, consent flow in auth state machine

---

## 2026-04-02 — Development Dashboard & PM Platform

### Added
- **Development Dashboard** (`dashboard/`): Astro + React + Tailwind v4 custom dashboard
  - KanbanBoard with dnd-kit drag-drop (8 columns, undo toast)
  - TableView with @tanstack/react-table (sortable, filterable, searchable)
  - PipelineOverview stacked bar chart
  - AlertsBanner (reconciliation alerts with severity levels)
  - SourceHealth panel (per-source health indicators)
  - ThemeToggle (dark mode with localStorage + system preference)
  - 6 markdown parsers (backlog, roadmap, PRD, metrics, state, unified)
  - GitHub API client + reconciliation engine
  - Responsive layout (desktop/tablet/mobile)
  - Vercel deployment config
  - 37 features tracked (11 shipped, 11 planned, 15 backlog)

---

## 2026-04-02 — Product Management Platform & Foundation Docs

### Added
- **Phase 0 Foundation Docs** (PR #20): unified PRD (620 lines, 11 features), metrics framework (40 metrics, 6 categories), complete backlog (Done/Planned/Backlog/Icebox), RICE-prioritized 18-task roadmap with phase gates
- **Public README**: badges, features (5 pillars), architecture diagram, tech stack, privacy section, getting started, roadmap
- **PM Workflow Skill** (PR #21): `/pm-workflow {feature-name}` — 9-phase lifecycle (Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs) with post-launch metrics review
- **PRD Template**: mandatory success metrics (primary, secondary, guardrails, leading/lagging indicators, instrumentation, baseline, target, review cadence, kill criteria)
- **Research Template**: Phase 0 discovery (alternatives comparison, external sources, market examples, design inspiration, data/demand signals, technical feasibility)
- **UX Research & Principles**: Fitts's Law, Hick's Law, progressive disclosure, Jakob's Law, iOS HIG patterns integrated into Phase 3
- **Design System Compliance Gateway**: automated 5-point check (tokens, components, patterns, accessibility, motion) with 3 user options: fix, evolve the system, or override with justification
- **Living Design System philosophy**: design system documented as evolving framework. New tokens/components proposed on feature branches, reviewed alongside code, merge together.
- **Dashboard Sync Automation**: auto-sync state.json → GitHub Issue labels on phase transitions, manual override (forward skip + backward rollback), transition audit log, conflict resolution between state.json and GitHub
- **CLAUDE.md**: project-wide rules for PM lifecycle, branching strategy, CI requirements, data-driven development, design system governance
- **SessionStart hook**: shows active features and current phase on every session open
- **Showcase doc**: `docs/showcase/pm-workflow-skill.md` — externally-shareable skill overview with diagrams
- **Figma prototype audit**: `docs/design-system/figma-prototype-audit.md` — file structure, 14 missing screens, MCP limitations
- **Figma prototype prompt**: `docs/design-system/figma-prototype-prompt.md` — 22+ screen build prompt for Claude console
- **Notion setup prompt**: `docs/product/notion-setup-prompt.md` — workspace creation prompt for Claude console
- **Development Dashboard** (in progress): custom Astro + Tailwind + GitHub API dashboard — first feature built using `/pm-workflow`, showcasing the PM system end-to-end

### Changed
- README.md replaced with public-facing product README (old version relocated to `docs/project/original-readme-redesign-casestudy.md`)
- `.gitignore` updated to allow `.claude/skills/` and `.claude/settings.json` to be committed

### Docs
- `docs/process/product-management-lifecycle.md` — full showcase documentation with lifecycle diagrams, phase walkthroughs, branching strategy, UX compliance gateway, dashboard sync, and example feature walkthrough

---

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
