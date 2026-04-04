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

### Analytics Spec (GA4 Event Definitions)

> **Required when `requires_analytics = true`.** Skip for infra/refactoring features.
> Reference: `FitTracker/Services/Analytics/AnalyticsProvider.swift` for existing naming conventions.

#### New Events
| Event Name | Category | GA4 Type | Screen/Trigger | Parameters | Conversion? | Notes |
|------------|----------|----------|----------------|------------|-------------|-------|
| {snake_case, <40 chars} | {Workout/Nutrition/Recovery/Engagement/Auth/Settings} | {Recommended/Custom} | {screen or action} | {param1, param2...} | {Yes/No} | |

#### New Parameters
| Parameter Name | Type | Allowed Values | Used By Events | Notes |
|---------------|------|----------------|----------------|-------|
| {snake_case, <40 chars} | {string/int/float} | {enumerated values or range} | {event1, event2} | {max 100 char values} |

#### New Screens
| Screen Name | View Name | SwiftUI View | Category |
|-------------|-----------|--------------|----------|
| {Human readable} | {snake_case} | {ViewClassName} | {core/workout/nutrition/recovery/engagement/settings/auth} |

#### New User Properties
| Property Name | Type | Values | Notes |
|--------------|------|--------|-------|
| {snake_case} | {string} | {enumerated} | {max 25 total custom properties} |

#### Naming Validation Checklist
- [ ] All event names: snake_case, <40 chars
- [ ] All parameter names: snake_case, <40 chars
- [ ] No reserved prefixes (ga_, firebase_, google_)
- [ ] No duplicate names (checked against AnalyticsProvider.swift)
- [ ] No PII in any parameter (no emails, names, user IDs)
- [ ] ≤25 parameters per event
- [ ] Total custom user properties still ≤25 (currently {N})
- [ ] Parameter values spec'd to max 100 chars
- [ ] Conversion events identified for GA4 UI setup

#### Files to Update During Implementation
- [ ] `AnalyticsProvider.swift` — add constants to AnalyticsEvent, AnalyticsParam, AnalyticsScreen, AnalyticsUserProperty enums
- [ ] `AnalyticsService.swift` — add typed convenience methods for new events
- [ ] `docs/product/analytics-taxonomy.csv` — add rows to events, screens, and properties sections

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
