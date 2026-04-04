# PM Workflow Skill — `/pm-workflow`

A Claude Code skill that orchestrates the complete product management lifecycle for features in the FitMe app. Invoke with `/pm-workflow {feature-name}`.

## What It Does

Guides every feature through 9 sequential phases with explicit user approval gates:

```
Research → PRD → Tasks → UX/Integration → Implement → Test → Review → Merge → Docs
```

Each phase produces artifacts (research docs, PRDs, task lists, UX specs), updates a JSON state file, and syncs with GitHub Issues for dashboard tracking.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Main workflow definition — all 9 phases, gates, transitions, overrides |
| `prd-template.md` | PRD template with mandatory metrics, analytics spec, kill criteria |
| `research-template.md` | Research phase template (10 sections) |
| `state-schema.json` | JSON Schema for feature state tracking |

## Key Concepts

- **`has_ui`** — Determines whether Phase 3 runs UX/UI Definition or Integration Requirements
- **`requires_analytics`** — Determines whether analytics instrumentation gates are active (PRD spec, testing verification, post-merge regression)
- **Phase Transition Procedure** — Automated state.json update + GitHub Issue label sync + audit trail
- **Manual Override** — User can skip forward or roll back to any phase at any time
- **Design System Compliance Gateway** — Phase 3 validates UI against semantic tokens, components, accessibility

## Conditional Gates

| Gate | Set During | Activates |
|------|-----------|-----------|
| `has_ui = true` | Phase 1 (PRD) | Phase 3: UX/UI Definition + Design System Compliance |
| `has_ui = false` | Phase 1 (PRD) | Phase 3b: Integration Requirements |
| `requires_analytics = true` | Phase 1 (PRD) | Analytics Spec Gate (PRD) + Analytics Verification (Testing) + Post-Merge Regression (Merge) |
| `requires_analytics = false` | Phase 1 (PRD) | All analytics sections skipped |

---

## Version History

### v1.2.0 — Analytics Instrumentation Gate (2026-04-02)

**Problem:** Features shipped without proper GA4 event definitions, leading to inconsistent naming, missing events, and no automated verification that analytics actually worked.

**What changed:**

Added `requires_analytics` conditional gate (mirrors `has_ui` pattern) with 3 touchpoints:

1. **Phase 1 (PRD) — Analytics Spec Gate**
   - New PRD section: "Analytics Spec (GA4 Event Definitions)"
   - Defines exact event names, parameters, screens, user properties before coding
   - Validates naming against existing `AnalyticsProvider.swift` taxonomy
   - Checks: snake_case, <40 chars, no reserved prefixes, no duplicates, no PII, ≤25 params/event
   - PRD blocked until validation checklist passes

2. **Phase 5 (Testing) — Analytics Verification**
   - Unit tests via `MockAnalyticsAdapter` for event firing + correct parameters
   - Screen tracking verification for all new screens
   - Consent gating test (events blocked when consent denied)
   - Taxonomy sync check (code enums ↔ CSV documentation)
   - Phase blocked until `analytics_verification_passed = true`

3. **Phase 7 (Merge) — Post-Merge Regression**
   - Run analytics test suite on main after merge
   - Verify no regressions in existing events
   - Taxonomy completeness check (every enum constant has a CSV row)
   - Alert + hotfix recommendation on failure

**Files modified:**
- `SKILL.md` — 4 insertions (state init, Phase 1 gate, Phase 5 verification, Phase 7 regression)
- `prd-template.md` — New "Analytics Spec" section with validation checklist
- `state-schema.json` — 5 new fields (`requires_analytics`, `analytics_spec_complete`, `analytics_tests_added`, `analytics_verification_passed`, `analytics_regression_passed`)

**Driven by:** Google Analytics feature (`/pm-workflow google-analytics`) revealed the need for standardized analytics instrumentation across all future features.

---

### v1.1.0 — Design System Compliance Gateway + UX Research (2026-03-28)

**Problem:** UI features shipped with hardcoded colors, inconsistent spacing, and no accessibility validation. The design system existed but wasn't enforced during feature development.

**What changed:**

1. **Phase 3 restructured** into 3 steps:
   - Step 1: UX Research & Principles (Fitts's Law, Hick's Law, iOS HIG, external research)
   - Step 2: Design Definition (behavior, screens, components, tokens, interactions)
   - Step 3: Design System Compliance Gateway (5-check validation)

2. **Compliance Gateway** runs 5 automated checks:
   - Token compliance (colors, fonts, spacing → `AppTheme.swift`)
   - Component reuse (UI elements → `AppComponents.swift`)
   - Pattern consistency (navigation, layout → existing screens)
   - Accessibility (44pt tap targets, WCAG AA contrast, Dynamic Type, VoiceOver)
   - Motion compliance (`AppMotion` presets, reduce-motion support)

3. **Three-option resolution** when violations found:
   - Fix violations (comply with current system)
   - Evolve the design system (update tokens/components on the feature branch)
   - Override with justification (proceed with documented exception)

4. **UX Research template** added with principles, iOS HIG references, and external research links.

**Files modified:**
- `SKILL.md` — Phase 3 rewritten with 3-step process + compliance gateway
- `state-schema.json` — Added `compliance_passed`, `compliance_violations`, `compliance_decision`, `design_system_changes`

**Driven by:** Design system audit revealed 15+ instances of raw hex colors and inconsistent spacing across feature branches.

---

### v1.0.0 — Initial PM Lifecycle (2026-03-20)

**Problem:** Features were implemented ad-hoc with no structured lifecycle, no success metrics, no kill criteria, and no post-launch review process.

**What changed:**

1. **9-phase lifecycle** with sequential gates and user approval at every transition:
   - Phase 0: Research & Discovery
   - Phase 1: PRD (with mandatory success metrics)
   - Phase 2: Task Breakdown
   - Phase 3: UX/UI Definition or Integration Requirements
   - Phase 4: Branch & Implement
   - Phase 5: Testing & Measurement
   - Phase 6: Code Review
   - Phase 7: Merge
   - Phase 8: Documentation & Metrics

2. **Mandatory success metrics** — No PRD approved without:
   - Primary metric with baseline and target
   - Secondary metrics (2-3)
   - Guardrail metrics (must not degrade)
   - Leading/lagging indicators
   - Kill criteria

3. **Dashboard sync automation**:
   - State tracked in `.claude/features/{name}/state.json`
   - GitHub Issue labels auto-updated on phase transitions
   - Audit trail in `transitions` array
   - Manual override support (skip forward / roll back)

4. **Templates** created:
   - `prd-template.md` — Structured PRD with all mandatory sections
   - `research-template.md` — 10-section research framework
   - `state-schema.json` — JSON Schema for state validation

**Files created:**
- `SKILL.md`, `prd-template.md`, `research-template.md`, `state-schema.json`

**Driven by:** Need for a repeatable, data-driven product development process that prevents shipping features without measurement or review.

---

## Features That Used This Skill

| Feature | Phases Completed | Analytics Gate? | Notes |
|---------|-----------------|-----------------|-------|
| `development-dashboard` | All 9 → complete | No | First feature through the full lifecycle |
| `google-analytics` | Phases 0-4 (in progress) | N/A (this IS the analytics feature) | Drove v1.2.0 evolution |
