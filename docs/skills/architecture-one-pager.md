# FitMe Skills Ecosystem — Architecture One-Pager

> **Version:** 6.1 | **Updated:** 2026-04-16
>
> Quick-reference system schematics and information flow for the entire PM-flow ecosystem.
> For the full deep-dive (per-skill sub-commands, shared data field descriptions, gap analysis, design decisions, evolution history), see [architecture.md](architecture.md).

---

## 1. Top-Level System Diagram (v6.0)

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

### 1a. Hardware-Aware Dispatch Extension (v6.1)

```text
╔══════════════════════════════════════════════════════════════╗
║           HADF — Hardware-Aware Dispatch (v6.1)              ║
║                                                              ║
║  Layer 0: Device Detection ──► Layer 1: Static Profiles      ║
║  (iOS/Android/macOS/Web)        (17 chips, 6 vendors)        ║
║           │                              │                   ║
║           ▼                              ▼                   ║
║  Layer 2: Cloud Fingerprint ──► Layer 3: Dynamic Adaptation  ║
║  (TTFT/TPS → Mahalanobis)      (thermal/cloud/net/battery)  ║
║           │                              │                   ║
║           └──────────┬───────────────────┘                   ║
║                      ▼                                       ║
║  Layer 4: Evolutionary Learning (Chip Affinity Map, EMA)     ║
║                      │                                       ║
║                      ▼                                       ║
║  Composite Optimizer ──► hardware_context                    ║
║  (latency/cost/quality)   in dispatch-intelligence.json      ║
║                                                              ║
║  Confidence Gate: >0.7 trust │ 0.4-0.7 blend │ <0.4 ignore  ║
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

## 5. v5.1 SoC Items (IMPLEMENTED)

6 additional chip-architecture-inspired optimizations shipped on top of v5.0's 2 items:

| # | Item | Inspiration | Config Key | What It Does |
|---|---|---|---|---|
| 3 | Batch Dispatch | TPU weight-stationary | `batch_dispatch` | Load skill template once, iterate over N targets as data. Saves N-1 dispatch cycles. |
| 4 | Result Forwarding | UMA zero-copy | `result_forwarding` | Pass skill output inline to next skill instead of write-to-disk-read-back. |
| 5 | Model Tiering | ANE mixed-precision | `model_tiering` | Sonnet for mechanical tasks, Opus for judgment tasks. Per-phase tier assignment. |
| 6 | Speculative Preload | Branch prediction | `speculative_preload` | Pre-load likely-next-skill cache when current skill runs. 85% hit rate target. |
| 7 | Systolic Chains | TPU systolic array | `systolic_chains` | Each skill in a chain receives ONLY upstream output + L1 cache. No global reads mid-chain. |
| 8 | Task Complexity Gate | big.LITTLE hybrid | `task_complexity_gate` | Classify tasks as lightweight (E-core, parallel, sonnet) or heavyweight (P-core, serial, opus). |

**Combined v5.0 + v5.1 savings:** ~63% framework overhead reduction.

**Batch dispatch example:** `/design audit --batch` across 6 screens loads UX foundations once, iterates 6 screen files, produces aggregated report + per-screen output files. 7 reads vs. 12 reads + 5 fewer hub dispatch cycles.

**Task complexity gate example:** Phase 4 with 9 tasks — 5 lightweight (config edits, label updates) run in parallel on E-core lane (sonnet), then 4 heavyweight (architecture, new services) run serially on P-core lane (opus).

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

| Version | Date | Key Innovation | Case Study |
|---|---|---|---|
| v1.2 | pre-April 2026 | Monolithic `/pm-workflow` — single skill does everything | — |
| v2.0 | 2026-04-07 | Hub-and-spoke — 11 skills, shared data layer, Phase 9 feedback loop | [Onboarding v2](../case-studies/pm-workflow-showcase-onboarding.md) |
| v3.0 | 2026-04-09 | External tool sync, parallel subagent dispatch, v2 refactor pipeline | [Home v2](../case-studies/pm-workflow-showcase-onboarding.md) |
| v4.0 | 2026-04-10 | Reactive data mesh, integration adapters, validation gate, L1/L2/L3 cache | [Training v2 (40% cache)](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.1 | 2026-04-10 | Skill Internal Lifecycle (Cache Check → Research → Execute → Learn) | [Nutrition v2 (55% cache), Stats v2 (65%), Settings v2 (70%)](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.2 | 2026-04-10 | Self-healing hub with Phase 0 health checks | [Readiness v2, AI Engine v2, AI Rec UI](../case-studies/pm-workflow-evolution-v1-to-v4.md) |
| v4.3 | 2026-04-11 | Control room, case-study monitoring, maintenance-program orchestration | — |
| v4.4 | 2026-04-13 | Eval-driven development — mandatory evals per feature | — |
| **v5.0** | **2026-04-14** | **SoC-on-Software: on-demand skill loading + cache compression = 54K tokens saved** | [SoC Savings Report](../architecture/soc-savings-report-v5.1.md) |
| **v5.1** | **2026-04-14** | **8 SoC items: batch dispatch, model tiering, result forwarding, speculative preload, systolic chains, task complexity gate** | [AI Engine Architecture](../case-studies/ai-engine-architecture-v5.1-case-study.md) |
| v5.2 | 2026-04-16 | Dispatch Intelligence (3-stage pipeline) + Parallel Write Safety (snapshot/mirror) | [v5.1→v5.2 Evolution](../case-studies/v5.1-v5.2-framework-evolution-case-study.md) |
| **v6.0** | **2026-04-16** | **Framework Measurement: deterministic phase timing, L1/L2/L3 cache tracking, eval gates, CU v2, rolling baselines, token counting (79K)** | [Framework Measurement v6.0](../case-studies/framework-measurement-v6-case-study.md) |

---

> **Need more detail?** See [architecture.md](architecture.md) for per-skill sub-command tables, shared data field descriptions, the CX feedback loop deep-dive, connection adjacency matrix, feature coverage analysis, gap analysis, and full design decision rationale.
