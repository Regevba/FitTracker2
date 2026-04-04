# PRD: PM Workflow Skill

> **ID:** PM Skill | **Status:** Shipped (v1.2) | **Priority:** HIGH
> **Last Updated:** 2026-04-04 | **Branch:** pm-workflow-skill

---

## Purpose

A Claude Code skill (`/pm-workflow {feature-name}`) that orchestrates a 9-phase product management lifecycle for every feature — from research to post-launch metrics review.

## Business Objective

Ensures every feature follows a consistent, data-driven lifecycle with explicit phase gates, success metrics, and kill criteria. Prevents scope creep, ensures analytics instrumentation, and creates an audit trail of all decisions.

## What Was Built

### 9-Phase Lifecycle
| Phase | Description | Key Output |
|-------|-------------|------------|
| 0. Research | Discovery, alternatives, market analysis | Research notes, RICE score |
| 1. PRD | Requirements, success metrics, kill criteria | PRD document |
| 2. Tasks | Breakdown, effort estimation, execution order | Task list |
| 3. UX/Integration | Design compliance, accessibility, patterns | UX spec or integration plan |
| 4. Implement | Code, following tasks and UX spec | Feature code |
| 5. Test | CI verification, test coverage | Tests passing |
| 6. Review | Code review, risk assessment | Review approval |
| 7. Merge | Feature branch → main | Merged code |
| 8. Docs | Documentation, state update | Complete docs |

### Key Features
- **State tracking** — `.claude/features/{name}/state.json` with full transition audit log
- **Phase gates** — explicit user approval required for each phase transition
- **Analytics Instrumentation Gate** (v1.2) — requires analytics spec in PRD, validates events before merge
- **Design System Compliance** — Phase 3 validates token/component usage
- **GitHub Issue sync** — auto-updates labels on phase transitions
- **Manual overrides** — user can skip or rollback phases (recorded in audit trail)
- **PRD template** — mandatory success metrics with baseline, target, kill criteria
- **Research template** — structured discovery with external sources and RICE scoring

### Templates Embedded in Skill
- PRD with metrics section (primary, secondary, guardrails, leading/lagging, instrumentation)
- Research notes with RICE scoring
- state.json with full phase tracking

## Key Files
| File | Purpose |
|------|---------|
| `.claude/skills/pm-workflow/SKILL.md` | Skill definition |
| `.claude/features/{name}/state.json` | Per-feature state tracking |
| `.claude/features/{name}/prd.md` | Per-feature PRD |
| `.claude/features/{name}/tasks.md` | Per-feature task breakdown |
| `docs/process/product-management-lifecycle.md` | Full lifecycle documentation |
| `docs/showcase/pm-workflow-skill.md` | Externally-shareable showcase |
| `CLAUDE.md` | Project rules enforcing PM workflow |

## Features Built Using This Skill
| Feature | Phases Completed | Status |
|---------|-----------------|--------|
| Development Dashboard | 9/9 | Complete |
| Google Analytics (GA4) | 9/9 | Complete |
| GDPR Compliance | 9/9 | Complete |
| Android Design System | 9/9 | Complete |
| Marketing Website | 9/9 | Complete |

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Features using PM workflow | All new features | 5/5 features used it |
| Phase completion rate | 100% (no skipped phases) | 100% |
| Analytics spec included in PRDs | 100% for features with analytics | 100% |
| State.json audit trail completeness | Full transition history | Complete |
