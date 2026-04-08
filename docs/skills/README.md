# FitMe Skills Ecosystem — One-pager

**Goal:** Give every domain of the product lifecycle its own first-class skill, so product management scales past a monolithic workflow without losing the connective tissue between domains.

**Why it exists:** v1 of `/pm-workflow` did everything inline — research, PRDs, UX specs, code review, testing, deployment, docs all in one file. Adding a new domain meant bloating it; using a design audit or analytics validation meant running the whole pipeline. The ecosystem replaces that monolith with a **hub-and-spoke architecture**: 1 hub + 10 spokes + 8 shared data files. Every skill is a **Lego piece** (works alone on a single task) AND a **puzzle piece** (fits into the hub's 10-phase lifecycle).

**Where to read more:** `docs/skills/{name}.md` for deep dives on each skill. The `SKILL.md` files under `.claude/skills/{name}/` are the agent-facing prompts the harness executes; the `docs/skills/` folder is the human-facing reference.

---

## The 11 skills

| # | Skill | One-liner | Phase it owns |
|---|---|---|---|
| 0 | [`/pm-workflow`](pm-workflow.md) | **The hub.** Orchestrates the 10-phase lifecycle and dispatches the other 10 skills at the right moments. | All phases (dispatch) |
| 1 | [`/ux`](ux.md) | **What & Why.** UX research, principles, specs, v2 audits. Feeds `/design` and `/dev`. | Phase 0 (v2) + Phase 3 + Phase 6 |
| 2 | [`/design`](design.md) | **How it Looks.** Design system governance, Figma automation, token pipeline, WCAG AA. | Phase 3 + Phase 6 |
| 3 | [`/dev`](dev.md) | **How it's Built.** Branching, code review, CI, dependencies, performance. | Phase 4 + Phase 6 + Phase 7 |
| 4 | [`/qa`](qa.md) | **Does it Work.** Test planning, coverage, regression, security. | Phase 5 |
| 5 | [`/analytics`](analytics.md) | **Can We Measure It.** Event taxonomy, instrumentation, dashboards, funnels. | Phase 1 + Phase 5 + Phase 8 |
| 6 | [`/cx`](cx.md) | **What Users Say.** Reviews, NPS, sentiment, post-deployment analysis, feedback loops. | Phase 0 + Phase 8 + Phase 9 |
| 7 | [`/marketing`](marketing.md) | **How We Tell the World.** ASO, campaigns, content, email, launch comms. | Phase 0 + Phase 8 |
| 8 | [`/research`](research.md) | **What's Out There.** Cross-industry → same-category → feature-specific research funnel. | Phase 0 |
| 9 | [`/ops`](ops.md) | **Is It Up.** Infrastructure monitoring, incidents, cost, alerting. | Cross-phase |
| 10 | [`/release`](release.md) | **Is It Ready.** Version bumps, changelogs, TestFlight, App Store submission. | Phase 7 |

**Added history:**
- 2026-04-02 — ecosystem v1 shipped with 10 skills (no `/ux`)
- 2026-04-07 — `/ux` added (PR #59), split from `/design` to own the "what & why" layer. Pilot run: Onboarding v2 UX Foundations alignment pass

---

## The 8 shared data files

Located under `.claude/shared/`:

| File | Purpose | Primary owner |
|---|---|---|
| `context.json` | Product identity, personas, brand, guardrails | `/pm-workflow` + `/research` |
| `feature-registry.json` | All 16 features with status + metrics + pain points | `/pm-workflow` |
| `metric-status.json` | 40 metrics with targets + instrumentation status | `/analytics` |
| `design-system.json` | Tokens, components, accessibility, Android mapping | `/design` |
| `test-coverage.json` | Test suites, gaps, guardrail gates | `/qa` |
| `cx-signals.json` | Reviews, NPS, sentiment, keyword patterns | `/cx` |
| `campaign-tracker.json` | Campaigns, UTM convention, channels, attribution | `/marketing` |
| `health-status.json` | Infrastructure services, CI, incidents, cost | `/ops` |

Every skill reads `context.json` on startup. Most skills write to one primary file and read from the others for context.

---

## How they connect — Flow Chart

```
                   ┌─────────────┐
                   │  WEB SEARCH  │
                   │  APP STORES  │
                   │ INDUSTRY DATA│
                   └──────┬──────┘
                          │
                          ▼
                   ┌─────────────┐
                   │  /research   │  ← teardowns, HIG, competitive intel
                   └──────┬──────┘
                          │
                          ▼
                   ┌────────────────────────┐
                   │  /pm-workflow (HUB)     │
                   │  10-phase lifecycle     │
                   │  reads/writes shared/*  │
                   └──┬──────┬──────┬──────┬─┘
                      │      │      │      │
     ┌────────────────┘      │      │      └──────────────┐
     │       (Phase 0 v2)    │      │  (Phase 4-7)        │
     │                       │      │                      │
     ▼                       ▼      ▼                      ▼
  ┌──────┐              ┌─────────┐ ┌──────────┐       ┌─────────┐
  │ /ux  │─ux-spec.md──▶│ /design │ │   /dev   │──────▶│ /release │
  │      │              │         │ │          │       │         │
  │ what │              │  how it │ │ how it's │       │ ship it │
  │ & why│              │  looks  │ │  built   │       │         │
  └──┬───┘              └────┬────┘ └────┬─────┘       └────┬────┘
     │                       │            │                  │
     │       ┌───────────────┘            ▼                  │
     │       │                       ┌────────┐              │
     │       │                       │  /qa   │              │
     │       │                       │ does   │              │
     │       │                       │ it work│              │
     │       │                       └────┬───┘              │
     │       │                            │                  │
     │       ▼                            ▼                  ▼
     │   ┌─────────────┐             App Build         App Store
     │   │ /analytics  │
     │   │ can we      │
     │   │ measure it  │
     │   └──────┬──────┘
     │          │
     └──────────┴──┐
                   │
                   ▼
          ┌──────────────┐
          │  Post-Launch  │
          └──────┬───────┘
                 │
       ┌─────────┼─────────┐
       │         │         │
       ▼         ▼         ▼
    ┌────┐  ┌──────────┐ ┌─────┐
    │/cx │  │/marketing│ │/ops │
    │what│  │   tell   │ │ is  │
    │users│  │the world│ │ up? │
    │ say│  └────┬─────┘ └──┬──┘
    └─┬──┘       │          │
      │          │          │
      └────┬─────┴──────────┘
           │
           ▼ feedback loop
     /pm-workflow ◄─── next cycle
      (back to hub)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    SHARED DATA LAYER (.claude/shared/*.json)

    context.json · feature-registry.json · metric-status.json
    design-system.json · test-coverage.json · cx-signals.json
    campaign-tracker.json · health-status.json
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Key connections:**

- **`/ux` → `/design`** — `ux-spec.md` is the handoff. `/ux` owns what and why; `/design` owns how it looks.
- **`/research` → `/ux`** — competitive UX patterns and HIG references flow from research into UX planning.
- **`/design` → `/dev`** — token pipeline (`design-system.json`) is the contract between designed components and coded components.
- **`/analytics` → `/qa`** — analytics tests go in the same test suite as functional tests; one CI gate validates both.
- **`/cx` → back to `/pm-workflow`** — post-deployment feedback closes the loop. Root cause classification (messaging / UX / functionality / expectation) dispatches a new work item to the appropriate skill.

---

## Where each skill sits in the PM workflow

```
Phase 0  Research  ─────▶ /research (new feat) OR /ux audit (v2 refactor) · /cx (pain points)
Phase 1  PRD       ─────▶ /analytics spec (instrumentation plan)
Phase 2  Tasks     ─────▶ /pm-workflow (internal — no dispatch)
Phase 3  UX/Integ  ─────▶ /ux research → /ux spec → /ux validate → /design audit
Phase 4  Implement ─────▶ /dev branch · parallel task dispatch to {skill}
Phase 5  Test      ─────▶ /qa plan · /qa run · /analytics validate · /ux validate
Phase 6  Review    ─────▶ /dev review · /design audit · /ux validate
Phase 7  Merge     ─────▶ /release checklist · /analytics regression
Phase 8  Docs      ─────▶ /marketing launch · /analytics dashboard
Phase 9  Learn     ─────▶ /cx analyze · /analytics report · root cause dispatch
```

The hub never does inline work — it reads state, decides which skill to dispatch, and waits for the user to approve each phase transition.

---

## Rules that apply to every skill

1. **Every skill is standalone.** You can invoke any skill directly (`/design audit`, `/qa run`, `/cx analyze`) without running a full PM workflow.
2. **Every skill is composable.** The hub can chain skills together for a full lifecycle.
3. **Every skill has clear boundaries.** Docs describe what it does AND what it doesn't.
4. **Every skill writes to at most one shared file.** Reads from many.
5. **No skill auto-advances.** User approves every phase transition.
6. **Change broadcasts.** When a work item completes, `/pm-workflow` writes to `change-log.json` and notifies downstream skills so the system stays aware.

---

## Related documents

- [`.claude/skills/{name}/SKILL.md`](../../.claude/skills/) — agent-facing prompts the harness executes when a skill is invoked
- [`docs/project/skills-ecosystem.md`](../project/skills-ecosystem.md) — the original long-form ecosystem doc (~1200 lines, kept as historical deep-dive; the per-skill docs here are the current source of truth)
- [`docs/design-system/ux-foundations.md`](../design-system/ux-foundations.md) — the 13 UX principles `/ux` references
- [`docs/design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — the checklist that every V2 refactor walks through
- [`CLAUDE.md`](../../CLAUDE.md) — project rules, including the UI Refactoring & V2 Rule
