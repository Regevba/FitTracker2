# Figma Library Structure

This repo does not assume an existing Figma design-system library. Create a fresh library using the structure below.

## Recommended pages

1. `Cover`
   - library purpose
   - team orientation
2. `Getting Started`
   - how to use the library
   - screen review standard
3. `Foundations`
   - color system
   - color meaning and usage
   - typography system
   - typography usage and hierarchy
   - spacing scale
   - radius and elevation
   - iconography basics
   - experimental UX copy guidance
2. `Components`
   - buttons / CTA
   - card surfaces
   - menu rows
   - badges
   - inputs
   - empty / loading / error states
3. `Patterns`
   - home / dashboard
   - forms
   - settings
   - navigation
   - charts and metric summaries
4. `Platform Adaptations`
   - iPhone
   - iPad
   - macOS
   - watch rules
   - Android / Pixel
5. `App Icon + App Store`
   - icon production rules
   - App Store sizing
   - screenshot/export checklists
6. Product-area pages
   - login
   - main screen
   - training
   - nutrition
   - stats
   - settings
   - additional roadmap surfaces as needed
7. Reference / appendix pages
   - `Typography Repository`
   - `Icon Repository`

## Current simplification rules

- `Foundations` is the primary guidance page for new design work.
- `Typography Repository` and `Icon Repository` are reference appendices, not the first stop for decision-making.
- `Greeting` should stay archived inside the broader `Main Screen` story unless it becomes a real standalone surface again.
- Do not keep empty separator pages in the long-term library structure.

## Variable collections

- `Color / Semantic`
- `Text / Roles`
- `Spacing`
- `Radius`
- `Elevation`
- `Motion`

## Component documentation schema

Every component should include:

- Purpose
- When to use
- When not to use
- Anatomy
- Variants
- States
- Accessibility notes
- Platform notes
- Code reference path

## Naming guidance

- Use semantic names that match code where possible.
- Prefer `surface/elevated`, `text/secondary`, `button/primary`, `badge/status`.
- Add descriptions to components, styles, and variables so Figma search surfaces the right guidance.
- Integrated runtime boards should also include:
  - `Runtime Verified`
  - `Uses`
  - `QA Checklist`

## Links to add in Figma descriptions

- link to matching SwiftUI component path
- link to audit/governance docs
- link to changelog or release note location when available
