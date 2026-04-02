# PRD: {Feature Name}

> **Owner:** {name}
> **Date:** {YYYY-MM-DD}
> **Phase:** {current program phase}
> **Status:** Draft | In Review | Approved

---

## Purpose

{1-2 sentences: what this feature does and why it matters}

## Business Objective

{Why are we building this? What business goal does it serve?}

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| {Consistent Lifter / Health-Conscious Professional / Data-Driven Optimizer} | {How this feature serves them} |

## Has UI?

{Yes / No — determines whether UX/UI Definition or Integration Requirements phase applies}

## Functional Requirements

| # | Requirement | Status | Details |
|---|-------------|--------|---------|
| 1 | | Planned | |
| 2 | | Planned | |
| 3 | | Planned | |

## User Flows

1. {Step 1}
2. {Step 2}
3. {Step 3}

## Current State & Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| | | |

## Acceptance Criteria

- [ ] {Criterion 1}
- [ ] {Criterion 2}
- [ ] {Criterion 3}

---

## Success Metrics & Measurement Plan

> **This section is mandatory.** No PRD is approved without complete metrics.

### Primary Metric
- **Metric:** {The one number that defines success}
- **Baseline:** {Current value before feature ships}
- **Target:** {Success threshold}
- **Timeframe:** {When we expect to hit the target}

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| {metric 1} | {current} | {goal} | {how measured} |
| {metric 2} | {current} | {goal} | {how measured} |

### Guardrail Metrics
> These must NOT degrade when this feature ships.

| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| Crash-free rate | >99.5% | Must stay >99.5% |
| Cold start time | <2s | Must stay <2s |
| Sync success rate | >99% | Must stay >99% |
| {feature-specific guardrail} | | |

### Leading Indicators
> Early signals measurable within 1 week of launch.

- {e.g., "50% of active users try the feature within 7 days"}

### Lagging Indicators
> Long-term impact measured at 30/60/90 days.

- {e.g., "D30 retention improves by 5% for users of this feature"}

### Instrumentation Plan
| Event/Metric | Method | Status |
|-------------|--------|--------|
| {event name} | {GA4 / HealthKit / Manual / Available now} | {Not started / Ready} |

### Review Cadence
- **First review:** {date, typically 1 week post-launch}
- **Ongoing:** {Weekly for 4 weeks, then monthly}

### Kill Criteria
> When to revert or fundamentally rethink this feature.

- {e.g., "If primary metric doesn't improve by >10% within 30 days"}
- {e.g., "If guardrail metrics degrade by >5%"}

---

## Key Files

| File | Purpose |
|------|---------|
| | |

## Dependencies & Risks

| Dependency/Risk | Mitigation |
|----------------|------------|
| | |

## Estimated Effort

- **Total:** {person-weeks}
- **Breakdown:** {research: X, design: X, implementation: X, testing: X}
