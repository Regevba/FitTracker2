# FitTracker Design System Gap Review and Backlog

**Date:** 2026-03-27

## Current gaps

### Must fix during active migration

- Auth and product still share the same semantic foundation but not yet the same full component language.
- Some screen-level SwiftUI still uses local fonts, local spacing choices, and one-off icon sizing.
- Shared state patterns are partially standardized, but not every flow uses the same empty, loading, success, and error treatment.
- Settings, Training, and Nutrition still contain repeated local control styles that should become shared primitives.

### Should fix in the next migration slices

- Main screen typography still uses some compact-layout-specific local sizing in deeper sections.
- Stats and Training need a cleaner reusable pattern for picker chips, filter bars, and data-density modes.
- Nutrition needs a more explicit “input shell” pattern for text entry, inline parsing states, and template/search modes.
- iPad and macOS regular-width behaviors are present, but not yet documented component-by-component.

### Later enhancements

- Reduce remaining compatibility aliases once adoption is broad enough.
- Export tokens from code automatically instead of maintaining a manual token artifact.
- Add a richer coded catalog section for forms, sheets, segmented controls, and chart interaction states.

## Ranked backlog

### Now

1. Migrate Home, Stats, Nutrition summary, auth lock, and settings controls onto semantic tokens and shared primitives.
2. Replace repeated selection-tile and menu-row patterns with shared components.
3. Expand tests to prevent raw colors and fixed-size fonts in newly migrated system files.
4. Tie the redesign roadmap and future feature specs to the checklist and catalog.

### Next

1. Build shared input-field and sheet-shell primitives, then migrate auth, nutrition entry, and training note entry flows.
2. Normalize remaining readiness and chart-support components to semantic text and color roles.
3. Add dedicated iPad/macOS screenshots or catalog states for sidebar, detail, and sheet variants.

### Later

1. Create a Figma library from the same semantic inventory and component contracts.
2. Introduce token export automation for Android/Pixel and future web/internal tooling.
3. Add watchOS rules and compact component guidance if a watch UI target is introduced.
