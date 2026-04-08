# `/ux` — UX Planning & Validation

> **Role in the ecosystem:** The planning layer. Owns user flows, behavior, heuristics, and principle-driven validation. Feeds `/design` (what-to-build → how-it-looks) and `/dev` (what-to-build → how-it's-built). Added 2026-04-07 as the skill that splits the "what & why" concern out of `/design`.

**Agent-facing prompt:** [`.claude/skills/ux/SKILL.md`](../../.claude/skills/ux/SKILL.md)

---

## What it does

Ensures every UI feature is grounded in research-backed UX principles **before** visual design or code implementation begins. `/ux` consumes PRDs and `docs/design-system/ux-foundations.md` (the 13 core + FitMe-specific principles) and produces three artifacts per feature: `ux-research.md`, `ux-spec.md`, and — for refactors — `v2-audit-report.md`. After Phase 3 approval it auto-generates a handoff prompt (`/ux prompt {feature}`) in `docs/prompts/` ready to transfer to a Figma MCP agent or implementation agent.

**Pilot run:** Onboarding v2 UX Foundations alignment pass (PR #59, 2026-04-07). The second feature to use it is `home-today-screen` v2 on this branch.

## Boundary: /ux vs /design

| Concern | `/ux` | `/design` |
|---|---|---|
| **What & Why** | User flows, behavior, heuristics, patterns | — |
| **How it Looks** | — | Tokens, components, Figma, compliance |
| **Research** | Principles, HIG, competitive UX | Market positioning, visual trends |
| **Validation** | Heuristic evaluation, cognitive walkthrough | Token compliance, contrast, motion |
| **Accessibility** | Usability (clarity, cognitive load, feedback) | Technical (WCAG AA, VoiceOver, tap targets) |

**Handoff:** `/ux` produces `ux-research.md` + `ux-spec.md` → `/design` validates against the design system → `/dev` implements.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/ux research {feature}` | UX principle audit from the 13 ux-foundations heuristics (8 core + 5 FitMe-specific) | "Research UX principles for the training plan redesign" | Phase 3 (UX), **Phase 0 for v2 refactors** |
| `/ux spec {feature}` | Generate `ux-spec.md` with Principle Application Table, screen flows, and state coverage | "Create ux-spec for the stats hub" | Phase 3 (UX) |
| `/ux validate {feature}` | Heuristic evaluation of a spec or shipped surface against ux-foundations.md | "Validate the current onboarding flow against Hick's Law" | Phase 3 (UX), Phase 6 (Review) |
| `/ux audit` | Walk a v1 Swift file against ux-foundations.md and produce `v2-audit-report.md` with P0/P1/P2 severity + tractability tags | "Audit MainScreenView.swift for UX Foundations compliance" | **Phase 0 for v2 refactors** |
| `/ux patterns` | Surface existing FitMe interaction patterns for reuse before introducing new ones | "What existing patterns handle a biometric entry flow?" | Phase 3 (UX) |
| `/ux prompt {feature}` | Auto-generate a handoff prompt in `docs/prompts/{date}-{feature}-ux-build.md` once Phase 3 is approved | dispatched by hub after `/ux validate` passes | Phase 3 Step 4 |

## Shared data

**Reads:**
- `context.json` — personas, positioning
- `design-system.json` — current inventory
- `cx-signals.json` — user confusion/friction signals
- `feature-registry.json` — feature status and pain points
- `docs/design-system/ux-foundations.md` — the 13 principles + 10 parts
- `docs/design-system/v2-refactor-checklist.md` — Sections A / E / F / G / H are owned by `/ux`

**Writes:**
- `.claude/features/{feature}/ux-research.md` (from `/ux research`)
- `.claude/features/{feature}/ux-spec.md` (from `/ux spec`)
- `.claude/features/{feature}/v2-audit-report.md` (from `/ux audit` in v2 mode)
- `docs/prompts/{date}-{feature}-ux-build.md` (from `/ux prompt`)

## PM workflow integration

| Phase | Subtype | Dispatches |
|---|---|---|
| Phase 0 (Research) | `v2_refactor` | `/ux audit {feature}` — primary output is `v2-audit-report.md` |
| Phase 0 (Research) | `new_ui` | `/ux research {feature}` from competitive research |
| Phase 3 (UX Definition) | both | `/ux research` → `/ux spec` → `/ux validate` → `/design audit` → `/ux prompt` + `/design prompt` |
| Phase 5 (Testing) | both | `/ux validate` — post-implementation verification |
| Phase 6 (Review) | both | `/ux validate` in parallel with `/design audit` |

### Phase 3 Choreography

**New UI feature (`new_ui`):**
1. `/ux research {feature}` → `ux-research.md`
2. `/ux spec {feature}` → `ux-spec.md`
3. `/ux validate {feature}` → heuristic validation
4. `/design audit` → design system compliance gateway
5. `/ux prompt` + `/design prompt` → handoff prompts in `docs/prompts/`
6. User approval → Phase 4

**V2 refactor (`v2_refactor`):**
1. `/ux audit {feature}` (from Phase 0) → `v2-audit-report.md` already in place
2. `/ux research {feature}` → consolidate audit findings into principles
3. `/ux spec {feature}` → spec for the v2 file (every P0/P1 finding resolved)
4. `/ux validate {feature}` → heuristic re-check
5. `/design audit` → compliance gateway
6. Tick Section A of `v2-refactor-checklist.md`
7. `/ux prompt` + `/design prompt` → handoff prompts
8. User approval → Phase 4 (build v2 file in `v2/` subdirectory per the V2 Rule)

## Upstream / Downstream

- **Upstream (who feeds `/ux`):**
  - `/research` — competitive UX patterns and HIG references
  - `/cx` — UX confusion signals from shipped features
  - `/pm-workflow` — approved PRDs at Phase 3 entry

- **Downstream (who consumes `/ux` output):**
  - `/design` — ux-spec.md is the input to design audit + figma automation
  - `/dev` — the Principle Application Table becomes acceptance criteria
  - `/pm-workflow` — gates Phase 3 advance (non-skippable for new UI features)

## Standalone usage examples

1. **Audit an existing screen before refactor:** `/ux audit` → "Audit `MainScreenView.swift` against `ux-foundations.md` and produce severity-graded findings for the v2 pass"
2. **Research principles for a new feature:** `/ux research barcode-scanning` → identifies which of the 13 principles apply, cites HIG sources, flags risks
3. **Generate a ux-spec:** `/ux spec stats-hub-v2` → creates `ux-spec.md` with Principle Application Table + 5-state coverage + a11y
4. **Validate a shipped surface:** `/ux validate settings` → heuristic evaluation with concrete fix suggestions
5. **Find existing patterns:** `/ux patterns` → "Is there an existing inline-edit pattern I should reuse?"

## Key references

- [`docs/design-system/ux-foundations.md`](../design-system/ux-foundations.md) — the 13 principles + IA + states + a11y + motion + content strategy
- [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — Sections A/E/F/G/H are owned by `/ux`
- [`docs/design-system/feature-development-gateway.md`](../design-system/feature-development-gateway.md) — the 7-stage workflow `/ux` walks
- [`docs/design-system/feature-design-checklist.md`](../design-system/feature-design-checklist.md) — per-feature design checklist
- [`CLAUDE.md`](../../CLAUDE.md) → "UI Refactoring & V2 Rule" — file convention for v2 refactors
- Apple Human Interface Guidelines — external reference for iOS platform conventions

## Related documents

- [README.md](README.md) — ecosystem one-pager
- [architecture.md](architecture.md) — full ecosystem deep-dive (§7.5)
- [design.md](design.md) — handoff partner for visual work
- [pm-workflow.md](pm-workflow.md) — hub skill that dispatches `/ux`
- [`.claude/skills/ux/SKILL.md`](../../.claude/skills/ux/SKILL.md) — agent-facing prompt
