# `/design` — Design System & Visual Governance

> **Role in the ecosystem:** The visual layer. Owns tokens, components, Figma automation, design system compliance, and WCAG AA accessibility. Pairs with `/ux` — `/ux` handles what-and-why, `/design` handles how-it-looks.

**Agent-facing prompt:** [`.claude/skills/design/SKILL.md`](../../.claude/skills/design/SKILL.md)

---

## What it does

Manages design system governance, creates UX specs from PRDs, generates Figma build prompts, validates the token pipeline, and enforces WCAG AA accessibility. After Phase 3 approval it auto-generates a visual-build prompt (`/design prompt {feature}`) in `docs/prompts/`, paired with `/ux prompt` for hand-off to a downstream agent.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/design audit` | Design system compliance check | "Check if this PR's UI changes comply with the design system" | Phase 3 (compliance gateway), Phase 6 (Review) |
| `/design ux-spec {feature}` | Generate UX spec from PRD | "Create UX spec for the onboarding flow" | Phase 3 (UX) — legacy; `/ux spec` is the newer path |
| `/design figma {feature}` | Generate Figma build prompt | "Generate Figma prompt for the stats redesign" | Phase 3 (UX) |
| `/design tokens` | Validate token pipeline | "Check if DesignTokens.swift matches tokens.json" | Phase 6 (Review) |
| `/design accessibility` | WCAG AA audit | "Run accessibility audit on the nutrition screens" | Phase 6 (Review) |
| `/design prompt {feature}` | Auto-generate a visual-build prompt in `docs/prompts/{date}-{feature}-design-build.md` once Phase 3 is approved | dispatched by hub after compliance gateway passes | Phase 3 Step 4 |

## Shared data

**Reads:**
- `context.json` — brand, personas
- `design-system.json` — current token/component inventory
- `cx-signals.json` — UX confusion signals that imply visual problems
- `.claude/features/{feature}/ux-spec.md` — the handoff from `/ux`

**Writes:**
- `design-system.json` — new tokens/components proposed
- `docs/prompts/{date}-{feature}-design-build.md` (from `/design prompt`)

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 3 (UX Definition) | `/design audit` on the ux-spec → compliance gateway decision (fix / evolve DS / override) |
| Phase 3 Step 4 | `/design prompt {feature}` (paired with `/ux prompt`) |
| Phase 6 (Review) | `/design audit` for visual sign-off + `/design tokens` + `/design accessibility` |

## Upstream / Downstream

- **Upstream:** `/ux` produces the ux-spec that `/design` validates against. `/research` feeds visual trends and market positioning. `/cx` surfaces UX confusion signals.
- **Downstream:** Feeds component specs to `/dev` via `design-system.json`. The `/design prompt` output lands in `docs/prompts/` for Figma MCP or SwiftUI implementation agents.

## Standalone usage examples

1. **Quick compliance check:** `/design audit` → "I just changed the nutrition view, check if it follows the design system"
2. **Figma automation:** `/design figma onboarding` → generates a copy-paste prompt for Figma MCP
3. **Token drift check:** `/design tokens` → runs `make tokens-check`, flags any raw literals in the current diff

## Recent usage

- **`/design build {feature}`** sub-command added (2026-04-09) — executes a Figma MCP design-to-code build with SwiftUI fallback. Reads Figma file context via `get_design_context`, adapts to the project's token system.
- **Home v2 Figma screen** — first end-to-end Figma MCP integration. Design context retrieved from Figma, adapted to AppTheme tokens, implemented as v2/ SwiftUI views.
- **`/design prompt`** — auto-generated visual-build prompts for Home v2 and Training v2 in `docs/prompts/`.

## Key references

- [`FitTracker/Services/AppTheme.swift`](../../FitTracker/Services/AppTheme.swift) — semantic token layer
- [`FitTracker/DesignSystem/AppComponents.swift`](../../FitTracker/DesignSystem/AppComponents.swift) — reusable components
- [`docs/design-system/feature-development-gateway.md`](../design-system/feature-development-gateway.md) — 7-stage workflow
- [`docs/design-system/approval-process.md`](../design-system/approval-process.md) — governance rules
- [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — `/design` owns Sections B / C / D
- [`docs/design-system/ux-foundations.md`](../design-system/ux-foundations.md) — referenced from ux-spec handoff

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §7
- [ux.md](ux.md) — handoff partner for the what-and-why layer
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/design/SKILL.md`](../../.claude/skills/design/SKILL.md)
