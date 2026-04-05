---
name: design
description: "Design system governance, UX specs, Figma automation, accessibility audits. Sub-commands: /design audit, /design ux-spec {feature}, /design figma {feature}, /design tokens, /design accessibility."
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

## Key References

- `FitTracker/Services/AppTheme.swift` — semantic token layer
- `FitTracker/DesignSystem/AppComponents.swift` — reusable components
- `FitTracker/DesignSystem/AppMotion.swift` — motion tokens
- `FitTracker/DesignSystem/AppViewModifiers.swift` — view modifiers
- `docs/design-system/feature-development-gateway.md` — 7-stage workflow
- `docs/design-system/design-system-governance.md` — governance rules
- `docs/design-system/feature-design-checklist.md` — per-feature checklist
