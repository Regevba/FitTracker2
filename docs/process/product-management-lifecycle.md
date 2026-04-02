# FitMe — Product Management Lifecycle

> A data-driven, gated workflow that takes every feature from research to production.  
> Built as a Claude Code skill (`/pm-workflow`) with automated state tracking and CI integration.

---

## Philosophy

Every feature in FitMe follows the same disciplined lifecycle — whether it's a 1-day fix or a 3-week feature. The core principles:

1. **Research before building.** Understand what exists, why we're choosing this approach, and what alternatives we rejected.
2. **Measure everything.** No feature ships without defined success metrics, baselines, targets, and kill criteria.
3. **Gate every phase.** No phase is skipped. Explicit approval required before proceeding.
4. **Isolate risk.** Large features get their own branch. Both branches must pass CI before merge.
5. **Close the loop.** Post-launch metrics review is mandatory. Features that don't deliver value get iterated or killed.

---

## Lifecycle Overview

```
/pm-workflow {feature-name}
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 0: RESEARCH & DISCOVERY      │
│  What? Why? Why this over others?   │
│  Sources, competitors, data signals │
│  If UI: design inspiration & mood   │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 1: PRD                        │
│  Requirements, user flows, personas │
│  Success metrics (MANDATORY):       │
│    Primary + secondary metrics      │
│    Guardrails, leading/lagging      │
│    Instrumentation, baseline, target│
│    Review cadence, kill criteria    │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 2: TASK BREAKDOWN             │
│  Subtasks with effort estimates     │
│  Dependency ordering                │
│  UI vs non-UI classification        │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────┐
│Phase 3 │ │Phase 3b  │
│UX/UI   │ │Integ.    │
│Screens │ │API/Data  │
│Tokens  │ │Contracts │
│⏸ Gate │ │⏸ Gate   │
└────┬───┘ └────┬─────┘
     └────┬─────┘
          ▼
┌─────────────────────────────────────┐
│  Phase 4: BRANCH & IMPLEMENT        │
│  Create feature/{name} branch      │
│  Code implementation                │
│  Incremental commits                │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 5: TESTING & MEASUREMENT     │
│  Unit tests + regression suite     │
│  CI must be GREEN                   │
│  Verify metric instrumentation     │
│  Record baseline values             │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 6: CODE REVIEW               │
│  Diff feature branch vs main       │
│  Risk assessment (high-risk files) │
│  CI GREEN on BOTH branches         │
│  ⏸ Approval Gate                   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 7: MERGE                      │
│  Create PR → squash merge to main  │
│  Delete feature branch              │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Phase 8: DOCUMENTATION & METRICS   │
│  Update PRD with final state        │
│  Record baselines                   │
│  Set review cadence                 │
│  Update CHANGELOG + backlog         │
│  Archive feature state              │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  POST-LAUNCH: METRICS REVIEW        │
│  Review at defined cadence          │
│  Compare current vs baseline/target │
│  Check kill criteria                │
│  Decision: keep / iterate / kill    │
└─────────────────────────────────────┘
```

---

## Phase Details

### Phase 0: Research & Discovery

Before writing a single line of code or a PRD, we research.

**Deliverable:** `.claude/features/{name}/research.md`

| Section | Purpose |
|---------|---------|
| What is this solution? | Plain-language description anyone can understand |
| Why this approach? | Problem it solves, pain points addressed |
| Why this over alternatives? | Comparison table of 2-3 approaches with pros/cons |
| External sources | Articles, docs, APIs, libraries — with links |
| Market examples | How competitors solve this, what they do well/poorly |
| Design inspiration (if UI) | Screenshots of designs we liked, solutions we tested, visual mood |
| Data & demand signals | Analytics, user feedback, market research that justifies building this |
| Technical feasibility | Dependencies, risks, platform constraints |
| Proposed metrics | Draft primary + secondary success metrics |
| Decision | Final recommendation with rationale |

### Phase 1: PRD

Every PRD uses the same template (`.claude/skills/pm-workflow/prd-template.md`).

**The success metrics section is non-negotiable.** Every PRD must define:

| Metric Type | Description |
|-------------|-------------|
| **Primary metric** | The one number that defines success |
| **Secondary metrics** | 2-3 supporting signals |
| **Guardrail metrics** | Things that must NOT degrade |
| **Leading indicators** | Early signals (within 1 week) |
| **Lagging indicators** | Long-term impact (30/60/90 days) |
| **Instrumentation** | How we measure each metric |
| **Baseline** | Current value before the feature ships |
| **Target** | Success threshold |
| **Review cadence** | When to check (daily/weekly/monthly) |
| **Kill criteria** | When to revert or fundamentally rethink |

### Phases 2-3: Task Breakdown & Design/Integration

Tasks are broken down by type (UI, backend, data, test, docs, infra) with effort estimates and dependency ordering.

For non-UI features: API contracts, data model changes, service dependencies, backward compatibility.

For UI features, Phase 3 has three steps:

**Step 1: UX Research** — Before designing, research the relevant UX principles (Fitts's Law, Hick's Law, progressive disclosure, etc.), check iOS Human Interface Guidelines for applicable patterns, and find external research on best practices for the specific interaction type. Documented in `ux-research.md`.

**Step 2: Design Definition** — Screen list, component inventory, design tokens, interaction flows, accessibility. Every design decision references which UX principle informed it.

**Step 3: Design System Compliance Gateway** — Automated check against the design system:

| Check | What's validated |
|-------|-----------------|
| Token compliance | Every color/font/spacing maps to AppTheme.swift |
| Component reuse | Uses AppComponents.swift or justifies new components |
| Pattern consistency | Matches existing screen patterns |
| Accessibility | 44pt targets, WCAG AA contrast, Dynamic Type, VoiceOver |
| Motion | Uses AppMotion presets, reduce-motion support |

**If violations are found**, the user gets three options:

1. **Fix** — Update the design to comply with the current system
2. **Evolve** — Update the design system as part of this feature (new tokens/components on the feature branch)
3. **Override** — Proceed with documented justification

This reflects a core philosophy: **the design system is a living, evolving framework — not a static constraint.** Since every feature is on its own branch, there's zero risk to main. Design system changes proposed by a feature are reviewed alongside the code and merge together.

### Phases 4-5: Implementation & Testing

- Code on isolated `feature/{name}` branch
- Incremental commits with descriptive messages
- Unit tests for all new functionality
- Full CI suite must pass (token check + build + test)
- Metric instrumentation verified before merge
- Baseline values recorded

### Phase 6: Code Review

Parallel review of feature branch vs main:

**High-risk files requiring extra scrutiny:**
- `DomainModels.swift` — data model changes affect everything
- `EncryptionService.swift` — security-critical
- `SupabaseSyncService.swift` / `CloudKitSyncService.swift` — sync integrity
- `SignInService.swift` / `AuthManager.swift` — auth flows
- `AIOrchestrator.swift` — AI pipeline

**CI requirement:** Both `feature/{name}` AND `main` must be green before merge is approved.

### Phases 7-8: Merge & Documentation

Squash merge to main, delete feature branch, update all documentation, archive feature state.

---

## Branching Strategy

```
main ─────────────────────────────────────────────►
       \                                    /
        \── feature/dark-mode ────────────/
              (isolated, CI-green)     (squash merge)
```

| Rule | Description |
|------|-------------|
| Large features (>5 files or new models) | Must use `feature/{name}` branch |
| Small fixes (<5 files, no new models) | Can use direct task branch |
| Before merge | CI must pass on BOTH feature branch and main |
| Merge method | Squash merge (clean history) |
| After merge | Delete feature branch |

---

## State Tracking

Every feature has a state file at `.claude/features/{name}/state.json` that tracks:
- Current phase
- Phase completion status
- Commit history
- CI results
- Metric baselines and targets
- PR number

State is automatically loaded at session start via the SessionStart hook.

---

## System-Wide Guardrails

These metrics are tracked across ALL features and must not degrade:

| Metric | Threshold |
|--------|-----------|
| Crash-free rate | > 99.5% |
| Cold start time | < 2s |
| Sync success rate | > 99% |
| CI pass rate | > 95% |
| Cross-feature WAU | Trending up or flat |

---

## How to Use

### Start a new feature
```
/pm-workflow dark-mode-support
```

### Resume an in-progress feature
```
/pm-workflow dark-mode-support
```
(The skill detects existing state and resumes from the current phase.)

### Check active features
Active features are shown automatically at session start. Or manually:
```bash
ls .claude/features/*/state.json
```

---

## Integration with Notion

Feature PRDs and research docs can be exported to Notion using the Notion MCP prompt at `docs/product/notion-setup-prompt.md`. The PRD template fields map directly to Notion database properties.

---

## File Structure

```
.claude/
├── settings.json                          # SessionStart hook
├── skills/
│   └── pm-workflow/
│       ├── SKILL.md                       # Main orchestration
│       ├── prd-template.md                # PRD template
│       ├── research-template.md           # Research template
│       └── state-schema.json              # State JSON schema
├── features/                              # Per-feature state (gitignored)
│   └── {feature-name}/
│       ├── state.json                     # Lifecycle state
│       ├── research.md                    # Phase 0 output
│       ├── prd.md                         # Phase 1 output
│       ├── tasks.md                       # Phase 2 output
│       ├── ux-spec.md                     # Phase 3 output (if UI)
│       ├── integration-spec.md            # Phase 3b output (if non-UI)
│       └── design-refs/                   # Design inspiration (if UI)
CLAUDE.md                                  # Project-wide rules
docs/process/product-management-lifecycle.md  # This document
```

---

## Example: Feature Walkthrough

Here's how the lifecycle plays out for a hypothetical "Push Notifications" feature:

1. **Research:** Investigate APNs vs Firebase Cloud Messaging, review how Strong/Hevy/MyFitnessPal handle notifications, find 12 App Store reviews requesting reminders, draft metrics.
2. **PRD:** Define notification types (training reminder, readiness alert, streak), primary metric: "D7 retention +5%", kill criteria: "no retention improvement in 30 days".
3. **Tasks:** 8 subtasks — APNs registration, notification service, permission request UI, 4 notification types, tests.
4. **UX:** Permission request screen design, notification center UI, quiet hours settings.
5. **Implement:** `feature/push-notifications` branch, 12 commits across 8 files.
6. **Test:** 6 new tests, CI green, GA4 events `notification_sent` and `notification_opened` instrumented.
7. **Review:** No high-risk file changes (no encryption/sync impact), CI green on both branches.
8. **Merge:** PR #25 squash-merged to main.
9. **Docs:** CHANGELOG updated, backlog item moved to Done, baseline recorded.
10. **Post-launch:** Week 1 review shows 35% opt-in rate. Week 4 review shows D7 retention +3% (below 5% target). Decision: iterate on notification timing algorithm.
