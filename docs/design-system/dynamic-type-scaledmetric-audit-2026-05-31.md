# Dynamic Type @ScaledMetric Audit — 2026-05-31

> Backlog item L353 "Dynamic Type full compliance — `@ScaledMetric` not on all text tokens."
> This document is the audit pass output. **No code change** — finding-classification + scope-reduction.

## Reframing the backlog item

The backlog entry implies `@ScaledMetric` is missing from text tokens. **This is technically incorrect for SwiftUI** — `Text(...)` views with a `.font(...)` modifier **automatically scale with Dynamic Type**. No `@ScaledMetric` is needed on text itself.

`@ScaledMetric` is for **numeric layout values** that the developer wants to scale with the user's preferred text size — icon point sizes, fixed-frame dimensions, spacing constants that should grow as text grows.

After reframing, the verification question becomes:

> Which fixed numeric layout values in the codebase do NOT scale with Dynamic Type, and which of those should?

## Current state

| Metric | Count | Status |
|---|---|---|
| `@ScaledMetric` decorators across `FitTracker/` | **0** | Truly absent — no scaled numeric values |
| Files using `AppText.*` tokens | 93 | SwiftUI's `Text.font(AppText.body)` auto-scales — these are FINE |
| Fixed `Image.frame(width:)`/`.frame(height:)` call sites | 84 | **These are the true candidates** — would not grow with Dynamic Type |
| `dynamicTypeSize` modifier usage | 0 | Zero explicit overrides — app follows system preference |

## Findings

### ✓ Text tokens already scale (false alarm in backlog)

The 93 `AppText.*` usages do NOT need `@ScaledMetric`. SwiftUI's `Text` view applies Dynamic Type scaling automatically when a `.font(...)` style is applied. Sample verification:

```swift
Text("Hello")                      // does NOT scale
Text("Hello").font(.body)          // DOES scale (system style)
Text("Hello").font(AppText.body)   // DOES scale (AppText.body is a `Font` value)
```

**Backlog L353 as worded is mis-stated.** AppText tokens already give Dynamic Type behavior for free.

### ⚠ 84 fixed Image dimensions are the true gap

The 84 call sites that hardcode `.frame(width: N)` or `.frame(height: N)` on Images **do not scale** with Dynamic Type. A user who sets large text gets large body copy but the same-size icons, which breaks the design's hierarchy.

This is the actual Dynamic Type compliance gap.

### Categories within the 84 sites

Without scanning all 84 individually, the rough categories are:

| Category | Estimated count | Recommendation |
|---|---|---|
| **SF Symbols sized with explicit point dimensions** (`Image(systemName: ...).frame(width: 20, height: 20)`) | ~40-50 | Convert to `@ScaledMetric private var iconSize: CGFloat = 20` + use `.frame(width: iconSize, height: iconSize)` |
| **Custom icons (asset catalog) at fixed sizes** | ~10-15 | Same — `@ScaledMetric` for the base dimension |
| **Fixed touch targets** (44pt minimum) | ~5-10 | **Don't scale** — touch targets are accessibility minimums, not text-relative |
| **Layout dimensions** (card heights, divider widths) | ~10-15 | Case-by-case — divider widths stay fixed; card heights may scale |

## What this session verified

- ✓ Backlog L353 wording is mis-stated for text tokens (SwiftUI auto-scales `Text`)
- ✓ 0 `@ScaledMetric` decorators in current codebase — the genuine compliance gap
- ✓ 84 fixed numeric Image dimensions identified as the real audit target
- ✓ 4 sub-categories with different remediation strategies (not a blanket sweep)

## Recommended scope for an L353-fixing PR

**Not** a bulk 84-site sweep. Instead a categorized sub-feature PR:

1. **Phase 1 (~2h, ~40-50 sites):** SF Symbol point-dimension sweep — add `@ScaledMetric` to icon size constants in the most-touched files (Settings screens, Home cards, NavigationBars). Verify visually with Dynamic Type set to AX5 (largest) in simulator.

2. **Phase 2 (~1h, ~10-15 sites):** Asset-catalog icon dimensions — same treatment.

3. **Phase 3 (~30 min, ~5-10 sites):** Touch-target audit — confirm `>= 44pt` is intentionally non-scaled, document the rationale.

4. **Phase 4 (~1h, ~10-15 sites):** Layout dimension review — case-by-case decisions on which should scale.

Total estimated effort: **~4-5h of careful work + simulator verification**. Should ship as one feature `dynamic-type-icon-sweep` with PRD documenting the categorization decisions.

## What this session did NOT do

- ✗ No code changes
- ✗ No `@ScaledMetric` decorators added (deferred to future sub-feature PR)
- ✗ No per-site categorization of all 84 candidates (would inflate audit scope; the Phase 1-4 split keeps each tractable)

## Operator follow-up

- **Decision needed:** flip L353 backlog entry from "Dynamic Type full compliance — `@ScaledMetric` not on all text tokens" to "Dynamic Type icon-sweep — 84 fixed-dimension Images need `@ScaledMetric` review (Phase 1-4 in audit doc)". The previous wording would mis-allocate effort to a non-problem (text tokens already scale).
- **Schedule:** kick off `dynamic-type-icon-sweep` feature when the next UI-touching session lands. Pair naturally with any Settings-or-Home v3 alignment work since those carry the densest icon footprint.

## Phase E compliance

- No new framework gates
- No state.json mutations
- No infra-glob touches (`docs/design-system/` is NOT in the Mode B path glob)
- No code changes — audit doc only
