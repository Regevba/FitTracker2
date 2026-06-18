# iOS Design System Architecture (FitTracker2 / FitMe app)

> **Source-of-truth model:** **code is canonical; the Figma library is a manually-maintained mirror.** Figma Code Connect is **disabled** (it needs a Figma Org/Enterprise plan; this account is Pro — see honesty ledger [FT2-FH-005](../case-studies/framework-honesty-ledger.md) and [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md)). The SwiftUI token → component → screen architecture below is real and operational; the Figma mirror is kept in sync by hand per the [maintenance protocol](./figma-mirror-maintenance-protocol.md).

This is the iOS companion to [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md) (web). One doc per surface; shared philosophy, different stacks.

---

## §1 What this doc is

The single place an iOS developer answers: **"where is the design-system source of truth, what are its layers, and how do I keep the Figma mirror in sync?"** It maps the token pipeline, the component layer, and the verified Figma mirror node IDs (audited live 2026-06-18).

## §2 The big picture — token → component → screen

```
design-tokens/tokens.json          ← SOURCE OF TRUTH (12 token categories)
        │  Style Dictionary v5 (`make tokens`)
        ▼
FitTracker/DesignSystem/DesignTokens.swift   ← generated (golden-verified, PR #677)
        │  consumed by
        ▼
FitTracker/Services/AppTheme.swift   ← ~177 semantic tokens (AppColor / AppSpacing / AppRadius / …)
        │  consumed by
        ▼
FitTracker/DesignSystem/*.swift      ← reusable components (AppComponents, ProgressBar, …)
        │  composed into
        ▼
FitTracker/Views/**                  ← screens (v2 surfaces)
        ╎  mirrored (manually) into
        ▼
Figma: FitTracker Design System Library (0Ai7s3fCFqR5JXDW8JvgmD)
```

CI gates protecting the chain: `make tokens-check` (token drift), `make ui-audit` (P0=0 raw-literal/a11y scan), `xcodebuild build && test`.

## §3 Token inventory (`tokens.json` → `AppTheme.swift`)

`tokens.json` has **12 categories**; `AppTheme.swift` exposes them as namespaced enums:

| tokens.json category | Swift enum | Count | Example symbol |
|---|---|---|---|
| color (brand/background/text/surface/border/status/accent/chart/selection) | `AppColor.<Group>` | 47 | `AppColor.Brand.primary` (#FA8F40) |
| spacing | `AppSpacing` | 8 | `AppSpacing.large` (24) |
| borderRadius | `AppRadius` | 10 | `AppRadius.card` (16) |
| opacity | `AppOpacity` | 3 | `AppOpacity.disabled` (0.15) |
| size | `AppSize` | 6 | `AppSize.ctaHeight` (52) |
| layout | `AppLayout` | 6 | `AppLayout.chartHeight` (158) |
| typography | `AppText` (type ramp) | 15 | `AppText.hero` |
| shadow | effect modifiers | 2 | card / cta |
| motion | `AppMotion` | 6 | `AppMotion.quickInteraction` |

**Rule:** always use semantic tokens — never raw literals. Enforced by `make ui-audit` (`DS-RAW-*` rules). New `Color("name")` tokens require the matching `.colorset` + `tokens.json` entry + `DesignTokens.swift` line in the same commit (`DS-MISSING-ASSET`).

## §4 Appearance

The iOS app ships a **single light-first appearance** (the glassy blue/orange FitMe system). Dark-context tokens exist for specific surfaces (`background/authTop|authMiddle|authBottom`, `text/inverse*`, `surface/inverse`) but there is no global Light/Dark mode switch like the web surface has. The Figma mirror's "Color / Semantic" collection carries Light/Dark modes for completeness; the app consumes the light values.

## §5 Component architecture

Components live in `FitTracker/DesignSystem/`:

| File | Components |
|---|---|
| `AppComponents.swift` | AppPickerChip, AppFilterBar, AppSheetShell, AppStatRow, AppSegmentedControl, AppProgressRing, AppMetricColumn, AppMetricTile |
| `ProgressBar.swift` | ProgressBar |
| `FitMeBrandIcon.swift` | FitMeBrandIcon (also the AI avatar) |
| `AppViewModifiers.swift` | shared modifiers (elevation, motion-safe, scaledFont) |
| `AppIcon.swift` / `AppPalette.swift` / `AppMotion.swift` / `DesignTokens.swift` | icon set, raw palette, motion presets, generated tokens |

All visual properties bind to `AppTheme` tokens. Screens follow the [V2 Rule](../../CLAUDE.md#ui-refactoring--v2-rule): aligned surfaces live in a `v2/` subdirectory; v1 stays as a HISTORICAL reference.

## §6 The Figma mirror (verified live 2026-06-18)

**File:** `FitTracker Design System Library` — `0Ai7s3fCFqR5JXDW8JvgmD`. **Status: Mirror — manually maintained.** Fidelity ~95–100% (audit: [`.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md`](../../.claude/features/figma-design-architecture/mirror-fidelity-audit-2026-06-18.md)).

| Layer | Node ID | Contents |
|---|---|---|
| Foundations page | `10:3` | Overview + Color Tokens frames |
| Components page | `10:5` | 22 component sets, full variant matrices |
| Code-mirror variable collection | `985:2` | 80 vars, values == `tokens.json`; iOS codeSyntax = `AppColor.*` / `AppSpacing.*` / … (populated 2026-06-18) |
| Text styles | — | 22 (`text/hero` → `text/button`) |
| Effect styles | — | 2 (`effect/elevation-card`, `effect/elevation-cta`) |

**Component-set node IDs:** AppButton `12:21`, AppCard `15:21`, AppMenuRow `16:36`, StatusBadge `17:17`, EmptyStateView `19:21`, AppSelectionTile `20:18`, AppInputShell `21:26`, AppFieldLabel `22:10`, AppQuietButton `22:23`, AppPickerChip `356:8`, AppFilterBar `357:11`, AppStatRow `357:19`, AppSegmentedControl `357:36`, AppProgressRing `357:49`, AppSheetShell `357:57`, SectionHeader `359:7`, TrendIndicator `359:14`, MetricCard `359:23`, ChartCard `359:30`, ReadinessCard `359:40`, MacroTargetBar `359:50`, MealSectionView `359:57`.

**Definition of "Synced":** Figma frame visually matches rendered code + real node ID recorded here + recent verification date. **No** Code Connect publish (Pro-plan blocked).

## §7 Maintenance contract

Code → Figma is **one-directional and manual**. The full protocol (owner, cadence, propagation steps) lives in [`figma-mirror-maintenance-protocol.md`](./figma-mirror-maintenance-protocol.md). Drift is surfaced by the `figma-mirror-staleness` advisory (`make figma-mirror-staleness`). In short:

- **New/changed token** → edit `tokens.json` → `make tokens` → update the matching variable in the `985:2` code-mirror collection (value + iOS codeSyntax).
- **New/changed component** → ship the SwiftUI component → add/update the matching component set on Components page `10:5`, recording the node ID in §6.

## §8 Cross-references

- Tokens: [`design-tokens/tokens.json`](../../design-tokens/tokens.json) · [`AppTheme.swift`](../../FitTracker/Services/AppTheme.swift)
- Components: [`AppComponents.swift`](../../FitTracker/DesignSystem/AppComponents.swift)
- Figma↔code matrix + verification contract: [`figma-code-sync-status.md`](./figma-code-sync-status.md)
- Rebuild decision + honesty disclosure: [`figma-source-of-truth-plan-2026-06-15.md`](./figma-source-of-truth-plan-2026-06-15.md) · [FT2-FH-005](../case-studies/framework-honesty-ledger.md)
- Web counterpart: [`fitme-story-design-architecture.md`](./fitme-story-design-architecture.md)

## §9 What this doc is NOT

- **Not the source of truth for token values** — `tokens.json` + `AppTheme.swift` are. This doc points at them.
- **Not a Code Connect spec** — Code Connect is disabled on this plan; the mirror is documentation, not a code-generation bridge.
- **Not auto-synced** — the Figma mirror is maintained by hand per §7. A node ID here is verified-as-of its audit date, not continuously.
