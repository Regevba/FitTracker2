# UX & UI Build Prompts

> Collection of all handoff prompts used to brief other agents (Figma MCP, SwiftUI implementation agents, audit agents) on UX and UI build work for FitMe. Kept in one folder so we can review them, track what was sent where, and iterate on the prompt templates.

---

## What goes here

This folder contains:

1. **Hand-authored prompts** used historically to build FitMe's UI (Figma prototypes, iteration 2 screens, prototype audits, onboarding v2 screens, UX foundations deep dive).
2. **Auto-generated prompts** produced by `/ux prompt {feature}` and `/design prompt {feature}` once Phase 3 of the PM workflow is approved. These are the contemporary path — every new feature in Phase 3 onward generates its own pair of prompts here.
3. **Setup guides** for the MCP servers that run these prompts (Figma MCP automation guide).

## Naming convention

| Type | Pattern | Example |
|---|---|---|
| Auto-generated UX prompt | `{YYYY-MM-DD}-{feature}-ux-build.md` | `2026-04-15-training-plan-v2-ux-build.md` |
| Auto-generated design prompt | `{YYYY-MM-DD}-{feature}-design-build.md` | `2026-04-15-training-plan-v2-design-build.md` |
| Hand-authored Figma prompt | `figma-{purpose}.md` | `figma-prototype-prompt.md` |
| Hand-authored iteration batch | `iteration-{n}-{purpose}.md` | `iteration-2-master-prompt.md` |
| MCP setup | `{tool}-{guide}.md` | `figma-mcp-automation-guide.md` |

The auto-generated prompts always come in pairs — `/ux prompt` and `/design prompt` both write files with matching filename prefixes so the receiving agent can read them together. See `/ux prompt` in [`../skills/ux.md`](../skills/ux.md) and `/design prompt` in [`../skills/design.md`](../skills/design.md) for the generation contract.

## Current contents

### Auto-generated (pm-workflow Phase 3 output)

*None yet* — the `/ux prompt` and `/design prompt` sub-commands were added 2026-04-08. The first features to use them will be `home-today-screen` v2 and the subsequent per-screen UX alignment passes.

### Hand-authored prompts (pre-automation)

| File | Purpose | Used for |
|---|---|---|
| `figma-runner-prompt.md` | Generic Figma MCP runner prompt template | Any Figma build task |
| `figma-prototype-prompt.md` | Full-app Figma prototype build | Iteration 1 28-screen prototype |
| `figma-prototype-audit-prompt.md` | Figma prototype audit prompt | Reviewing existing Figma work |
| `iteration-2-master-prompt.md` | Iteration 2 20-screen master prompt | Iteration 2 redesign |
| `iteration-2-figma-prompts.md` | Iteration 2 section-by-section prompts | Iteration 2 section batches |
| `figma-onboarding-v2-prompt.md` | Onboarding v2 Figma build prompt | Onboarding v2 pilot (PR #59) |
| `figma-ux-foundations-prompt.md` | UX Foundations section build prompt | `ux-foundations.md` Figma companion |
| `figma-mcp-automation-guide.md` | Figma MCP setup + automation notes | Ops / dev reference |

## Why this folder exists

Before 2026-04-08 these prompts were scattered across `docs/project/` and `docs/design-system/` with no clear naming or discoverability. After adding `/ux prompt` and `/design prompt` to the skills ecosystem, we needed a single place where:

- The auto-generated prompts could land deterministically
- The hand-authored historical prompts could be reviewed as references for the auto-generation templates
- The team could see what's been sent to other agents without hunting through multiple folders

## How to use a prompt from here

1. Open the prompt file
2. Read the "target agent" header to see which MCP / skill / Claude Console profile it's meant for
3. Copy the prompt body (everything below the metadata block)
4. Paste into the target agent's interface
5. Wait for the receiving agent to produce its output (Figma nodes, Swift code, screenshots)
6. Log the result back into the feature's `state.json` under `phases.ux_or_integration.handoff_results`

## Related documents

- [`../skills/ux.md`](../skills/ux.md) — `/ux prompt` sub-command contract
- [`../skills/design.md`](../skills/design.md) — `/design prompt` sub-command contract
- [`../skills/pm-workflow.md`](../skills/pm-workflow.md) — Phase 3 dispatch chain that triggers auto-generation
- [`../design-system/ux-foundations.md`](../design-system/ux-foundations.md) — the 13 UX principles every prompt references
- [`../design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — the checklist every v2 refactor prompt must include
