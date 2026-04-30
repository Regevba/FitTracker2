# Case-Study Visual Aid Catalog

> **Locked 2026-04-28** as part of the case-study presentation refactor (Alternative A locked).
> **Project rule:** every case study MUST include at least one visual aid (graph or indicator).
> **Selection rule:** the visual is chosen *per case study* — match the data shape to the component, never default-and-forget.
>
> The catalog below maps a case study's primary claim to the component that visualizes it best.
> Authoritative inventory of existing components is at the bottom.

---

## How to pick the right visual

Read the case study's **primary claim** — the single sentence in `tldr` or the headline. The shape of that claim determines the visual:

| If the primary claim is about… | The data has shape… | Use |
|---|---|---|
| One headline outcome ("X / Y shipped", "0 findings", "first wall-clock check") | Single value | **HeroMetric** |
| A measurable change between two states ("1170 → 294 lines", "v7.1 → v7.5 capability matrix") | Two snapshots, before + after | **BeforeAfter** |
| A breakdown of total time/effort across phases or items ("10h split as 2h research + 4h impl + …") | Stack of magnitudes summing to a whole | **DurationStack** |
| A ranking — which thing dominated, which was smallest ("3 chips ranked by latency") | Ordered items with magnitudes | **RankedBars** |
| A funnel — items entering, items surviving each filter ("185 findings → 35 closed → 0 critical") | Decreasing counts through tiers | **AuditFunnel** |
| Parallel work happening on a clock ("3 features ran concurrently for 4h") | Multi-lane timeline with start/end | **ParallelGantt** |
| A race between concurrent attempts that may collide ("2 writers wrote at t=3.2s, conflict at t=4.1s") | Multi-lane events on a shared time axis | **RaceTimeline** |
| PR dependencies ("M-1a → M-1b → M-1c → M-1d") | DAG of nodes with base relationships | **PRStackDiagram** |
| A trend across versions / over time ("velocity per case-study, v2.0 → v5.1") | Scatter or line of (time × metric) | **FrameworkAdvancement** (scatter) — or **LinearTimeline** (gap, see below) |
| A linear sequence of process steps ("Research → PRD → Tasks → Implement → …") | Ordered nodes with arrows | **FlowDiagram** |
| A taxonomic floor / framework architecture | Levels with nested components | **BlueprintOverlay** |
| Skill-or-chip × signature heatmap | Two-axis affinity matrix | **ChipAffinityMap** |
| A trace/replay of an execution | Timeline of beats with floor states | **DispatchReplay** |
| Findings list with severity coding | Array of (severity, domain, description) | **FindingsTable** |
| A static image / diagram | Image | **Figure** |

**Last-resort fallback:** if no specialised visual fits, `<KeyNumbersChart />` auto-renders the three `key_numbers` from frontmatter ("X of Y" → progress; "X → Y" → delta; "0 across N" → all-clear; else big-number). Cases that fall back are flagged for visual review during the periodic case-study audit.

---

## Anti-patterns

- **Forcing a chart to fit the data.** If the data is two strings ("we shipped" vs "we deferred"), don't compress them into a 2-column bar. Use HeroMetric or a callout — visual mass should track signal density.
- **Universal default.** `<KeyNumbersChart />` is the fallback, not the answer. A case study that uses it should be a small minority once the corpus is migrated.
- **Decorative visuals.** A visual that doesn't disambiguate or compress information is noise. If a sentence tells the story better, the sentence wins.
- **Duplicating the SummaryCard.** Three big numbers in the SummaryCard + the same three in a chart below is redundant. The visual should add a dimension the card cannot — relative magnitude, ranking, time, comparison.

---

## Frontmatter contract

```yaml
visual_aid:
  component: BeforeAfter        # one of the 17 components in the catalog
  data:                         # component-specific props
    before:
      label: "v7.1"
      items:
        - "8 check codes"
        - "Post-hoc cycle audit only"
        - "No runtime verification"
    after:
      label: "v7.5"
      items:
        - "11 check codes"
        - "Pre-commit + cycle"
        - "5 staging smoke profiles"
```

If `visual_aid:` is omitted, the renderer falls back to `<KeyNumbersChart numbers={frontmatter.key_numbers} />`. The validator (`scripts/validate-frontmatter.ts`, added with this rule) fails the build when a case study has neither a `visual_aid:` block nor parseable `key_numbers`.

---

## Component inventory (17 components, 3 directories)

| Component | Path (under `src/components/`) | Visualizes | Data shape |
|---|---|---|---|
| HeroMetric | `case-study/HeroMetric.tsx` | One headline value | `{ value, label, context?, accentVar?, size? }` |
| BeforeAfter | `case-study/BeforeAfter.tsx` | Two-state comparison | `{ before, after, delta?, beforeLabel?, afterLabel? }` (each side: `{ label, value, subtitle?, accentVar? }` or list) |
| DurationStack | `case-study/DurationStack.tsx` | Horizontal duration breakdown | `[{ label, minutes, colorVar }]` |
| RankedBars | `case-study/RankedBars.tsx` | Horizontal ranked bars | `[{ label, value, colorVar?, valueSuffix? }]` |
| FlowDiagram | `case-study/FlowDiagram.tsx` | Left-to-right node flow | `[{ label, sublabel?, colorVar? }]` |
| ParallelGantt | `case-study/ParallelGantt.tsx` | Concurrent work timeline | `[{ feature, complexity, endedAt, colorVar, phaseMark }]` |
| AuditFunnel | `case-study/AuditFunnel.tsx` | Filter-stage funnel | `[{ label, count, colorVar? }]` |
| RaceTimeline | `case-study/RaceTimeline.tsx` | Multi-lane events with collision | `[{ label, events: [{ t, label, detail? }], colorVar? }]` |
| PRStackDiagram | `case-study/PRStackDiagram.tsx` | PR dependency tree | `[{ id, label, title?, base, highlight?: 'ok' \| 'wrong' \| 'intended' }]` |
| FrameworkAdvancement | `case-study/FrameworkAdvancement.tsx` | Trend scatter w/ modal | `[{ name, shortLabel, shipDate, wallMinutes, cu, tier, frameworkVersion }]` |
| BlueprintOverlay | `bespoke/BlueprintOverlay.tsx` | Floor-by-floor framework taxonomy | Imported FLOORS: `[{ level, name, sub, accent, components }]` |
| ChipAffinityMap | `bespoke/ChipAffinityMap.tsx` | 2-axis affinity heatmap | Imported CHIPS × SIGNATURES × AFFINITY matrix |
| PhaseTimingChart | `bespoke/PhaseTimingChart.tsx` | Phase duration breakdown | Hardcoded PHASES: `[{ name, minutes, color }]` |
| DispatchReplay | `bespoke/DispatchReplay.tsx` | Execution trace with floor states | Imported TRACES: `[{ id, title, beats: [{ id, title, narrative, floorStates, metrics?, flow? }] }]` |
| MetricsCard | `mdx/MetricsCard.tsx` | Pinned key-metrics list | `[{ value, label }]` |
| FindingsTable | `mdx/FindingsTable.tsx` | Severity-coded findings | `[{ id, severity, domain, description }]` |
| Figure | `mdx/Figure.tsx` | Image + caption | `{ src, alt, caption?, width?, height? }` |

---

## Identified gaps

Gaps surface during corpus mapping. Build a new component only when ≥3 case studies need the same shape and no existing component covers it.

| Proposed component | Data shape | Status |
|---|---|---|
| **LinearTimeline** | Time-series line chart for "metric over weeks" or "adoption over snapshots" | **Likely needed.** `FrameworkAdvancement` is a scatter, not a continuous line. Tier 1.1 + Tier 3.2 trend dashboards would use a true line chart. Build during rollout if ≥3 case studies want it. |
| **VerticalStackBar** | Vertical stacked bar — categories within a single bar | **Speculative.** `DurationStack` is horizontal; flipping it for cases with very long category labels could help. Hold until a real case demands it. |
| **AnnotatedNumber** | Big number with hover-revealed methodology footnote | **Speculative.** `HeroMetric` already has `context?` for short notes. Build if `context` proves insufficient. |

---

## Audit rhythm

Per the v7.6/v7.7 framework integrity rules, this catalog gets reviewed at:

- **Every case-study merge** — the PR template will require declaring `visual_aid.component` (or explicitly accepting the fallback). Validator enforces.
- **Every cycle snapshot (72h)** — `make documentation-debt` adds a `visual_aid_specified` coverage dimension. Trend mode flags drift.
- **Every framework version bump** — the catalog is reviewed for new shapes the latest version surfaced. Last reviewed: 2026-04-28 at v7.7.
