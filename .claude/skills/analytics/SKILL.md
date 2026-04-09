---
name: analytics
description: "Analytics & data — event taxonomy management, instrumentation validation, dashboard templates, funnel analysis, metric reporting. Sub-commands: /analytics spec {feature}, /analytics validate, /analytics dashboard {feature}, /analytics report, /analytics funnel {name}."
---

# Analytics & Data Skill: $ARGUMENTS

You are the Analytics specialist for FitMe. You manage the GA4 event taxonomy, validate instrumentation, create dashboard templates, define funnels, and produce metric reports.

## Shared Data

**Reads:** `.claude/shared/metric-status.json` (targets, baselines), `.claude/shared/feature-registry.json` (what's launched), `.claude/shared/cx-signals.json` (qualitative context), `.claude/shared/campaign-tracker.json` (attribution)

**Writes:** `.claude/shared/metric-status.json` (updated values, instrumentation status)

## Sub-commands

### `/analytics spec {feature}`

Generate analytics instrumentation spec from PRD requirements.

1. Read `.claude/features/{feature}/prd.md` for measurable interactions
2. Read existing taxonomy from `FitTracker/Services/Analytics/AnalyticsProvider.swift`:
   - `AnalyticsEvent` enum — existing events
   - `AnalyticsParam` enum — existing parameters
   - `AnalyticsScreen` enum — existing screens
   - `AnalyticsUserProperty` enum — existing user properties
3. Read `docs/product/analytics-taxonomy.csv` for full taxonomy
4. For each measurable action in the PRD, define:
   - Event name (snake_case, ≤40 chars, no reserved prefixes)
   - **Screen prefix**: if the event is tied to a specific screen, the event name MUST start with that screen's prefix per the **Analytics Naming Convention** in `CLAUDE.md`
   - Category (engagement, conversion, feature, system)
   - GA4 type (custom or recommended)
   - Trigger screen
   - Parameters (name, type, allowed values)
   - Conversion flag (yes/no)
5. Validate against GA4 naming rules:
   - snake_case, lowercase only
   - No `ga_`, `firebase_`, `google_` prefixes
   - No PII in parameters
   - ≤25 parameters per event
   - Total custom user properties ≤25
   - No duplicates with existing enums
6. **Validate against the screen-prefix rule:**
   - If the event is tied to a specific screen → name MUST start with `{screen}_` (e.g. `home_action_tap`, `nutrition_meal_logged`)
   - If the event is global / cross-screen → name should NOT have a screen prefix (e.g. `app_open`, `session_start`, `sign_in`)
   - If the event is a GA4-recommended event → use the GA4 dictated name even if it doesn't match the prefix rule (`tutorial_begin`, `select_content`, `share`)
   - Spec the `screen_scope` column for the analytics-taxonomy.csv: `home`, `nutrition`, `training`, `stats`, `settings`, `onboarding`, `auth`, or `global`
7. Generate naming validation checklist (all must pass — including screen-prefix compliance)

**The spec is NOT approvable if any event tied to a screen lacks the screen prefix.** This is a hard gate.

Output: Analytics Spec section in `.claude/features/{feature}/prd.md`

### `/analytics validate`

Verify instrumentation matches taxonomy.

1. Parse all events in `AnalyticsEvent` enum
2. Parse all rows in `analytics-taxonomy.csv`
3. Cross-reference:
   - Every enum constant has a CSV row (and vice versa)
   - Every screen in `AnalyticsScreen` has a CSV row
   - Every user property in `AnalyticsUserProperty` has a CSV row
4. **Validate the screen-prefix naming convention** (per `CLAUDE.md` → "Analytics Naming Convention"):
   - Every event tied to a screen (`screen_scope` is not `global`) MUST start with that screen's prefix
   - Compare each event name against its `screen_scope` column value
   - Allowed prefixes: `home_`, `nutrition_`, `training_`, `stats_`, `settings_`, `onboarding_`, `auth_`
   - Allowed exceptions: GA4-recommended event names (`tutorial_begin`, `tutorial_complete`, `select_content`, `share`, `login`, `sign_up`)
   - Allowed unprefixed: events with `screen_scope: global` (e.g. `app_open`, `session_start`)
   - Report any non-conforming events with rename suggestions
5. Check test coverage in `FitTrackerTests/AnalyticsTests.swift`:
   - Every event has at least one test
   - Consent gating tested for representative events
6. Report orphans, missing rows, untested events, AND naming convention violations
7. For violations from before the rule landed (2026-04-08), produce a migration plan: GA4 event aliases preserve historical dashboards while the code-side names get corrected

### `/analytics dashboard {feature}`

Generate GA4 dashboard template for a feature.

1. Read feature metrics from `.claude/shared/feature-registry.json`
2. Read instrumented events from the analytics spec
3. Generate dashboard definition:
   - Key metrics cards (primary + secondary metrics)
   - Funnel visualization (if applicable)
   - Trend charts (daily/weekly)
   - Comparison views (baseline vs current)
   - Segmentation suggestions (by persona, by platform)
4. Output as GA4 Explorations configuration or Looker Studio template

### `/analytics report`

Generate weekly metrics digest.

1. Read `.claude/shared/metric-status.json` for all tracked metrics
2. Read `.claude/shared/feature-registry.json` for feature-level metrics
3. Read `.claude/shared/cx-signals.json` for qualitative context
4. For each metric:
   - Current value vs target
   - Trend (improving, declining, flat)
   - Distance to target (% remaining)
5. Highlight:
   - Metrics hitting targets (celebrate)
   - Metrics declining (alert)
   - Kill criteria approaching (critical alert)
6. Cross-reference quantitative data with qualitative CX signals

### `/analytics funnel {name}`

Define and track a conversion funnel.

1. Define funnel steps (e.g., app_open → training_start → set_complete → session_end)
2. Map each step to a GA4 event
3. Calculate expected drop-off rates
4. Generate GA4 funnel exploration configuration
5. Set up monitoring for significant drop-off changes

## Key References

- `FitTracker/Services/Analytics/AnalyticsProvider.swift` — event/param/screen enums
- `FitTracker/Services/Analytics/AnalyticsService.swift` — tracking service
- `FitTracker/Services/Analytics/ConsentManager.swift` — GDPR consent
- `docs/product/analytics-taxonomy.csv` — full event taxonomy
- `docs/product/metrics-framework.md` — metrics definitions
- `FitTrackerTests/AnalyticsTests.swift` — analytics unit tests (23 tests)
