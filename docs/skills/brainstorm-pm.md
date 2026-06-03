# `/brainstorm-pm` — Product Brainstorming Partner

> **Role in the ecosystem:** The problem-framing layer. Default Phase 0 entry point for `/pm-workflow` whenever the problem shape isn't obvious. Expands the option space (problem framings, candidate solutions, assumptions, strategic angles) BEFORE the user commits.

**Agent-facing prompt:** [`.claude/skills/brainstorm-pm/SKILL.md`](../../.claude/skills/brainstorm-pm/SKILL.md)

---

## What it does

PM-flavored brainstorming with 4 modes (problem / solution / assumption / strategy), **1 trade-off mode (three-option, added 2026-06-03)**, and 4 frameworks (HMW / JTBD / First Principles / OST). Every output is reducible to a PRD section: problem statement, success metric, kill criterion, JTBD statement, opportunity branch, or alternatives-considered matrix.

Distinct from [`superpowers:brainstorming`](https://github.com/anthropics/superpowers) — that one is for generic creative work (naming, copywriting, essays). `/brainstorm-pm` is for product decisions that will land in a PRD.

## Sub-commands (modes)

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/brainstorm-pm problem` | Surface 3–5 problem framings at different abstraction levels | "Add a streak counter" → derive the actual behavioral problem | Phase 0 (Research) |
| `/brainstorm-pm solution` | Generate 5–8 RICE-light scored candidates including "do nothing" baseline | Problem locked, solution unclear | Phase 0 → Phase 1 (PRD) |
| `/brainstorm-pm assumption` | Surface user / behavior / market / technical / resource assumptions and classify (Validated / Plausible / Speculative / Unknown) | Feature picked but the bet is unproven | Phase 0 (Research) |
| `/brainstorm-pm strategy` | Three-question frame: why this / why now / why not the alternative | RICE > 3.0 feature needs strategic justification | Pre-Phase 0 prioritization |
| `/brainstorm-pm three-option` | Produce a 3-option trade-off matrix across UX / Design / Dev dimensions for a scoped problem with multiple viable implementation paths. NO ranking — user picks. | "Build this 3 different ways and lay out the trade-offs" | Phase 0 (Research) → Phase 1 (PRD §Alternatives considered) |

## When to use vs. `superpowers:brainstorming`

| Situation | Skill |
|---|---|
| "We need to ship X" with no PRD, no metric, no real problem statement | `/brainstorm-pm` (problem mode) |
| "Should we build A or B?" between candidate solutions | `/brainstorm-pm` (solution mode) |
| "I'm worried we're betting on something untrue" | `/brainstorm-pm` (assumption mode) |
| "Why are we doing this now and not the alternative?" | `/brainstorm-pm` (strategy mode) |
| Naming a feature, drafting marketing copy, essay-style writing | `superpowers:brainstorming` |

If unsure, start with `/brainstorm-pm problem` — wrong-skill cost is one re-route; under-triggering cost is shipping a feature on no real problem.

## Frameworks applied per mode

- **HMW (How Might We)** — reframe a stated want as an opportunity question, used in problem + solution modes.
- **JTBD (Jobs To Be Done)** — uncover the underlying need behind a stated behavior, used in problem + assumption modes.
- **First Principles** — strip a candidate solution back to its load-bearing assumptions, used in assumption + strategy modes.
- **OST (Opportunity Solution Tree)** — branch from outcome → opportunities → solutions → experiments, used in strategy mode.

## Shared data

**Reads:** `context.json` (positioning, personas), `feature-registry.json` (active features and their phase), `cx-signals.json` (CX-surfaced problems), `case-study-monitoring.json` (kill criteria from prior features for pattern transfer).

**Writes:** `state.json::brainstorm` block on the active feature — `problem_alternatives`, `solution_alternatives`, `assumption_map`, `strategy_frame`, `three_option_matrix`. Each becomes a PRD source citation downstream.

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Pre-Phase 0 | `/brainstorm-pm strategy` for RICE > 3.0 candidates surfacing during `/pm-workflow roadmap` |
| Phase 0 (Research & Discovery) | Default entry point — auto-dispatched by `/pm-workflow {feature-name}` when the new feature's `state.json::problem_statement` is empty or low-confidence |
| Phase 1 (PRD) | `/brainstorm-pm assumption` re-run after PRD draft to stress-test load-bearing claims |

## Upstream / Downstream

- **Hands off to** `/research` once the problem framing is locked and the funnel-style external scan is needed.
- **Reads from** `/cx` — surfaced user-reported pain becomes input to problem mode.
- **Feeds** `/pm-workflow` Phase 1 (PRD) directly; the `state.json::brainstorm` block becomes PRD source-citations.
- **Reads from** `/marketing` — competitive positioning context informs strategy mode.

## Standalone usage examples

1. **No-PRD start:** `/brainstorm-pm problem` on "we should add a workout AI coach" → surfaces that the actual user-stated problem is "I don't know what to do next" → reframes as a recommendation problem (cheaper) before AI scope is locked.
2. **Solution comparison:** `/brainstorm-pm solution` on "improve onboarding completion" → 5 candidates from "do nothing + measure" → "AI-personalized first session" → user picks medium-RICE option with a 4-week kill criterion.
3. **Assumption pressure-test:** `/brainstorm-pm assumption` on a paused feature about to resume → surfaces 3 Speculative-tier assumptions that became Validated via a 1-day analytics probe → unblocks Phase 1.
4. **Three-option trade-off matrix:** `/brainstorm-pm three-option` on "add a stats expansion for richer recovery insights" → 3 options on the compute axis (in-app summarization / cloud LLM / hybrid prefetch) each with UX / Design / Dev rows + deferred-to-v2 column + failure modes. User picks; mid-tier option drops into PRD §Alternatives considered.

## Recent usage

- **2026-06-03** — added Three-Option Trade-Off Mode as a 5th mode. Backlog row authored 2026-05-28 (drafted on `save/r9-dirty-2026-05-28`, preserved into main 2026-06-03 via PR #592). Addresses the convergence-too-fast pattern previously observed: PRD candidates landing with one solution path and zero documented alternatives, losing the cheap-but-real audit-trail value of having ≥2 abandoned alternatives in the case study.
- **First production use 2026-05-13** during the skills-review execution sweep — shipped as part of FT2 PR #350. The skill formalizes a brainstorming pattern previously embedded inside `/pm-workflow` Phase 0; extracting it to a dedicated skill made the protocol reusable outside the full lifecycle.

## Key references

- [`.claude/integrity/observed-patterns.md`](../../.claude/integrity/observed-patterns.md) — preflight mandatory before any brainstorm output that ships into a PRD or case study (W2, W6, #17 most relevant)
- [`.claude/shared/case-study-monitoring.json`](../../.claude/shared/case-study-monitoring.json) — past feature kill criteria, used as reference data when proposing new ones
- [`docs/product/PRD.md`](../product/PRD.md) — PRD template that brainstorm output drops into

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md)
- [pm-workflow.md](pm-workflow.md) — primary consumer
- [research.md](research.md) — downstream sibling in Phase 0
- [`.claude/skills/brainstorm-pm/SKILL.md`](../../.claude/skills/brainstorm-pm/SKILL.md) — agent-facing prompt
