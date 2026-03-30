# FitTracker Feature Memory

This file is the persistent in-repo memory for future feature development.

Use it to capture the final design-system decisions for each shipped or approved feature so future work can build on them instead of starting over.

## Memory format

For each feature, add:

- Date
- Feature name
- Problem solved
- Primary platform
- Reused tokens
- Reused components
- New primitives introduced, if any
- Wireframe and UX notes
- Final UI decisions
- Accessibility considerations
- Android adaptation note
- Follow-up gaps

---

## 2026-03-27 — Design system gateway

- Problem solved: feature work was at risk of jumping directly into polished UI without aligned behavior, state coverage, or shared-system mapping.
- Primary platform: iPhone first, with iPad/macOS and Android adaptation documented.
- Reused tokens: `AppColor`, `AppText`, `AppSpacing`, `AppRadius`, `AppSheet`.
- Reused components: `AppCard`, `AppButton`, `AppMenuRow`, `AppSelectionTile`, `MetricCard`, `ChartCard`, `StatusBadge`, `EmptyStateView`.
- New primitives introduced: `AppSelectionTile`.
- Wireframe and UX notes: future features must define low-fidelity structure and behavior before final UI.
- Final UI decisions: settings controls, auth entry, app shell, and selected Home/Stats/Nutrition surfaces now use the semantic system.
- Accessibility considerations: gate requires Dynamic Type, contrast, states, and tap targets to be reviewed before implementation is considered complete.
- Android adaptation note: every feature should specify whether it maps directly to Material 3 patterns or needs a platform-distinct implementation.
- Follow-up gaps: deep Training, Nutrition entry, ReadinessCard, and AuthHub still need fuller system migration.

## 2026-03-27 — Shared form and input primitives

- Problem solved: input-heavy flows in auth, meal entry, and training had repeated local field shells, labels, and secondary button treatments.
- Primary platform: iPhone first.
- Reused tokens: `AppColor.Surface.*`, `AppColor.Text.*`, `AppColor.Border.*`, `AppColor.Accent.*`, `AppText.*`.
- Reused components: `AppButton`.
- New primitives introduced: `AppInputShell`, `AppFieldLabel`, `AppQuietButton`.
- Wireframe and UX notes: input-heavy flows should group labels and controls consistently and keep helper actions visually secondary to the main task.
- Final UI decisions: auth, nutrition search/manual entry, and training/cardio helper fields now share the same shell language instead of bespoke rounded inputs.
- Accessibility considerations: labels stay visible outside the field, and utility buttons remain text-labeled rather than icon-only wherever possible.
- Android adaptation note: these map conceptually to Material text field containers plus secondary/tonal utility buttons.
- Follow-up gaps: broader auth, training, and nutrition screens still contain older local styling outside the migrated helper components.

## 2026-03-27 — Readiness, hydration, and quick-entry migration

- Problem solved: high-visibility summary and input surfaces were still using bespoke fonts, color literals, and local UI treatments that bypassed the semantic system.
- Primary platform: iPhone first, with iPad/macOS-friendly semantics preserved.
- Reused tokens: `AppColor.Text.inverse*`, `AppColor.Accent.*`, `AppColor.Chart.nutritionFat`, `AppGradient.darkAccent`, `AppText.metricDisplay`, `AppText.monoMetric`, `AppText.monoLabel`.
- Reused components: `AppInputShell`.
- New primitives introduced: none.
- Wireframe and UX notes: readiness stays a compact multi-page health summary, hydration remains a quick-adjust surface, and manual biometrics stay lightweight inside the current sheet flow.
- Final UI decisions: `ReadinessCard`, nutrition hydration and supplement accents, and manual biometric entry now use semantic color and typography roles instead of local styling.
- Accessibility considerations: inverse text roles are explicit on dark surfaces, numeric summaries keep consistent hierarchy, and manual inputs preserve clearer field affordances.
- Android adaptation note: readiness should translate into a high-signal overview card with semantic status roles, while hydration and manual-entry controls map cleanly to Material cards and text field containers.
- Follow-up gaps: deeper nutrition logging, remaining training subviews, and some auth/account surfaces still need full component-level migration.

## 2026-03-27 — Auth and settings detail migration

- Problem solved: sign-in, account, and editable settings surfaces still mixed local typography, raw presentation styles, and inconsistent field treatments.
- Primary platform: iPhone first.
- Reused tokens: `AppText.*`, `AppColor.Text.*`, `AppColor.Accent.*`, `AppColor.Status.warning`, `AppRadius.*`, `AppSpacing.*`.
- Reused components: `AppButton`, `AppInputShell`, `AppFieldLabel`, `AppMenuRow`, `AppSelectionTile`.
- New primitives introduced: none.
- Wireframe and UX notes: account and sign-in remain simple stacked decision surfaces, while editable settings rows now separate label/helper context from the input shell.
- Final UI decisions: `SignInView`, `AccountPanelView`, `AuthHub` headers, and the editable nutrition settings fields now use the same semantic type scale and field language as the rest of the app.
- Accessibility considerations: helper text remains visible above editable fields, action hierarchy is clearer on sign-in surfaces, and account metadata keeps readable contrast without relying on default system styling.
- Android adaptation note: these patterns map cleanly to Material onboarding/account cards and labeled text field groups without preserving Apple-specific visuals verbatim.
- Follow-up gaps: the deepest training views and any future Android implementation still need platform-ready component mapping beyond the current Apple-first codebase.

## 2026-03-27 — Training system migration

- Problem solved: the main training flow still contained the densest cluster of bespoke timer, completion, focus, and set-entry UI.
- Primary platform: iPhone first, with compact-touch ergonomics preserved.
- Reused tokens: `AppText.monoMetric`, `AppText.metricHero`, `AppText.metricDisplayMono`, `AppColor.Surface.*`, `AppColor.Text.*`, `AppColor.Status.*`, `AppRadius.*`.
- Reused components: `AppButton`, `AppInputShell`.
- New primitives introduced: none.
- Wireframe and UX notes: timers, set rows, focus mode, and completion summaries should remain high-signal and low-friction, with data entry kept visually direct.
- Final UI decisions: `TrainingPlanView` now uses semantic typography and surfaces for rest timers, set logging notes, status chips, completion summaries, and focus-mode entry fields instead of fixed-size one-offs.
- Accessibility considerations: numeric hierarchy is now more consistent, labels remain present beside entry surfaces, and completion states are communicated by text plus color.
- Android adaptation note: these patterns should translate into Material workout cards, bottom sheets, and numeric entry panels without cloning the exact Apple visual treatment.
- Follow-up gaps: future work should extract more of training’s repeated panels into dedicated shared system components if the flow expands further.

## 2026-03-27 — Figma library foundations started

- Problem solved: the repo had a documented design-system structure but no real Figma library to share tokens, components, and usage guidance across the team.
- Primary platform: Apple-first foundations for iPhone, with later iPad/macOS and Android adaptation planned from the same semantic core.
- Reused tokens: `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `AppShadow.*`, `docs/design-system/design-tokens.json`.
- Reused components: planned first library set is `AppButton`, `AppCard`, `AppMenuRow`, `AppSelectionTile`, `AppInputShell`, `AppFieldLabel`, `AppQuietButton`, `StatusBadge`, `EmptyStateView`.
- New primitives introduced: none in code; this work establishes the Figma-side source of truth.
- Wireframe and UX notes: Figma library build is following the same gateway logic as product features, with foundations first, then page structure, then components and patterns.
- Final UI decisions: created a fresh Figma design file and populated the initial six variable collections plus the first semantic variable layers for color, spacing, radius, elevation, motion, and text roles.
- Accessibility considerations: color variables include explicit text, border, focus, and status roles so contrast-sensitive usage can be documented and reviewed at the component stage.
- Android adaptation note: Android code is still deferred, but the Figma variable syntax now includes semantic Android token paths to make later adaptation cleaner.
- Follow-up gaps: Figma MCP hit the current plan call limit before text styles, effect styles, page structure, and component pages could be created; resume from the saved library progress doc and local state ledger.

## 2026-03-27 — Figma library phase 2 and first component

- Problem solved: the Figma library needed to move beyond tokens into a shareable, navigable system file with real documentation and the first reusable component family.
- Primary platform: Apple-first library with Figma font fallbacks chosen for the current runtime.
- Reused tokens: Figma variable collections for semantic color, text roles, spacing, radius, elevation, and motion.
- Reused components: conceptually mapped from `AppButton` in `FitTracker/Views/Shared/AppDesignSystemComponents.swift`.
- New primitives introduced: none in code; Figma-side text styles and effect styles were added to complete the foundation layer.
- Wireframe and UX notes: the file now starts with overview and usage guidance before dropping the team into foundations and components.
- Final UI decisions: added `Cover`, `Getting Started`, and `Foundations` documentation frames, then created the first `AppButton` component family with hierarchy and disabled-state variants on the `Components` page.
- Accessibility considerations: button hierarchy remains text-labeled in every variant, and destructive/secondary states stay distinct without relying on layout changes.
- Android adaptation note: the button family keeps semantic hierarchy rather than platform-locked visuals, which will make later Material mapping easier.
- Follow-up gaps: remaining component families, patterns, platform-adaptation pages, and later Code Connect mapping still need to be built in Figma.

## 2026-03-27 — Figma approved v1 component set completed

- Problem solved: the Figma library needed the full first-pass component vocabulary so the team could reference real shared UI patterns instead of only tokens and one sample button.
- Primary platform: Apple-first design system with later Android adaptation still deferred to a separate phase.
- Reused tokens: semantic color, spacing, radius, elevation, motion, and text-role collections already created in the same library file.
- Reused components: `AppCard`, `AppMenuRow`, `AppSelectionTile`, `AppInputShell`, `AppFieldLabel`, `AppQuietButton`, `StatusBadge`, `EmptyStateView`, plus the previously added `AppButton`.
- New primitives introduced: none in code; this was a Figma representation pass of already-defined shared primitives.
- Wireframe and UX notes: the file now includes both atomic controls and no-content/system patterns so feature design can start from reusable states instead of screenshots or ad hoc references.
- Final UI decisions: completed the approved v1 component set on the `Components` page and added initial overview frames on `Patterns` and `Platform Adaptations`.
- Accessibility considerations: status, empty-state, row, and input families all preserve text-led communication rather than color-only meaning, which keeps the design-system guidance aligned with the app-side accessibility goals.
- Android adaptation note: the `Platform Adaptations` page now explicitly frames Android as a semantic adaptation layer rather than a second independent visual system.
- Follow-up gaps: next Figma work should deepen component-level documentation, optionally split busy families into dedicated pages, and add Code Connect mapping once naming is stable.

## 2026-03-27 — Figma repositories and product-area spaces

- Problem solved: the library still needed operational spaces for icons, typography, App Store assets, and screen-by-screen planning so the team could use it for real feature work instead of only component reference.
- Primary platform: Apple-first, with App Store and later Android adaptation explicitly documented.
- Reused tokens: the existing semantic color, type, spacing, radius, and elevation layers.
- Reused components: all approved v1 shared components now inform the product-area pages.
- New primitives introduced: none in code; this was information architecture and documentation work inside Figma and repo docs.
- Wireframe and UX notes: each product-area page now starts with purpose/problem framing before visuals, which supports the feature gateway process defined earlier.
- Final UI decisions: created dedicated Figma pages for icon inventory, typography inventory, app icon/App Store assets, and each major product area including onboarding, login, greeting, main, settings, nutrition, stats, training, and account/security.
- Accessibility considerations: the new repositories explicitly call out text-led status communication and typography debt so future visual work doesn’t regress into decoration without clarity.
- Android adaptation note: the App Store and product-area work stays Apple-first, while the separate platform page continues to reserve Android/Pixel adaptation for its own governed phase.
- Follow-up gaps: app icon source artwork, actual `.xcassets` creation, App Store screenshots, and Code Connect mappings still need follow-through beyond the current documentation layer.

## 2026-03-27 — Responsive handoff and iPhone 14 Pro runtime validation

- Problem solved: the system needed an explicit contract for how assets and components scale from Figma into code, plus a real runtime check on the target Apple baseline device.
- Primary platform: iPhone first, with iPhone 14 Pro as the current runtime validation baseline.
- Reused tokens: `AppText.*`, `AppColor.*`, `AppSpacing.*`, `AppRadius.*`.
- Reused components: `AppInputShell`, `AppSelectionTile`.
- New primitives introduced: none in code; this phase tightened responsive behavior and added a formal handoff document.
- Wireframe and UX notes: future feature work must define narrow-width behavior, asset crop rules, and min, ideal, and max sizes before final UI.
- Final UI decisions: compact biometric entry fields, stats metric tiles, training set entry fields, and nutrition quick-meal cards now use flexible width ranges instead of rigid fixed widths.
- Accessibility considerations: preserving readable text and safe tap targets now takes priority over visual rigidity when width is constrained.
- Android adaptation note: the same semantic sizing contract should later map to Material size ranges and adaptive-width behavior rather than fixed dp assumptions.
- Follow-up gaps: smaller-width simulator spot checks and the Figma-side responsive notes still need to be completed for every major page family.

## 2026-03-27 — Reverse sync from code back into Figma

- Problem solved: the team needed a way to take the current production-truth SwiftUI UI and turn it back into editable Figma assets in the correct product-area pages.
- Primary platform: iPhone first, with both 14 Pro and compact-width references used for auth.
- Reused tokens: the auth screen rebuild follows the current semantic Apple-first auth palette and typography from `AppTheme.swift`.
- Reused components: this pass focused on screen reconstruction rather than new primitives, using the existing auth system language from `AuthHubView`.
- New primitives introduced: none.
- Wireframe and UX notes: the Figma `Login` page now contains a live `Current Login UI from Code` board so future auth changes can be reviewed visually before implementation diverges.
- Final UI decisions: the current editable auth screen in Figma reflects the unified `AuthHub` flow, includes quick-return state on iPhone 14 Pro, and preserves the compact-width behavior discovered on the smaller simulator pass.
- Accessibility considerations: the reverse-synced auth screen keeps the inverse text treatment and avoids the clipped/truncated badge problem found during compact-width review.
- Android adaptation note: this reverse-sync process should later be reused to create Android adaptation boards from the same semantic screens instead of hand-redrawing them from scratch.
- Follow-up gaps: the reverse-sync process now needs to continue for Home, Nutrition, Stats, Training, and Settings screens so the full product can be edited in Figma from live code truth.

## 2026-03-27 — Design-first auth refinement workflow

- Problem solved: auth visual tweaks were moving too quickly from idea to code, which made it harder to review the direction before implementation.
- Primary platform: iPhone first.
- Reused tokens: `AppGradient.screenBackground`, `AppColor.Surface.*`, `AppColor.Text.*`, `AppColor.Accent.*`.
- Reused components: `AppInputShell`, standard `SignInWithAppleButton`.
- New primitives introduced: none.
- Wireframe and UX notes: for screen-level UI changes, update the live Figma product-area board first, confirm the intended visual hierarchy there, then implement the matching SwiftUI change.
- Final UI decisions: auth now follows a lighter containerless layout, blends controls directly into the blue gradient shell, and keeps trust badges anchored at the bottom center instead of leaving them in the scroll content stack.
- Accessibility considerations: bottom trust badges remain text-led and centered, while the floating controls preserve readable contrast against the lighter background.
- Android adaptation note: the same design-first review loop should be used later for Android adaptation boards before Compose or native implementation.
- Follow-up gaps: continue this same Figma-first workflow for `Home`, `Training`, `Nutrition`, `Stats`, and `Settings`.

## 2026-03-29 — Settings grouped architecture restored and approved

- Problem solved: the dedicated `Settings` branch had drifted back to an older flat `Form` layout, which hid the newer grouped settings architecture and made the user flow feel less organized.
- Primary platform: iPhone first.
- Reused tokens: `AppGradient.screenBackground`, `AppColor.Text.*`, `AppColor.Surface.*`, `AppColor.Border.*`, `AppColor.Accent.*`, legacy-compatible `Color.app*` aliases, `AppType`.
- Reused components: category cards and detail cards are custom to this screen, while the account entry still relies on the approved `AccountPanelView` launcher flow.
- New primitives introduced: `SettingsCategory`, `SettingsHomeHeader`, `SettingsCategoryCard`, `SettingsSectionCard`, `SettingsValueRow`, `SettingsActionLabel`, `SettingsSelectionTile`, `SettingsChoiceGrid`, `SettingsNumericFieldRow`, `SettingsSliderRow`.
- Wireframe and UX notes: Settings is now a grouped dashboard first, with five clear areas: `Account & Security`, `Health & Devices`, `Goals & Preferences`, `Training & Nutrition`, and `Data & Sync`. Each area opens a focused detail surface instead of forcing the user through one long form.
- Final UI decisions: restored the grouped settings home from the approved redesign history, migrated it onto the current semantic color roles so text contrast works on the blue shell, and preserved direct iPhone launch verification on the dedicated branch.
- Accessibility considerations: grouping reduces cognitive load, category cards keep text-first summaries, and corrected semantic text colors prevent low-contrast white-on-blue regressions.
- Android adaptation note: this architecture maps naturally to a Material settings hub with grouped preference destinations rather than one oversized preference list.
- Follow-up gaps: sync the approved grouped settings board into Figma, then integrate this approved screen with the other locked screens on a shared UI branch.

## 2026-03-29 — Approved screen set synced as integrated Figma live assets

- Problem solved: the approved app screens were locked across separate code branches, but Figma still mixed real live assets with placeholder or notes-only boards, which made the design file harder to trust as a working surface.
- Primary platform: iPhone first, with the integrated app branch now acting as the shared base for the next UI phase.
- Reused tokens: the synced boards follow the approved Apple-first blue runtime direction already established in code and the design system foundations.
- Reused components: existing approved product-area frames for `Login`, `Main Screen`, `Nutrition`, and `Stats` were kept and normalized through new integrated runtime boards; `Training` and `Settings` were rebuilt into editable screen assets so they are no longer represented by placeholders alone.
- New primitives introduced: none in app code; this was a Figma synchronization and organization pass.
- Wireframe and UX notes: every approved screen page now has an explicit integrated runtime board that can be edited directly for future design work without losing the locked approved baseline.
- Final UI decisions: the live Figma file now contains:
  - `Integrated Runtime / Login / Mar 29`
  - `Integrated Runtime / Home / Mar 29`
  - `Integrated Runtime / Training / Mar 29`
  - `Integrated Runtime / Nutrition / Mar 29`
  - `Integrated Runtime / Stats / Mar 29`
  - `Integrated Runtime / Settings / Mar 29`
- Accessibility considerations: the synced runtime boards preserve the text-led hierarchy and high-contrast ink treatment approved in code, especially for `Training` and grouped `Settings`.
- Android adaptation note: keeping the approved Apple screens in Figma as semantic live assets will make later Pixel/Material adaptation easier because the information architecture and component roles are now editable in one place.
- Follow-up gaps: run a full integrated simulator pass from `codex/ui-integration`, then refresh any live asset board whose runtime diverges during shell integration polish.

## 2026-03-29 — Unified simulator review mode established

- Problem solved: the integrated Apple-first QA process needed a repeatable way to review the unified app shell without manually re-entering auth state or triggering biometric storage errors on simulator.
- Primary platform: iPhone 14 Pro simulator as the current integrated runtime baseline.
- Reused tokens: no new design tokens; this was a runtime verification and workflow improvement pass.
- Reused components: no new component primitives; the change standardizes how existing approved screens are verified together in one runtime.
- New primitives introduced: none in the design system. A simulator review mode was added to the integrated branch through launch environment values and review-aware runtime guards.
- Wireframe and UX notes: the same standardized launch path can now be used to verify `Home`, `Training`, `Nutrition`, and `Stats` from the integrated branch with a mock authenticated session.
- Final UI decisions: the integrated review path now bypasses the auth gate with `FITTRACKER_REVIEW_AUTH=authenticated`, routes to a chosen tab with `FITTRACKER_REVIEW_TAB`, and skips encrypted disk loading in review mode so simulator QA is not blocked by biometric alerts.
- Accessibility considerations: no accessibility behavior was intentionally changed; this was strictly a QA/runtime flow improvement.
- Android adaptation note: the idea of a standardized review mode should later carry over to the Android adaptation phase so runtime verification is equally repeatable there.
- Follow-up gaps: `Training` currently shows a meaningful runtime-vs-Figma state mismatch (`Rest Day` runtime versus earlier `Lower Body` live asset), and the remaining approved boards should be refreshed wherever the integrated runtime diverges.

## 2026-03-29 — Integrated runtime boards reconciled to current Figma truth

- Problem solved: the integrated Figma boards had drifted from the current runtime evidence, especially in `Training`, and the review metadata was inconsistent across approved screens.
- Primary platform: iPhone 14 Pro integrated runtime review from `codex/ui-integration`.
- Reused tokens: existing Apple-first blue shell, semantic color roles, and approved type hierarchy.
- Reused components: existing integrated live assets for `Login`, `Home`, `Training`, `Nutrition`, `Stats`, and `Settings`.
- New primitives introduced: none in app code. Figma-side additions included `Runtime Verified`, `Uses`, and `QA Checklist` board sections.
- Wireframe and UX notes: `Training` now reflects the integrated `Rest Day` recovery state; `Nutrition` and `Stats` now reflect the integrated runtime direction rather than older approved snapshots.
- Final UI decisions: all approved integrated boards now carry explicit source metadata, usage mapping, and QA structure in the same visual contract.
- Accessibility considerations: this pass focused on keeping live assets editable and readable while reflecting true runtime structure instead of leaving stale states in circulation.
- Android adaptation note: this tighter runtime-to-design sync will make later Android adaptation safer because the Figma surface now reflects actual integrated product truth rather than historical states.
- Follow-up gaps: `Settings` still needs one more integrated runtime screenshot refresh to move from approved grouped baseline to full integrated runtime proof.

## 2026-03-29 — Foundations became the primary guidance layer

- Problem solved: the design system had good inventories, but color and typography guidance were still too inventory-heavy and the library structure was slightly more fragmented than necessary.
- Primary platform: Apple-first FitTracker design system documentation in Figma and the integrated repo docs.
- Reused tokens: `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `docs/design-system/design-tokens.json`.
- Reused components: no new code components; this was a guidance and library-information-architecture pass.
- New primitives introduced: none in runtime code. New guidance boards were added in Figma for color, typography, and experimental UX copy.
- Wireframe and UX notes: `Foundations` is now the primary place to learn how to use the system, while typography and icon repositories are treated as appendices/reference pages.
- Final UI decisions: added `Color System`, `Color Meaning + Usage`, `Typography System`, `Typography Usage + Hierarchy`, and `Content + UX Copy (Experimental)` to `Foundations`; archived `Greeting`; removed empty separator pages.
- Accessibility considerations: color guidance now emphasizes semantic meaning over decoration, and typography guidance limits unnecessary hierarchy complexity.
- Android adaptation note: the clearer semantic guidance will make Material mapping easier later because the system explains intent, not just visual samples.
- Follow-up gaps: the next major platform phase is still Android / Pixel adaptation, and `Settings` should still receive a final integrated runtime capture when the shell pass returns there.

## 2026-03-29 — Settings code truth resynced while review harness remains flaky

- Problem solved: the `Settings` Figma board still reflected an older grouped placeholder summary and a pending runtime note, while the current integrated code had more specific grouped copy and a partially upgraded review route.
- Primary platform: iPhone 14 Pro review flow on `codex/ui-integration`.
- Reused tokens: existing Apple-first grouped settings styling and semantic typography.
- Reused components: grouped settings dashboard cards and the existing integrated runtime board on the `Settings` page.
- New primitives introduced: none in product UI. Review-only support was extended in code so `FITTRACKER_REVIEW_AUTH=settings` can target the grouped settings screen directly.
- Wireframe and UX notes: the grouped settings home remains the correct source of truth, but the simulator is still inconsistently reopening a stale prior frame instead of honoring the requested Settings review destination every time.
- Final UI decisions: updated the Figma live asset text to match current `SettingsView.swift` copy and changed the runtime note to explicitly state that the board is code-aligned while direct runtime capture remains inconsistent.
- Accessibility considerations: no new interaction or visual behavior changed here; this was primarily a truth-sync and QA-harness improvement pass.
- Android adaptation note: the grouped dashboard architecture remains the correct conceptual baseline for a later Material settings hub.
- Follow-up gaps: finish the direct Settings simulator capture once the CoreSimulator launch-state issue is stable, then replace the code-truth note with a fresh runtime-proof note like the other approved screens.

## 2026-03-29 — Color guidance completed with exact implementation values

- Problem solved: the `Foundations` color guidance explained meaning well, but it still lacked complete implementation data for reliable design and engineering handoff.
- Primary platform: Apple-first FitTracker design system documentation in Figma and the integrated repo docs.
- Reused tokens: `AppColor.*` from `/Users/regevbarak/Downloads/FitTracker2/.worktrees/ui-integration/FitTracker/Services/AppTheme.swift` and the semantic snapshot in `/Users/regevbarak/Downloads/FitTracker2/.worktrees/ui-integration/docs/design-system/design-tokens.json`.
- Reused components: existing `Color System` and `Color Meaning + Usage` boards inside the `Foundations` page.
- New primitives introduced: none in runtime code. This was a completeness pass on design-system documentation and live Figma guidance.
- Wireframe and UX notes: the color section now shows both semantic meaning and exact token values, including hex for solid colors and RGBA for translucent roles.
- Final UI decisions: designers should document token name, exact value, meaning, and restrictions together; legacy auth greens remain restricted and should not be reused on new light-product surfaces.
- Accessibility considerations: clearer role/value guidance reduces accidental misuse of low-contrast or semantically incorrect colors across screens.
- Android adaptation note: this richer token metadata will make later Material token mapping and parity checks more reliable.
- Follow-up gaps: typography and icon appendix pages are still reference-heavy, but color guidance is now complete enough to serve as a true source-of-truth handoff section.

## 2026-03-29 — Resume handoff captured for future continuation

- Problem solved: important project history, branch state, approved screens, documentation work, and current blockers were still spread across chat history, git history, and multiple docs.
- Primary platform: Apple-first integrated branch and shared Figma workspace.
- Reused tokens: no runtime token changes; this was a continuity and project-memory pass.
- Reused components: no UI mutations; this pass captured process and state only.
- New primitives introduced: none in product code. A dedicated resume handoff was added at `/Users/regevbarak/Downloads/FitTracker2/.worktrees/ui-integration/docs/project/resume-handoff-2026-03-29.md`.
- Wireframe and UX notes: the handoff explicitly records that the next major deliverable is the live iPhone prototype in the same Figma file, followed by final runtime proof and merge packaging.
- Final UI decisions: `codex/ui-integration` remains the integrated Apple-first source of truth; approved screens remain Login, Home, Training, Nutrition, Stats, and grouped Settings.
- Accessibility considerations: no visual or interaction behavior changed in this pass.
- Android adaptation note: this handoff keeps the Apple-first phase legible so Android / Pixel adaptation can begin from a stable documented baseline later.
- Follow-up gaps: complete the prototype, finalize Settings runtime proof, restore GitHub auth, and create the real remote draft PR into `main`.

## 2026-03-29 — Prototype scaffold created in the live Figma file

- Problem solved: the project had approved integrated runtime boards, but it still did not have a dedicated prototype layer that represented the app as one reviewable product story.
- Primary platform: iPhone-first prototype planning and presentation inside the existing design-system file.
- Reused tokens: existing Apple-first blue shell, approved screen assets, and Foundations guidance.
- Reused components: editable integrated runtime boards for `Login`, `Home`, `Training`, `Nutrition`, `Stats`, and `Settings`.
- New primitives introduced: none in code. New Figma pages were created: `Prototype / iPhone App` and `Prototype / Flow Map`.
- Wireframe and UX notes: the prototype page now contains cloned editable live assets for the approved screens laid out as one product story, with state labels and scope/fidelity metadata.
- Final UI decisions: the prototype must live in the same Figma file as the design system and be built from approved integrated assets instead of screenshots.
- Accessibility considerations: this pass focused on structure and editability, not new interaction behavior.
- Android adaptation note: the prototype layout will later provide a useful comparison artifact when the same flows are adapted to Pixel/Material.
- Follow-up gaps: interaction wiring is still pending because the current Figma API reaction payloads were rejected as invalid; next pass should solve prototype linking and then expand representative state variants.

## 2026-03-29 — Prototype interactions and Settings detail states added

- Problem solved: the prototype existed only as a static scaffold, which was not enough to review the app as a clickable product story.
- Primary platform: iPhone-first prototype inside the shared Figma design-system file.
- Reused tokens: approved Apple-first runtime assets and the existing blue-shell design language.
- Reused components: prototype frames were built from the editable integrated live assets for Login, Home, Training, Nutrition, Stats, and Settings.
- New primitives introduced: no code primitives. In Figma, representative grouped Settings detail screens were added for `Account & Security`, `Health & Devices`, `Goals & Preferences`, `Training & Nutrition`, and `Data & Sync`.
- Wireframe and UX notes: the prototype now supports core app navigation between Login, Home, Training, Nutrition, Stats, and Settings, with menu-driven access to grouped Settings and return paths back into the prototype.
- Final UI decisions: prototype hotspots must live inside the source screen frames; page-level overlay hotspots caused invalid reaction payloads and were replaced by frame-local interactions.
- Accessibility considerations: this pass focused on structural navigation and editability rather than new visual system changes.
- Android adaptation note: having a clickable Apple-first prototype will make later cross-platform flow mapping easier because it expresses app behavior, not just screen inventory.
- Follow-up gaps: auth variants, more populated state variants, and final prototype polish still need to be added before the Apple-first phase is fully closed.
