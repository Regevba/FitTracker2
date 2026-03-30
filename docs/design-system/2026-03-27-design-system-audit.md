# FitTracker Design System Audit

Date: 2026-03-27  
Audience: product design, SwiftUI engineering, future Android implementation

## 1. Current Inventory

### Existing foundations in code

| Area | Current state | Source |
| --- | --- | --- |
| Brand and palette seed | Warm orange + cool blue palette, status colors, accent colors | `FitTracker/Services/AppTheme.swift` |
| Typography seed | Small fixed type scale already exists | `FitTracker/Services/AppTheme.swift` |
| Adaptive shell | iPhone tab bar, iPad/macOS sidebar split | `FitTracker/Views/RootTabView.swift` |
| Shared UI primitives | Metric card, chart shell, readiness card, badge, header, empty state, trend pill | `FitTracker/Views/Shared/` |
| Product docs | v2 redesign, current README product shape | `docs/superpowers/specs/2026-03-14-fittracker-v2-redesign.md`, `README.md` |

### Current implementation observations

- The app already behaves like an Apple-first product: compact-first home, adaptive nav on larger screens, HealthKit and watch connectivity, native sheets and toolbars.
- The shared component layer exists, but adoption is still partial.
- The codebase still contains many screen-local presentation decisions.
- Auth and the main app evolved with different visual moods and token usage, so the system feels partially split.

### Audit counts captured during implementation planning

- About 100 ad hoc `.font(.system(...))` usages remain in app code.
- About 26 raw `Color(red: ...)` usages remain in app code.
- Shared components were present, but canonical card/button/menu wrappers were missing before this pass.

## 2. Current Inconsistencies

### Foundation-level inconsistencies

- Color roles were mostly palette-based, not semantic. The code knew brand colors, but not clear roles like `surface`, `border`, `focus`, `selection`, or `chart`.
- Typography was only partially standardized. A token scale existed, but many views bypassed it with local sizes.
- Radius, sheet corners, spacing, and shadows were repeated as literals.

### Component-level inconsistencies

- Card treatments were repeated as `RoundedRectangle(cornerRadius: 16)` plus local opacity/stroke combinations.
- CTA/button styling was screen-owned rather than system-owned.
- Menu/list rows in account and settings surfaces were custom-built instead of using a canonical row contract.
- Empty, informative, and stateful layouts varied slightly by screen.

### Product-level inconsistencies

- The signed-in app shell uses a soft, bright, glassy palette.
- Auth surfaces use a dark, trust-oriented palette.
- Both directions are valid, but they lacked a shared semantic layer to connect them.

## 3. Benchmark Research Summary

### Spotify Encore

- Strong reference for semantic tokens, governance, and adoption at scale.
- Key lesson: non-semantic tokens and local overrides do not scale well across teams and platforms.
- FitTracker takeaway: keep palette aliases for migration, but make semantic roles the public API.

### Apple HIG

- Strongest reference for iPhone, iPad, and macOS behavior.
- Key lesson: platform-native hierarchy and adaptation matter more than visual novelty.
- FitTracker takeaway: preserve Apple conventions for nav, settings, sheets, typography rhythm, and input density.

### Material 3 / Android

- Strongest reference for future Pixel-ready adaptation.
- Key lesson: adaptive layouts, edge-to-edge behavior, and token mapping should happen from a semantic layer.
- FitTracker takeaway: Android should be an adaptation of FitTracker semantics, not a separate design language.

### Additional system references

- Atlassian: mature foundation documentation and token discipline.
- Primer: strong pattern contribution mindset and explicit system ownership.
- Figma + zeroheight-style documentation models: documentation must work for engineering, PM, research, and content, not only for designers.

## 4. Recommended Target Model

### System architecture

1. Semantic foundation layer
   - `AppColor`, `AppText`, `AppSpacing`, `AppRadius`, `AppShadow`, `AppSheet`
2. Compatibility alias layer
   - keep `Color.appOrange1`, `AppType`, and similar old names alive while screens migrate
3. Canonical shared components
   - card, button/CTA, menu row, badge, metric tile, chart shell, empty state, section header
4. Product usage layer
   - screens consume semantic roles and canonical components instead of literal styling
5. Documentation and governance layer
   - audit, checklist, ownership, changelog, Android mapping

### Apple-first platform order

1. iPhone compact width is the primary design baseline
2. iPad and macOS get regular-width adaptations of the same semantic system
3. watchOS is rules-first for now because there is no watch UI target yet
4. Android / Pixel comes next by mapping semantics to Material 3 roles

## 5. Migration Priorities

### Must fix now

- Establish semantic token roles in `AppTheme.swift`
- Add canonical shared wrappers for card, CTA, and menu rows
- Add a coded catalog so the team can inspect the system in-app
- Add documentation and a feature-planning checklist

### Should fix during migration

- Replace screen-local rounded-rectangle card styling with shared card surfaces
- ~~Reduce remaining ad hoc font sizes and raw color literals in major flows~~ **Done 2026-03-30** — all remaining `Color.white.opacity()`, `Color.secondary/primary`, `Font.system()`, magic shadow values, and legacy brand aliases replaced across 12 view files. See `color-usage-guidelines.md` → Token migration mapping.
- Standardize settings and account row treatments
- Unify auth and product under shared semantic roles

### Later improvements

- Formal motion and haptics guidelines
- More complete dark-mode policy by surface type
- Accessibility review by component
- Android component equivalents and large-screen rules

## 6. Files Introduced or Updated In This Pass

### Code

- `FitTracker/Services/AppTheme.swift`
- `FitTracker/Views/Shared/AppDesignSystemComponents.swift`
- `FitTracker/Views/Settings/DesignSystemCatalogView.swift`
- shared component updates in `FitTracker/Views/Shared/`
- settings/account integration updates

### Documentation

- `docs/design-system/design-system-governance.md`
- `docs/design-system/feature-design-checklist.md`
- `docs/design-system/figma-library-structure.md`
- `docs/design-system/android-adaptation.md`

## 7. Recommended Next Migration Slice

1. Migrate the highest-traffic screens after the shared layer:
   - Home
   - Training
   - Nutrition
   - Stats
2. Replace remaining repeated card/button/menu patterns
3. Convert the largest groups of local font literals to `AppText` roles
4. Introduce a lightweight lint or CI check once the raw literal count is much lower
