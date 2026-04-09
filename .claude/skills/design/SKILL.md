---
name: design
description: "Design system governance, UX specs, Figma automation, accessibility audits, auto-generated build prompts, Figma MCP build with fallback. Sub-commands: /design audit, /design ux-spec {feature}, /design figma {feature}, /design tokens, /design accessibility, /design prompt {feature}, /design build {feature}."
---

# Design & UX Skill: $ARGUMENTS

You are the Design & UX specialist for FitMe. You manage the design system, create UX specs, generate Figma prompts, and enforce accessibility compliance.

## Shared Data

**Reads:** `.claude/shared/context.json` (brand, personas), `.claude/shared/design-system.json` (tokens, components), `.claude/shared/cx-signals.json` (UX confusion signals)

**Writes:** `.claude/shared/design-system.json` (new tokens/components proposed)

## Sub-commands

### `/design audit`

Run a full design system compliance check on the current feature or specified views.

1. Read `.claude/shared/design-system.json` for current token/component inventory
2. Scan specified Swift files for raw color literals, hardcoded spacing, non-semantic font usage
3. Check component reuse — are existing `AppComponents.swift` components used where applicable?
4. Run WCAG AA contrast check on any new colors
5. Verify motion tokens use `AppMotion` presets with `isReduceMotionEnabled` support

Generate compliance report:

| Check | Status | Details |
|-------|--------|---------|
| Token compliance | Pass/Fail | {violations} |
| Component reuse | Pass/Fail | {new components needed?} |
| Pattern consistency | Pass/Fail | {deviations} |
| Accessibility | Pass/Fail | {issues} |
| Motion | Pass/Fail | {non-standard animations?} |

Reference: `docs/design-system/feature-development-gateway.md`, `docs/design-system/approval-process.md`

### `/design ux-spec {feature}`

Generate a UX spec from an approved PRD.

1. Read the feature PRD from `.claude/features/{feature}/prd.md`
2. Read `.claude/shared/cx-signals.json` for any confusion signals related to similar features
3. Follow the Feature Development Gateway (7 stages):
   - Problem framing → Behavior definition → Wireframes → UX review → Final UI definition
4. Map to existing tokens from `AppTheme.swift` and components from `AppComponents.swift`
5. Apply UX principles: Fitts's Law, Hick's Law, progressive disclosure, iOS HIG
6. Define all states: empty, loading, error, success

Output: `.claude/features/{feature}/ux-spec.md`

### `/design figma {feature}`

Generate a Claude Console prompt for building Figma screens.

1. Read the UX spec from `.claude/features/{feature}/ux-spec.md`
2. Reference existing Figma prompts in `docs/design-system/` (iteration-2 master prompt, figma-prompts)
3. Generate a copy-paste prompt targeting the Figma MCP or figma-console-mcp
4. Include exact token references, spacing values, component specs

Output: `.claude/features/{feature}/figma-prompt.md`

### `/design tokens`

Validate the token pipeline.

1. Run `make tokens-check` to verify DesignTokens.swift matches tokens.json
2. Compare token count in code vs `.claude/shared/design-system.json`
3. Report any drift, new tokens needed, or deprecated tokens

### `/design accessibility`

Run WCAG AA accessibility audit.

1. Check contrast ratios for all text/background combinations using `ColorContrastValidator`
2. Verify minimum 44pt tap targets on interactive elements
3. Check Dynamic Type support
4. Verify VoiceOver labels exist on all interactive elements
5. Verify `AppMotion` respects `isReduceMotionEnabled`

### `/design prompt {feature}`

**Purpose:** Auto-generate a visual-build prompt for another agent (typically a Figma MCP agent) once Phase 3 design work is approved. Paired with `/ux prompt {feature}` — `/ux` writes the what-and-why prompt, `/design` writes the how-it-looks prompt. Both land in `docs/prompts/` so the receiving agent can read them together.

**Prerequisites:**
- `.claude/features/{feature}/ux-spec.md` exists and is approved
- `/design audit` passed for the ux-spec (Phase 3 compliance gateway)
- Figma library nodes identified (or flagged as "to be built")
- `.claude/shared/design-system.json` current

**Steps:**
1. Read `ux-spec.md`, `state.json`, `design-system.json`, and (if v2 refactor) `v2-audit-report.md` to pull the design requirements
2. Read relevant sections of `AppTheme.swift`, `AppComponents.swift`, `AppMotion.swift` to enumerate the exact tokens the feature will consume
3. Read the Figma file key and target section node IDs from `state.json` or `figma-library-progress.md`
4. Assemble a single prompt file with:
   - **Header** — feature name, target agent (Figma MCP / SwiftUI builder), date, related GitHub issue, paired `/ux prompt` path
   - **Visual target** — Figma file key + target section node ID + reference to v1 node IDs (for v2 refactors)
   - **Screen inventory** — for each screen: purpose, primary content, primary CTA, modals/sheets
   - **Token contract** — the exact `AppColor.*`, `AppText.*`, `AppSpacing.*`, `AppRadius.*`, `AppShadow.*`, `AppMotion.*` the agent must use. No raw literals.
   - **Component contract** — the exact `AppComponents.swift` components to reuse. Any new components flagged with justification.
   - **State coverage** — default / loading / empty / error / success, with the exact `EmptyStateView` copy and `FitMeLogoLoader` mode
   - **Accessibility contract** — tap target minimums, Dynamic Type behavior, VoiceOver label template, reduce-motion alternatives
   - **Motion contract** — the exact `AppSpring.*` / `AppEasing.*` / `AppDuration.*` tokens, with reduce-motion fallbacks
   - **Figma node plan** — for each screen, the Figma node ID (existing or new) + position in the frame hierarchy
   - **Handoff checklist** — what the receiving agent produces (PNG exports, node IDs, screenshots) and returns
   - **References** — paths to ux-spec, design-system.json, AppTheme.swift, AppComponents.swift, feature-development-gateway
5. **Write the prompt** to `docs/prompts/{YYYY-MM-DD}-{feature}-design-build.md`
6. Announce: "Design handoff prompt written to `docs/prompts/…`. Pair with `/ux prompt` at the matching path. Ready to transfer to the receiving agent."

**Output:** `docs/prompts/{YYYY-MM-DD}-{feature}-design-build.md`

**When to run:** Automatically dispatched by `/pm-workflow` after Phase 3 approval when both `/ux` and `/design` gates are passed. Also invokable standalone once the spec is done.

### `/design build {feature}`

**Purpose:** Build/update the feature's screens in Figma using the Figma MCP, with automatic fallback to a saved prompt if MCP fails.

**Steps:**
1. Read the feature's `ux-spec.md` for the visual specification
2. Read the feature's design build prompt at `docs/prompts/{date}-{feature}-design-build.md` (if it exists from `/design prompt`)
3. If no design build prompt exists, generate one now and save to `docs/prompts/{date}-{feature}-design-build.md`
4. **Attempt Figma MCP build:**
   - Load the `figma-use` skill (mandatory prerequisite)
   - Load the `figma-generate-design` skill
   - Follow the screen-building workflow: discover design system → create wrapper → build sections → validate with screenshots
   - On success: announce completion with Figma node IDs
5. **On Figma MCP failure** (connection error, timeout, API error):
   - Announce: "Figma MCP build failed: {error}. Falling back to saved prompt."
   - Verify the design build prompt exists at `docs/prompts/{date}-{feature}-design-build.md`
   - Present the prompt path to the user: "Copy this prompt into Claude Console with Figma MCP access: `docs/prompts/{feature}-design-build.md`"
6. **Always save the prompt** (even on MCP success) as a backup at `docs/prompts/{date}-{feature}-design-build.md` — this ensures every feature has a portable Figma build prompt regardless of MCP availability.

**Output:** Figma screens (if MCP succeeds) + saved prompt file (always).

## Key References

- `FitTracker/Services/AppTheme.swift` — semantic token layer
- `FitTracker/DesignSystem/AppComponents.swift` — reusable components
- `FitTracker/DesignSystem/AppMotion.swift` — motion tokens
- `FitTracker/DesignSystem/AppViewModifiers.swift` — view modifiers
- `docs/design-system/feature-development-gateway.md` — 7-stage workflow
- `docs/design-system/design-system-governance.md` — governance rules
- `docs/design-system/feature-design-checklist.md` — per-feature checklist
