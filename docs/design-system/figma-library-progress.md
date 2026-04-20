> ⚠️ Historical document. References to `docs/project/` paths are from before the April 2026 reorganization. See `docs/master-plan/`, `docs/setup/`, and `docs/case-studies/` for current locations.

# FitTracker Figma Library Progress

## Current file

- File name: `FitTracker Design System Library`
- File key: `0Ai7s3fCFqR5JXDW8JvgmD`
- File URL: <https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD>
- Run ID: `fittracker-ds-2026-03-27`

## Completed so far

### Phase 0: discovery

- Confirmed there was no pre-existing FitTracker Figma library to preserve.
- Mapped the source of truth from:
  - `FitTracker/Services/AppTheme.swift`
  - `FitTracker/Views/Shared/AppDesignSystemComponents.swift`
  - `docs/design-system/design-tokens.json`
  - `docs/design-system/component-contracts.md`
  - `docs/design-system/figma-library-structure.md`
- Searched subscribed design-system assets and found no meaningful reusable match, so this is a clean FitTracker-native build.
- Locked the approved v1 scope:
  - Foundations: semantic colors, typography roles, spacing, radius, elevation, motion placeholders
  - Components: `AppButton`, `AppCard`, `AppMenuRow`, `AppSelectionTile`, `AppInputShell`, `AppFieldLabel`, `AppQuietButton`, `StatusBadge`, `EmptyStateView`
  - Pages to create later: `Cover`, `Getting Started`, `Foundations`, `---`, `Components`, `---`, `Patterns`, `Platform Adaptations`

### Phase 1: foundations completed

- Created these variable collections in Figma:
  - `Color / Semantic`
  - `Text / Roles`
  - `Spacing`
  - `Radius`
  - `Elevation`
  - `Motion`
- Created semantic variables in the library:
  - `Color / Semantic`: 46 variables
  - `Text / Roles`: 22 variables
  - `Spacing`: 8 variables
  - `Radius`: 6 variables
  - `Elevation`: 6 variables
  - `Motion`: 4 variables
- Applied explicit scopes to every created variable.
- Added code syntax for:
  - `WEB`
  - `iOS`
  - `ANDROID`
- Created text styles for all `AppText` roles using a reliable Figma fallback stack:
  - Rounded roles: `Nunito`
  - Monospaced roles: `IBM Plex Mono`
- Created effect styles:
  - `effect/elevation-card`
  - `effect/elevation-cta`

### Phase 2: file structure and docs in progress

- Created the page skeleton:
  - `Cover`
  - `Getting Started`
  - `Foundations`
  - `---`
  - `Components`
  - `---`
  - `Patterns`
  - `Platform Adaptations`
- Added initial documentation frames on:
  - `Cover`
  - `Getting Started`
  - `Foundations`
- Validated the `Foundations` page with a screenshot pass.

### Phase 3: first component started

- Created the first component family on the `Components` page:
  - `AppButton`
- Added 8 variants:
  - hierarchy: `Primary`, `Secondary`, `Tertiary`, `Destructive`
  - state: `Default`, `Disabled`
- Validated the `Components` page with a screenshot pass.

### Phase 3: approved v1 component set built

- Created the remaining approved v1 component families on the `Components` page:
  - `AppCard`
  - `AppMenuRow`
  - `AppSelectionTile`
  - `AppInputShell`
  - `AppFieldLabel`
  - `AppQuietButton`
  - `StatusBadge`
  - `EmptyStateView`
- Added representative state and semantic variants for each family instead of leaving them as single static examples.
- Re-validated the `Components` page after the full v1 component pass.

### Phase 3: documentation pages expanded

- Added initial documentation frames on:
  - `Patterns`
  - `Platform Adaptations`
- Validated the `Patterns` page with a screenshot pass.

### Phase 3: repositories and product spaces expanded

- Added dedicated pages for:
  - `Icon Repository`
  - `Typography Repository`
  - `App Icon + App Store`
- Added dedicated product-area pages for:
  - `Onboarding`
  - `Login`
  - `Greeting`
  - `Main Screen`
  - `Settings`
  - `Nutrition`
  - `Stats`
  - `Training`
  - `Account + Security`
- Populated the new repository pages with:
  - icon categories
  - typography role usage
  - raw font debt notes
  - app icon and App Store submission sizing guidance
- Populated the new product-area pages with:
  - purpose/problem
  - source files
  - key components
  - key typography
  - key icons
- Validated the `Icon Repository` and `Main Screen` pages with screenshot passes.

### Phase 3: responsive handoff rules added

- Added the responsive asset and handoff contract to the repo in `docs/design-system/responsive-handoff-rules.md`.
- Validated the current app runtime on an iPhone 14 Pro simulator:
  - build succeeded
  - install succeeded
  - launch succeeded
  - screenshot capture succeeded
- Identified and patched the first remaining fixed-width risks in code:
  - compact numeric fields in `MainScreenView`
  - stats metric tiles in `StatsView`
  - training entry fields in `TrainingPlanView`
  - quick-meal cards in `NutritionView`
- Mirrored the same rules into the Figma library on:
  - `Platform Adaptations`
  - `App Icon + App Store`
- Validated both new Figma documentation blocks with screenshot passes.

### Phase 3: live screen sync started

- Reversed the flow from code back into Figma by rebuilding the current auth screen as live editable layers on the `Login` page.
- Confirmed the active login source of truth is `FitTrackerApp.swift` → `AuthHubView.swift` rather than the older standalone `SignInView`.
- Captured fresh simulator references for:
  - iPhone 14 Pro current login state with quick return
  - compact-width auth state on iPhone 16e
- Added a new `Current Login UI from Code` board plus a live `Auth Screen / iPhone 14 Pro` frame to the Figma `Login` page.
- Validated the new live auth frame with a screenshot pass.

### Phase 3: auth screen refined with design-first loop

- Updated the `Login` page board first in Figma before the next auth code pass.
- Removed the large auth surface container from the live auth mockup and shifted to a lighter floating-control layout on the blue gradient background.
- Moved the trust badges into a bottom-centered anchored position on the auth frames instead of leaving them in the main content flow.
- Synced the same direction back into `AuthHubView.swift` after the Figma pass.
- Verified the refreshed auth runtime successfully on iPhone 14 Pro after the containerless refactor.
- Compact-device simulator launch remains intermittently flaky during screenshot capture, so the current compact auth board is still design-verified in Figma even when simulator foregrounding is inconsistent.

### Phase 3: approved screen set expanded through Settings

- Approved and locked these product-area pages in the live file:
  - `Login`
  - `Main Screen`
  - `Training`
  - `Nutrition`
  - `Stats`
- The `Settings` source of truth was corrected on 2026-03-29 after discovering that the dedicated branch had drifted back to an older flat form.
- The approved runtime truth for `Settings` is now the grouped dashboard architecture with category cards and detail destinations:
  - `Account & Security`
  - `Health & Devices`
  - `Goals & Preferences`
  - `Training & Nutrition`
  - `Data & Sync`
- The next Figma sync should place this grouped Settings screen into the `Settings` page as the locked source-of-truth board and retire the stale flat-form interpretation.

### Phase 3: integrated runtime boards normalized across all approved screens

- Added integrated runtime boards to the approved product-area pages so each locked screen can be edited in place as a live asset:
  - `Integrated Runtime / Login / Mar 29`
  - `Integrated Runtime / Home / Mar 29`
  - `Integrated Runtime / Training / Mar 29`
  - `Integrated Runtime / Nutrition / Mar 29`
  - `Integrated Runtime / Stats / Mar 29`
  - `Integrated Runtime / Settings / Mar 29`
- `Login`, `Home`, `Nutrition`, and `Stats` were normalized by cloning their approved screen frames into consistent integrated boards.
- `Training` and `Settings` were the main missing pieces; both now have editable iPhone screen assets on their pages instead of placeholder-only boards.
- Verified the new Training and Settings integrated runtime boards with Figma screenshot passes after fixing the initial write errors and clipped Settings copy.
- Working rule going forward: once a screen is approved in code, its corresponding integrated runtime board in Figma must be updated in the same phase before the screen is considered fully synced.

### Phase 3: runtime editability audit and spacing spec added

- Audited the integrated runtime boards directly in Figma and confirmed all approved screen pages now contain editable layered screen frames rather than flat screenshot placeholders.
- Current audit result:
  - `Login` board `131:31` → live asset `131:2` with `28` child layers
  - `Main Screen` board `131:93` → live asset `131:43` with `8` child layers
  - `Training` board `135:2` → live asset `135:14` with `17` child layers
  - `Nutrition` board `131:141` → live asset `131:105` with `4` child layers
  - `Stats` board `131:186` → live asset `131:153` with `4` child layers
  - `Settings` board `135:80` → live asset `135:92` with `23` child layers
- Added detailed iPhone runtime spec boards on the `Platform Adaptations` page:
  - `iPhone Runtime Layout Spec`
  - `Element Size + Icon Spec`
- Mirrored the same rules into repo docs at `docs/design-system/iphone-runtime-layout-spec.md` so Figma and code review use the same spacing and sizing contract.

### Phase 3: screen review process standardized

- Added `Screen Review Standard` to the `Getting Started` page in Figma as the shared process board for every screen.
- Added a consistent `Standard Review + QA` card to each integrated runtime board so every approved screen carries the same verification expectations in the file itself.
- Normalized the `Settings` page so it now matches the other approved screen pages with:
  - `Settings / Approval Notes / Mar 29`
  - `Context / Settings`
  - `Approved Source of Truth / Settings`
- Mirrored the same process into repo docs at `docs/design-system/screen-review-standard.md`.

### Phase 3: unified simulator review mode added

- Added a lightweight simulator review mode to the integrated app branch:
  - `FITTRACKER_REVIEW_AUTH=authenticated`
  - `FITTRACKER_REVIEW_TAB=home|training|nutrition|stats`
- Review mode bypasses the auth gate with a mock session and skips the encrypted disk/sync path that was causing a blocking biometric alert during simulator QA.
- Confirmed unified runtime captures from `codex/ui-integration` on iPhone 14 Pro for:
  - Auth entry screen
  - Home review state
  - Training review state
  - Nutrition review state
  - Stats review state
- First meaningful runtime-vs-Figma drift discovered:
  - `Training` live asset currently shows the earlier `Lower Body` working block
  - integrated runtime review currently lands on a `Rest Day`/recovery state
  - this must be reconciled before the integrated Apple-first phase is considered fully closed

### Phase 3: integrated runtime boards reconciled and foundations completed

- Refreshed the integrated runtime boards using the current iPhone 14 Pro evidence set from `codex/ui-integration`:
  - `Training` was updated from the earlier `Lower Body` working-block state to the integrated `Rest Day` / recovery state
  - `Nutrition` was refreshed to reflect the integrated rest-day nutrition state
  - `Stats` was refreshed to reflect the integrated empty-state view with the `Track More` row
- Added a standardized board contract across all approved integrated runtime boards:
  - `Runtime Verified`
  - `Uses`
  - `QA Checklist`
- Recorded runtime sources directly in the board metadata for:
  - `Login`
  - `Home`
  - `Training`
  - `Nutrition`
  - `Stats`
  - `Settings` currently notes that it is still anchored to the approved grouped baseline pending a unified runtime refresh
- Expanded `Foundations` with new guidance boards:
  - `Color System`
  - `Color Meaning + Usage`
  - `Typography System`
  - `Typography Usage + Hierarchy`
  - `Content + UX Copy (Experimental)`
- Simplified the library information architecture:
  - archived `Greeting` as `Greeting (Archived)`
  - removed empty separator pages
  - marked `Typography Repository` and `Icon Repository` as reference/appendix destinations

### Current status after reconciliation

- `Training`: visual and state mismatch resolved
- `Nutrition`: synced to integrated runtime direction, with the board now carrying runtime metadata and QA structure
- `Stats`: synced to integrated runtime direction, with the board now carrying runtime metadata and QA structure
- `Foundations`: now acts as the primary guidance page rather than an inventory-only overview

### Phase 3: Settings integrated review route tightened

- Added a dedicated Settings review path to the integrated branch so the app can be reviewed outside the four-tab shell flow:
  - `FITTRACKER_REVIEW_AUTH=settings`
  - fallback support remains in code for `FITTRACKER_REVIEW_SETTINGS=1` and `--review-settings`
- The live `Settings` Figma board was updated to match current grouped-settings code truth from `SettingsView.swift`:
  - refreshed home subtitle
  - refreshed category summaries
  - refreshed bottom supporting note
- Current blocker:
  - direct simulator capture is still inconsistent for the Settings route
  - the app sometimes reopens into a stale prior frame instead of rendering the requested review destination
- Current Figma truth for `Settings` is therefore:
  - code-aligned grouped baseline
  - explicit runtime note documenting the simulator inconsistency
  - ready for direct visual editing while the runtime harness issue remains under investigation

## Important notes

- The `Foundations` color guidance now includes exact token values directly in the live boards:
  - solid colors documented with exact hex values
  - translucent semantic roles documented with exact RGBA values
  - implementation notes clarify that handoff should always show token name, exact value, meaning, and restrictions together
- The Figma MCP runtime still does not expose Apple system fonts such as `SF Pro Rounded` or `SF Mono`, so the current Figma fallback stack is `Nunito` plus `IBM Plex Mono`.
- Local continuation state is stored in `/tmp/dsb-state-fittracker-2026-03-27.json`.
- Prototype pages now exist in the live file:
  - `Prototype / iPhone App`
  - `Prototype / Flow Map`
- The first prototype pass cloned the approved integrated live assets into a dedicated prototype layer and added state labels plus scope/fidelity notes.
- Prototype navigation is now partially wired:
  - Login routes into Home
  - Home routes into Training, Nutrition, and Stats
  - Training, Nutrition, and Stats route across the main flow and into Settings
  - grouped Settings routes into representative detail screens and back
- The key prototyping implementation lesson is now documented: prototype hotspots must be attached inside the source screen frames, not as page-level overlays.

## Next resume steps

1. Refine the `Components` page documentation for each family:
   - purpose
   - anatomy
   - states
   - accessibility notes
   - code reference
2. Refine the repository pages with export-ready checklists:
   - icon ownership
   - final app icon source file
   - screenshot production workflow
3. Optionally split large component families onto dedicated pages if the library grows beyond the current single-page layout.
4. Start lightweight Code Connect mappings once the component naming is stable.
5. Run a unified simulator verification pass from `codex/ui-integration` and refresh any board whose runtime diverges from the integrated shell.
6. Tighten the lower-detail integrated boards (`Home`, `Nutrition`, `Stats`) if more granular editable sublayers are needed for future design iteration.
7. Add responsive notes to the highest-traffic product-area pages as those screens are refined further.
8. Prepare the later Android adaptation phase from the existing `Platform Adaptations` page rather than creating a second independent system.
9. Use `docs/project/resume-handoff-2026-03-29.md` as the primary project-level resume document before continuing prototype or merge work.
10. Expand the live prototype with more auth variants, populated-state variants, and final polish, then update the README/PR draft once the prototype reaches final closure quality.

## Resume prompt

Use this if the work needs to continue in a new session:

> Continue the FitTracker Figma design-system library build. Run ID: `fittracker-ds-2026-03-27`. File key: `0Ai7s3fCFqR5JXDW8JvgmD`. Resume after the full approved v1 component set and documentation pages, using `docs/design-system/figma-library-progress.md` and `/tmp/dsb-state-fittracker-2026-03-27.json` as the source of truth.
