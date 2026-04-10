# FitMe Skills Ecosystem — One-pager

**Goal:** Give every domain of the product lifecycle its own first-class skill, so product management scales past a monolithic workflow without losing the connective tissue between domains.

**Why it exists:** v1 of `/pm-workflow` did everything inline — research, PRDs, UX specs, code review, testing, deployment, docs all in one file. Adding a new domain meant bloating it; using a design audit or analytics validation meant running the whole pipeline. The ecosystem replaces that monolith with a **hub-and-spoke architecture**: 1 hub + 11 spokes + 11 shared data files + 6 integration adapters + 3-level learning cache + self-healing health check system. Every skill is a **Lego piece** (works alone on a single task) AND a **puzzle piece** (fits into the hub's 10-phase lifecycle).

**Where to read more:** `docs/skills/{name}.md` for deep dives on each skill. The `SKILL.md` files under `.claude/skills/{name}/` are the agent-facing prompts the harness executes; the `docs/skills/` folder is the human-facing reference.

---

## The 12 skills (1 hub + 11 spokes)

| # | Skill | One-liner | Sub-commands | Phase it owns |
| --- | --- | --- | --- | --- |
| 0 | [`/pm-workflow`](pm-workflow.md) | **The hub.** Orchestrates the 9-phase lifecycle, dispatches 11 spokes, syncs external tools. | `{feature-name}` | All phases (dispatch) |
| 1 | [`/ux`](ux.md) | **What & Why.** UX research, principles, specs, wireframes, v2 audits. | `research`, `spec`, `wireframe`, `validate`, `audit`, `patterns`, `prompt` | Phase 0 (v2) + Phase 3 + Phase 6 |
| 2 | [`/design`](design.md) | **How it Looks.** Design system governance, Figma MCP builds, token pipeline, WCAG AA. | `audit`, `ux-spec`, `figma`, `tokens`, `accessibility`, `prompt`, `build` | Phase 3 + Phase 6 |
| 3 | [`/dev`](dev.md) | **How it's Built.** Branching, code review, CI, dependencies, performance. | `branch`, `review`, `deps`, `perf`, `ci-status` | Phase 4 + Phase 6 + Phase 7 |
| 4 | [`/qa`](qa.md) | **Does it Work.** Test planning, coverage, regression, security. | `plan`, `run`, `coverage`, `regression`, `security` | Phase 5 |
| 5 | [`/analytics`](analytics.md) | **Can We Measure It.** Event taxonomy, instrumentation, dashboards, funnels. | `spec`, `validate`, `dashboard`, `report`, `funnel` | Phase 1 + Phase 5 + Phase 8 |
| 6 | [`/cx`](cx.md) | **What Users Say.** Reviews, NPS, sentiment, post-deployment analysis, feedback loops. | `reviews`, `nps`, `sentiment`, `testimonials`, `roadmap`, `digest`, `analyze` | Phase 0 + Phase 8 + Phase 9 |
| 7 | [`/marketing`](marketing.md) | **How We Tell the World.** ASO, campaigns, content, email, launch comms. | `aso`, `campaign`, `competitive`, `content`, `email`, `launch`, `screenshots` | Phase 0 + Phase 8 |
| 8 | [`/research`](research.md) | **What's Out There.** Cross-industry → same-category → feature-specific research funnel. | `wide`, `narrow`, `feature`, `competitive`, `market`, `ux-patterns`, `aso` | Phase 0 |
| 9 | [`/ops`](ops.md) | **Is It Up.** Infrastructure monitoring, incidents, cost, alerting. | `health`, `incident`, `cost`, `alerts` | Cross-phase |
| 10 | [`/release`](release.md) | **Is It Ready.** Version bumps, changelogs, TestFlight, App Store submission. | `prepare`, `checklist`, `notes`, `submit` | Phase 7 |

**Evolution history:**

- 2026-04-02 — ecosystem v1 shipped with 10 skills (no `/ux`)
- 2026-04-07 — `/ux` added (PR #59), split from `/design` to own the "what & why" layer. Pilot run: Onboarding v2 UX Foundations alignment pass
- 2026-04-08 — screen audit research mode (`/ux audit`), v2 refactor subtype, sub-feature queue pattern
- 2026-04-09 — v3.0: external integrations (Notion MCP, Figma MCP, Vercel), `/ux wireframe`, `/design build`, parallel subagent execution, 5 features shipped through the full lifecycle
- 2026-04-10 — v4.0: reactive data mesh, integration adapter layer (6 adapters), automatic validation gate (GREEN/ORANGE/RED), L1/L2/L3 learning cache, per-skill cache + external data source sections in all SKILL.md files
- 2026-04-10 — v4.1: Skill Internal Lifecycle (Cache Check → Research → Execute → Learn). Every skill mirrors the hub internally — 4-phase lifecycle with domain-specific research scope. Skills learn from prior executions and get faster over time.
- 2026-04-10 — v4.2: Self-healing hub. Phase 0 (Health Check) added to Skill Internal Lifecycle — 5 weighted integrity checks at random intervals verify cache staleness, hit accuracy, shared layer consistency, routing integrity, and adapter availability. Alert if score drops below 90%. L1 cache seeded from 6 completed refactors. All 11 SKILL.md files wired with cache protocol, adapters, and research scope.

---

## The 11 shared data files

Located under `.claude/shared/`:

| File | Purpose | Primary owner |
| --- | --- | --- |
| `context.json` | Product identity, personas, brand, guardrails | `/pm-workflow` + `/research` |
| `feature-registry.json` | All 16 features with status + metrics + pain points | `/pm-workflow` |
| `metric-status.json` | 40 metrics with targets + instrumentation status | `/analytics` |
| `design-system.json` | Tokens, components, accessibility, Android mapping | `/design` |
| `test-coverage.json` | Test suites, gaps, guardrail gates | `/qa` |
| `cx-signals.json` | Reviews, NPS, sentiment, keyword patterns | `/cx` |
| `campaign-tracker.json` | Campaigns, UTM convention, channels, attribution | `/marketing` |
| `health-status.json` | Infrastructure services, CI, incidents, cost | `/ops` |
| `skill-routing.json` | Task→skill mapping + integration sources + validation gate config | `/pm-workflow` |
| `task-queue.json` | Pending work items and priority queue | `/pm-workflow` |
| `change-log.json` | Audit trail + validation log entries | `/pm-workflow` |

Every skill reads `context.json` on startup. Most skills write to one primary file and read from the others for context.

---

## External integrations

### Existing (v3.0)

| Integration | Protocol | Direction | What it does |
| --- | --- | --- | --- |
| **GitHub** | `gh` CLI | Bidirectional | Issue labels, PR management, CI status, milestone tracking |
| **Notion MCP** | Model Context Protocol | Bidirectional | Project board sync — phase transitions push status updates automatically |
| **Figma MCP** | Model Context Protocol | Read + Write | Design context retrieval, screenshot capture, code connect, design-to-code builds |
| **Vercel** | Deploy preview | Read | Preview URLs attached to PRs for visual review |

### New (v4.0) — Integration Adapters

Each adapter lives in `.claude/integrations/{service}/` with `adapter.md` + `schema.json` + `mapping.json`. All data passes through the **automatic validation gate** before entering the shared layer.

| Adapter | MCP Package | Consuming Skills | Shared Layer Target |
| --- | --- | --- | --- |
| **GA4** | `mcp-server-ga4` | /analytics, /pm-workflow, /cx | metric-status.json |
| **App Store Connect** | `asc-mcp` (208 tools) | /cx, /release, /marketing | cx-signals.json, feature-registry.json |
| **Sentry** | `mcp.sentry.dev` | /ops, /cx, /qa | health-status.json, cx-signals.json |
| **Firecrawl** | `firecrawl-mcp` | /research, /marketing | context.json, feature-registry.json |
| **Axe** | `@anthropic-ai/mcp-axe` | /ux, /qa, /design | design-system.json, test-coverage.json |
| **Security Audit** | `mcp-security-audit` | /dev, /ops, /qa | health-status.json, test-coverage.json |

### Validation Gate

All incoming external data is automatically cross-referenced against existing shared layer state:

- **GREEN (>= 95%)** — Data is clean. Write + notify receiving skill and hub.
- **ORANGE (90-95%)** — Minor discrepancies. Write + advisory. Review when convenient.
- **RED (< 90%)** — Significant contradictions. DO NOT write. User must resolve.

Validation is automatic. Resolution is always manual.

---

## Learning Cache

Located under `.claude/cache/`:

| Level | Location | Scope | Promotion |
| --- | --- | --- | --- |
| **L1** | `.claude/cache/{skill}/` | Per-skill patterns and decisions | Default home |
| **L2** | `.claude/cache/_shared/` | Cross-skill patterns (2+ skills share) | Promoted from L1 |
| **L3** | `.claude/cache/_project/` | Project-wide architectural conventions | Promoted from L2 (5+ skills) |

Cache entries store: task signatures, learned patterns, anti-patterns, and speedup instructions. Staleness is tracked via SHA256 hashes of source files. Demonstrated ~65% speedup by 4th similar task (e.g., applying UX foundations across screens).

---

## What's been built (as of 2026-04-10)

**8 features shipped through the full PM lifecycle (all 6 screens v2 aligned):**

| Feature | PR | Type | Key artifact |
| --- | --- | --- | --- |
| Home Today Screen v2 | #61 | Feature (v2_refactor) | 27-finding audit, v2/ convention at scale |
| Onboarding retro | #63 | Enhancement | Retroactive v2 alignment of pilot feature |
| Body Composition card | #65 | Enhancement | Reusable metric tile drill-down pattern |
| Metric Deep Link | #67 | Enhancement | Home tile → detail view deep navigation |
| Training Plan v2 | #74 | Feature (v2_refactor) | 533-line container + 6 extracted views, 12 events, 16 tests |
| Nutrition v2 | #75 | Feature (v2_refactor) | ProgressBar component, AppOpacity enum, 5 events, 7 tests |
| Stats v2 | #76 | Feature (v2_refactor) | AppLayout enum, chart a11y, 4 events, 6 tests |
| Settings v2 | #77 | Feature (v2_refactor) | Color tokenization, destructive action a11y, 3 events, 5 tests |

**Ecosystem capabilities validated:**

- **All 6 main screens v2 aligned** — Onboarding, Home, Training, Nutrition, Stats, Settings all pass UX Foundations
- **119 audit findings** fixed across 6 screens (from v2-audit-report.md)
- **33 screen-prefixed analytics events** instrumented (`home_*`, `training_*`, `nutrition_*`, `stats_*`, `settings_*`, `onboarding_*`)
- **60+ analytics tests** across 6 test files validating instrumentation
- **Screen audit workflow** — `/ux audit` produces `v2-audit-report.md` with numbered findings + decisions log before code
- **Sub-feature queue** — parent audit (Home v2) spawned 4 child features, each tracked independently
- **Parallel subagent execution** — independent tasks dispatched to multiple skills simultaneously, converging at review gates
- **Learning cache validated** — Nutrition v2 (4th refactor) completed research→implementation in ~2h vs Home v2 (1st) at ~36h
- **v4.1 Skill Internal Lifecycle** — Cache Check → Research → Execute → Learn validated across 3 refactors

---

## How they connect — Flow Chart

```text
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

```text
Phase 0  Research  ─────▶ /research (new feat) OR /ux audit (v2 refactor / screen scope) · /cx (pain points)
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
7. **Every skill follows the 4-phase internal lifecycle.** Cache Check → Research (if miss) → Execute → Learn. Skills mirror the hub's structure internally.
8. **Every skill declares its external data sources.** Adapters, shared layer targets, and validation gate behavior documented in each SKILL.md.
9. **Every skill has a domain-specific research scope.** 5 research dimensions + source priority order. When cache misses, the skill knows exactly what to investigate.
10. **Data flows reactively.** Any entry point, any time. A single skill invocation can ripple through the entire shared layer.
11. **Every skill runs Phase 0 (Health Check) on random trigger.** ~25% probability with 2h cooldown. 5 weighted checks verify cache, shared layer, routing, and adapter integrity. If score < 90%, execution halts until resolved.

---

## Related documents

- [`architecture.md`](architecture.md) — full ecosystem deep-dive (~1400 lines). Covers the hub-and-spoke architecture, shared data layer, per-skill sections, connection map, feature review, and a merged-in gap analysis snapshot from 2026-04-04 with current deltas.
- [`evolution.md`](evolution.md) — history of how the ecosystem evolved from `/pm-workflow` v1.0 (monolith) → v1.2 (shared data) → v2.0 (hub-and-spoke) → v3.0 (external integrations + screen audits + parallel execution) → v4.1 (reactive data mesh + learning cache + validation gate + skill internal lifecycle). Useful context for understanding why the current architecture looks the way it does.
- [`pm-workflow.md`](pm-workflow.md) — hub skill deep-dive
- [`.claude/skills/{name}/SKILL.md`](../../.claude/skills/) — agent-facing prompts the harness executes when a skill is invoked
- [`../design-system/ux-foundations.md`](../design-system/ux-foundations.md) — the 13 UX principles `/ux` references
- [`../design-system/v2-refactor-checklist.md`](../design-system/v2-refactor-checklist.md) — the checklist that every V2 refactor walks through
- [`../case-studies/`](../case-studies/) — concrete examples of the PM workflow running on real features
- [`../case-studies/pm-workflow-evolution-v1-to-v4.md`](../case-studies/pm-workflow-evolution-v1-to-v4.md) — comprehensive case study: PM hub evolution v1.0 → v4.1 with measurable efficiency data across 6 screen refactors
- [`../../CLAUDE.md`](../../CLAUDE.md) — project rules, including the UI Refactoring & V2 Rule
