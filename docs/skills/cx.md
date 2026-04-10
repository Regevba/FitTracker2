# `/cx` — Customer Experience

> **Role in the ecosystem:** The feedback layer. The only spoke that completes the PM workflow **circle** — Phase 9 (Learn) routes user signals back to the responsible skill via root-cause classification, turning a linear pipeline into a learning loop.

**Agent-facing prompt:** [`.claude/skills/cx/SKILL.md`](../../.claude/skills/cx/SKILL.md)

---

## What it does

The most complex spoke skill. Monitors App Store reviews with deep keyword analysis, runs NPS surveys, performs sentiment analysis with root-cause classification, extracts testimonials, manages the public roadmap, and — most critically — runs post-deployment feedback loops that connect user signals back to original feature pain points.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/cx reviews` | Scrape and analyze reviews | "Analyze our latest App Store reviews" | Phase 0 (Research) |
| `/cx nps` | Design/analyze NPS survey | "Design an NPS survey for our active users" | Phase 8 (Docs) |
| `/cx sentiment` | Keyword/sentiment analysis | "What themes are emerging from user feedback?" | Continuous |
| `/cx testimonials` | Extract marketing-ready quotes | "Find our best testimonials for the App Store listing" | Continuous |
| `/cx roadmap` | Generate public roadmap | "Create a public roadmap page from GitHub issues" | Phase 8 (Docs) |
| `/cx digest` | Weekly CX summary | "What's the CX picture this week?" | Continuous |
| `/cx analyze {feature}` | Post-deployment feedback loop | "Did the training feature solve the original pain point?" | **Phase 9 (Learn)** |

## Shared data

**Reads:** `feature-registry.json` (pain points), `metric-status.json` (quant context), `health-status.json` (tech context).

**Writes:** `cx-signals.json` (ALL fields — reviews, NPS scores, sentiment, testimonials, keyword patterns, root cause dispatch log).

## Deep Feedback Analysis Engine

`/cx` doesn't just categorize reviews — it classifies them by **signal type** and **root cause**:

**Signal Types:** Positive, Negative, Feature Request, Confusion, Friction, Comparison — each with specific keyword patterns stored in `cx-signals.json → keyword_patterns`.

**Root Cause Classification** (for negative/confusion signals):

| Root Cause | Example Signal | Dispatched To |
|---|---|---|
| Messaging | "what does this do", "I thought it would..." | `/marketing` |
| UX | "how do I", "can't find", "confusing navigation" | `/ux` + `/design` |
| Functionality | "doesn't work", "broken", "bug" | `/dev` + `/qa` |
| Expectation mismatch | "I expected", "not what I wanted" | `/pm-workflow` (re-scope) |

### Post-deployment assessment categories

| Assessment | Meaning | Action |
|---|---|---|
| **Solved** | Pain point eliminated | Celebrate, marketing fuel |
| **Improved** | Reduced but not eliminated | Plan iteration |
| **Status Quo** | No measurable change | Investigate discoverability / messaging |
| **Worsened** | New confusion introduced | UX emergency review |
| **New Problem** | Solved original, created new | New PRD cycle |

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 0 (Research) | Hub pulls CX signals for user pain points |
| Phase 8 (Docs) | `/cx roadmap` for public roadmap |
| **Phase 9 (Learn)** | `/cx analyze {feature}` — the feedback loop that makes the pipeline circular |

## Upstream / Downstream

- **Upstream:** receives review batches, NPS responses, support tickets (external sources)
- **Downstream:** dispatches to `/marketing` (messaging), `/ux` + `/design` (UX), `/dev` + `/qa` (bugs), `/pm-workflow` (rescope)
- **Feeds:** testimonials → `/marketing`, feature requests → `/pm-workflow` backlog, qualitative context → `/analytics`

## Standalone usage examples

1. **Review analysis:** `/cx reviews` → "Paste our latest 50 App Store reviews" → categorizes by signal type, extracts themes
2. **Feature health check:** `/cx analyze training` → "Did training solve 'Logging is tedious'?" → assessment with evidence
3. **Weekly digest:** `/cx digest` → aggregates all signals, highlights actionable items for PM

## Key references

- [`.claude/shared/cx-signals.json`](../../.claude/shared/cx-signals.json) — the primary data store
- [`architecture.md`](architecture.md) — §16 "The CX Feedback Loop" covers the full Phase 9 walkthrough

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §11, §16
- [marketing.md](marketing.md), [ux.md](ux.md), [dev.md](dev.md), [qa.md](qa.md) — dispatch targets
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/cx/SKILL.md`](../../.claude/skills/cx/SKILL.md)

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| app-store-connect | MCP (`asc-mcp`, 208 tools) | App Store reviews, ratings, app metadata, TestFlight feedback |
| sentry | MCP (`mcp.sentry.dev`) | Error reports, crash logs, user-impacting issue traces |

**Adapter config:** `.claude/integrations/app-store-connect/` and `.claude/integrations/sentry/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

### Learning Cache

**Location:** `.claude/cache/cx/`

Caches: review analysis patterns (keyword clusters by signal type), sentiment classification models (trained on prior review batches), root-cause dispatch templates (which signals route to which skill).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
