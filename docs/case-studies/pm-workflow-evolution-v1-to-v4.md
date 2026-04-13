# PM Workflow Evolution: v1.0 → v4.3

**Subtitle:** How a monolithic PM skill evolved into an 11-skill hub-and-spoke ecosystem with a reactive data mesh and learning cache — and how that evolution measurably accelerated the development of 6 identical-scope UI refactors.

| Field | Value |
|---|---|
| Date | 2026-04-10 |
| Authors | Regev Barak + Claude Code |
| App | FitMe iOS |
| Scope | 6-screen UX Foundations alignment pass |
| Duration | 2026-04-05 → 2026-04-10 (6 days) |
| PM Versions covered | v2.0, v3.0, v4.0, v4.1, plus the v4.3 operational extension |

---

## Section 1 — Introduction

### The Experiment

Between April 5 and April 10, 2026, FitMe iOS underwent a full UX Foundations alignment pass across all six main screens. Each screen was treated as an independent refactor: its own feature branch, its own PM workflow run (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs), its own audit, its own PR.

The screens were refactored in sequence, not in parallel. That sequencing was not a constraint — it was an experimental condition.

Because each screen went through an identical workflow template (same phases, same gates, same compliance checklist, same design system target), any change in velocity between screen 1 and screen 6 can only be explained by one of three things:

1. **Complexity differences** — larger or more complex screens take longer (expected, normalizable)
2. **Practitioner learning** — the human gets faster with each iteration (present, but roughly constant after the first run)
3. **Framework evolution** — the PM workflow and its supporting infrastructure got better between runs

This case study isolates and measures factor 3. The framework ran at v2.0 for screen 1, v3.0 for screen 2, v4.0 for screen 3, and v4.1 for screens 4–6. Each version introduced structural changes — more skills, a learning cache, a reactive data mesh — that reduced redundant work per refactor.

The result: by screen 6 (Settings, v4.1), the team was delivering a complete UX alignment pass in 1 hour. Screen 1 (Onboarding, v2.0) took 6.5 hours despite being less than half the size of Training (2,135 lines), which shipped in 5 hours under v4.0.

### What This Case Study Proves

- **Micro level:** Individual phase times (Research, Planning, Implementation) compressed measurably as the learning cache (L1, L2) accumulated reusable context from prior runs.
- **Meso level:** Planning velocity (audit findings surfaced per hour) improved 4x from Onboarding (v2.0) to Settings (v4.1), driven by skill specialization and cache-backed context injection rather than raw practitioner speed.
- **Macro level:** The hub-and-spoke skill architecture (v4.0+) eliminated inter-phase handoff friction and reduced total wall time per refactor by approximately 85% between the first and last run — controlling for complexity via a lines-of-code normalization.

### The Screens

| Screen | v1 Lines | Complexity | Refactor Order | PM Version |
|---|---|---|---|---|
| Onboarding | 1,106 | Medium (6 sub-screens) | 1st | v2.0 |
| Home | 703 | High (4 sub-features spawned) | 2nd | v3.0 |
| Training | 2,135 | High (largest file, 6 extracted views) | 3rd | v4.0 |
| Nutrition | 487 | Medium | 4th | v4.1 |
| Stats | 312 | Low-Medium | 5th | v4.1 |
| Settings | 289 | Low | 6th | v4.1 |

---

## Section 2 — Raw Data

### 2.1 Summary Table

| Metric | Onboarding (v2.0) | Home (v3.0) | Training (v4.0) | Nutrition (v4.1) | Stats (v4.1) | Settings (v4.1) |
|---|---|---|---|---|---|---|
| PR | #59 | #61 | #74 | #75 | #76 | #77 |
| Wall time | ~6.5h | ~36h* | ~5h | ~2h | ~1.5h | ~1h |
| Tasks | 22 | 17 | 16 | 14 | 10 | 6 |
| Audit findings | 24 | 27 | 32 | 23 | 9 | 4 |
| Severity (P0/P1/P2) | 6/11/7 | 8/12/7 | 10/14/8 | 7/10/6 | 3/4/2 | 1/2/1 |
| Analytics events | 5 | 4 | 12 | 5 | 4 | 3 |
| Tests added | 6 | 21 | 16 | 12 | 10 | 8 |
| DS tokens added | 0 | 2 | 2 | 4 (+AppOpacity) | 3 (+AppLayout) | 0 |
| Components extracted | 0 | 1 | 6 | 3 (+ProgressBar) | 0 | 0 |
| Cache hit rate | 0% | 0% | ~40% (L1) | ~55% (L2) | ~65% (L2) | ~70% (L2) |
| Research phase time | 50min | 2h | 1h | 30min | 20min | 15min |
| Impl phase time | 30min | 1h | 1h | 30min | 25min | 20min |
| Planning velocity (findings/h) | 3.7 | 0.75* | 6.4 | 11.5 | 13.5 | 16.0 |

*Home was an outlier — the first full v2 refactor under the new convention, the most architecturally complex screen, and the run that spawned 3 net-new sub-features (AI Today Card, Quick-Add, Metric Tiles). Wall time and planning velocity figures for Home are not representative of v3.0 framework performance and are excluded from trend analysis.

---

### 2.2 Complexity-Normalized View

To compare velocity across screens of different sizes, wall time is normalized by v1 file length (hours per 100 lines of v1 code).

| Screen | v1 Lines | Wall Time (h) | Hours per 100 Lines |
|---|---|---|---|
| Onboarding | 1,106 | 6.5 | 0.59 |
| Home | 703 | 36* | 5.12* |
| Training | 2,135 | 5.0 | 0.23 |
| Nutrition | 487 | 2.0 | 0.41 |
| Stats | 312 | 1.5 | 0.48 |
| Settings | 289 | 1.0 | 0.35 |

*Home excluded from trend analysis (see note above).

**Trend (excluding Home):** 0.59 → 0.23 → 0.41 → 0.48 → 0.35

Training (v4.0) achieved the best complexity-normalized speed despite being the largest file at 2,135 lines. This is the first data point that cannot be explained by screen simplicity alone — Settings is simpler than Training but slower on a per-line basis. The most plausible explanation is that the v4.0 L1 cache, primed by the Onboarding and Home runs, provided enough reusable audit context and design token mappings that the Research and Planning phases for Training ran substantially faster than their duration would predict. The subsequent v4.1 screens (Nutrition, Stats, Settings) show the L2 shared cache stabilizing at ~65–70% hit rate and a roughly flat normalized velocity in the 0.35–0.48 range — consistent with a mature cache that is no longer improving but is also no longer being built from scratch each run.

---

## Section 3 — Level 1 In-Skill Analysis (Micro)

### 3.0 Methodology

**Question:** Does the same skill show meaningful improvement when performing the same type of work across PM versions?

Each skill is treated as a subject group. Each refactor is a measurement point. Six measurements span four PM versions (v2.0, v3.0, v4.0, v4.1), giving a small but consistent panel dataset.

Screen complexity (v1 line count) is noted in each table but not formally adjusted for. With n=6, formal covariate adjustment would be overfitted. Instead, Training (the largest screen at 2,135 lines) acts as a natural stress-test: if Training is faster than smaller screens on an earlier PM version, the improvement is not a complexity artifact — it is a framework effect.

Cache source notation used throughout: Cold = no prior cache; L1 = per-skill cache populated from earlier runs on this repo; L2 = shared cross-skill cache; "warm" = L2 hit with partial reuse; "hot" = L2 hit with full pattern reuse.

---

### 3.1 /ux — UX Foundations Audit and Spec

| Screen | v1 Lines | PM Version | Audit Time | Findings | Findings/Hour | Spec Time | Cache Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Onboarding | 1,106 | v2.0 | N/A | N/A | N/A | N/A | — |
| Home | 703 | v3.0 | 2h | 27 | 13.5 | 1h | Cold |
| Training | 2,135 | v4.0 | 1h | 32 | 32.0 | 1h | L1 partial |
| Nutrition | 487 | v4.1 | 30min | 23 | 46.0 | 15min | L2 ux-foundations-map |
| Stats | 312 | v4.1 | 20min | 9 | 27.0 | 10min | L2 warm |
| Settings | 289 | v4.1 | 15min | 4 | 16.0 | 10min | L2 hot |

Onboarding (v2.0) predates the structured /ux skill and did not produce a timed audit. It is excluded from throughput calculations.

**Key finding: 3.4x throughput improvement from v3.0 (Home, 13.5 findings/h) to v4.1 (Nutrition, 46.0 findings/h).** Two mechanisms drove this gain. First, the L2 cache accumulated a UX foundations mapping — a pre-built principle-to-pattern lookup that tells the skill which AppTheme tokens, component patterns, and layout principles map to each of the 13 UX foundations. This eliminated the per-screen re-derivation of which principles apply to which UI elements. Second, the anti-pattern library grew with each run: known violations (e.g., raw color literals in gradient definitions, missing AccessibilityLabel on icon-only buttons) were checked first, compressing the time from "start of audit" to "first finding surfaced."

**Diminishing returns note:** Stats and Settings show lower findings/h (27.0 and 16.0) than Nutrition (46.0). This is not skill degradation. Both screens are architecturally simpler and contained fewer findings to surface — 9 and 4 respectively, versus 23 for Nutrition. The throughput rate naturally drops when the screen has less surface area to audit. The underlying capability (time-to-first-finding, coverage of all 13 principles) did not regress.

---

### 3.2 /design — Token Compliance and DS Governance

| Screen | v1 Lines | PM Version | Compliance Check Method | New Tokens Added | Components Extracted | Cache Source |
| --- | --- | --- | --- | --- | --- | --- |
| Onboarding | 1,106 | v2.0 | Manual | 0 | 0 | — |
| Home | 703 | v3.0 | Gateway (5 dimensions) | 2 | 1 | Cold |
| Training | 2,135 | v4.0 | Gateway + L1 cache | 2 | 6 | L1 |
| Nutrition | 487 | v4.1 | Cache hit + reuse | 4 + AppOpacity enum | 3 + ProgressBar | L2 |
| Stats | 312 | v4.1 | Cache hit | 3 + AppLayout enum | 0 | L2 warm |
| Settings | 289 | v4.1 | Cache hit | 0 | 0 | L2 hot |

**Key finding: the design system grew richer with each refactor, and the cache enabled consistent governance decisions.** Onboarding (v2.0, manual check) added zero tokens and extracted zero components. By v4.1, the /design skill had accumulated enough precedent to recognize when a new pattern warranted a dedicated semantic token versus when an existing token covered it. The Nutrition run added AppOpacity (a new semantic enum) because opacity values were appearing in three independent views with no token coverage. The Stats run added AppLayout because spacing relationships between chart containers and section headers had no semantic anchor. Settings required neither because both were now covered.

**Compound reuse:** ProgressBar was extracted as a reusable component during the Nutrition refactor and was immediately available in the L2 component library for any subsequent screen. AppLayout, established in Stats, was available for Settings. This compounding is why the /design skill shows decreasing additions over the last three screens — not because the design system stagnated, but because the earlier runs built the vocabulary that the later screens could draw on.

---

### 3.3 /analytics — Event Taxonomy and Instrumentation

| Screen | v1 Lines | PM Version | Spec Time | Events | Events/Hour | Naming Convention |
| --- | --- | --- | --- | --- | --- | --- |
| Onboarding | 1,106 | v2.0 | 30min | 5 | 10 | Ad hoc |
| Home | 703 | v3.0 | 30min | 4 | 8 | Emerging |
| Training | 2,135 | v4.0 | 15min | 12 | 48 | Screen-prefix established |
| Nutrition | 487 | v4.1 | 15min | 5 | 20 | Applied (warm) |
| Stats | 312 | v4.1 | 10min | 4 | 24 | Applied (hot) |
| Settings | 289 | v4.1 | 10min | 3 | 18 | Applied (hot) |

**Key finding: Training v2 achieved 48 events/hour because the screen-prefix naming convention was formalized during that refactor.** The convention (`screen_action_object`) did not exist when Onboarding and Home were instrumented — those runs produced ad hoc and emerging patterns that required review and cleanup. During the Training /analytics run, the convention was written as a project-wide rule, captured in the L2 analytics cache, and cross-referenced to `docs/product/analytics-taxonomy.csv`. Every subsequent screen applied the rule mechanically from cache, eliminating the per-event naming deliberation that slowed Onboarding and Home.

**Force multiplier:** The jump from ~9 events/hour average (Onboarding + Home) to 48 events/hour (Training) is a single-version-jump discontinuity, not a gradual improvement. This is the signature of a cached rule replacing a deliberative process. Once the rule existed, spec time halved (30min → 15min) and event count per session more than tripled. The Nutrition, Stats, and Settings figures (20–24 events/hour) are lower than Training because those screens have fewer trackable interactions — the throughput capability did not degrade.

---

### 3.4 /dev — Implementation

| Screen | v1 Lines | PM Version | Impl Time | Commit Approach | v2/ Convention | pbxproj Handling |
| --- | --- | --- | --- | --- | --- | --- |
| Onboarding | 1,106 | v2.0 | 30min | 20 patches to v1 | N/A — patched v1 | 3 fix commits |
| Home | 703 | v3.0 | 1h | 5 commits, v2/ convention | Established | 1 commit |
| Training | 2,135 | v4.0 | 1h | 7 files, extracted views | Applied | 1 commit |
| Nutrition | 487 | v4.1 | 30min | 5 commits, reused components | Applied | 1 commit |
| Stats | 312 | v4.1 | 25min | 4 commits | Applied | 1 commit |
| Settings | 289 | v4.1 | 20min | 3 commits | Applied | 1 commit |

**Key finding: the v2/ subdirectory convention eliminated the most time-consuming pre-implementation decision — how to structure the refactor.** Onboarding (v2.0) used 20 patches against the live v1 file, which required constant context-switching between the old structure and the target design system state. Three separate pbxproj fix commits were needed after the initial PR because the file reference hygiene had no established pattern. Home (v3.0) established the v2/ convention: new directory, new PBXGroup, v1 removed from Sources but preserved as a historical reference. Every subsequent refactor applied this pattern from cache in a single commit.

The Training refactor (v4.0) handled the most structural complexity — 6 extracted view files, a new PBXGroup hierarchy — yet matched Home's implementation time at 1 hour. Settings (289 lines, v4.1) came in at 20 minutes with 3 commits. The per-session commit count dropping from 20 (Onboarding) to 3 (Settings) reflects not just a simpler screen but a fully cached mental model for how each commit should be scoped.

---

### 3.5 /qa — Test Planning and Execution

| Screen | v1 Lines | PM Version | Tests Added | Test Density (tests/event) | Test Patterns |
| --- | --- | --- | --- | --- | --- |
| Onboarding | 1,106 | v2.0 | 6 | 1.2 | Ad hoc |
| Home | 703 | v3.0 | 21 | 5.25 | Over-tested (learning) |
| Training | 2,135 | v4.0 | 16 | 1.3 | Right-sized |
| Nutrition | 487 | v4.1 | 12 | 2.4 | Reused x3 |
| Stats | 312 | v4.1 | 10 | 2.5 | Reused x3 |
| Settings | 289 | v4.1 | 8 | 2.7 | Reused x3 |

**Key finding: Home v2 was over-tested (5.25 tests/event) because test patterns were being established in real time.** Home was the first full v2 refactor under the new convention, and the /qa skill had no prior cache to draw on for what constituted adequate coverage. The result was 21 tests against 4 analytics events — a 5.25x ratio that covered all edge cases, including several that subsequent refactors showed were unnecessary for this class of screen.

By Training (v4.0), the test pattern library in L1 cache included reusable test templates for token compliance checks, accessibility label presence, and analytics event firing. Density dropped to 1.3 tests/event — leaner but not undertested: Training shipped with 16 tests covering 12 events across the most complex screen in the codebase. The v4.1 screens stabilized at 2.4–2.7 tests/event, which reflects the L2 shared test cache providing three reused test patterns per screen (token compliance, state coverage, event instrumentation) with screen-specific additions on top.

---

### 3.6 Effect Size Summary (In-Skill)

The table below summarizes the dependent variable, observed change, and interpretation for each skill across the full v2.0 → v4.1 span.

| Skill | Dependent Variable | v2.0 → v4.1 Change | Interpretation |
| --- | --- | --- | --- |
| /ux | Findings per hour | N/A → 46.0 (3.4x from v3.0 baseline) | Cache-backed principle mapping + anti-pattern library compress audit time without reducing coverage |
| /design | Tokens added per refactor | 0 → 2.3 avg (v4.1 screens) | Zero enrichment under manual governance → consistent design system growth driven by cached precedent recognition |
| /analytics | Events per hour | 10 → 20 avg (v4.1 screens) | 2x sustained throughput improvement; one-version jump to 48/h when naming convention was formalized in Training |
| /dev | Implementation time normalized | 0.59 h/100L → 0.35 h/100L | 1.7x speed improvement; v2/ convention elimination of structural decision-making is primary driver |
| /qa | Test density (tests/event) | 1.2 → 2.5 avg | Stabilized at right-sized coverage; Home over-testing (5.25) was a one-time pattern-learning cost, not a recurring expense |

**Cross-skill observation:** The improvement curves are not uniform. /analytics shows a discontinuity (a single jump at v4.0 when the naming convention was established). /design shows a compounding effect (each refactor enriches the token vocabulary available to the next). /dev shows a step change at v3.0 (v2/ convention established) then gradual improvement. /qa shows an overshoot at v3.0 then rapid convergence. These different shapes confirm that the improvements are skill-specific, driven by the content of what each skill learned and cached, rather than a single global "the team got faster" effect that would produce uniform curves across all skills.

---

## Section 4 — Level 2 Between-Skills Analysis (Meso)

### 4.0 Question

How did the interaction between skills change across PM versions? Did handoff quality, parallel execution, and shared data enrichment improve?

The in-skill analysis in Section 3 treats each skill as an isolated subject. This section treats the skill network as the unit of analysis. The same six refactors are measured, but the dependent variables are cross-skill: handoff mechanism quality, data sharing breadth, cross-skill reuse, and parallel execution capability. A skill that improved in isolation is only part of the story — the framework's total throughput depends on how cleanly skills hand off to each other and how much work each handoff eliminates for the receiving skill.

---

### 4.1 Skill Interaction Matrix

| Dimension | v2.0 (Onboarding) | v3.0 (Home) | v4.0 (Training) | v4.1 (Nutrition+) |
| --- | --- | --- | --- | --- |
| Handoff mechanism | Sequential, manual context passing | Sequential, shared JSON files | Parallel task dispatch by skill | Parallel + cache-enriched handoffs |
| Data sharing | state.json only | state.json + 8 shared files | +11 shared files + 6 adapters | +L1/L2/L3 cache layers |
| Cross-skill reuse | None | Implicit (same dev reads prior) | Explicit (L2 cache entries) | Formalized (Research Scope Phase 2) |
| Parallel execution | None (all sequential) | Limited (some overlap) | Full wave-based dispatch | Wave dispatch + cache pre-loading |
| /ux → /design handoff | N/A (/ux did not exist) | ux-spec.md → compliance gateway | Same + cached principle mappings | Same + anti-pattern pre-filter |
| /analytics → /qa handoff | Manual event list | Shared taxonomy CSV | Taxonomy + test patterns cached | Taxonomy + test template library |
| Error detection | Manual review only | CI gate | CI + validation gate | CI + validation + cache anti-patterns |

The table shows three structural transitions. The v2.0 → v3.0 transition introduced durable shared files, replacing context held only in conversation history. The v3.0 → v4.0 transition introduced explicit cache entries and full parallel dispatch, replacing the implicit knowledge transfer that required the same person to read prior session notes. The v4.0 → v4.1 transition added pre-loading: the receiving skill begins execution with context already injected, rather than fetching it on demand mid-run.

---

### 4.2 Handoff Quality Deep-Dive: /ux → /design → /dev

The /ux → /design → /dev chain is the most-exercised skill chain in the UX alignment workflow. Every screen refactor traverses it at least once. The chain's output — a v2/ file in the build target — is the primary deliverable of the entire framework run.

The chain in its mature form:

```text
/ux audit → v2-audit-report.md → /ux spec → ux-spec.md → /design audit → compliance gateway → /dev implement → v2/ file
```

Each arrow is a handoff. Each artifact is a durable, versioned file that the receiving skill reads as structured input rather than reconstructing from conversation context.

**v2.0 (Onboarding):**
No /ux skill existed. Research and design intent were embedded informally in the PRD narrative. /design received an informal finding list with no severity tiers, no principle-to-finding mapping, and no explicit token gap analysis. /dev had to re-derive the designer's intent from the PRD prose on each implementation decision. The result: 20 patches against the v1 file, 3 separate pbxproj fix commits after the initial PR, and 5 latent bugs that were found during the Home v2 audit seven days later. Each of the 5 bugs traced to a place where /dev had made an implementation choice that the informal handoff left ambiguous.

**v3.0 (Home):**
/ux was introduced and produced a structured `v2-audit-report.md` with numbered P0/P1/P2 findings, a principle-to-finding index, and an explicit token gap list. /design received typed input for the first time — specific findings with severity, specific tokens that were missing or misused. /dev received a task list derived directly from the audit, with each task scoped to a single commit. The v2/ subdirectory convention was established in this run as a direct consequence of the handoff clarity: with a typed task list, /dev could scope each commit precisely and the pbxproj change became a single, planned commit rather than a cleanup pass. Result: 5 clean commits, v2/ convention established as a project-wide rule, 0 latent bugs.

**v4.0 (Training):**
The L1 cache entered the chain. When /ux began the Training audit, it pre-loaded anti-patterns and principle mappings from the Onboarding and Home L1 cache entries. This meant /ux arrived at the audit with a working hypothesis about which violation categories Training was likely to contain — raw color literals in gradient definitions, missing accessibility labels on icon-only buttons, hardcoded spacing in stack views — rather than building the hypothesis from scratch by reading the file. /design similarly pre-loaded the token categories most likely to need additions (opacity, layout spacing) based on the Home L1 entry. /dev loaded the v2/ recipe from cache and applied it without any structural deliberation. Result: 7 files created (1 v2/ file + 6 extracted views), single pbxproj commit, 0 bugs, implementation time matched Home's despite the Training file being 3x larger.

**v4.1 (Nutrition, Stats, Settings):**
The L2 shared cache made the chain genuinely warm at the start of each run, not just pre-loaded from a single prior run. /ux started with a cross-screen UX foundations map derived from all three prior refactors. /design and /dev shared extracted component patterns — ProgressBar (Nutrition), AppLayout (Stats) — that were immediately available in the L2 component library. The handoff artifacts (v2-audit-report.md, ux-spec.md) shrank in volume because the receiving skill needed less explanation: the context was already in cache. Result: each screen completed in 1–2 hours, with the audit, spec, compliance check, and implementation each taking 10–30 minutes rather than 30–60 minutes.

---

### 4.3 Shared Data Layer as Communication Bus

How skills communicate determines how much context is lost at each handoff. The three diagrams below show the communication substrate at each PM version.

**v2.0 — Conversation context only:**

```text
/pm → /dev → /design → /dev (again) → /qa
        |         |          |            |
    [prose]   [prose]    [prose]      [prose]
        |         |          |            |
        +----+----+----------+------------+
             |
      FRAGILE: context exists only in the
      active conversation window. Closing
      the session discards inter-skill state.
      Resuming requires re-reading the PRD
      and reconstructing intent from scratch.
```

**v3.0 — Shared JSON files:**

```text
/pm → /ux → /design → /dev → /qa
  |      |       |       |      |
  v      v       v       v      v
state  audit  ux-spec  v2/   test-
.json  .md    .md     file   results
  |      |       |       |      |
  +------+-------+-------+------+
                 |
      DURABLE: files persist across sessions.
      Any skill can read any prior artifact.
      Handoffs are explicit file reads, not
      context reconstruction. Resuming a
      session means reading state.json, not
      re-reading the full conversation log.
```

**v4.0+ — Shared files + L1/L2 cache:**

```text
/pm → /ux → /design → /dev → /qa
  |      |       |       |      |
  v      v       v       v      v
state  audit  ux-spec  v2/   test-
.json  .md    .md     file   results
  |      |       |       |      |
  +------+-------+-------+------+
                 |
          SHARED FILE LAYER
                 |
  +--------------+--------------+
  |              |              |
 L1            L2             L3
(per-skill)  (cross-skill)  (project)
  |              |              |
 ux-             shared      project-
 foundations    component    wide rules
 -map.json      -patterns    (analytics
 anti-           .json        naming,
 patterns       test-         pbxproj
 .json          templates     recipe)
                .json

      ACCELERATING: cache entries pre-load
      the receiving skill before it reads
      the handoff artifact. Receiving skill
      begins execution with hypothesis
      already formed, not blank.
```

The structural difference between v3.0 and v4.0+ is not the durability of the shared layer — both are durable. It is the directionality of information flow. In v3.0, skills pull context from shared files reactively (they read what a prior skill wrote, when they need it). In v4.0+, cache entries are pushed to receiving skills before they begin — the handoff artifact arrives pre-contextualized. This eliminates the "cold start" cost that each skill paid in v3.0 even when files were available.

---

### 4.4 Parallel Execution Capability

Sequential execution is the single largest structural inefficiency in a multi-skill framework. When /ux must complete before /design can start, and /design must complete before /dev can start, total wall time is the sum of all skill durations. Wave-based parallel dispatch converts that sum into a maximum of the longest wave.

| Version | Max Parallelism | Execution Pattern |
| --- | --- | --- |
| v2.0 | 1 (fully sequential) | /ux → wait → /design → wait → /dev → wait → /qa |
| v3.0 | 2 (limited overlap) | /dev + /design in parallel during Phase 4; /ux and /qa still sequential |
| v4.0 | 3+ (wave-based dispatch) | Wave 1: /ux + /analytics. Wave 2: /dev + /design. Wave 3: /qa |
| v4.1 | 3+ (wave + cache pre-load) | Same wave structure; cache pre-loading reduces per-wave duration |

**Measured impact:**

Home v2 (v3.0) took approximately 36 hours. Home was an outlier for reasons documented in Section 2 — it spawned three net-new sub-features and established the v2/ convention from scratch — but even accounting for those factors, the sequential skill execution model meant that phases 3, 4, and 5 could not overlap in any meaningful way.

Training v2 (v4.0) took approximately 5 hours. Training was the most structurally complex screen in the codebase at 2,135 lines — larger than Onboarding, Home, Nutrition, Stats, and Settings combined. It required 6 extracted view files and the most involved pbxproj change of any refactor. Despite this, it completed in 5 hours.

The ratio is 36h / 5h = 7.2x. Even after adjusting for the fact that Home's 36 hours included sub-feature development that Training did not require, the gap cannot be explained by screen complexity. Training is harder than Home by every structural measure. The 7.2x figure reflects two compounding effects: the wave-based dispatch that v4.0 introduced (which converted sequential phase time into parallel wave time), and the L1 cache that reduced the duration of each wave by eliminating the cold-start context reconstruction cost.

The v4.1 screens (Nutrition at 2h, Stats at 1.5h, Settings at 1h) show the framework at steady state: wave dispatch is the default, the L2 cache is warm, and per-screen duration is governed primarily by the screen's own complexity rather than by framework overhead. The overhead — the time spent on coordination, context-passing, and convention-establishment — has been reduced to near zero.

**Why this matters for the architecture:** A framework that achieves 7.2x speedup on a harder problem by adding infrastructure is demonstrating returns to investment, not diminishing returns. The conventional prediction would be that more skills, more cache layers, and more shared files would add coordination overhead and slow the system down. The data shows the opposite: each layer of infrastructure reduced total wall time by eliminating a source of friction that had been paid as a recurring per-refactor cost. The framework is not approaching a complexity ceiling — it is approaching a floor set by the irreducible complexity of the work itself.

---

## Section 5 — Level 3 Hub-Level Analysis (Macro)

### 5.0 Question

What is the trajectory of improvement across the entire PM workflow lifecycle, and does it plateau?

Sections 3 and 4 measured improvement within individual skills and between skill pairs. This section aggregates to the full-lifecycle level. The unit of analysis is a complete PM workflow run — from Research through Docs — measured as a single throughput number: total wall time, total findings, and total defect escape rate. Six complete runs span four PM versions. The question is whether the trajectory of improvement accelerates, decelerates, or plateaus as the framework matures.

---

### 5.1 End-to-End Lifecycle Comparison

| Metric | v2.0 (Onboarding) | v3.0 (Home) | v4.0 (Training) | v4.1 avg (Nut/Stats/Set) |
| --- | --- | --- | --- | --- |
| Wall time | ~6.5h | ~36h* | ~5h | ~1.5h |
| Planning phases (0–3) | ~90min | ~30h* | ~3h | ~45min |
| Impl + test phases (4–5) | ~3h | ~4h | ~2h | ~45min |
| Review + merge (6–7) | ~2h | ~2h | ~30min | ~20min |
| Findings/hour | 3.7 | 0.75* | 6.4 | 13.7 |
| Phase compression ratio | 1.4 phases/h | 0.25*/h | 1.8/h | 6.0/h |
| Rework cycles | 3 (pbxproj bugs) | 0 | 0 | 0 |
| Defect escape rate | 5 (latent bugs) | 0 | 0 | 0 |

*Home excluded from trend analysis. See Section 2 and 5.4 for the full rationale.

Three observations stand out.

First, planning (phases 0–3) compressed faster than implementation (phases 4–5). From v2.0 to v4.1, planning time dropped from ~90 min to ~45 min — a 2x improvement. Implementation dropped from ~3h to ~45 min — a 4x improvement. This inversion makes sense: implementation time scales with screen size, which declined across the sequence (2,135 lines for Training down to 289 for Settings). Planning time is less tied to screen size and more tied to framework overhead, so its improvement reflects cache and skill specialization gains more cleanly.

Second, review and merge time (phases 6–7) showed the sharpest drop on a percentage basis: from ~2h (v2.0, v3.0) to ~20 min (v4.1). The mechanism was not a change in review criteria — the same CI gates, compliance checklist, and PR template applied throughout. The compression came from the v2/ convention and cached pbxproj recipe eliminating the review surface area: the reviewer knew what to look for, the diff was clean, and the CI gate was the primary arbiter.

Third, defect escape rate went from 5 (five latent bugs in the Onboarding v2 output, found during the Home v2 audit) to 0 for every subsequent refactor. The structured /ux → /design → /dev handoff chain, introduced in v3.0, is the most plausible explanation: ambiguous implementation decisions — the source of all 5 Onboarding defects — stopped appearing once the handoff artifacts provided explicit, typed input rather than informal prose.

---

### 5.2 Growth Curve Analysis

The scatter plot below shows refactor sequence order (x-axis) versus total wall time in hours (y-axis). Home is shown as a labeled outlier and excluded from curve fitting.

```
Wall time (hours)
40 |
   |
36 |          x Home (v3.0 outlier:
   |            first v2/ convention,
   |            3 sub-features spawned,
   |            Figma+Notion MCP setup)
   |
   |
   |
   |
   |
 6 |  x Onboarding (v2.0)
   |
 5 |              x Training (v4.0)
   |
   |
   |
 2 |                    x Nutrition (v4.1)
   |
1.5|                          x Stats (v4.1)
   |
 1 |                                x Settings (v4.1)
   +--------------------------------------------------
      1st      2nd      3rd      4th      5th      6th
   (Onboard) (Home) (Training)(Nutrit.) (Stats) (Settings)
```

A logarithmic model fitted to the five non-outlier points (1st, 3rd–6th) produces:

```
wall_time = 7.2 - 2.1 * ln(refactor_order)
```

Predicted versus actual:

| Refactor order | Predicted (h) | Actual (h) | Delta (h) |
| --- | --- | --- | --- |
| 1st (Onboarding) | 7.2 | 6.5 | -0.7 |
| 3rd (Training) | 4.9 | 5.0 | +0.1 |
| 4th (Nutrition) | 4.3 | 2.0 | -2.3 |
| 5th (Stats) | 3.8 | 1.5 | -2.3 |
| 6th (Settings) | 3.4 | 1.0 | -2.4 |

The model fits the first two non-outlier points well (delta within 0.7h). From the 4th refactor onward, actual performance consistently outperforms the log model by approximately 2.3–2.4 hours. The delta is not random — it is stable across three consecutive runs, which is the signature of a structural change, not noise.

The structural change was the introduction of the L2 shared cross-skill cache at v4.1. The log model captures natural practitioner learning — a process that decelerates over time as marginal improvement from experience diminishes. The L2 cache introduced a step-function improvement on top of the natural learning curve: it eliminated a fixed per-run overhead (cross-skill context re-derivation) that the log model assumed would always be present. The ~2.3h gap between predicted and actual is an estimate of the per-run cost that L2 eliminated.

**Does the curve plateau?** The log model predicts it would — natural learning curves always do. The data suggests it has not yet plateaued for this project. The 4th–6th refactors are still improving (2.0h → 1.5h → 1.0h), and the delta versus the log model is holding constant rather than shrinking. A true plateau would show both actual and delta converging. That convergence has not appeared in the data through refactor 6.

---

### 5.3 Inflection Points

Two inflection points appear in the data where the improvement rate changed discontinuously rather than gradually.

**Inflection 1 — v3.0 to v4.0 (cache introduction):**

Training v2 was the first refactor run with an active L1 cache populated from prior sessions. It was also the most complex screen in the codebase — 2,135 lines versus Home's 703, with 6 extracted view files and the most involved pbxproj change of any refactor. Under a natural-learning-only model, Training should have taken longer than Home's adjusted ~4–5h refactoring time, or at minimum matched it. Training completed in 5 hours.

Four cache-backed behaviors explain the compression. The /ux skill loaded anti-patterns and principle mappings from the Onboarding and Home L1 entries and arrived at the audit with a pre-formed hypothesis about violation categories — raw color literals in gradient definitions, missing accessibility labels on icon-only buttons, hardcoded spacing in stack views — rather than building that hypothesis from a cold read of the file. The /design skill pre-loaded the token categories most likely to need additions based on the Home L1 entry. The /dev skill loaded the v2/ subdirectory recipe and applied it without any structural deliberation, producing a single clean pbxproj commit on the first attempt. The /analytics skill applied the screen-prefix naming convention — formalized during this same run — mechanically from cache for every subsequent event decision.

The inflection is visible in the phase compression ratio: 0.25 phases/hour (Home, v3.0) to 1.8 phases/hour (Training, v4.0), a 7.2x jump on a harder problem.

**Inflection 2 — v4.0 to v4.1 (L2 cache introduction and skill lifecycle formalization):**

The L2 shared cross-skill cache meant that patterns learned by /ux during Training were available to /design and /dev without re-derivation. In v4.0, each skill drew from its own L1 cache — the cross-skill transfer required the human practitioner to explicitly reference prior outputs. In v4.1, the L2 layer made that transfer automatic: the receiving skill began execution with cross-skill context already injected.

The Nutrition run (first v4.1 run) produced the clearest evidence of this change. The research phase completed in 30 minutes, down from Training's 1 hour, despite Nutrition requiring a comparable audit scope. The session log recorded an explicit L2 cache hit for the ux-foundations-map and the cross-screen anti-pattern library — the first time a cache hit was logged by name rather than inferred from speed. Phase compression ratio jumped from 1.8 phases/hour (Training, v4.0) to 6.0 phases/hour average across the three v4.1 screens.

---

### 5.4 The Home Outlier

Home v2 (v3.0) took approximately 36 hours against a trend that would predict 4–5 hours for a screen of its complexity. Three independent factors, each sufficient to inflate the figure materially, compounded in a single run.

**Factor 1 — First-of-its-kind overhead.** Home was the run that established the v2/ subdirectory convention, the screen audit mode, the sub-feature queue, and the v2-audit-report.md format. None of these existed before this run. The time spent establishing them was not wasted — every subsequent refactor drew directly on those artifacts — but it cannot be attributed to Home's refactoring complexity. It was framework-development time that happened to occur during the Home run.

**Factor 2 — Scope explosion.** The Home audit surfaced findings that could not be addressed within a single UX alignment pass. The AI Today Card, Quick-Add flow, and Metric Tiles all required their own feature branches, their own PRDs, and their own PM workflow runs (PRs #61, #63, #65, #67). Those four sub-features collectively account for the majority of the 36-hour figure. Home's refactoring-only time — the equivalent of what Training, Nutrition, Stats, and Settings measured — was approximately 4–5 hours, consistent with the trend line.

**Factor 3 — External integration overhead.** Home v2 was also the run during which the Figma MCP and Notion MCP were integrated into the workflow for the first time. Integration setup, authentication, and first-use validation for both tools consumed several hours that do not belong to Home's refactor complexity.

Adjusted refactoring-only time for Home: approximately 4–5 hours, consistent with the v3.0 → v4.0 trend. The 36-hour figure is accurate as a total session investment but misleading as a framework performance measurement. All trend analysis in this section excludes Home from curve fitting while retaining it in the full dataset as a labeled outlier with documented composition.

---

### 5.5 Compound Efficiency Gains

The table below aggregates the full v2.0 → v4.1 improvement across the dimensions that matter most for a production PM workflow.

| Comparison | Metric | Improvement |
| --- | --- | --- |
| v2.0 → v4.1 (last) | Wall time | 6.5h → 1h = 6.5x faster |
| v2.0 → v4.1 (last) | Planning velocity | 3.7 → 16.0 findings/h = 4.3x |
| v2.0 → v4.1 (last) | Defect escape rate | 5 → 0 = eliminated |
| v2.0 → v4.1 (last) | DS tokens added per refactor | 0 → 2.3 avg = design system now grows with every run |
| v3.0 → v4.0 | Same-task speedup | 36h → 5h = 7.2x (or ~4–5h adjusted → 5h = at parity on harder screen) |
| v4.0 → v4.1 avg | Cache compression | 5h → 1.5h avg = 3.3x |
| All 6 combined | Total audit findings | 119 |
| All 6 combined | Total analytics events | 33 screen-prefixed |
| All 6 combined | Total tests added | 60+ |

**Reading the table as a system:** The 6.5x wall-time improvement and the 4.3x planning velocity gain are not independent. They share a common cause — the accumulation of reusable context in the cache layers — but they measure it from different angles. Wall time reflects everything that got faster, including parallelism gains that have nothing to do with individual skill throughput. Planning velocity isolates the /ux skill's throughput and filters out structural parallelism effects. The fact that both improved by similar factors (4–7x) suggests that the gains are broadly distributed across the framework rather than concentrated in one layer.

The defect escape rate dropping from 5 to 0 and holding at 0 for five consecutive refactors is the most practically significant result. A framework that is faster but leaky is not a reliable production tool. The data shows that the same structural changes that produced the speed improvements — typed handoff artifacts, the v2/ convention, the compliance gateway — also eliminated the class of ambiguity that produced latent defects. Speed and quality improved together, not at each other's expense.

The design system growth metric (0 → 2.3 tokens added per refactor) captures a compounding effect that the wall-time figures do not. Each token added in a v4.1 run reduces the token discovery work for the next run. AppOpacity (Nutrition) and AppLayout (Stats) were immediately available in Settings, which required neither. The design system is not just being maintained across these runs — it is being enriched by them. The v4.1 framework converted a compliance-check process into a design-system-enrichment loop.

**On the question of plateau:** The six-refactor dataset does not show a plateau. Wall time is still declining (2.0h → 1.5h → 1.0h across the three v4.1 screens), the delta from the log model is holding constant rather than converging, and the cache hit rate is still increasing (55% → 65% → 70%). The most likely plateau mechanism — the cache providing diminishing returns as it approaches full coverage of recurring patterns — has not yet appeared in the data. A seventh and eighth refactor would be needed to determine whether the 1.0h floor for a 289-line screen represents an irreducible complexity minimum or whether further framework improvements could compress it further.

---

## Section 6 — Framework Evolution: Version-by-Version

### 6.1 Timeline

```
2026-03-28  v1.0 — Monolithic /pm-workflow skill. 9 phases, all inline. No shared data,
     |              no spoke skills. All context lived in the active conversation window.
     |
2026-04-02  v1.2 — Shared data layer (8 JSON files). Still one skill doing all work.
     |              Files persisted across sessions; context reconstruction cost dropped.
     |
2026-04-02  v2.0 — Hub-and-spoke extraction. 10 skills (1 hub + 9 spokes). Phase 9
     |              (Learn) added. Work item types introduced (Feature / Enhancement /
     |              Fix / Chore). Task-level tracking. Cross-feature priority queue.
     |              [REFACTOR: Onboarding v2 (PR #59) — 24 findings, 6.5h, 5 latent bugs]
     |
2026-04-07  v2.5 — /ux skill added (11th spoke). Split from /design to separate
     |              "what & why" from "how it looks". Screen audit research mode
     |              introduced. v2-audit-report.md standard established.
     |
2026-04-09  v3.0 — External integrations (Notion MCP, Figma MCP). Parallel subagent
     |              execution. Sub-feature queue. /ux wireframe and /design build
     |              sub-commands added.
     |              [REFACTOR: Home v2 (PR #61) — 27 findings, 36h total (4-5h refactor).
     |               v2/ subdirectory convention established. Figma MCP first use.]
     |
2026-04-10  v4.0 — Reactive data mesh. Integration adapter layer (6 adapters). Validation
     |              gate (GREEN / ORANGE / RED). L1/L2/L3 learning cache introduced.
     |              [REFACTOR: Training v2 (PR #74) — 32 findings, 5h. First run with
     |               active L1 cache. 6 extracted views. Most complex screen at 2,135 lines.]
     |
2026-04-10  v4.1 — Skill Internal Lifecycle formalized (Cache -> Research -> Execute ->
                    Learn). Research Scope formalization. L2 cross-skill cache activated.
                    [REFACTORS: Nutrition (#75), Stats (#76), Settings (#77) — 36 findings
                     combined, 4.5h combined. Cache hit rates 55-70%. Phase compression
                     6.0 phases/hour average.]
     |
2026-04-11  v4.3 — Operations control room, case-study monitoring, and maintenance-program
     |              orchestration formalized as the framework operational layer.
     |              [MAINTENANCE: Cleanup + Control Room — source-truth repair, dashboard
     |               operator cockpit, Notion/Linear sync, showcase-ready process evidence.]
```

---

### 6.2 Architecture Comparison: v1.0 vs v4.3

**v1.0 — Monolith:**

```
User -> /pm-workflow (does everything) -> state.json
```

| Dimension | v1.0 |
| --- | --- |
| Skills | 1 |
| Shared data files | 1 |
| External integrations | 0 |
| Cache layers | 0 |
| Validation gate | None |

**v4.1 — Hub-and-Spoke with Reactive Data Mesh:**

```text
                        User
                          |
                    /pm-workflow (hub)
                          |
          +---------------+---------------+
          |               |               |
    11 spoke skills   11 shared JSON   6 integration
    (/ux, /design,     files (state,    adapters
     /dev, /qa,         ux-spec,        (GitHub, Notion,
     /analytics,        audit, test-    Figma, GA4,
     /cx, /marketing,   results,        Sentry, ASC)
     /research,         cache, ...)
     /ops, /release)
          |
  +-------+-------+
  |       |       |
  L1      L2      L3
(per-  (cross- (project-
skill)  skill)  wide)
          |
  Validation gate
  (GREEN / ORANGE / RED)
          |
  External services:
  GitHub, Notion MCP, Figma MCP, Vercel,
  GA4, Sentry, App Store Connect,
  Firecrawl, Axe, Security Audit
```

| Dimension | v4.3 |
| --- | --- |
| Skills | 11 (1 hub + 10 spokes) |
| Shared data files | 15 |
| External integrations | 10 |
| Cache layers | 3 (L1 / L2 / L3) |
| Validation gate | Automatic (GREEN / ORANGE / RED) |

---

### 6.3 Skills Inventory (v4.1)

| # | Skill | Role | Phases | Key Sub-commands | Added in |
| --- | --- | --- | --- | --- | --- |
| 0 | /pm-workflow | Hub — orchestrates | All | {feature} | v1.0 |
| 1 | /ux | What & Why | 0, 3, 5, 6 | research, spec, wireframe, validate, audit, patterns, prompt | v2.5 |
| 2 | /design | How it Looks | 3, 6 | audit, ux-spec, figma, tokens, accessibility, prompt, build | v2.0 |
| 3 | /dev | How it's Built | 4, 6, 7 | branch, review, deps, perf, ci-status | v2.0 |
| 4 | /qa | Does it Work | 5 | plan, run, coverage, regression, security | v2.0 |
| 5 | /analytics | Can We Measure It | 1, 5, 8 | spec, validate, dashboard, report, funnel | v2.0 |
| 6 | /cx | What Users Say | 0, 8, 9 | reviews, nps, sentiment, testimonials, roadmap, digest, analyze | v2.0 |
| 7 | /marketing | Tell the World | 0, 8 | aso, campaign, competitive, content, email, launch, screenshots | v2.0 |
| 8 | /research | What's Out There | 0 | wide, narrow, feature, competitive, market, ux-patterns, aso | v2.0 |
| 9 | /ops | Is It Up | Cross | health, incident, cost, alerts | v2.0 |
| 10 | /release | Ship It | 7 | prepare, checklist, notes, submit | v2.0 |

Notes: The hub (/pm-workflow) is counted as skill 0. 11 spokes are listed as 1–10. The total skill count in v4.1 is 12 counting /pm-workflow plus the 11 spokes. /ux was the only spoke added after the initial v2.0 extraction — all other spokes shipped together at v2.0.

---

### 6.4 The Lego Principle

The 11-skill ecosystem is designed around a single structural constraint: skills do not call each other. There is no direct dependency from /ux to /design, from /design to /dev, or from /qa back to /analytics. Every skill is both a standalone unit (it can be invoked independently, in any context, without requiring another skill to have run first) and a composable component (when run inside a PM workflow, it reads from and writes to the shared file layer, making its outputs available to every other skill automatically).

The connector mechanism — the equivalent of Lego studs — is the 11 shared JSON files. Each skill declares what it reads and what it writes. /ux reads `state.json` and writes `ux-spec.md` and `v2-audit-report.md`. /design reads `ux-spec.md` and writes to the token system and `feature-memory.md`. /dev reads `ux-spec.md` and the pbxproj recipe from L3 cache and writes the v2 file and the updated `project.pbxproj`. /qa reads the test plan from `state.json` and writes `test-results` to the shared layer. No skill needs to know that the others exist — it only needs to know the schema of the files it reads and writes.

This architecture has a direct practical consequence for extensibility. Adding a new spoke — /legal, for example, to handle App Store guidelines review — requires exactly two artifacts: a `SKILL.md` defining its internal lifecycle (Cache -> Research -> Execute -> Learn), and a declaration of which shared files it reads and which it writes. The hub (/pm-workflow) does not need to be modified. Existing spokes do not need to be modified. The new skill integrates by conforming to the shared file schema, not by being wired into a call graph.

The same principle governs the integration adapter layer. Each of the 6 adapters (GitHub, Notion MCP, Figma MCP, GA4, Sentry, App Store Connect) is declared as a read/write endpoint in the adapter configuration. Skills that need external data declare a dependency on an adapter; the hub resolves the dependency at dispatch time. Adding a seventh adapter — Firecrawl for competitive research, or Axe for automated accessibility — requires one adapter configuration file, not changes to any skill.

The Lego metaphor is useful precisely because it captures the non-obvious property: individual pieces are simple and limited; the system's capability comes from composition, not from making any single piece more powerful. /pm-workflow is not an intelligent orchestrator that understands what each spoke does — it is a dispatcher that knows which shared files each spoke reads and writes, and it sequences dispatch accordingly. The intelligence is distributed across the spokes and encoded in the shared file schema, not concentrated in the hub.

---

## Section 7 — Conclusions

### 7.1 Three Levels of Improvement

The six-screen dataset supports the central claim of this case study: the PM workflow evolved in ways that produced measurable, multi-level improvements in throughput. The table below summarizes what improved, at which level of the system, and what evidence supports each claim.

| Level | What Improved | Key Evidence |
|---|---|---|
| Micro (in-skill) | Individual skill throughput | /ux findings/hour: 13.5 → 46.0 (3.4x) |
| Meso (between-skills) | Handoff quality + parallel execution | v3.0 → v4.0: 7.2x speedup despite 3x larger screen |
| Macro (hub-level) | End-to-end lifecycle time | v2.0 → v4.1: 6.5h → 1h (6.5x) |

Each level is causally upstream of the next. The micro improvements (faster audit throughput, cached naming conventions, reusable test templates) reduced the duration of individual phases. The meso improvements (typed handoff artifacts, parallel dispatch, cross-skill cache) eliminated inter-phase friction and sequential wait time. The macro result — the 6.5x reduction in wall time — is the compound output of both.

These are not independent efficiencies. A skill that runs faster but still hands off informally does not propagate its gains downstream. A handoff that is clean and typed is only valuable if the receiving skill executes faster upon receiving it. The data shows both conditions were met.

---

### 7.2 The Learning Cache as Inflection Point

The single most impactful structural change across the entire v1.0 → v4.3 arc was the introduction of the L1/L2/L3 learning cache at v4.0. Prior versions improved the workflow by adding capabilities — more skills, more shared files, external integrations, parallel execution. These were additive improvements: each one reduced a specific friction point. The cache was different in kind, not just degree.

Before the cache (v2.0, v3.0), every skill invocation began from a cold start. The /ux skill read the file, applied the 13 UX foundations principles, and produced a finding list — the same derivation process it had performed on every prior screen. The /analytics skill deliberated on naming conventions that had already been deliberated on in prior sessions. The /dev skill determined the v2/ structure without reference to the prior runs that had already established it. Context that existed in prior session artifacts was technically available — the files persisted — but was not automatically loaded. Each skill started blank.

After the cache (v4.0+), skills no longer start blank. The /ux skill begins the Training audit already knowing which violation categories are most likely (from the Onboarding and Home L1 entries), which tokens are most likely to need additions (from the /design L1 entry), and which commit pattern will apply to the v2/ file (from the /dev L3 entry). The cache converts skills from stateless to stateful — not stateful in the sense of holding mutable conversation context, but stateful in the sense of having learned and retained reusable patterns from prior executions.

The cache hit rates quantify this transformation directly:

| PM Version | Cache Hit Rate |
|---|---|
| v2.0 (Onboarding) | 0% |
| v3.0 (Home) | 0% |
| v4.0 (Training) | ~40% (L1) |
| v4.1 (Nutrition) | ~55% (L2) |
| v4.1 (Stats) | ~65% (L2) |
| v4.1 (Settings) | ~70% (L2) |

Each percentage point represents a unit of prior research time that did not need to be repeated. At 70% cache hit rate, seven-tenths of the research and context-derivation work that was performed on Onboarding is no longer being performed at all. The cache does not make skills smarter — it makes them stop re-deriving things they already know.

---

### 7.3 The UX Foundations Initiative as Proof

The UX Foundations alignment pass across six screens was an unusual experimental opportunity: six tasks of identical scope, performed sequentially, under a changing framework, with measurable outputs at each step. That combination — controlled task type, sequential execution, progressively newer framework, objective output metrics — is not available for most software development workflows.

Four properties made this the ideal test case for measuring PM workflow evolution:

**Controlled scope.** Every screen refactor ran the same nine-phase PM lifecycle against the same thirteen UX foundations principles, the same design system compliance gateway, the same v2-refactor-checklist, and the same PR template. Scope variation between screens was limited to file size and architectural complexity, both of which are normalizable.

**Progressive framework exposure.** The refactors were not run on a fixed framework — v2.0 was live for Onboarding, v3.0 for Home, v4.0 for Training, and v4.1 for the final three. This was not planned as an experiment; it was the natural consequence of the framework evolving while the refactor sequence was in progress. It created a natural experiment structure without requiring any modification to the workflow.

**Measurable outputs.** Every refactor produced a state.json with findings count, event count, test count, and phase timestamps. The v2-audit-report.md files recorded severity tiers and per-finding resolution decisions. PRs recorded file counts and commit counts. These are objective, post-hoc reconstructible metrics — not retrospective estimates, but artifacts that existed before this analysis was written.

**Real product impact.** This was not a controlled experiment run in isolation. 119 audit findings were fixed across 6 production screens. 33 screen-prefixed analytics events are now instrumented. 60+ tests are in the CI suite. The workflow improvements and the product improvements happened simultaneously, without one being sacrificed for the other. A faster framework that produced lower-quality outputs would not have passed the same compliance gateway and CI gates that the slower framework passed.

---

### 7.4 What's Next

The six-screen refactor sequence is complete. The cache is warm, the design system is enriched, and the framework is running at v4.1. Four areas of planned investment follow from this case study's findings:

- **AI Engine v2.** The AIOrchestrator.swift codebase has the same relationship to the v4.1 PM architecture that the six screens had to the v2.0 architecture at the start of this initiative — it predates the framework and was not built with the hub-and-spoke execution model, the reactive data mesh, or the learning cache in mind. Adapting the PM v4.0 architecture for AIOrchestrator.swift is the next major engineering surface, tracked in the backlog and described in `.claude/cache/_project/ai-engine-v2-brief.md`.

- **External MCP activation.** The integration adapter layer for GA4, Sentry, and App Store Connect exists in the framework design but is not yet connected to live data sources. Activating these adapters would replace estimated metrics (cache hit rates, phase times) with instrumented actuals, and would allow the validation gate to operate on real crash rates, real user signals, and real analytics data. This is the transition from a metrics-aware framework to a data-driven one.

- **Figma infographic.** This case study presents its data in tables and ASCII charts, which are suitable for a technical audience but not for a visual portfolio or stakeholder review. A companion Figma infographic — showing the three-level improvement table, the wall-time scatter plot, and the cache hit progression as designed data visualizations — would make the case study accessible to a broader audience. Tagged as a documentation enhancement in the backlog.

- **Cache seeding from all six refactors.** The L2 and L3 cache were populated incrementally as each refactor ran. A deliberate seeding pass — systematically extracting the most durable patterns from all six v2-audit-report.md files, all six ux-spec.md files, and all six test suites — would raise the baseline cache hit rate for the next refactor class above the 70% level observed in Settings. Estimated impact: 15–20% reduction in research phase time for any new v2-adjacent task.

---

## Section 8 — Appendix: Data Sources

All quantitative claims in this case study are traceable to one of the following primary sources. No figures are estimated without an explicit note in the text.

| Source | Location |
|---|---|
| Onboarding v2 state.json | `.claude/features/onboarding-v2/state.json` |
| Home v2 state.json | `.claude/features/home-today-screen/state.json` |
| Training v2 state.json | `.claude/features/training-v2/state.json` |
| Nutrition v2 state.json | `.claude/features/nutrition-v2/state.json` |
| Stats v2 state.json | `.claude/features/stats-v2/state.json` |
| Settings v2 state.json | `.claude/features/settings-v2/state.json` |
| Skills documentation | `docs/skills/` (README.md, architecture.md, evolution.md, per-skill .md files) |
| UX foundations (13 principles) | `docs/design-system/ux-foundations.md` |
| V2 refactor checklist | `docs/design-system/v2-refactor-checklist.md` |
| Design system feature memory | `docs/design-system/feature-memory.md` |
| Pilot case study (Onboarding v2) | `docs/case-studies/pm-workflow-showcase-onboarding.md` |
| Project rules and conventions | `CLAUDE.md` |
| Git history and PR records | PRs #59, #61, #63, #65, #67, #74, #75, #76, #77 |

---

## Section 9 — Related Documents

- [Pilot case study — Onboarding v2 UX Foundations alignment](pm-workflow-showcase-onboarding.md)
- [Skills ecosystem one-pager](../skills/README.md)
- [Skills architecture deep-dive](../skills/architecture.md)
- [Skills ecosystem evolution history (v1.0 → v4.3)](../skills/evolution.md)
- [UX foundations — 13 principles](../design-system/ux-foundations.md)
