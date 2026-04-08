# FitMe Skills Ecosystem — Architecture & Usage Guide

> **Version:** 2.0 | **Updated:** 2026-04-05 | **Branch:** `claude/investigate-ci-failure-xP9kS`
>
> A new contributor (human or AI) can read this single document to understand the entire skills ecosystem — how it was built, why each piece exists, how to use each skill independently, and how they all connect through the hub.

---

## 1. Why This Exists

**Problem:** The original `/pm-workflow` (v1.2) was the only skill, doing everything inline — research, PRD writing, task breakdown, UX specs, code review, testing, deployment, and docs all lived in one monolithic skill definition. It worked, but it didn't scale:

- Adding a new domain (marketing, CX, ops) meant bloating one already-large file
- You couldn't use design audits or analytics validation without running a full PM cycle
- Cross-domain information stayed trapped inside one workflow's context

**Solution:** Hub-and-spoke architecture where each domain has its own skill, connected through a shared data layer.

**Result:** 11 skills (1 hub + 10 spokes) + 8 shared data files. Adding `/ux` in 2026-04-07 split the "what should this feature do?" planning concern out of `/design`, so `/design` now owns only the how-it-looks layer and `/ux` owns the what-and-why layer. The boundary is documented in §7.5.

**Key principle:** Every skill is a **Lego piece** (works alone) AND a **puzzle piece** (fits into the hub).

- **Lego piece** = self-contained unit with its own sub-commands, data reads/writes, and outputs. You can invoke `/cx reviews` or `/design audit` without touching the hub.
- **Puzzle piece** = follows a standard interface contract (reads shared JSON → does work → writes shared JSON → produces artifacts) so the hub can orchestrate skills in sequence.
- **The connector studs** = the shared data layer (`.claude/shared/*.json`). This is what makes skills interoperable — they don't call each other directly, they communicate through shared state.

---

## 2. The Evolution: v1.2 → v2.0

### What Changed

| Phase | v1.2 Behavior | v2.0 Behavior |
|-------|--------------|---------------|
| **0. Research** | Inline research template | Dispatches to `/research wide` + `/research narrow` + `/research feature`; pulls `/cx` signals and `/analytics` baselines |
| **1. PRD** | Inline PRD template + analytics gate | PRD template + dispatches to `/analytics spec` for instrumentation spec |
| **2. Tasks** | Inline task breakdown | Task breakdown + auto-assigns to `/dev`, `/design`, `/qa`, `/analytics` |
| **3. UX** | Inline UX spec + compliance gateway | Dispatches to `/design ux-spec` for UX spec, accessibility audit, component selection |
| **4. Implement** | Inline coding | Dispatches to `/dev branch`, code patterns, dependency check |
| **5. Test** | Inline CI check | Dispatches to `/qa plan` + `/qa run` for test plan, coverage check, regression |
| **6. Review** | Inline diff review | Dispatches to `/dev review` for code review + `/design audit` for visual review |
| **7. Merge** | Inline merge | Dispatches to `/release checklist` + `/release prepare` for version check, changelog |
| **8. Docs** | Inline doc update | Dispatches to `/marketing launch` for comms, `/cx roadmap` for support docs, `/analytics dashboard` |
| **9. Learn** | *Did not exist* | **NEW:** `/cx analyze` + `/analytics report` → assess → classify root cause → dispatch fix → loop until solved |

### The Big Shift: Linear Pipeline → Living Cycle

v1.2 was a pipeline that ended at Phase 8 (Docs). v2.0 adds Phase 9 (Learn), which makes the workflow **circular** — after shipping, the hub continuously monitors user feedback and metrics, classifies problems by root cause, and dispatches fixes to the responsible skill. The pipeline never truly ends; it feeds back into itself.

---

## 3. Architecture Overview

### Hub-and-Spoke Diagram

```
                        ┌─────────────────┐
                        │   WEB SEARCH    │
                        │  APP STORES     │
                        │  INDUSTRY DATA  │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   /research     │
                        └────────┬────────┘
                                 │ competitive data, UX patterns
                                 ▼
               ┌─────────────────────────────────────┐
               │        /pm-workflow (HUB)            │
               │   Orchestrates Phases 0-9            │
               │   Reads/writes .claude/shared/*.json │
               └──┬──────┬──────┬──────┬──────┬──────┘
                  │      │      │      │      │
          ┌───────┘   ┌──┘  ┌───┘  ┌───┘  ┌───┘
          ▼           ▼     ▼      ▼      ▼
        /ux ─→ /design /dev  /qa /analytics /release
          │           │      │      │          │
          │ (planning │      │      │          │
          │  layer)   │      │      │          │
          └──────┬────┴──────┴──────┘          │
                 │                             │
                 ▼                             ▼
          ┌─────────────┐            App Store / TestFlight
          │  App Build   │
          └──────┬──────┘
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
   /cx      /marketing     /ops
     │           │           │
     └─────┬─────┘           │
           │                 │
           ▼ feedback loops  │
     /pm-workflow ◄──────────┘
     (back to hub)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    SHARED DATA LAYER (.claude/shared/)
    context.json │ feature-registry.json
    metric-status.json │ design-system.json
    test-coverage.json │ cx-signals.json
    campaign-tracker.json │ health-status.json
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Directory Structure

```
.claude/
├── skills/                         # Skill definitions (11 skills)
│   ├── pm-workflow/SKILL.md        # Hub — orchestrates all phases
│   ├── ux/SKILL.md                 # UX planning & validation — the What & Why layer
│   ├── design/SKILL.md             # Design system, Figma, tokens, accessibility (visual)
│   ├── dev/SKILL.md                # Branching, code review, CI, deps, perf
│   ├── qa/SKILL.md                 # Test planning, coverage, regression, security
│   ├── analytics/SKILL.md          # Taxonomy, instrumentation, dashboards, funnels
│   ├── cx/SKILL.md                 # Reviews, NPS, sentiment, feedback loops
│   ├── marketing/SKILL.md          # ASO, campaigns, content, email, launches
│   ├── ops/SKILL.md                # Infrastructure, incidents, cost, alerts
│   ├── research/SKILL.md           # Cross-industry → same-category → feature-specific
│   └── release/SKILL.md            # Version bumps, changelogs, submission
│
├── shared/                         # Shared data layer (8 JSON files)
│   ├── context.json                # Global product context
│   ├── feature-registry.json       # All 16 features with status + pain points
│   ├── metric-status.json          # 40 metrics with targets + instrumentation
│   ├── design-system.json          # ~120 tokens, components, accessibility
│   ├── test-coverage.json          # Test suites, gaps, guardrail gates
│   ├── cx-signals.json             # Reviews, NPS, sentiment, keyword patterns
│   ├── campaign-tracker.json       # Campaigns, UTM convention, channels
│   └── health-status.json          # Infrastructure, CI, incidents, cost
│
├── features/                       # Per-feature state (existing)
│   └── {feature}/
│       ├── state.json              # Phase tracking, blockers, metrics
│       ├── prd.md                  # Feature PRD
│       ├── ux-spec.md              # UX specification
│       ├── test-plan.md            # Test plan
│       └── research.md             # Research notes
│
└── settings.json                   # Hooks configuration
```

### Information Flow Protocol

Every skill follows the same contract:

1. **READS** from `.claude/shared/*.json` for context
2. **WRITES** its outputs back to `.claude/shared/*.json`
3. **PRODUCES** artifacts in `docs/` or `.claude/features/`
4. **REPORTS** status that other skills can query

---

## 4. The Shared Data Layer

### context.json — Global Product Context

| Field | Purpose |
|-------|---------|
| `product` | Name, tagline, positioning, differentiators |
| `personas` | 3 personas (Consistent Lifter, Health-Conscious Professional, Data-Driven Optimizer) with traits, pain points |
| `brand` | Colors (#FA8F40 primary, #8AC7FF secondary), fonts (Inter, SF Mono) |
| `guardrails` | Crash-free >99.5%, cold start <2s, sync >99%, CI >95% |
| `north_star` | Cross-feature WAU (train + log meal in same week) |
| `competitive_landscape` | Market size ($12.12B→$33.58B), 6 competitor profiles |
| `tech_stack` | SwiftUI, HealthKit, Supabase, FastAPI, Firebase GA4, Astro+Vercel |

**Who reads:** Every skill (startup context injection)
**Who writes:** `/research` (competitive updates), `/pm-workflow` (positioning changes)

### feature-registry.json — All Features

| Field | Purpose |
|-------|---------|
| `features[]` | Array of 16 features |
| `.id` | Unique identifier (e.g., `training`, `nutrition`, `onboarding`) |
| `.status` | `shipped` or `planned` |
| `.pain_point` | Original problem this feature solves |
| `.metrics` | Target + current values per feature |
| `.prd` | Path to PRD document |

**Who reads:** `/qa` (what to test), `/analytics` (what's launched), `/cx` (pain points for feedback loops), `/release` (what's in release), `/marketing` (what to launch)
**Who writes:** `/pm-workflow` (new features), `/cx analyze` (metric updates)

**Example:**
```json
{
  "id": "training",
  "name": "Training Tracking",
  "status": "shipped",
  "pain_point": "Logging workouts across 3+ apps is tedious and fragmented",
  "metrics": { "sessions_per_week": { "target": 3, "current": null } }
}
```

### metric-status.json — 40 Metrics

| Field | Purpose |
|-------|---------|
| `categories` | 6 categories: product_engagement, health_fitness, ai_intelligence, technical_health, business_growth, customer_experience |
| Per metric: | `name`, `target`, `current`, `instrumented` (bool), `source`, `blocker` (if not instrumented) |
| `instrumentation_summary` | 14 available now, 35% instrumented overall |

**Who reads:** `/analytics` (targets), `/qa` (guardrails), `/ops` (alert thresholds), `/cx` (quantitative context)
**Who writes:** `/analytics` (updated values)

### design-system.json — Token Inventory

| Field | Purpose |
|-------|---------|
| `tokens` | ~120 total: 45 colors, 9 spacing, 9 radius, 20 typography, 8 motion, 2 shadow, 40 icons |
| `components` | Atomic (AppPickerChip, etc.), composite (AppCard, etc.), motion, modifiers |
| `accessibility` | WCAG AA, contrast validation, reduced motion |
| `android_mapping` | 92 tokens mapped, Style Dictionary config |

**Who reads:** `/design` (current inventory), `/marketing` (brand tokens for screenshots)
**Who writes:** `/design` (new tokens/components proposed)

### test-coverage.json — Quality Status

| Field | Purpose |
|-------|---------|
| `suites` | Analytics (23 tests), token pipeline (1 test), Xcode build/test status |
| `gaps` | No integration, UI, performance, security, or visual regression tests |
| `guardrail_gates` | CI pass rate, tokens-check, analytics regression — all enforced |

**Who reads:** `/qa` (what's covered), `/release` (quality gate status)
**Who writes:** `/qa` (updated coverage)

### cx-signals.json — Customer Signals

| Field | Purpose |
|-------|---------|
| `reviews` | Avg rating, count, sentiment arrays, word analysis |
| `keyword_patterns` | Positive/negative/request/confusion/friction/comparison keyword lists |
| `root_cause_dispatch` | Rules mapping confusion patterns → responsible skill |
| `confusion_signals[]` | Per-signal: text, feature, root cause, severity, dispatched_to |
| `post_deployment` | Per-feature assessments (solved/improved/status_quo/worsened/new_problem) |
| `testimonials[]` | High-value reviews for marketing |

**Who reads:** `/design` (UX confusion signals), `/marketing` (testimonials, user language), `/analytics` (qualitative context), `/pm-workflow` (backlog prioritization)
**Who writes:** `/cx` (all fields)

### campaign-tracker.json — Marketing Campaigns

| Field | Purpose |
|-------|---------|
| `campaigns[]` | Campaign definitions (currently empty — pre-launch) |
| `utm_convention` | Standardized UTM parameter format |
| `channels` | 8 channels with status (organic_search active, rest not started) |
| `attribution` | Last-touch model, no deep links yet |

**Who reads:** `/analytics` (attribution data), `/research` (marketing context)
**Who writes:** `/marketing` (campaign definitions)

### health-status.json — Infrastructure Health

| Field | Purpose |
|-------|---------|
| `infrastructure` | Railway, Supabase, CloudKit, Firebase, Vercel website/dashboard — all status unknown (pre-monitoring) |
| `ci` | Last build status, tokens-check passing |
| `quality_gates` | Crash-free, cold start, sync, CI — thresholds + alert thresholds |
| `incidents[]` | Incident log (currently empty) |
| `cost` | Monthly estimates by service (Apple Developer $99/yr confirmed, rest TBD) |

**Who reads:** `/qa` (quality gates), `/ops` (everything), `/dev` (CI status)
**Who writes:** `/ops` (health updates), `/dev` (CI results), `/qa` (quality gate status)

---

## 5. The Lego Principle — Every Skill Stands Alone

### Dual-Use Design

Every skill in the ecosystem serves two roles:

**STANDALONE mode:** Invoke any skill directly for a specific task, without running a full PM cycle. The skill reads its needed context from shared data, does its work, writes its outputs, and reports results.

**INTEGRATED mode:** The hub (`/pm-workflow`) invokes skills automatically at the right phase. The skill receives the same context but as part of an orchestrated sequence.

### The Mechanism

What makes this work is the **shared data layer as connector studs**:

1. Every skill declares what it READS and WRITES (like Lego brick connection points)
2. Shared JSON files are the physical connections — they hold state between skill invocations
3. The hub orchestrates the ORDER of invocation, but each skill is self-sufficient

**Analogy:** A Lego brick (say, a 2x4) works perfectly as a standalone building block. But it also has a specific shape (interface) that lets it snap into a larger structure. The studs on top and tubes underneath are the shared data contracts.

### Why This Matters

- **Flexibility:** A solo founder can use `/design audit` at 2 AM without running a 10-phase cycle
- **Composability:** The hub can skip skills that aren't relevant to a particular feature
- **Extensibility:** Adding a new skill (e.g., `/legal`) means creating one SKILL.md and declaring its shared data reads/writes — no hub modification needed (graceful fallback)

---

## 6. /pm-workflow — The Hub

**What it does:** Orchestrates the complete product management lifecycle for a feature through 10 phases (0-9), dispatching to domain skills at each phase.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/pm-workflow {feature}` | Start or resume full lifecycle | "Start the onboarding feature" | N/A — this IS the hub |
| Phase transitions | Move between phases with approval gates | "Move to Phase 4" | Automatic at each gate |

### Shared Data

| Reads | Writes |
|-------|--------|
| `context.json` (startup injection) | `feature-registry.json` (new features) |
| `feature-registry.json` (resume state) | Per-feature `state.json` |
| All shared files (phase-dependent) | Phase-specific outputs |

### Key Features

- **State management:** `.claude/features/{name}/state.json` tracks current phase, blockers, metrics, history
- **GitHub Issue sync:** Bidirectional sync between state.json and GitHub Issue labels (`phase:0-research`, etc.)
- **Approval gates:** Every phase requires explicit user approval before proceeding
- **Graceful fallback:** If a dispatched skill doesn't exist yet, falls back to inline behavior
- **Manual override:** "Move to {phase}" or "Roll back to {phase}" for flexibility

### Standalone Usage

```
/pm-workflow onboarding       → Start/resume the onboarding feature lifecycle
/pm-workflow training          → Check status of training (already shipped)
"Move to Phase 4"             → Skip ahead (with confirmation)
"Roll back to Phase 1"        → Revisit PRD (with confirmation)
```

### Hub Integration

This IS the hub. Every other skill is dispatched FROM here.

---

## 7. /design — Design & UX

**What it does:** Manages design system governance, creates UX specs from PRDs, generates Figma build prompts, validates the token pipeline, and enforces WCAG AA accessibility.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/design audit` | Design system compliance check | "Check if this PR's UI changes comply with the design system" | Phase 6 (Review) |
| `/design ux-spec {feature}` | Generate UX spec from PRD | "Create UX spec for the onboarding flow" | Phase 3 (UX) |
| `/design figma {feature}` | Generate Figma build prompt | "Generate Figma prompt for the stats redesign" | Phase 3 (UX) |
| `/design tokens` | Validate token pipeline | "Check if DesignTokens.swift matches tokens.json" | Phase 6 (Review) |
| `/design accessibility` | WCAG AA audit | "Run accessibility audit on the nutrition screens" | Phase 6 (Review) |

### Shared Data

| Reads | Writes |
|-------|--------|
| `context.json` (brand, personas) | `design-system.json` (new tokens/components) |
| `design-system.json` (current inventory) | |
| `cx-signals.json` (UX confusion signals) | |

### Key References

- `FitTracker/Services/AppTheme.swift` — semantic token layer
- `FitTracker/DesignSystem/AppComponents.swift` — reusable components
- `docs/design-system/feature-development-gateway.md` — 7-stage workflow
- `docs/design-system/approval-process.md` — governance rules

### Standalone Usage Examples

1. **Quick compliance check:** `/design audit` → "I just changed the nutrition view, check if it follows the design system"
2. **UX for a new feature:** `/design ux-spec onboarding` → Generates full UX spec with all states, accessibility, and token mapping
3. **Figma automation:** `/design figma onboarding` → Generates a copy-paste prompt for Figma MCP

### Hub Integration

- **Phase 3 (UX):** Hub dispatches `/design ux-spec` and `/design figma`
- **Phase 6 (Review):** Hub dispatches `/design audit` for visual review

### Connections

- Receives UX confusion signals from `/cx` (via `cx-signals.json`)
- Feeds component specs to `/dev` (via `design-system.json`)
- Receives personas and brand from `/pm-workflow` (via `context.json`)
- **Receives UX research and specs from `/ux`** (via `ux-research.md` + `ux-spec.md` in `.claude/features/{name}/`)

---

## 7.5 /ux — UX Planning & Validation

**What it does:** Ensures every UI feature is grounded in research-backed UX principles *before* visual design or code implementation begins. `/ux` is the planning layer that feeds `/design` and `/dev` — the What & Why before the How it Looks and How it's Built.

**Added:** 2026-04-07 (PR #59) as the UX planning layer for the PM workflow hub. Pilot run was the Onboarding v2 UX Foundations alignment pass.

### Boundary: /ux vs /design

| Concern | `/ux` | `/design` |
|---------|-------|-----------|
| What & Why | User flows, behavior, heuristics, patterns | — |
| How it Looks | — | Tokens, components, Figma, compliance |
| Research | Principles, HIG, competitive UX | Market positioning, visual trends |
| Validation | Heuristic evaluation, cognitive walkthrough | Token compliance, contrast, motion |
| Accessibility | Usability (clarity, cognitive load, feedback) | Technical (WCAG AA, VoiceOver, tap targets) |

**Handoff:** `/ux` produces `ux-research.md` + `ux-spec.md` → `/design` validates against the design system → `/dev` implements.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/ux research {feature}` | UX principle audit from the 13 ux-foundations heuristics (8 core + 5 FitMe-specific) | "Research UX principles for the training plan redesign" | Phase 3 (UX), **Phase 0 Research for v2 refactors** |
| `/ux spec {feature}` | Generate `ux-spec.md` with Principle Application Table, screen flows, and state coverage | "Create ux-spec for the stats hub" | Phase 3 (UX) |
| `/ux validate {feature}` | Heuristic evaluation of a proposed spec or shipped surface against ux-foundations.md | "Validate the current onboarding flow against Hick's Law" | Phase 3 (UX) and Phase 6 (Review) |
| `/ux audit` | Full UX audit — walks a v1 surface against ux-foundations.md and produces `v2-audit-report.md` with P0/P1/P2 severity and tractability tags | "Audit MainScreenView.swift for UX Foundations compliance" | **Phase 0 for v2 refactors** |
| `/ux patterns` | Surface existing FitMe interaction patterns for reuse before introducing new ones | "What existing patterns already handle a biometric entry flow?" | Phase 3 (UX) |

### Shared Data

| Reads | Writes |
|-------|--------|
| `context.json` (personas, positioning) | `ux-research.md` in `.claude/features/{name}/` |
| `design-system.json` (current inventory) | `ux-spec.md` in `.claude/features/{name}/` |
| `docs/design-system/ux-foundations.md` (the 13 principles) | `v2-audit-report.md` in `.claude/features/{name}/` (refactors) |
| `.claude/features/{name}/research.md` (PRD research phase) | `docs/design-system/v2-refactor-checklist.md` Section A ticks |

### Key References

- `docs/design-system/ux-foundations.md` — 13 principles (8 core UX heuristics + 5 FitMe-specific) + IA + states + accessibility + motion + content strategy
- `docs/design-system/v2-refactor-checklist.md` — Sections A/E/F/G/H owned by `/ux`
- `docs/design-system/feature-development-gateway.md` — 7-stage workflow that `/ux` walks
- `docs/design-system/feature-design-checklist.md` — per-feature design checklist
- Apple HIG — external reference for iOS platform conventions

### Standalone Usage Examples

1. **Audit an existing screen before refactor:** `/ux audit` → "Audit `MainScreenView.swift` against `ux-foundations.md` and produce severity-graded findings for the v2 pass"
2. **Research principles for a new feature:** `/ux research barcode-scanning` → Identifies which of the 13 principles apply, cites HIG sources, flags risks
3. **Generate a ux-spec:** `/ux spec stats-hub-v2` → Creates `ux-spec.md` with Principle Application Table, 5-state coverage, and a11y requirements
4. **Validate a shipped surface:** `/ux validate settings` → Heuristic evaluation with concrete fix suggestions
5. **Find existing patterns:** `/ux patterns` → "Is there an existing inline-edit pattern I should reuse, or do I need a new one?"

### Hub Integration

- **Phase 0 (Research, v2 refactor only):** Hub dispatches `/ux audit` to produce `v2-audit-report.md` as the gap analysis that drives the rest of the lifecycle.
- **Phase 3 (UX Definition):** Hub dispatches `/ux research` → `/ux spec` → `/ux validate` in sequence. The design system compliance gateway (Phase 3) is where `/ux` handoff to `/design` happens.
- **Phase 6 (Review):** Hub dispatches `/ux validate` as a heuristic sanity check before merge approval, in parallel with `/design audit`.

### Connections

- **Feeds `/design`:** `ux-spec.md` is the input to `/design ux-spec` and `/design figma`. `/ux` defines the what; `/design` defines the how it looks.
- **Feeds `/dev`:** The Principle Application Table in `ux-spec.md` becomes the acceptance criteria that `/dev` implements against.
- **Receives from `/research`:** Competitive UX patterns surfaced by `/research narrow` feed `/ux research` as market context.
- **Receives from `/cx`:** UX confusion signals from `cx-signals.json` surface existing pain points that inform `/ux audit` findings.
- **Gates `/pm-workflow` Phase 3:** No UI feature advances from Phase 3 without an approved `ux-spec.md`. Non-skippable for new UI features (per the V2 Rule in CLAUDE.md).

---

## 8. /dev — Development

**What it does:** Manages branching strategy, runs code review checklists (flagging high-risk files and security issues), checks dependency health, profiles performance, and monitors CI status.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/dev branch {feature}` | Create correctly named branch | "Create a feature branch for push-notifications" | Phase 4 (Implement) |
| `/dev review` | Code review checklist | "Review my current diff for security and perf issues" | Phase 6 (Review) |
| `/dev deps` | Dependency health check | "Are there any vulnerable dependencies?" | Phase 4 (Implement) |
| `/dev perf` | Performance profiling | "Profile cold start and main thread blockers" | Phase 4 (Implement) |
| `/dev ci-status` | CI pipeline status | "What's the current CI status?" | Phase 7 (Merge) |

### Shared Data

| Reads | Writes |
|-------|--------|
| `feature-registry.json` (features in flight) | `health-status.json` (build status, CI) |
| `test-coverage.json` (coverage) | |
| `health-status.json` (CI status) | |

### Key References

- `.github/workflows/ci.yml` — CI pipeline
- `CLAUDE.md` — branching strategy, high-risk files list
- `Makefile` — token pipeline targets

### Standalone Usage Examples

1. **Branch creation:** `/dev branch push-notifications` → Creates `feature/push-notifications` from main
2. **Pre-PR review:** `/dev review` → Scans diff for high-risk file changes, security issues, perf problems
3. **Dependency audit:** `/dev deps` → Checks SPM + npm for vulnerabilities and updates

### Hub Integration

- **Phase 4 (Implement):** Hub dispatches `/dev branch` for setup
- **Phase 6 (Review):** Hub dispatches `/dev review` for code review
- **Phase 7 (Merge):** Hub dispatches `/dev ci-status` for merge readiness

### Connections

- Reads test coverage from `/qa` (via `test-coverage.json`)
- Writes CI status consumed by `/release` (via `health-status.json`)
- Receives functionality bug dispatches from `/cx` (via root cause classification)

---

## 9. /qa — Quality Assurance

**What it does:** Creates test plans from PRD acceptance criteria, executes test suites, measures coverage, runs regression checks, and performs security audits against OWASP Mobile Top 10.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/qa plan {feature}` | Generate test plan from PRD | "Create test plan for the onboarding feature" | Phase 5 (Test) |
| `/qa run` | Execute test suite | "Run all tests and report" | Phase 5 (Test) |
| `/qa coverage` | Coverage report by feature | "Which features have test gaps?" | Phase 5 (Test) |
| `/qa regression` | Post-merge regression | "Run regression on main after merge" | Phase 7 (Merge) |
| `/qa security` | OWASP security audit | "Run security audit on the auth module" | Phase 5 (Test) |

### Shared Data

| Reads | Writes |
|-------|--------|
| `feature-registry.json` (what to test) | `test-coverage.json` (coverage per feature) |
| `metric-status.json` (quality guardrails) | `health-status.json` (quality gate status) |

### System Guardrails (must NEVER degrade)

- Crash-free rate > 99.5%
- Cold start < 2s
- Sync success rate > 99%
- CI pass rate > 95%

### Standalone Usage Examples

1. **Test planning:** `/qa plan onboarding` → Generates test cases from PRD acceptance criteria with effort estimates
2. **Quick test run:** `/qa run` → Executes `make tokens-check` + `xcodebuild build` + `xcodebuild test`
3. **Security check:** `/qa security` → Checks encryption (AES-256-GCM), Keychain ACL, JWT handling, PII exposure

### Hub Integration

- **Phase 5 (Test):** Hub dispatches `/qa plan` + `/qa run`
- **Phase 7 (Merge):** Hub dispatches `/qa regression`

### Connections

- Writes coverage consumed by `/dev` and `/release` (via `test-coverage.json`)
- Receives functionality bug dispatches from `/cx` alongside `/dev`

---

## 10. /analytics — Analytics & Data

**What it does:** Manages the GA4 event taxonomy, generates instrumentation specs from PRDs, validates that code events match the taxonomy CSV, creates dashboard templates, defines funnels, and produces metric reports.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/analytics spec {feature}` | Generate analytics spec | "What events should onboarding fire?" | Phase 1 (PRD) |
| `/analytics validate` | Verify events match taxonomy | "Are all our events properly instrumented?" | Phase 5 (Test) |
| `/analytics dashboard {feature}` | Dashboard template | "Create a GA4 dashboard for training metrics" | Phase 8 (Docs) |
| `/analytics report` | Weekly metrics digest | "How are our metrics trending?" | Phase 9 (Learn) |
| `/analytics funnel {name}` | Define conversion funnel | "Define the onboarding completion funnel" | Phase 1 (PRD) |

### Shared Data

| Reads | Writes |
|-------|--------|
| `metric-status.json` (targets, baselines) | `metric-status.json` (updated values) |
| `feature-registry.json` (what's launched) | |
| `cx-signals.json` (qualitative context) | |
| `campaign-tracker.json` (attribution) | |

### Key References

- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — event/param/screen enums
- `docs/product/analytics-taxonomy.csv` — full event taxonomy
- `docs/product/metrics-framework.md` — 40 metric definitions
- `FitTrackerTests/AnalyticsTests.swift` — 23 analytics unit tests

### Standalone Usage Examples

1. **Taxonomy audit:** `/analytics validate` → Cross-references AnalyticsEvent enum ↔ taxonomy CSV ↔ test coverage
2. **Metric check:** `/analytics report` → Weekly digest: 14 metrics active, 35% instrumented, gaps highlighted
3. **Funnel definition:** `/analytics funnel onboarding` → Defines steps: app_open → profile_setup → healthkit_connect → first_workout

### Hub Integration

- **Phase 1 (PRD):** Hub dispatches `/analytics spec` for instrumentation requirements
- **Phase 5 (Test):** Hub dispatches `/analytics validate` for instrumentation verification
- **Phase 8 (Docs):** Hub dispatches `/analytics dashboard` for monitoring setup
- **Phase 9 (Learn):** Hub dispatches `/analytics report` for post-launch metrics

### Connections

- Reads qualitative context from `/cx` (via `cx-signals.json`) to correlate quant + qual
- Reads attribution from `/marketing` (via `campaign-tracker.json`)
- Feeds metric status to `/ops` for alert thresholds

---

## 11. /cx — Customer Experience

**What it does:** The most complex spoke skill. Monitors App Store reviews with deep keyword analysis, runs NPS surveys, performs sentiment analysis with root cause classification, extracts testimonials, manages the public roadmap, and — most critically — runs post-deployment feedback loops that connect user signals back to original feature pain points.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/cx reviews` | Scrape and analyze reviews | "Analyze our latest App Store reviews" | Phase 0 (Research) |
| `/cx nps` | Design/analyze NPS survey | "Design an NPS survey for our active users" | Phase 8 (Docs) |
| `/cx sentiment` | Keyword/sentiment analysis | "What themes are emerging from user feedback?" | Continuous |
| `/cx testimonials` | Extract marketing-ready quotes | "Find our best testimonials for the App Store listing" | Continuous |
| `/cx roadmap` | Generate public roadmap | "Create a public roadmap page from our GitHub issues" | Phase 8 (Docs) |
| `/cx digest` | Weekly CX summary | "What's the CX picture this week?" | Continuous |
| `/cx analyze {feature}` | Post-deployment feedback loop | "Did the training feature solve the original pain point?" | **Phase 9 (Learn)** |

### Shared Data

| Reads | Writes |
|-------|--------|
| `feature-registry.json` (pain points) | `cx-signals.json` (ALL fields) |
| `metric-status.json` (quant context) | |
| `health-status.json` (tech context) | |

### Deep Feedback Analysis Engine

The CX skill doesn't just categorize reviews — it classifies them by **signal type** and **root cause**:

**Signal Types:** Positive, Negative, Feature Request, Confusion, Friction, Comparison — each with specific keyword patterns stored in `cx-signals.json → keyword_patterns`.

**Root Cause Classification** (for negative/confusion signals):

| Root Cause | Example Signal | Dispatched To |
|-----------|---------------|--------------|
| Messaging | "what does this do", "I thought it would..." | `/marketing` |
| UX | "how do I", "can't find", "confusing navigation" | `/design` |
| Functionality | "doesn't work", "broken", "bug" | `/dev` + `/qa` |
| Expectation mismatch | "I expected", "not what I wanted" | `/pm-workflow` |

### Post-Deployment Assessment Categories

| Assessment | Meaning | Action |
|-----------|---------|--------|
| **Solved** | Pain point eliminated | Celebrate, marketing fuel |
| **Improved** | Reduced but not eliminated | Plan iteration |
| **Status Quo** | No measurable change | Investigate discoverability/messaging |
| **Worsened** | New confusion introduced | UX emergency review |
| **New Problem** | Solved original, created new | New PRD cycle |

### Standalone Usage Examples

1. **Review analysis:** `/cx reviews` → "Paste our latest 50 App Store reviews" → Categorizes by signal type, extracts themes
2. **Feature health check:** `/cx analyze training` → "Did training solve 'Logging is tedious'?" → Assessment with evidence
3. **Weekly digest:** `/cx digest` → Aggregates all signals, highlights actionable items for PM

### Hub Integration

- **Phase 0 (Research):** Hub pulls CX signals for user pain points
- **Phase 8 (Docs):** Hub dispatches `/cx roadmap` for public roadmap
- **Phase 9 (Learn):** Hub dispatches `/cx analyze {feature}` — the feedback loop

### Connections

- Dispatches to `/marketing` (messaging fixes), `/design` (UX fixes), `/dev`+`/qa` (bug fixes), `/pm-workflow` (PRD rescope)
- Feeds testimonials to `/marketing`
- Feeds feature requests to `/pm-workflow` for backlog
- Correlates with `/analytics` data for quant+qual synthesis

---

## 12. /marketing — Marketing & Growth

**What it does:** Manages App Store Optimization, campaign creation with UTM tracking, competitive positioning, content strategy, email automation sequences, feature launch communications, and App Store creative assets.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/marketing aso` | App Store listing optimization | "Optimize our App Store listing for 'fitness tracker AI'" | Pre-launch |
| `/marketing campaign {name}` | Create campaign brief | "Create a campaign for our launch week" | Phase 8 (Docs) |
| `/marketing competitive` | Competitive analysis | "How does our positioning compare to Hevy and Strong?" | Phase 0 (Research) |
| `/marketing content {topic}` | SEO content brief | "Write a content brief about progressive overload tracking" | Continuous |
| `/marketing email {sequence}` | Email automation | "Design the onboarding email drip" | Phase 8 (Docs) |
| `/marketing launch {feature}` | Launch communications | "Prepare launch comms for the AI recommendations feature" | Phase 8 (Docs) |
| `/marketing screenshots` | App Store screenshots | "Spec out our App Store screenshots" | Pre-launch |

### Shared Data

| Reads | Writes |
|-------|--------|
| `context.json` (brand, personas, positioning) | `campaign-tracker.json` (campaigns, UTMs) |
| `cx-signals.json` (testimonials, user language) | |
| `metric-status.json` (conversion, retention) | |
| `feature-registry.json` (what's launched) | |

### Standalone Usage Examples

1. **ASO optimization:** `/marketing aso` → Generates title, subtitle, keywords, description optimized for 2026 ASO best practices
2. **Email drip:** `/marketing email onboarding` → Designs 3-email sequence (day 1, 3, 7) with A/B subject lines
3. **Launch kit:** `/marketing launch ai` → Multi-channel kit: in-app modal, email, social posts, App Store update

### Hub Integration

- **Phase 0 (Research):** Hub may dispatch `/marketing competitive` for positioning context
- **Phase 8 (Docs):** Hub dispatches `/marketing launch` for feature announcement comms

### Connections

- Receives messaging-problem dispatches from `/cx` (root cause = messaging)
- Reads testimonials from `/cx` (via `cx-signals.json`)
- Feeds campaign data to `/analytics` (via `campaign-tracker.json`)

---

## 13. /research — Market Research

**What it does:** Conducts market research using a wide-to-narrow funnel: cross-industry pattern recognition → same-category competitive analysis → feature-specific deep dives. Also covers UX pattern libraries and ASO research.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/research wide {topic}` | Cross-industry scan | "How do non-fitness apps solve habit formation?" | Phase 0 (Research) |
| `/research narrow {category}` | Same-category deep dive | "Deep dive into fitness app nutrition tracking" | Phase 0 (Research) |
| `/research feature {name}` | Feature-specific analysis | "How do 5 apps implement onboarding?" | Phase 0 (Research) |
| `/research competitive` | Full competitive landscape | "Update our competitive analysis" | On-demand |
| `/research market` | Market sizing and trends | "What's the fitness app market outlook?" | On-demand |
| `/research ux-patterns {pattern}` | Best-in-class UX patterns | "Find best streak/gamification implementations" | Phase 3 (UX) |
| `/research aso` | App Store keyword research | "Research keywords for fitness tracker apps" | Pre-launch |

### The Funnel

```
WIDE (Cross-Industry)
  Duolingo → streaks, XP, leaderboards (31M DAU)
  Headspace → value-first onboarding (70M downloads)
  Signal → zero-knowledge privacy (trust positioning)
  Spotify → freemium → 46% premium conversion
  Notion → template ecosystem, product-led growth
  Strava → community-driven retention

NARROW (Fitness/Health)
  MyFitnessPal │ Strong │ Hevy │ Fitbod │ Strava │ MacroFactor │ Noom

FEATURE-SPECIFIC
  How does each competitor implement THIS exact feature?
```

### Shared Data

| Reads | Writes |
|-------|--------|
| `context.json` (positioning, personas) | `context.json` (competitive updates) |
| `feature-registry.json` (find gaps) | `cx-signals.json` (user research) |
| `cx-signals.json` (what users ask for) | |
| `campaign-tracker.json` (marketing context) | |

### Standalone Usage Examples

1. **Cross-industry insight:** `/research wide habit-formation` → Analyzes Duolingo, Strava, Headspace mechanics and applies to FitMe
2. **Competitor check:** `/research narrow fitness-apps` → Updates competitive landscape with latest pricing, features, ratings
3. **Feature deep-dive:** `/research feature onboarding` → 5+ app teardowns of onboarding flows with best/worst practices

### Hub Integration

- **Phase 0 (Research):** Hub dispatches all three levels: `/research wide` → `/research narrow` → `/research feature`

### Connections

- Feeds competitive data to `/marketing` (via `context.json`)
- Feeds UX patterns to `/design` (via research artifacts)
- Informs `/pm-workflow` PRD decisions with market data

---

## 14. /ops — Operations

**What it does:** Monitors infrastructure health across all services (Railway, Supabase, CloudKit, Firebase, Vercel, GitHub Actions), manages incident response with severity classification and runbooks, tracks costs, and configures monitoring alerts.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/ops health` | Full infrastructure check | "Is everything running?" | Continuous |
| `/ops incident {desc}` | Start incident response | "The AI engine is returning 500s" | Continuous |
| `/ops cost` | Cost report | "What are our monthly cloud costs?" | Continuous |
| `/ops alerts` | Configure monitoring | "Set up alerts for our guardrail metrics" | Continuous |

### Shared Data

| Reads | Writes |
|-------|--------|
| `metric-status.json` (guardrail thresholds) | `health-status.json` (all fields) |
| `health-status.json` (current status) | |

### Incident Severity

| Level | Criteria | Examples |
|-------|----------|---------|
| P0 | App crashes, data loss, auth broken | Encryption failure, sync corruption |
| P1 | Feature broken, perf degraded >50% | AI engine down, HealthKit observer stuck |
| P2 | Feature partially broken, minor perf | Slow dashboard load, stale metrics |
| P3 | UI glitch, minor inconsistency | Wrong icon, alignment issue |

### Standalone Usage Examples

1. **Health check:** `/ops health` → Checks Railway, Supabase, CloudKit, Firebase, Vercel, GitHub Actions
2. **Incident response:** `/ops incident "sync failures spiking"` → Classifies severity, generates runbook, creates GitHub Issue
3. **Cost planning:** `/ops cost` → Projects costs at 100, 1K, 10K, 100K users

### Hub Integration

- Ops is primarily standalone/continuous — not dispatched by specific phases
- Feeds health data that `/release` checks before submission

### Connections

- Reads guardrail thresholds from `/analytics` (via `metric-status.json`)
- Writes health status consumed by `/qa` and `/release` (via `health-status.json`)

---

## 15. /release — Release Management

**What it does:** Handles version bumps with semantic versioning, generates changelogs from git history and feature registry, runs pre-release checklists, and prepares App Store submission materials.

### Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---------|---------|-------------------|-------------|
| `/release prepare` | Version bump + release notes | "Prepare v1.3.0 release" | Phase 7 (Merge) |
| `/release checklist` | Pre-release readiness | "Are we ready to submit?" | Phase 7 (Merge) |
| `/release notes` | Generate changelog | "Write release notes from recent commits" | Phase 7 (Merge) |
| `/release submit` | App Store submission prep | "Prepare App Store submission materials" | Post-Phase 8 |

### Shared Data

| Reads | Writes |
|-------|--------|
| `feature-registry.json` (what's in release) | `CHANGELOG.md` updates |
| `test-coverage.json` (quality gates) | Version bump in Xcode project |
| `health-status.json` (CI ready) | |

### Standalone Usage Examples

1. **Release prep:** `/release prepare` → Bumps version, generates notes, tags release
2. **Readiness check:** `/release checklist` → 11-point checklist: CI, tests, tokens, bugs, analytics, perf, PII, ASO, screenshots, notes, registry
3. **App Store:** `/release submit` → Metadata checklist, privacy labels, review notes, TestFlight config

### Hub Integration

- **Phase 7 (Merge):** Hub dispatches `/release checklist` + `/release prepare`

### Connections

- Reads quality gates from `/qa` (via `test-coverage.json`)
- Reads CI/infra status from `/ops`/`/dev` (via `health-status.json`)
- Reads feature list from `/pm-workflow` (via `feature-registry.json`)

---

## 16. The CX Feedback Loop (Phase 9: Learn)

Phase 9 is what makes the v2.0 pipeline **circular** instead of linear. After a feature ships (Phase 8: Docs), the hub enters a continuous monitoring phase.

### The Complete Feedback Cycle

```
    ┌──────────────────────────────────────────────────────────┐
    │                  POST-DEPLOYMENT LOOP                     │
    │                                                           │
    │   /cx analyze {feature}                                   │
    │      │                                                    │
    │      ├── Is it a MESSAGING problem?                       │
    │      │   └── YES → /marketing (reposition, rephrase)      │
    │      │            → /cx feeds back: "did new message work?"│
    │      │                                                    │
    │      ├── Is it a UX problem?                              │
    │      │   └── YES → /design (revise UX spec)               │
    │      │            → /pm-workflow (new iteration cycle)     │
    │      │                                                    │
    │      ├── Is it a FUNCTIONALITY problem?                   │
    │      │   └── YES → /dev + /qa (bug fix cycle)             │
    │      │            → /release (hotfix or next version)      │
    │      │                                                    │
    │      ├── Is it an EXPECTATION mismatch?                   │
    │      │   └── YES → /pm-workflow (re-scope PRD)            │
    │      │            → /research (validate user needs)        │
    │      │                                                    │
    │      └── Did it SOLVE the original pain point?            │
    │          ├── YES → /analytics (track success metric)      │
    │          │        → /marketing (success story)             │
    │          └── NO  → /pm-workflow (re-enter Phase 0)        │
    │                                                           │
    └──────────────────── feeds back to ────────────────────────┘
```

### Root Cause Classification

| Root Cause | Detection Signals | Dispatched To | What Happens |
|-----------|------------------|--------------|-------------|
| **Messaging** | "what does this do", "what is this for" | `/marketing` | Repositions feature messaging, A/B tests |
| **UX** | "how do I", "can't find", "confusing" | `/design` | Revises UX spec, triggers new design cycle |
| **Functionality** | "doesn't work", "broken", "bug" | `/dev` + `/qa` | Bug fix → test → hotfix release |
| **Expectation** | "I expected", "not what I wanted" | `/pm-workflow` | Re-scopes PRD, validates with `/research` |

### Assessment Flow

1. `/cx analyze {feature}` runs on every new review/feedback batch
2. `/analytics report` checks if success metrics hit targets
3. **Assessment:** solved / improved / status quo / worsened / new problem
4. If NOT solved → classify root cause → dispatch to responsible skill
5. Loop continues until assessment = "solved" or kill criteria triggered

This is what transforms FitMe's PM workflow from a "ship it and forget it" pipeline into a **learning organization** — every shipped feature generates data that improves the next feature.

---

## 17. Connection Map — How Every Skill Connects

### Adjacency Table

Each cell shows the direction and type of information flow between skills.

| From ↓ / To → | pm-workflow | ux | design | dev | qa | analytics | cx | marketing | ops | research | release |
|---------------|------------|-----|--------|-----|-----|-----------|-----|-----------|------|----------|---------|
| **pm-workflow** | — | dispatches (P0-v2,P3,P6) | dispatches (P3,P6) | dispatches (P4,P6,P7) | dispatches (P5) | dispatches (P1,P5,P8) | dispatches (P0,P8,P9) | dispatches (P0,P8) | — | dispatches (P0) | dispatches (P7) |
| **ux** | reports (P0-v2,P3) | — | ux-spec→design-spec | principle checklist | — | — | — | — | — | — | — |
| **design** | reports (P3) | compliance feedback | — | tokens→code | — | — | — | — | — | — | — |
| **dev** | reports (P4,P6) | — | — | — | — | — | — | — | CI status | — | CI status |
| **qa** | reports (P5) | — | — | coverage | — | — | — | — | quality gates | — | quality gates |
| **analytics** | reports (P1) | — | — | — | — | — | quant context | attribution | — | — | — |
| **cx** | pain points, dispatch | UX confusion signals | UX problems | bugs | bugs | qual context | — | testimonials, messaging fixes | tech context | — | — |
| **marketing** | reports (P8) | — | — | — | — | campaigns | user language | — | — | competitive | — |
| **ops** | — | — | — | — | — | alert thresholds | — | — | — | — | health status |
| **research** | reports (P0) | UX patterns, HIG | UX patterns | — | — | — | user needs | competitive | — | — | — |
| **release** | reports (P7) | — | — | — | — | — | — | — | — | — | — |

### Shared Data Connection Map

Which JSON files connect which skills:

```
context.json ─────────────── ALL skills read (startup context)
                             /research + /pm-workflow write

feature-registry.json ────── /pm-workflow writes
                             /qa, /analytics, /cx, /release, /marketing read

metric-status.json ───────── /analytics writes
                             /qa, /ops, /cx read

design-system.json ───────── /design reads + writes
                             /marketing reads (brand tokens)

test-coverage.json ───────── /qa writes
                             /dev, /release read

cx-signals.json ──────────── /cx writes (ALL fields)
                             /design, /marketing, /analytics, /pm-workflow read

campaign-tracker.json ────── /marketing writes
                             /analytics, /research read

health-status.json ───────── /ops, /dev, /qa write
                             /release, /cx read
```

---

## 18. Quick Reference

### All 11 Skills

| # | Skill | Sub-commands | One-liner |
|---|-------|-------------|-----------|
| 0 | `/pm-workflow` | `{feature}` | Hub — orchestrates 10-phase lifecycle with skill dispatch |
| 1 | `/design` | `audit`, `ux-spec`, `figma`, `tokens`, `accessibility` | Design system governance, UX specs, Figma prompts, WCAG AA |
| 1.5 | `/ux` | `research`, `spec`, `validate`, `audit`, `patterns` | UX planning & validation — the What & Why layer that feeds `/design`. Added 2026-04-07, pilot run was Onboarding v2 |
| 2 | `/dev` | `branch`, `review`, `deps`, `perf`, `ci-status` | Branching, code review, dependencies, performance, CI |
| 3 | `/qa` | `plan`, `run`, `coverage`, `regression`, `security` | Test planning, execution, coverage, regression, OWASP audit |
| 4 | `/analytics` | `spec`, `validate`, `dashboard`, `report`, `funnel` | Event taxonomy, instrumentation, dashboards, metric reports |
| 5 | `/cx` | `reviews`, `nps`, `sentiment`, `testimonials`, `roadmap`, `digest`, `analyze` | Reviews, NPS, sentiment, feedback loops, post-deployment analysis |
| 6 | `/marketing` | `aso`, `campaign`, `competitive`, `content`, `email`, `launch`, `screenshots` | ASO, campaigns, content, email automation, launch comms |
| 7 | `/ops` | `health`, `incident`, `cost`, `alerts` | Infrastructure monitoring, incidents, cost, alerting |
| 8 | `/research` | `wide`, `narrow`, `feature`, `competitive`, `market`, `ux-patterns`, `aso` | Cross-industry → same-category → feature-specific research |
| 9 | `/release` | `prepare`, `checklist`, `notes`, `submit` | Version bumps, changelogs, readiness checks, App Store submission |

### All 8 Shared Data Files

| File | Purpose | Primary Owner |
|------|---------|--------------|
| `context.json` | Product identity, personas, brand, guardrails, competitive landscape | `/pm-workflow` + `/research` |
| `feature-registry.json` | 16 features with status, pain points, metrics | `/pm-workflow` |
| `metric-status.json` | 40 metrics across 6 categories, 35% instrumented | `/analytics` |
| `design-system.json` | ~120 tokens, components, accessibility, Android mapping | `/design` |
| `test-coverage.json` | Test suites, gaps (no integration/UI/perf/security tests), guardrail gates | `/qa` |
| `cx-signals.json` | Reviews, NPS, sentiment, keyword patterns, root cause dispatch rules | `/cx` |
| `campaign-tracker.json` | Campaigns, UTM convention, 8 channels, attribution model | `/marketing` |
| `health-status.json` | 6 infrastructure services, CI, quality gates, incidents, cost | `/ops` |

---

## 19. Feature Review — Skills Ecosystem Lens

For each of the 16 features in `feature-registry.json`, here is the skill chain that would apply if built today with the v2.0 ecosystem.

### Shipped Features (10)

#### 1. Training Tracking (`training`) — SHIPPED

| Phase | Skills Invoked | What Happens |
|-------|---------------|-------------|
| 0. Research | `/research feature training` | Teardown of Strong, Hevy, Fitbod logging UX |
| 1. PRD | `/analytics spec training` | Define: training_start, set_complete, session_end events |
| 3. UX | `/design ux-spec training` | Exercise picker, set logging, rest timer states |
| 4. Implement | `/dev branch training` | `feature/training` branch |
| 5. Test | `/qa plan training`, `/qa run` | Happy path, edge cases (empty gym, no exercises) |
| 6. Review | `/dev review`, `/design audit` | High-risk file scan, token compliance |
| 7. Merge | `/release checklist` | CI green, tests pass, analytics regression |
| 8. Docs | `/marketing launch training`, `/analytics dashboard training` | Launch comms, GA4 dashboard |
| 9. Learn | `/cx analyze training` | "Did it solve 'logging is tedious'?" |

**Gap:** None — fully covered by ecosystem.

#### 2. Nutrition Logging (`nutrition`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research feature nutrition`, `/research narrow nutrition-tracking` |
| 1 | `/analytics spec nutrition` |
| 3 | `/design ux-spec nutrition` (meal entry, macro display, supplement tracking) |
| 5 | `/qa plan nutrition` |
| 9 | `/cx analyze nutrition` ("Did it solve 'no connection to training'?") |

**Gap:** Food database search and barcode scanning are listed as critical gaps in the roadmap but not in the current feature registry as separate items. `/research feature food-database` would be needed.

#### 3. Recovery & Biometrics (`recovery`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research wide biometric-tracking`, `/research feature recovery-scores` |
| 1 | `/analytics spec recovery` |
| 3 | `/design ux-spec recovery` (HRV, sleep, RHR, readiness score) |
| 5 | `/qa plan recovery`, `/qa security` (HealthKit data is sensitive) |
| 9 | `/cx analyze recovery` ("Did it solve 'no way to know if body is ready'?") |

**Gap:** None — ecosystem handles HealthKit sensitivity via `/qa security`.

#### 4. Home / Today Screen (`home`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research wide decision-reduction` (Headspace, Duolingo daily screens) |
| 1 | `/analytics spec home` (sessions_per_day, training_cta_tap_rate) |
| 3 | `/design ux-spec home` (today view, quick actions, readiness card) |
| 9 | `/cx analyze home` ("Did it solve 'decision fatigue'?") |

**Gap:** None.

#### 5. Stats / Progress Hub (`stats`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research feature stats-dashboards` (Strong muscle heatmaps, Strava year-in-review) |
| 3 | `/design ux-spec stats` (charts, trends, PR tracking, body composition) |
| 9 | `/cx analyze stats` ("Did it solve 'no unified progress view'?") |

**Gap:** None.

#### 6. Authentication (`auth`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research wide auth-friction` (Signal passkeys, Apple Sign In patterns) |
| 3 | `/design ux-spec auth` (sign in, sign up, passkey, error states) |
| 5 | `/qa security` (JWT handling, passkey WebAuthn, session persistence, Keychain ACL) |
| 9 | `/cx analyze auth` ("Did it reduce signup abandonment?") |

**Gap:** Google Sign In listed as critical gap — would need `/research feature social-signin`.

#### 7. Settings (`settings`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 3 | `/design ux-spec settings` (preferences, data management, GDPR controls) |
| 5 | `/qa security` (account deletion GDPR, data export) |

**Gap:** Account deletion and data export listed as critical gaps — `/qa security` would catch these.

#### 8. Data & Sync (`data-sync`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research wide zero-knowledge-sync` (Signal protocol, end-to-end patterns) |
| 3 | `/design ux-spec data-sync` (sync indicator, conflict resolution UI) |
| 5 | `/qa security` (AES-256-GCM, ChaCha20-Poly1305 validation), `/qa plan data-sync` |
| 9 | `/cx analyze data-sync` ("Is sync reliable? Any data loss reports?") |

**Gap:** None — this is the most security-critical feature and `/qa security` covers it thoroughly.

#### 9. AI / Cohort Intelligence (`ai`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research wide federated-learning`, `/research feature ai-fitness-recommendations` |
| 1 | `/analytics spec ai` (recommendation_acceptance, confidence_score, escalation_rate) |
| 3 | `/design ux-spec ai` — **GAP: AI recommendation UI is listed as critical gap** |
| 5 | `/qa plan ai`, `/dev perf` (AI latency, fallback behavior) |
| 9 | `/cx analyze ai` ("Are recommendations useful? Are users confused by AI suggestions?") |

**Gap:** AI recommendation UI is a critical gap. The ecosystem would handle it via `/design ux-spec ai` + `/cx analyze ai` to monitor if users understand the AI output.

#### 10. Design System v2 (`design-system`) — SHIPPED

| Phase | Skills Invoked |
|-------|---------------|
| 0 | `/research ux-patterns design-systems` (Material Design, Human Interface Guidelines) |
| 3 | `/design tokens`, `/design audit` |
| 5 | `/qa run` (make tokens-check) |

**Gap:** None — the `/design` skill was literally built to manage this feature.

### Shipped (Measurement/Compliance/Tooling)

#### 11. Google Analytics (`google-analytics`) — SHIPPED

| Skills | `/analytics validate`, `/analytics dashboard`, `/qa run` (23 analytics tests) |
|--------|---|
| **Gap** | None — `/analytics` is purpose-built for this. |

#### 12. GDPR Compliance (`gdpr`) — SHIPPED

| Skills | `/qa security` (encryption audit, data exposure), `/design ux-spec` (consent UI) |
|--------|---|
| **Gap** | None. |

#### 13. Development Dashboard (`dashboard`) — SHIPPED

| Skills | `/ops health` (data sources), `/dev ci-status` |
|--------|---|
| **Gap** | None. |

#### 14. Android Design System (`android-ds`) — SHIPPED

| Skills | `/design tokens` (token mapping), `/research narrow android-fitness-apps` |
|--------|---|
| **Gap** | None — `design-system.json` already tracks 92 Android-mapped tokens. |

#### 15. Marketing Website (`marketing-website`) — SHIPPED

| Skills | `/marketing aso`, `/marketing content`, `/marketing screenshots`, `/analytics spec` (cta_click, section_view events) |
|--------|---|
| **Gap** | None. |

### Planned Features (1 in registry)

#### 16. Onboarding (`onboarding`) — PLANNED

| Phase | Skills Invoked | What Happens |
|-------|---------------|-------------|
| 0 | `/research wide onboarding` | Duolingo value-first, Headspace immersive, Noom quiz-based |
| 0 | `/research feature onboarding` | 5+ app teardowns of fitness onboarding flows |
| 0 | `/cx reviews` | Pull any existing confusion signals about first-time experience |
| 1 | `/analytics spec onboarding` | completion_rate, d1_retention, healthkit_connect events |
| 1 | `/analytics funnel onboarding` | app_open → profile_setup → healthkit_connect → first_workout |
| 2 | Tasks → `/dev`, `/design`, `/qa`, `/analytics` | Auto-assign based on scope |
| 3 | `/design ux-spec onboarding` | Value-first flow, HealthKit permission, goal setting |
| 3 | `/design figma onboarding` | Figma build prompt for all onboarding screens |
| 4 | `/dev branch onboarding` | `feature/onboarding` |
| 5 | `/qa plan onboarding` | Happy path, skip flow, HealthKit denied, returning user |
| 6 | `/dev review`, `/design audit` | High-risk review (auth flow touched), visual compliance |
| 7 | `/release prepare` | Version bump for onboarding release |
| 8 | `/marketing launch onboarding` | In-app highlight, email to existing users, App Store update |
| 8 | `/analytics dashboard onboarding` | Completion funnel, D1 retention chart |
| 9 | `/cx analyze onboarding` | "Did it solve 'no guided first experience'?" |

**Gap:** Push notifications (for onboarding reminders) are a critical gap not covered by any current skill. Would need to be handled by `/dev` implementation + `/design` permission UX.

### Critical Gaps Not in Feature Registry

These items from the roadmap are not tracked as features in `feature-registry.json`:

| Gap | Skills That Would Cover It |
|-----|---------------------------|
| **Account deletion (GDPR)** | `/qa security`, `/design ux-spec`, `/dev` |
| **Data export (GDPR)** | `/qa security`, `/design ux-spec`, `/dev` |
| **AI recommendation UI** | `/design ux-spec ai`, `/cx analyze ai` |
| **Food database search** | `/research feature food-database`, `/design ux-spec`, `/dev` |
| **Barcode scanning** | `/research feature barcode-scanning`, `/dev`, `/qa plan` |
| **Push notifications** | `/research wide push-notification-patterns`, `/design ux-spec`, `/dev`, `/marketing email` |
| **Onboarding flow** | Tracked in registry as `onboarding` |
| **Google Sign In** | `/research feature social-signin`, `/qa security`, `/dev` |

### Ecosystem Coverage Summary

| Aspect | Coverage |
|--------|---------|
| Features fully covered | 14 of 16 (87.5%) |
| Features with gaps | 2 (AI — needs recommendation UI; Nutrition — needs food database/barcode) |
| Critical gaps addressable | All 8 gaps can be handled by existing skills |
| Skills with no feature gaps | `/design`, `/dev`, `/qa`, `/analytics`, `/ops`, `/release`, `/research` |
| Skill needing most future work | `/cx` (no real data yet — pre-launch) |

---

## 20. Key Design Decisions

1. **Shared data over direct calls:** Skills communicate through JSON files, not by invoking each other directly. This keeps skills decoupled and independently testable.

2. **Graceful fallback:** The hub checks if a skill exists before dispatching. If it doesn't, it falls back to inline behavior. This means you can incrementally add skills without breaking the pipeline.

3. **State in features/, context in shared/:** Per-feature state (phase, blockers) lives in `.claude/features/`. Cross-cutting context (metrics, brand, health) lives in `.claude/shared/`. This separation keeps feature work isolated while maintaining global awareness.

4. **Phase 9 is continuous, not one-time:** Unlike Phases 0-8 which are sequential gates, Phase 9 (Learn) runs indefinitely. The hub re-enters the loop on every new feedback batch until the feature is assessed as "solved."

5. **Every skill has standalone examples:** Not just "you can use this skill independently" but concrete invocations. This is critical for AI agents and new contributors who need to see exactly how to invoke a skill outside the hub.
