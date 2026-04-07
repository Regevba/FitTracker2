# Onboarding — UX Research (v2 retroactive)

> **Date:** 2026-04-07
> **Phase:** Phase 3 — UX (v2 alignment)
> **Status:** Reference document — companion to ux-spec.md and v2-audit-report.md
> **Reference:** docs/design-system/ux-foundations.md (1,533 lines, 10 parts)

## Purpose

This file documents the UX research that **should have been** produced before v1 implementation. It is being created retroactively as part of the v2 UX alignment initiative. The substance was implicit in v1 but never written down — this codifies it so future features have a template, and so the v2 audit findings have a principled basis.

## Applicable ux-foundations principles

### Core heuristics (from §1)

| Principle | How it applies to onboarding |
|-----------|------------------------------|
| **Fitts's Law** | First-time users may be on-the-go. CTAs must be impossible to miss. → 52pt CTA height, full-width buttons, 48pt selection circles. |
| **Hick's Law** | New users have zero context. Each screen must present ≤4 choices. → 4 goal cards, 3 experience levels, 5 frequency options. |
| **Jakob's Law** | Users expect onboarding to behave like other iOS apps they know. → linear progression, page indicator, tappable cards, system permission prompts. |
| **Progressive Disclosure** | Overwhelm = abandonment. One topic per screen. → Welcome → Goal → Profile → HealthKit → Consent → First Action. |
| **Recognition over Recall** | Users can't remember selections from 2 screens ago. → Back navigation must exist (gap in v1 — fixed in v2 P0-06). |
| **Consistency** | Inconsistency erodes trust. → All CTAs same shape/color/shadow; all skips quiet-secondary; all selection cards share visual language. |
| **Feedback** | Every action gets a response. → Selection state visible AND haptic (gap in v1 — fixed in v2 P0-05). |
| **Error Prevention** | Stop mistakes before they happen. → Skip should explain consequences; HealthKit denial should be acknowledged (gaps in v1 — fixed in v2 P1-08, P1-11). |

### FitMe-specific principles (from §1)

| Principle | How it applies |
|-----------|----------------|
| **Readiness-First** | Onboarding's job is to enable readiness scoring ASAP — hence the HealthKit screen is critical, not optional. |
| **Zero-Friction Logging** | Onboarding must end with a clear path to first action (workout or meal). → First Action screen. |
| **Privacy by Default** | Analytics consent is opt-in via Consent screen; HealthKit is contextually requested (not at app launch). |
| **Progressive Profiling** | Don't ask for everything upfront. → Body weight, diet prefs deferred to Settings. |
| **Celebration Not Guilt** | Welcome copy must be encouraging. → "Your fitness command center" — no judgment language. |

## iOS HIG references

| HIG topic | Application |
|-----------|-------------|
| **Onboarding** (HIG > Patterns > Onboarding) | "Help people understand what they can do, not what your app can do." → First Action screen frames the next step in user terms ("Start Your First Workout"). |
| **Modality** | TabView with `.scrollDisabled(true)` and explicit advance buttons — modal-feeling but not actually modal (no dismiss gesture). |
| **HealthKit Authorization** | HIG > System Capabilities > HealthKit: "Explain what data you'll access and why before showing the system prompt." → 3-step priming pattern in OnboardingHealthKitView. |
| **Tap targets** | Minimum 44pt — v1 already exceeds (52pt CTAs, 48pt circles). |
| **Dynamic Type** | All text must scale; layouts must accommodate accessibility text sizes. → v1 GAP: no ScrollView wrappers. Fixed in v2 P1-06. |

## External research sources

Sources that informed v1 onboarding patterns (referenced by `research.md`):
- **Strava onboarding** — single-purpose screens, deferred profile completion
- **Whoop onboarding** — heavy emphasis on HealthKit/Bluetooth setup
- **MyFitnessPal onboarding** — goal-first selection
- **Apple Fitness+ onboarding** — celebration moment + clear first action

Patterns adopted from these:
- Goal-first (MFP)
- HealthKit priming with data type list (Whoop)
- First Action moment (Apple Fitness+)
- Single-decision-per-screen (Strava)

## Recommended patterns based on research

| Pattern | v1 status | v2 alignment |
|---------|-----------|--------------|
| Linear single-purpose screens | ✅ implemented | ✅ retained |
| Page indicator | ✅ 6-segment progress bar | ✅ retained |
| Skip with consequences shown | ❌ silent skip | 🔧 P1-11 |
| Haptic on selection | ❌ none | 🔧 P0-05 |
| Back navigation | ❌ none | 🔧 P0-06 |
| Permission outcome telemetry | ❌ discarded | 🔧 P0-01 |
| Dynamic Type support | ❌ no scroll wrappers | 🔧 P1-06 |
| Celebration moment | ✅ First Action screen | ✅ retained |
| Privacy-by-default | ✅ Consent + HealthKit explicit | ✅ retained |

## Conclusion

v1 onboarding's structure is sound. The principles were honored in spirit but not all of them were implemented at the level required by ux-foundations.md. v2 closes the implementation gaps without changing the structure or scope.

## Cross-references

- Audit report: `.claude/features/onboarding/v2-audit-report.md`
- UX spec: `.claude/features/onboarding/ux-spec.md`
- PRD v2 section: `.claude/features/onboarding/prd.md` → `# v2 — UX Alignment`
- ux-foundations: `docs/design-system/ux-foundations.md`
