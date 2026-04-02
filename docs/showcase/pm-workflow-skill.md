# FitMe — Product Management Lifecycle Skill

> A data-driven, AI-orchestrated product management system built as a Claude Code skill.  
> Automates the full feature lifecycle from research to production with gated approvals, UX research, design system compliance, and post-launch metrics review.

**Try it:** `/pm-workflow {feature-name}` in any Claude Code session with this repo.

---

## What It Does

Every feature — whether a 1-day fix or a 3-week build — follows the same disciplined, data-driven lifecycle:

```
/pm-workflow push-notifications
         │
         ▼
   ┌─ RESEARCH ────────────────┐
   │ What? Why? Alternatives?  │
   │ Sources, competitors, data│
   │ UX principles & patterns  │
   │ Design inspiration & mood │
   └───────────┬───────────────┘
               ▼
   ┌─ PRD ─────────────────────┐
   │ Requirements & user flows │
   │ Success metrics (MANDATORY)│
   │ • Primary metric + target │
   │ • Guardrails (can't break)│
   │ • Kill criteria           │
   └───────────┬───────────────┘
               ▼
   ┌─ TASKS ───────────────────┐
   │ Subtask breakdown         │
   │ Effort estimates          │
   │ Dependency graph          │
   └───────────┬───────────────┘
               ▼
      ┌────────┴────────┐
      ▼                 ▼
   ┌─ UX/UI ──┐   ┌─ INTEGRATION ─┐
   │ Screens   │   │ API contracts │
   │ Components│   │ Data models   │
   │ Tokens    │   │ Dependencies  │
   │ Compliance│   └───────┬───────┘
   │ Gateway   │           │
   └─────┬─────┘           │
         └────────┬────────┘
                  ▼
   ┌─ IMPLEMENT ───────────────┐
   │ Feature branch isolation  │
   │ Incremental commits       │
   └───────────┬───────────────┘
               ▼
   ┌─ TEST & MEASURE ─────────┐
   │ Unit tests + regression  │
   │ CI must be GREEN         │
   │ Verify instrumentation   │
   │ Record baselines         │
   └───────────┬───────────────┘
               ▼
   ┌─ CODE REVIEW ────────────┐
   │ Diff feature vs main     │
   │ Risk assessment           │
   │ CI GREEN on BOTH branches│
   └───────────┬───────────────┘
               ▼
   ┌─ MERGE ───────────────────┐
   │ PR → squash merge → clean│
   └───────────┬───────────────┘
               ▼
   ┌─ DOCS & METRICS ─────────┐
   │ Update PRD, CHANGELOG     │
   │ Record baselines          │
   │ Schedule metrics review   │
   └───────────┬───────────────┘
               ▼
   ┌─ POST-LAUNCH ────────────┐
   │ Review at cadence         │
   │ Current vs target         │
   │ Keep / iterate / kill     │
   └───────────────────────────┘
```

Every arrow is a **gate** — the user must approve before proceeding.

---

## Key Differentiators

### 1. Research Before Building
Phase 0 forces you to understand what exists, compare 2-3 alternatives, and validate your approach with data before writing a single line of code or PRD.

### 2. Data-Driven at Every Level
Every feature PRD requires 10 mandatory metrics fields:

| Field | Purpose |
|-------|---------|
| Primary metric | The one number that defines success |
| Secondary metrics | Supporting signals |
| Guardrail metrics | Things that must NOT degrade |
| Leading indicators | Early signals (within 1 week) |
| Lagging indicators | Long-term impact (30/60/90 days) |
| Instrumentation | How we measure |
| Baseline | Current value before launch |
| Target | Success threshold |
| Review cadence | When to check |
| Kill criteria | When to revert or rethink |

**No PRD is approved without complete metrics.** No exceptions.

### 3. UX Research + Principles
UI features start with UX research before design:
- Applicable principles (Fitts's Law, Hick's Law, progressive disclosure)
- iOS Human Interface Guidelines
- External best practices research
- Design inspiration with documented reasoning

### 4. Living Design System
The design system is a **living, evolving framework** — not a static constraint.

When a feature's design doesn't align with the current system, the compliance gateway presents three options:
1. **Fix** — comply with the current system
2. **Evolve** — update the design system on the feature branch (merges with the feature)
3. **Override** — proceed with documented justification

Since every feature is on its own branch, there's zero risk to main.

### 5. Branch Isolation + Parallel CI
Large features get isolated `feature/{name}` branches. Before merge:
- CI must pass on **both** the feature branch and main
- High-risk files (encryption, sync, auth, AI) get extra scrutiny
- Parallel diff review identifies risks and gaps

### 6. Post-Launch Accountability
Features don't end at merge. The lifecycle includes mandatory post-launch metrics review at the cadence defined in the PRD. Features that don't deliver value get iterated or killed.

---

## System-Wide Guardrails

Every feature must not degrade these metrics:

| Metric | Threshold |
|--------|-----------|
| Crash-free rate | > 99.5% |
| Cold start time | < 2s |
| Sync success rate | > 99% |
| CI pass rate | > 95% |
| Cross-feature WAU | Trending up or flat |

---

## How It Works

### Start a new feature
```
/pm-workflow push-notifications
```

### Resume an in-progress feature
```
/pm-workflow push-notifications
```
The skill detects existing state and resumes from the current phase.

### Check active features
Active features are shown automatically when you start a session:
```
## Active Features
- push-notifications: phase=implementation
- food-search: phase=prd
```

---

## File Structure

```
.claude/
├── settings.json                     # SessionStart hook
├── skills/pm-workflow/
│   ├── SKILL.md                      # Main orchestration (249 lines)
│   ├── prd-template.md               # PRD with mandatory metrics
│   ├── research-template.md          # Phase 0 discovery
│   └── state-schema.json             # Lifecycle state schema
├── features/{name}/                  # Per-feature runtime state
│   ├── state.json
│   ├── research.md
│   ├── prd.md
│   ├── tasks.md
│   └── ux-spec.md
CLAUDE.md                             # Project rules
docs/process/product-management-lifecycle.md  # Full documentation
```

---

## Source Code

| File | Link |
|------|------|
| Orchestration Skill | [SKILL.md](../../.claude/skills/pm-workflow/SKILL.md) |
| PRD Template | [prd-template.md](../../.claude/skills/pm-workflow/prd-template.md) |
| Research Template | [research-template.md](../../.claude/skills/pm-workflow/research-template.md) |
| State Schema | [state-schema.json](../../.claude/skills/pm-workflow/state-schema.json) |
| Project Rules | [CLAUDE.md](../../CLAUDE.md) |
| Full Documentation | [product-management-lifecycle.md](../process/product-management-lifecycle.md) |
| Settings & Hooks | [settings.json](../../.claude/settings.json) |

---

## Built With

- [Claude Code](https://claude.ai/code) — AI coding assistant
- Claude Code Skills — custom `/command` orchestration
- Claude Code Hooks — automated session context injection
- GitHub MCP — issue tracking and PR management

---

## Live Dashboard

See the development pipeline in real-time: **[FitMe Development Dashboard](../dashboard/)**

*The dashboard itself was built using this PM workflow skill — dogfooding the system.*
