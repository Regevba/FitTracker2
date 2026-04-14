# FitMe Skills Ecosystem — Architecture One-Pager

> **Version:** 5.1 | **Updated:** 2026-04-14
>
> Quick-reference system schematics and information flow for the entire PM-flow ecosystem.
> For the full deep-dive (per-skill sub-commands, shared data field descriptions, gap analysis, design decisions, evolution history), see [architecture.md](architecture.md).

---

## 1. Top-Level System Diagram (v5.0)

```
╔══════════════════════════════════════════════════════════════╗
║              EXTERNAL SERVICES (MCPs / APIs)                ║
║  GA4 │ App Store Connect │ Sentry │ Firecrawl │ Axe │ ...  ║
║  Linear │ Notion │ Figma │ GitHub │ Xcode │ Fastlane       ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
                             ▼
╔══════════════════════════════════════════════════════════════╗
║              INTEGRATION ADAPTERS (6 local)                 ║
║              .claude/integrations/{service}/                ║
║              adapter.md + schema.json + mapping.json        ║
╚════════════════════════════╤═════════════════════════════════╝
                             │ normalized JSON
                             ▼
╔══════════════════════════════════════════════════════════════╗
║              AUTOMATIC VALIDATION GATE                      ║
║         GREEN (≥95%) │ ORANGE (90-95%) │ RED (<90%)         ║
║         Scoring: numeric 5% tolerance, gap-fills = ok       ║
║         Validation = automatic. Resolution = manual.        ║
╚════════════════════════════╤═════════════════════════════════╝
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
╔═══════════════╗ ╔══════════════╗ ╔═══════════════════╗
║ SHARED LAYER  ║ ║ CHANGE LOG   ║ ║ LEARNING CACHE    ║
║ 15 JSON files ║ ║ (audit trail)║ ║ L1 (per-skill)    ║
║ (see §2)      ║ ║              ║ ║ L2 (cross-skill)  ║
╚══════╤════════╝ ╚══════════════╝ ║ L3 (project-wide) ║
       │                           ╚═══════╤═══════════╝
       └──────────────┬────────────────────┘
                      ▼
╔══════════════════════════════════════════════════════════════╗
║                    SKILLS LAYER (11 total)                   ║
║              ┌──────────────────────┐                       ║
║              │    /pm-workflow      │ ◄── Phase 0 Health    ║
║              │    (HUB)             │     Check (v4.2)      ║
║              └──┬──┬──┬──┬──┬──┬──┘                       ║
║     ┌───────────┘  │  │  │  │  └───────────┐              ║
║     ▼     ▼     ▼     ▼     ▼     ▼        ▼              ║
║  /research /ux /design /dev /qa /analytics /release        ║
║                  ▼        ▼        ▼                       ║
║                /cx    /marketing  /ops                      ║
║                  └────────┴────┬───┘                        ║
║                                ▼                            ║
║                /pm-workflow (Phase 9: Learn → loop)         ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 2. Shared Data Layer — 15 JSON Files

Skills never call each other directly. All inter-skill communication flows through `.claude/shared/*.json`:

| File | Primary Writer(s) | Primary Reader(s) |
|---|---|---|
| `context.json` | /research, /pm-workflow | ALL skills (startup injection) |
| `feature-registry.json` | /pm-workflow | /qa, /analytics, /cx, /release, /marketing |
| `metric-status.json` | /analytics | /qa, /ops, /cx |
| `design-system.json` | /design, /ux | /marketing |
| `test-coverage.json` | /qa | /dev, /release |
| `cx-signals.json` | /cx | /design, /marketing, /analytics, /pm-workflow |
| `campaign-tracker.json` | /marketing | /analytics, /research |
| `health-status.json` | /ops, /dev, /qa | /release, /cx |
| `skill-routing.json` | config (manual) | /pm-workflow (dispatch routing) |
| `task-queue.json` | /pm-workflow, /dev | /pm-workflow |
| `change-log.json` | ALL (broadcast) | ALL (audit trail) |
| `framework-health.json` | hub health check | /pm-workflow |
| `framework-manifest.json` | config (manual) | docs, dashboards |
| `case-study-monitoring.json` | /pm-workflow | cross-cycle evidence |
| `external-sync-status.json` | /pm-workflow | Notion/Linear sync |

---

## 3. Hub: /pm-workflow — 10-Phase Lifecycle

```
Phase 0: RESEARCH ──── /research wide → narrow → feature
                       /cx reviews (pain points)
      │
Phase 1: PRD ───────── /analytics spec (instrumentation)
                       /analytics funnel (conversion def)
      │
Phase 2: TASKS ──────── auto-assign tasks by skill routing
      │
Phase 3: UX ─────────── /ux research → spec → validate
                         /design ux-spec, figma, accessibility
      │
Phase 4: IMPLEMENT ──── /dev branch
                        parallel subagent dispatch (deps graph)
      │
Phase 5: TEST ────────── /qa plan + run
                         /analytics validate
      │
Phase 6: REVIEW ──────── /dev review (code)
                         /design audit (visual)
                         /ux validate (heuristic)
      │
Phase 7: MERGE ───────── /release checklist + prepare
                         /dev ci-status
      │
Phase 8: DOCS ────────── /marketing launch
                         /cx roadmap
                         /analytics dashboard
      │
Phase 9: LEARN ───────── /cx analyze (feedback loop) ──┐
                         /analytics report              │
                         Root cause → dispatch fix       │
                         Loop until "solved" ◄──────────┘
```

**Work Item Types** (not everything runs all 10 phases):

| Type | Phases | Use Case |
|---|---|---|
| **Feature** | All 10 (0-9) | New capabilities needing research + PRD |
| **Enhancement** | Tasks → Implement → Test → Review → Merge | Improvements to shipped features |
| **Fix** | Implement → Test → Review → Merge | Bug fixes, security patches |
| **Chore** | Implement → Review → Merge | Docs, config, refactoring |

---

## 4. v5.0 SoC Optimizations (SHIPPED)

Two chip-architecture-inspired optimizations reclaiming **~54K tokens (27% of 200K context)**:

### 4a. Skill-On-Demand Loading (~30K saved)

Inspired by Apple's LoRA adapter hot-swap. Instead of loading all 11 SKILL.md files, the hub loads only phase-relevant ones:

```
phase_skills mapping (from skill-routing.json):

  research          → [research, cx]
  prd               → [pm-workflow, analytics]
  tasks             → [pm-workflow]
  ux_or_integration → [ux, design]
  implementation    → [dev, design]
  testing           → [qa, analytics]
  review            → [dev, qa]
  merge             → [release, dev]
  documentation     → [marketing, cx]
  learn             → [cx, analytics, ops]
```

### 4b. Cache Compression (~24K saved)

Inspired by Apple's 3.7-bit palettization. Each cache entry has a `compressed_view` (~200 words) loaded by default. Full expansion only on demand.

---

## 5. v5.1 Adaptive Batch Execution (DESIGN APPROVED)

Inspired by CPU out-of-order execution. Adds a **batch dispatcher** for running the same skill across multiple features/screens simultaneously:

```
BATCH DISPATCHER
      │
      ▼
PREFLIGHT COST ESTIMATOR (per-item scoring)
      │
      ├─── Token Est. >15K or dependent ──→ SERIAL LANE (main stream)
      │                                          │
      ├─── Token Est. 5K-15K + independent ──→ PARALLEL LANE (if budget allows)
      │                                          │
      └─── Token Est. <5K + independent ───→ PARALLEL LANE (subagent)
                                                 │
                                          RESULT COLLECTOR
                                          (merge + unified summary)
```

**Key constraints:**
- Parallel budget cap: **30K tokens** (prevents eating v5.0 savings)
- Max parallel agents: **3**
- Serial is always the fallback — system never degrades below serial-only
- Failed subagents move to serial fallback queue

**Example:** `/design audit --batch` across 6 screens:
- Home (18K est.) → serial
- 5 other screens (2K-12K) → parallel (~24K total, under 30K cap)
- Wall-clock time = Home audit time only

---

## 6. Skill Internal Lifecycle (every skill invocation)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ 1. CACHE │───▶│2. RESEARCH│───▶│3. EXECUTE│───▶│ 4. LEARN │
│  CHECK   │    │ (if miss) │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
Read L1/L2/L3   Investigate      Do the work     Write back
for matching    via adapters,    using cached +   patterns +
task signature  MCPs, codebase   researched data  anti-patterns
```

Speedup over repeated invocations: 1st screen = 0% savings → 4th screen = ~65% savings.

---

## 7. Self-Healing Hub (Phase 0 Health Check)

Runs probabilistically (25% chance, min 2hr interval) with 5 weighted integrity checks:

| Check | Weight | What It Validates |
|---|---|---|
| Cache Staleness | 25% | SHA256 hashes of source files vs. cache entries |
| Cache Hit Accuracy | 25% | Correction rate after cache hits |
| Shared Layer Consistency | 20% | Cross-reference 3 random fields across JSONs |
| Skill Routing Integrity | 15% | SKILL.md files exist for all routed task types |
| Adapter Availability | 15% | Each adapter dir has adapter.md + schema.json + mapping.json |

**Scoring:** healthy >= 0.95 (silent), warning 0.90-0.95 (advisory), critical < 0.90 (STOP).

---

## 8. Information Flow Summary

```
User ──→ /pm-workflow (hub)
              │
              ├──→ skill-routing.json (which skills for this phase?)
              │
              ├──→ Load ONLY phase-relevant SKILL.md files (v5.0 on-demand)
              │
              ├──→ Dispatch to spoke skill(s)
              │         │
              │         ├──→ Phase 1: CACHE CHECK (L1/L2/L3)
              │         ├──→ Phase 2: RESEARCH (adapters, MCPs, codebase)
              │         ├──→ Phase 3: EXECUTE (the actual work)
              │         └──→ Phase 4: LEARN (write cache, anti-patterns)
              │
              ├──→ Spoke writes to .claude/shared/*.json
              │
              ├──→ Validation Gate scores incoming external data
              │
              ├──→ change-log.json broadcast → all skills notified
              │
              └──→ Phase gate approval (user) → next phase
                        │
                        └──→ Phase 9: feedback loop → back to hub
```

---

## 9. Complete Skill Inventory

| # | Skill | Sub-commands | Role |
|---|---|---|---|
| 0 | `/pm-workflow` | `{feature}` | **Hub** — orchestrates 10-phase lifecycle |
| 1 | `/ux` | `research`, `spec`, `validate`, `audit`, `patterns` | What & Why (planning layer) |
| 2 | `/design` | `audit`, `ux-spec`, `figma`, `tokens`, `accessibility` | How it Looks (visual layer) |
| 3 | `/dev` | `branch`, `review`, `deps`, `perf`, `ci-status` | Build & ship |
| 4 | `/qa` | `plan`, `run`, `coverage`, `regression`, `security` | Quality gates |
| 5 | `/analytics` | `spec`, `validate`, `dashboard`, `report`, `funnel` | Measurement |
| 6 | `/cx` | `reviews`, `nps`, `sentiment`, `testimonials`, `roadmap`, `digest`, `analyze` | Customer voice |
| 7 | `/marketing` | `aso`, `campaign`, `competitive`, `content`, `email`, `launch`, `screenshots` | Growth & comms |
| 8 | `/ops` | `health`, `incident`, `cost`, `alerts` | Infrastructure |
| 9 | `/research` | `wide`, `narrow`, `feature`, `competitive`, `market`, `ux-patterns`, `aso` | Intelligence |
| 10 | `/release` | `prepare`, `checklist`, `notes`, `submit` | Ship to store |

---

## 10. Evolution Timeline

| Version | Date | Key Innovation |
|---|---|---|
| v1.2 | pre-April | Monolithic `/pm-workflow` — single skill does everything |
| v2.0 | 2026-04-07 | Hub-and-spoke — 11 skills, shared data layer, Phase 9 feedback loop |
| v3.0 | 2026-04-09 | External tool sync, parallel subagent dispatch, v2 refactor pipeline |
| v4.0 | 2026-04-10 | Reactive data mesh, integration adapters, validation gate, L1/L2/L3 cache |
| v4.1 | 2026-04-10 | Skill Internal Lifecycle (Cache Check → Research → Execute → Learn) |
| v4.2 | 2026-04-10 | Self-healing hub with Phase 0 health checks |
| v4.3 | 2026-04-11 | Control room, case-study monitoring, maintenance-program orchestration |
| v4.4 | 2026-04-13 | Eval-driven development — mandatory evals per feature |
| **v5.0** | **2026-04-14** | **SoC-on-Software: on-demand skill loading + cache compression = 54K tokens saved** |
| **v5.1** | **Design approved** | **Adaptive batch execution: serial backbone + opportunistic parallel offload** |

---

> **Need more detail?** See [architecture.md](architecture.md) for per-skill sub-command tables, shared data field descriptions, the CX feedback loop deep-dive, connection adjacency matrix, feature coverage analysis, gap analysis, and full design decision rationale.
