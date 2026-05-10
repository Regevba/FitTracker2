# `/design` — Design System & Visual Governance

> **Role in the ecosystem:** The visual layer. Owns tokens, components, Figma automation, design system compliance, and WCAG AA accessibility. Pairs with `/ux` — `/ux` handles what-and-why, `/design` handles how-it-looks.

**Agent-facing prompt:** [`.claude/skills/design/SKILL.md`](../../.claude/skills/design/SKILL.md)

---

## What it does

Manages design system governance, validates the token pipeline, enforces WCAG AA accessibility, gates Phase 3 + Phase 6 with preflight (DS + Figma MCP liveness + **Code Connect write-access**) and pre-merge UI review (ui-audit + node ID validation + **spec ↔ build parity**), auto-builds Figma frames via the Figma MCP (with prompt-fallback when MCP is unreachable), AND maintains the cross-repo Figma↔code bridge via Code Connect (added v4.X+CC, 2026-05-09 → 2026-05-10). After Phase 3 approval the chain auto-generates a visual-build prompt (`/design prompt {feature}` → `docs/prompts/ui/`), then auto-dispatches `/design build {feature}` to push the screens into the FitMe Design System Library, write Figma node IDs back to `state.json`, AND auto-scaffold matching `.figma.{swift,tsx}` Code Connect mapping files via `scripts/scaffold-figma-mapping.{py,mjs}` (Layer B). CI publish workflows then auto-publish those mappings to Figma Dev Mode on merge to main (Layer C, gated on `FIGMA_ACCESS_TOKEN` repo secret in BOTH `Regevba/FitTracker2` and `Regevba/fitme-story`; secret set 2026-05-10).

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
| --- | --- | --- | --- |
| `/design audit` | Design system compliance check | "Check if this PR's UI changes comply with the design system" | Phase 3 (compliance gateway), Phase 6 (Review) |
| **`/design preflight {feature}`** *(v4.X+CC)* | **P0 gate — token/component/pattern existence (delegates to `/ux preflight`) + Figma MCP liveness (`whoami`) + Figma library accessibility (`get_metadata` on `0Ai7s3fCFqR5JXDW8JvgmD`) + Figma library node availability + **Code Connect write-access gate (Step 3.5, v4.X+CC)** — token presence (local env + repo secret in BOTH repos via `gh api`) + publish dry-run probe (catches missing `file_dev_resources:write` scope). Writes `figma-bridge-status.json` (now includes `code_connect_access` block). Spec NOT approvable on P0.** | "Preflight import-training-plan against design system + Figma MCP + Code Connect" | **Phase 3 Step 3f** |
| **`/design pre-merge-review {feature}`** *(v4.X+CC)* | **Phase 6 gate — `make ui-audit` P0=0 + `state.json.figma_node_ids` populated + PR description references those node IDs + **spec ↔ build parity check (Step 3.5, v4.X+CC)** — every spec'd surface has BOTH a Figma node ID AND a `.figma.{swift,tsx}` mapping file (BLOCK on `missing` or `mapping_only`) + optional screenshot diff via Figma MCP. Sets `state.json.pre_merge_review.design` AND `design_parity`. BLOCK halts Phase 7.** | "Pre-merge review on import-training-plan" | **Phase 6 Step 6c** |
| `/design tokens` | Validate token pipeline | "Check if DesignTokens.swift matches tokens.json" | Phase 6 (Review) |
| `/design accessibility` | WCAG AA audit | "Run accessibility audit on the nutrition screens" | Phase 6 (Review) |
| `/design prompt {feature}` | Auto-generate a visual-build prompt in `docs/prompts/ui/{date}-{feature}-design-build.md` once Phase 3 is approved | dispatched by hub after compliance gateway passes | Phase 3 Step 3i |
| **`/design build {feature}`** *(auto-dispatched v4.X+CC)* | **Build Figma screens via Figma MCP with prompt-fallback when MCP is unreachable. Writes captured node IDs back to `state.json.figma_node_ids` AND adds row to `figma-code-sync-status.md` AND auto-invokes `scripts/scaffold-figma-mapping.{py,mjs}` (Layer B, v4.X+CC) to generate `.figma.{swift,tsx}` Code Connect mapping files alongside the matching SwiftUI Views / React components.** | dispatched by hub after `/design prompt` lands; idempotent on re-run | **Phase 3 Step 3j (auto)** |
| `/design ux-spec {feature}` *(DEPRECATED)* | Forwarder — `/ux spec` is canonical | — | (legacy) |
| `/design figma {feature}` *(DEPRECATED)* | Forwarder — `/design build` is canonical | — | (legacy) |

## Shared data

**Reads:**
- `context.json` — brand, personas
- `design-system.json` — current token/component inventory
- `cx-signals.json` — UX confusion signals that imply visual problems
- `.claude/features/{feature}/ux-spec.md` — the handoff from `/ux`
- `.claude/cache/_shared/ux-spec-preflight.json` — `/ux preflight` audit log (v4.X)
- `docs/design-system/figma-code-sync-status.md` — current Figma node mappings (v4.X read; also write target)

**Writes:**
- `design-system.json` — new tokens/components proposed
- `docs/prompts/ui/{date}-{feature}-design-build.md` (from `/design prompt` — folder split established 2026-05-06)
- `.claude/features/{feature}/design-preflight-{date}.md` (from `/design preflight`, v4.X)
- `.claude/features/{feature}/design-pre-merge-review-{date}.md` (from `/design pre-merge-review`, v4.X)
- `.claude/shared/figma-bridge-status.json` (from `/design preflight`, v4.X)
- `state.json.figma_node_ids` (from `/design build`, v4.X)
- `state.json.figma_build_status` (from `/design build`, v4.X)
- `state.json.pre_merge_review.design` (from `/design pre-merge-review`, v4.X)
- `docs/design-system/figma-code-sync-status.md` (from `/design build` — appends matrix row, v4.X)

## PM workflow integration

| Phase | Dispatches |
| --- | --- |
| Phase 3 Step 3f | **`/design preflight {feature}` — DS + Figma MCP + library + node availability check (v4.X)** |
| Phase 3 Step 3g | `/design audit` on the ux-spec → compliance gateway decision (fix / evolve DS / override) |
| Phase 3 Step 3i | `/design prompt {feature}` → `docs/prompts/ui/` (paired with `/ux prompt` → `docs/prompts/ux/`) |
| Phase 3 Step 3j | **`/design build {feature}` — Figma MCP build, fallback to prompt; writes figma_node_ids + sync-status row (v4.X)** |
| Phase 6 Step 6c | **`/design pre-merge-review {feature}` — ui-audit P0=0 + figma_node_ids present + PR description gate (v4.X)** |
| Phase 6 (also) | `/design audit` for visual sign-off + `/design tokens` + `/design accessibility` |

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

---

## v4.0 — External Data + Learning Cache

### Integration Adapters

| Adapter | Type | What It Provides |
| --- | --- | --- |
| figma | MCP (already connected) | Design context, component specs, variable definitions, screenshots, Code Connect mappings |

**Adapter config:** `.claude/integrations/figma/`

All incoming data passes through the **automatic validation gate**:

- GREEN (>= 95%): clean, auto-written
- ORANGE (90-95%): minor discrepancies, written with advisory
- RED (< 90%): blocked, user must resolve

Validation is automatic. Resolution is always manual.

### Learning Cache

**Location:** `.claude/cache/design/`

Caches: token mappings (Figma variables → AppTheme semantic tokens), component selections (which AppComponent was chosen for which design pattern), v2 refactor patterns (recurring structural changes from v1 → v2 audits).

On start: check cache for matching task signature, load learned patterns.
On complete: extract new patterns, write to L1 cache. Flag cross-skill patterns for L2 promotion.
