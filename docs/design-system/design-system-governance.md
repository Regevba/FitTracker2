# FitTracker Design System Governance

## Source of Truth

The design system is intentionally multi-artifact:

1. Code foundation in `FitTracker/Services/AppTheme.swift`
2. Shared SwiftUI primitives in `FitTracker/Views/Shared/`
3. In-app catalog in `FitTracker/Views/Settings/DesignSystemCatalogView.swift`
4. Documentation in `docs/design-system/`
5. Future Figma library following `figma-library-structure.md`
6. Feature workflow and memory in `docs/design-system/feature-development-gateway.md` and `docs/design-system/feature-memory.md`
7. Responsive handoff contract in `docs/design-system/responsive-handoff-rules.md`

No single screenshot, mockup, or one-off screen is allowed to overrule the system without an explicit component or token change.

## Naming Rules

### Tokens

- Prefer semantic names over palette names for new work.
- Good: `AppColor.Surface.elevated`, `AppColor.Text.secondary`
- Avoid for new code: `Color(red: ...)`, `Color.orange`, ad hoc opacity chains as meaning

### Shared components

- Shared components should reflect purpose, not page context.
- Good: `AppCard`, `AppMenuRow`, `MetricCard`
- Avoid: `HomeActionCard`, `StatsShellThing`, `SettingsRoundedTile`

## Contribution Flow

1. Try to solve the design with existing tokens and components.
2. Define the feature problem, behavior, states, and wireframes before final UI.
3. If the component exists but is missing a needed state or variant, extend the shared primitive.
4. Only create a new primitive when the pattern is reusable across multiple product surfaces.
5. Document any new primitive in:
   - code
   - in-app catalog if relevant
   - design-system docs
   - feature memory if it affects future work

## Required Review Questions

Every design-system change should answer:

- What user problem or task flow is this supporting?
- Is this a new primitive, or can it reuse an existing one?
- Which semantic tokens does it use?
- Which states exist: default, pressed, disabled, empty, loading, error, success?
- Was the flow wireframed before final UI?
- Does it behave correctly on iPhone compact width first?
- What is the explicit asset handoff rule for this feature: content mode, crop behavior, min and max size, and overflow behavior?
- What changes for iPad/macOS?
- What is the Android / Material 3 equivalent or adaptation note?

## Deprecation Policy

- Keep legacy aliases only while they unblock migration.
- Mark old tokens/components as compatibility-only in code comments and docs.
- Remove deprecated aliases only after all known call sites are migrated and the replacement is documented.

## Ownership and Cadence

- Design system changes should be reviewed by both product/design and engineering.
- Maintain a lightweight changelog in PR descriptions and in docs when primitives or token contracts change.
- Review the system after any roadmap feature that introduces a new surface, navigation pattern, or input pattern.
- Every new or updated feature should record whether it was visually validated on the current baseline device, which is iPhone 14 Pro as of March 27, 2026.
