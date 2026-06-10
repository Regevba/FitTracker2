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

## Phase resolution (revised 2026-06-10 — L353 closure)

The original "~40-50 site" Phase 1 estimate was loose. Once the work landed, the
real count was far smaller, and Phases 3-4 resolved to **documented design
decisions, not code sweeps**. Phase-by-phase outcome:

1. **Phase 1 — SHIPPED via PR #557 (4 sites, not ~40-50).** Added `@ScaledMetric`
   to **4 v2 icon containers** — the genuinely text-adjacent icon dimensions where
   a fixed point size visibly desynchronizes from scaled text at AX5. The "~40-50"
   estimate over-counted because most fixed `Image` dimensions are *not*
   text-adjacent (see Phases 3-4). Operator simulator verification (AX5 Dynamic
   Type) is the remaining manual half (tracked separately as a ~10-min operator
   action).

2. **Phase 2 — folded into Phase 1.** The asset-catalog icons that mattered were
   among the 4 in #557; no separate sweep was warranted at this size.

3. **Phase 3 — Touch-target rationale (RESOLVED: fixed is correct, by design).**
   The ~5-10 `>= 44pt` touch targets **intentionally do NOT scale** with Dynamic
   Type, and that is the right call: 44pt is an **Apple HIG accessibility
   *minimum*** (a floor that must hold for every user regardless of text size),
   not a text-relative dimension. Applying `@ScaledMetric` to a touch target would
   make the *minimum* itself grow at large Dynamic Type sizes — harmless when text
   grows but wrong as a structural floor (it would inflate hit-areas past the
   layout). The correct pattern is what the codebase already does: a fixed
   `>= 44pt` frame, with the *content* (icon + label) scaling inside it.
   **Decision: leave touch targets non-scaled; this section is the documented
   rationale Phase 3 called for.**

4. **Phase 4 — Layout-dimension review (RESOLVED: structural dims stay fixed).**
   The ~10-15 layout dimensions (card heights, chart heights, section spacing) are
   **structural, not text-relative**, and correctly use the fixed design-system
   tokens (`AppSpacing.*`, `AppSize.*`, `AppLayout.*`) rather than `@ScaledMetric`.
   Rationale: these dimensions define the *container* geometry; the *text inside*
   already scales via SwiftUI's automatic `Text` Dynamic Type behavior + the
   `AppText.*` tokens, so the container holds a stable shape while its contents
   reflow. The one exception class — a dimension itself derived from a line-height
   or capping a single line of text — is rare and was handled case-by-case in
   Phase 1. **Decision: layout/structural dimensions stay on fixed DS tokens; no
   `@ScaledMetric` retrofit.**

**Net:** L353 closed as **1 small code PR (#557, 4 sites) + 2 documented design
decisions (Phases 3-4 above)** — not the imagined ~84-site sweep. The audit's
value was re-scoping a non-problem (text already scales) down to the handful of
genuinely text-adjacent icons, and recording *why* the rest correctly stay fixed.

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
