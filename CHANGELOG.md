> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# Changelog

All notable FitTracker milestones are summarized here in human-readable form.

This changelog is intentionally lightweight. It is not a commit dump and it is not a replacement for the README or the full walkthrough.

## 2026-04-07 — Onboarding v2 UX Alignment + 4-Day Branch Consolidation

PR #59 — squash-merged to main as `66e42cf`. Pilot run for the sequential UX alignment initiative; first feature in the feature-by-feature pass against `docs/design-system/ux-foundations.md`. Also consolidates 4 days of unmerged design system, UX foundations, marketing website, GDPR, GA4, and skills ecosystem work.

### Added
- **Onboarding flow shipped** — 6-screen onboarding (Welcome → Goals → Profile → HealthKit → Consent → First Action) with full GA4 instrumentation, back navigation, haptic feedback, Dynamic Type ScrollView wrappers, HealthKit loading + denial states, iPad fallback copy. v2 alignment per `ux-foundations.md`.
- **UX Foundations doc** — `docs/design-system/ux-foundations.md` (1,533 lines, 10 parts): 8 core heuristics + 5 FitMe-specific principles, IA, interaction patterns, data viz, permission/trust, state patterns, accessibility, motion, content strategy, platform adaptations.
- **5 new analytics events** — `permission_result`, `onboarding_step_viewed`, `onboarding_step_completed`, `onboarding_skipped`, `onboarding_goal_selected`. Plus 5 new screen tracking entries and 5 new params. All additive.
- **New design system token groups** — `AppSize` (ctaHeight, touchTargetLarge, iconBadge, progressBarHeight), `AppMotion` (stepTransition, quickInteraction), `AppShadow.ctaInverse*` (white-CTA-on-orange shadow), `AppRadius.card` alias.
- **`/ux` skill** — UX planning layer for the PM workflow hub.
- **Marketing website** — Astro + Tailwind static site (66 files under `website/`).
- **GDPR compliance feature complete** — account deletion + data export services, views, analytics taxonomy, Settings wiring, 6 GDPR analytics tests.
- **Android Design System complete** — full token mapping (92 iOS tokens → MD3) + Style Dictionary config.
- **Skills ecosystem v1** — 9 skills + 8 shared data files, parallel task hub with skill routing + priority queue + SSD storage.
- **18 standalone PRDs** for all features.
- **PM workflow showcase** — `docs/project/pm-workflow-showcase-onboarding.md` documenting onboarding v2 as the exemplar run for the enhanced `/pm-workflow` skill.

### Fixed
- **5 latent v1 onboarding compile bugs** discovered + fixed during v2 alignment audit. v1 onboarding had never built successfully:
  1. `analytics.logEvent()` called as public — actually private. Replaced with typed `logTutorialBegin()` / `logTutorialComplete()`.
  2. `analytics.logScreenView(_:screenClass:)` overload missing — added.
  3. `AppRadius.card` referenced but undefined — added as alias.
  4. `FitMeBrandIcon.swift` not in Xcode target — added.
  5. `Onboarding/*.swift` files not in Xcode target — added.
- **Sprint A**: eliminated all raw font/spacing literals across 11 view files (commit `8b16774`).
- **Accessibility**: a11y labels on icon-only and custom buttons across views, #Preview blocks on AppComponents and ReadinessCard.
- **Stabilization**: build, sync, privacy flows; force unwrap elimination; SSD home path migration.

### Verified
- `xcodebuild build` clean on iPhone 17 simulator
- `xcodebuild test` — all tests pass
- `make tokens-check` — DesignTokens.swift in sync with tokens.json
- CI green on PR #59 and on main post-merge

### Backwards Compatibility
- Analytics taxonomy: **additive only** — zero removed/renamed events
- Design tokens: **additive only** — zero removed/renamed tokens
- Sync, encryption, auth: **untouched** beyond onboarding gate placement in `FitTrackerApp.swift`
- New `@AppStorage("hasCompletedOnboarding")` — existing users see onboarding once on next launch (intentional v1 launch behavior)

### Deferred to follow-up
- Figma v2 build (V2-T5) — runner prompt ready at `docs/project/figma-runner-prompt.md`
- P2-01 component consolidation, P2-05 a11y hints, P2-06 contrast bump, P2-07 pillar text size
- Figma Code Connect mappings (13 components)

### First metrics review
Scheduled for 2026-04-14 (1 week post-merge). Primary metric: onboarding completion rate (target >80%). Kill criteria: redesign if completion rate <50% after 30 days.

## 2026-04-06 — Runtime Verification Checkpoint Before SSD Move

### Changed
- **Runtime checkpoint docs** now record that a clean simulator reinstall reaches the consent gate on first launch, and that the earlier `Biometry is not enrolled` alert was stale simulator state rather than the true first-launch path

### Verified
- `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination id=87E96E30-350E-46AC-AB34-B87AF8D1AB1E` passes from the matching stabilized clone at `/tmp/FitTracker2-review`
- the built app installs and launches on the iPhone 14 Pro simulator
- a clean reinstall lands on the consent screen on first launch

### Remaining Blockers
- real Supabase runtime verification is still blocked by placeholder values in `FitTracker/Info.plist`
- real Firebase runtime verification is still blocked until a local `FitTracker/GoogleService-Info.plist` is supplied

## 2026-04-05 — Stabilization Recovery, Build Repair, and Truth Alignment

### Added
- **`FitTracker/Info.plist` restored** so the app target can build again on a clean checkout
- **Supabase deletion support** for `sync_records`, `cardio_assets`, and encrypted cardio image blobs
- **CloudKit deletion support** for the app's encrypted private records
- **Explicit local encrypted-file deletion path** for `.ftenc` blobs
- **Explicit encryption-key deletion path** for the keychain-backed encryption material
- **Sync uniqueness repair migration** in `backend/supabase/migrations/000008_fix_sync_records_uniqueness.sql`
- **Expanded iOS core regression coverage** in `FitTrackerTests/FitTrackerCoreTests.swift` for auth/session and deletion-related flows
- **Stabilization report** in `docs/project/stabilization-report-2026-04-05.md`

### Changed
- **Xcode project recovery**: Firebase packages linked, missing analytics/GDPR source files re-added to the target, and the iOS app now builds with full Xcode
- **Firebase bootstrap**: analytics now fall back to the mock adapter during XCTest or when `GoogleService-Info.plist` is absent, so clean builds and unit tests do not depend on local secrets
- **Auth lifecycle**: `restoreSession()` can reactivate a valid stored session when biometric reopen is disabled, and `signOut()` now revokes the local Supabase auth session
- **Deletion flow**: analytics now report only stores actually deleted, and the service surfaces partial-failure state instead of always claiming success
- **Simulator settings review path**: `FITTRACKER_REVIEW_TAB=settings` now routes through the app-level settings review gate, and the settings destinations explicitly receive `AnalyticsService`
- **Simulator delete-account review route**: `FITTRACKER_REVIEW_SETTINGS_DESTINATION=delete-account` now opens the nested GDPR deletion screen through the real settings navigation stack for deterministic runtime verification
- **Simulator export-data review route**: `FITTRACKER_REVIEW_SETTINGS_DESTINATION=export-data` now opens the nested data-portability screen through the real settings navigation stack for deterministic runtime verification
- **Daily-log sync merge fix**: `mergeDailyLog` now matches on `resolvedLogicDayKey`, so different dated rows no longer collapse together when `logicDayKey` is absent on decoded logs
- **Data export** reconciled with the current domain model instead of stale field names
- **AI engine tests** now use a self-contained stub-settings fixture instead of implicitly depending on production-style Supabase env vars
- **Supabase runtime config handling** now degrades gracefully on placeholder local config instead of crashing on `fatalError`
- **Dashboard reconciliation** now marks GitHub as unhealthy when PM state exists without a matching GitHub issue
- **README / planning docs** updated to reflect the recovered build state and the remaining stabilization gaps

### Verified
- `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS'` passes
- `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -only-testing:FitTrackerTests/FitTrackerCoreTests` passes on simulator
- `npm run tokens:check` passes
- dashboard tests pass (`9/9`)
- dashboard production build passes
- marketing website production build passes
- AI engine tests pass (`5/5`)
- targeted local verification can now be reproduced via `make verify-local`

### Coverage Notes
- `FitTrackerCoreTests` now runs `31` simulator-backed tests
- `FitTrackerCoreTests` now also verifies graceful handling for missing local Supabase config
- coverage now includes simulator auto-login opt-out, lock/resume auth flow, stale-session cleanup, local encrypted-file deletion, deletion grace-period request/cancel/restore, simulator partial-failure deletion reporting, and JSON export generation verification
- `SyncMergeTests` passes (`9/9`) and now verifies multiple dated daily logs and weekly snapshots coexist correctly after merge
- the consolidated `make verify-local` target now passes end to end, including `40` passing XCTest cases across `FitTrackerCoreTests` and `SyncMergeTests`
- simulator runtime spot-check on `2026-04-06` now confirms the live Settings screen plus both nested GDPR/settings screens (`Delete Account`, `Export My Data`) launch in review mode after the settings-review routing and environment injection fixes

### Still Open
- Firebase runtime verification still needs a local `GoogleService-Info.plist`
- signed-in device/runtime sync plus deletion/export execution verification still needs local runtime credentials and backend validation

## 2026-04-04 — Marketing Website + Feature PRDs + README Update

### Added (Marketing Website)
- **Marketing website** (`website/`): Astro + Tailwind v4 single-page site
  - 9 components: Nav, Hero, Features, Screenshots, HowItWorks, Privacy, FAQ, CTA, Footer
  - GA4 web analytics: 3 custom events (cta_click, section_view, faq_expand)
  - SEO: JSON-LD structured data, OG tags, Twitter Cards, canonical URL, robots.txt
  - Vercel deployment config
  - FitMe brand tokens in global.css

### Added (Feature PRDs — Task 18)
- **18 standalone PRDs** in `docs/product/prd/`:
  - 11 shipped iOS features (training, nutrition, recovery, home, stats, auth, settings, data & sync, AI, design system, onboarding)
  - 5 PM workflow features (GA4, GDPR, dashboard, Android DS, website)
  - 3 infrastructure systems (AI backend, CI pipeline, PM skill)
  - PRD index with discrepancy notes

### Changed
- **README.md** updated: accurate feature descriptions, web properties section, current roadmap status, expanded documentation index
- **Roadmap** updated: Phase 0 marked complete, shipped features inventory expanded

---

## 2026-04-04 — Android Design System + GDPR + GA4 + Figma

### Added (Android Design System)
- **Token mapping document** — 92 iOS tokens mapped to MD3 equivalents (`docs/design-system/android-token-mapping.md`)
- **Style Dictionary Android config** — generates Kotlin/Compose + XML resources from `tokens.json`
- **Component parity audit** — 13 iOS components mapped to MD3 composables
- **Dark mode strategy** — iOS opacity-based → MD3 tonal elevation mapping
- **Compose code examples** — FitMeTheme, FitMeLightColors, FitMeExtendedColors

---

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
