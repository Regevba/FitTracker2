# `/research` — Market Research

> **Role in the ecosystem:** The discovery layer. Owns the wide-to-narrow research funnel: cross-industry pattern recognition → same-category competitive analysis → feature-specific deep dives.

**Agent-facing prompt:** [`.claude/skills/research/SKILL.md`](../../.claude/skills/research/SKILL.md)

---

## What it does

Conducts market research using a wide-to-narrow funnel. Also covers UX pattern libraries and ASO research. Feeds every Phase 0 (Research) run of `/pm-workflow` with structured competitive and market context.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/research wide {topic}` | Cross-industry scan | "How do non-fitness apps solve habit formation?" | Phase 0 (Research) |
| `/research narrow {category}` | Same-category deep dive | "Deep dive into fitness app nutrition tracking" | Phase 0 (Research) |
| `/research feature {name}` | Feature-specific analysis | "How do 5 apps implement onboarding?" | Phase 0 (Research) |
| `/research competitive` | Full competitive landscape | "Update our competitive analysis" | On-demand |
| `/research market` | Market sizing and trends | "What's the fitness app market outlook?" | On-demand |
| `/research ux-patterns {pattern}` | Best-in-class UX patterns | "Find best streak/gamification implementations" | Phase 3 (UX) |
| `/research aso` | App Store keyword research | "Research keywords for fitness tracker apps" | Pre-launch |

## The Funnel

```
WIDE (Cross-Industry)
  Duolingo → streaks, XP, leaderboards (31M DAU)
  Headspace → value-first onboarding (70M downloads)
  Signal → zero-knowledge privacy (trust positioning)
  Spotify → freemium → 46% premium conversion
  Notion → template ecosystem, product-led growth
  Strava → community-driven retention

NARROW (Fitness/Health)
  MyFitnessPal │ Strong │ Hevy │ Fitbod │ Strava │ MacroFactor │ Noom

FEATURE-SPECIFIC
  How does each competitor implement THIS exact feature?
```

## Shared data

**Reads:** `context.json` (positioning, personas), `feature-registry.json` (find gaps), `cx-signals.json` (what users ask for), `campaign-tracker.json` (marketing context).

**Writes:** `context.json` (competitive updates), `cx-signals.json` (user research).

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 0 (Research) | All three funnel levels: `/research wide` → `/research narrow` → `/research feature` |
| Phase 3 (UX) | `/research ux-patterns` for specific interaction patterns |

## Upstream / Downstream

- Feeds competitive data to `/marketing` (via `context.json`)
- Feeds UX patterns to `/ux` and `/design` (via research artifacts)
- Informs `/pm-workflow` PRD decisions with market data
- Reads CX signals from `/cx` to find user-reported gaps

## Standalone usage examples

1. **Cross-industry insight:** `/research wide habit-formation` → analyzes Duolingo, Strava, Headspace mechanics and applies to FitMe
2. **Competitor check:** `/research narrow fitness-apps` → updates competitive landscape with latest pricing, features, ratings
3. **Feature deep-dive:** `/research feature onboarding` → 5+ app teardowns with best/worst practices

## Recent usage

- **4 screen research audits completed** — Home Today Screen, Training Plan, Body Composition, Onboarding. Each produced structured findings feeding the v2 refactor pipeline.
- **Home v2 Phase 0** — `/research feature home-today-screen` ran the wide-to-narrow funnel, comparing 6 fitness apps' home screen patterns before the UX audit.
- **Training v2 Phase 0** — competitive research on workout logging flows across MyFitnessPal, Strong, Hevy, Fitbod.

## Key references

- [`.claude/shared/context.json`](../../.claude/shared/context.json) — competitive landscape
- [`docs/product/PRD.md`](../product/PRD.md) — competitive table + positioning

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §13
- [marketing.md](marketing.md), [ux.md](ux.md), [cx.md](cx.md) — consumers of research output
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/research/SKILL.md`](../../.claude/skills/research/SKILL.md)

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| firecrawl | MCP (`firecrawl-mcp`) | Web scraping, competitor page extraction, App Store listing analysis, content crawling |
| apify | MCP (20k+ actors) | Large-scale web data collection, social listening, app review scraping, market signal harvesting |

**Adapter config:** `.claude/integrations/firecrawl/` and `.claude/integrations/apify/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

### Learning Cache

**Location:** `.claude/cache/research/`

Caches: competitor analysis templates (structured teardown formats reused across features), market signal patterns (recurring themes from fitness app reviews and trends).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
