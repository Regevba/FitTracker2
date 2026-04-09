# `/marketing` — Marketing & Growth

> **Role in the ecosystem:** The outbound layer. Owns App Store Optimization, campaigns with UTM tracking, competitive positioning, content strategy, email automation, launch communications, and App Store creative assets.

**Agent-facing prompt:** [`.claude/skills/marketing/SKILL.md`](../../.claude/skills/marketing/SKILL.md)

---

## What it does

Manages everything outbound: ASO, paid campaigns, organic content, email drips, launch comms, and App Store creative. Takes inputs from `/cx` (testimonials, user language) and `/research` (competitive positioning) and produces campaign briefs, content briefs, email sequences, and App Store listings.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/marketing aso` | App Store listing optimization | "Optimize our App Store listing for 'fitness tracker AI'" | Pre-launch |
| `/marketing campaign {name}` | Create campaign brief | "Create a campaign for our launch week" | Phase 8 (Docs) |
| `/marketing competitive` | Competitive analysis | "How does our positioning compare to Hevy and Strong?" | Phase 0 (Research) |
| `/marketing content {topic}` | SEO content brief | "Write a content brief about progressive overload tracking" | Continuous |
| `/marketing email {sequence}` | Email automation | "Design the onboarding email drip" | Phase 8 (Docs) |
| `/marketing launch {feature}` | Launch communications | "Prepare launch comms for the AI recommendations feature" | Phase 8 (Docs) |
| `/marketing screenshots` | App Store screenshots | "Spec out our App Store screenshots" | Pre-launch |

## Shared data

**Reads:** `context.json` (brand, personas, positioning), `cx-signals.json` (testimonials, user language), `metric-status.json` (conversion, retention), `feature-registry.json` (what's launched).

**Writes:** `campaign-tracker.json` (campaigns, UTM convention, channels, attribution model).

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 0 (Research) | `/marketing competitive` for positioning context |
| Phase 8 (Docs) | `/marketing launch` for feature announcement comms |

## Upstream / Downstream

- Receives messaging-problem dispatches from `/cx` (root cause = messaging)
- Receives testimonials from `/cx` (via `cx-signals.json`)
- Feeds campaign data to `/analytics` (via `campaign-tracker.json`)
- Reads market sizing + positioning from `/research`

## Standalone usage examples

1. **ASO optimization:** `/marketing aso` → generates title, subtitle, keywords, description optimized for 2026 ASO best practices
2. **Email drip:** `/marketing email onboarding` → designs 3-email sequence (day 1, 3, 7) with A/B subject lines
3. **Launch kit:** `/marketing launch ai` → multi-channel kit: in-app modal, email, social posts, App Store update

## Key references

- [`.claude/shared/campaign-tracker.json`](../../.claude/shared/campaign-tracker.json) — campaigns + UTM conventions + attribution
- [`docs/product/PRD.md`](../product/PRD.md) — brand, positioning, value props

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §12
- [cx.md](cx.md), [research.md](research.md), [analytics.md](analytics.md) — upstream/downstream partners
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/marketing/SKILL.md`](../../.claude/skills/marketing/SKILL.md)
