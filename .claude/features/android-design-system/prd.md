# PRD: Android Design System Investigation

> **Owner:** Claude (PM Workflow)
> **Date:** 2026-04-04
> **Phase:** Phase 1
> **Status:** Draft
> **Priority:** MEDIUM (RICE 4.8)

---

## Purpose

Create a comprehensive token mapping document and Style Dictionary configuration that translates FitMe's 92 iOS design tokens to Material Design 3 equivalents, enabling future Android development to start with a ready-made design foundation.

## Business Objective

Expand FitMe's addressable market from iOS-only (28% of smartphones) to Android (72%). This investigation removes the design system blocker — the first step before any Android coding begins.

## Target Persona(s)

| Persona | Relevance |
|---------|-----------|
| Future Android developers | Ready-made token mapping, no design guesswork |
| Product designer | Single source of truth across platforms |
| Current iOS developers | Understand what stays consistent and what adapts |

## Has UI?

No — this is a documentation and configuration deliverable. No app screens ship.

## Requires Analytics?

No — no user-facing interactions.

---

## Functional Requirements

| # | Requirement | Priority | Details |
|---|-------------|----------|---------|
| 1 | Color token mapping (46 colors) | P0 | iOS → MD3 role mapping with hex values |
| 2 | Typography token mapping (22 text styles) | P0 | iOS text styles → MD3 type scale |
| 3 | Spacing token mapping (8 values) | P0 | 4pt grid → dp grid (should be 1:1) |
| 4 | Radius/shape token mapping (6+ values) | P0 | iOS radius → MD3 shape categories |
| 5 | Shadow/elevation mapping (2 shadow presets) | P1 | iOS shadows → MD3 tonal elevation |
| 6 | Motion/animation mapping (4 categories) | P1 | iOS springs/easings → MD3 motion specs |
| 7 | Component parity audit (13 iOS components) | P1 | Map each to MD3 equivalent or custom |
| 8 | Style Dictionary Android config | P0 | Generate .kt from tokens.json |
| 9 | Dark mode strategy | P1 | How FitMe's opacity-based system maps to MD3 dark theme |
| 10 | Mapping document (comprehensive) | P0 | Single reference doc for Android devs |

## Acceptance Criteria

- [ ] Every iOS token has a documented MD3 equivalent (or explicit "custom" designation)
- [ ] Style Dictionary config generates valid Kotlin/Compose output
- [ ] Dark mode strategy documented
- [ ] Component parity table complete (13 iOS → MD3 components)
- [ ] Document reviewed and approved

---

## Success Metrics & Measurement Plan

### Primary Metric
- **Metric:** Token mapping coverage
- **Baseline:** 0% (no Android tokens exist)
- **Target:** 100% of 92 iOS tokens mapped
- **Timeframe:** End of this feature

### Secondary Metrics
| Metric | Baseline | Target | Instrumentation |
|--------|----------|--------|-----------------|
| Style Dictionary dual output | iOS only | iOS + Android from same source | CI pipeline test |
| Component parity | 0/13 | 13/13 documented | Manual audit |

### Guardrail Metrics
| Metric | Current Value | Acceptable Range |
|--------|--------------|-----------------|
| iOS token pipeline | Passing | Must not break (`make tokens-check`) |
| Existing iOS design system | 92 tokens | Must not change |

### Leading Indicators
- Token mapping doc exists and is complete
- Style Dictionary generates .kt file without errors

### Lagging Indicators
- Android developer can use the mapping to implement a screen within 1 day

### Instrumentation Plan
| Event/Metric | Method | Status |
|-------------|--------|--------|
| Token coverage | Manual count | N/A |
| Style Dictionary output | CI build test | Not started |

### Review Cadence
- **First review:** On completion (one-time deliverable)
- **Ongoing:** Update when iOS tokens change

### Kill Criteria

Kill if: Android app decision is reversed (no longer building for Android). This is a research deliverable — no ongoing cost.

---

## Key Files

| File | Purpose |
|------|---------|
| `docs/design-system/android-token-mapping.md` | New — comprehensive mapping doc |
| `design-tokens/config-android.json` | New — Style Dictionary Android config |
| `design-tokens/tokens.json` | Existing — source of truth (read-only for this feature) |

## Estimated Effort

- **Total:** 1 week (5 working days)
- **Breakdown:** research: 1d, mapping doc: 2d, Style Dictionary config: 1d, component audit: 0.5d, review: 0.5d
