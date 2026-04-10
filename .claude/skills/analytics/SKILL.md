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

---

## External Data Sources

| Adapter | Type | What It Provides |
|---------|------|-----------------|
| ga4 | MCP | Real GA4 event data, user metrics, conversion rates, funnel analysis |
| mixpanel | MCP | Alternative analytics source, event tracking, user segmentation |

**Adapter location:** `.claude/integrations/{ga4,mixpanel}/`
**Shared layer writes:** `metric-status.json`

### Validation Gate

All incoming analytics data passes through automatic validation before entering the shared layer:
- Score >= 95% GREEN: Data is clean. Write to shared layer. Notify /analytics + /pm-workflow.
- Score 90-95% ORANGE: Minor discrepancies. Write + advisory. Review when convenient.
- Score < 90% RED: DO NOT write. Alert /analytics + /pm-workflow. User must resolve.

Validation is automatic. Resolution is always manual.

## Research Scope (Phase 2)

When the cache doesn't have an answer for an analytics task, research:

1. **Event naming** — check GA4 recommended events list, project naming convention (screen_prefix rule in CLAUDE.md), existing taxonomy in `analytics-taxonomy.csv`
2. **Instrumentation** — how similar features instrumented events, what parameters are standard, consent gating patterns
3. **Dashboard patterns** — GA4 exploration configs, funnel definitions, cohort analysis setups
4. **Tools & APIs** — GA4 Data API capabilities (via ga4 adapter), Mixpanel query patterns, new analytics features
5. **Validation methods** — XCTest patterns for analytics verification, mock provider approaches

Sources checked in order: L1 cache → shared layer (metric-status.json) → integration adapters (ga4) → codebase (AnalyticsProvider.swift) → external docs

## Cache Protocol

**Phase 1 (Cache Check):** Read `.claude/cache/analytics/_index.json`. Check for matching task signature (e.g., `analytics:event-spec:{feature}`). If hit, load learned event naming patterns, parameter conventions, and skip boilerplate derivation.

**Phase 4 (Learn):** Extract new patterns (event naming, parameter structure, validation outcomes). Write/update L1 cache entry. If pattern overlaps with /qa or /cx cache, flag for L2 promotion.

**Cache location:** `.claude/cache/analytics/`

---

## Cache Protocol

### Phase 1 — Cache Check (on skill start)
Read `.claude/cache/analytics/_index.json`, match `analytics_event_spec`, check L2 for cross-skill event patterns. If hit: generate events mechanically from template. If miss: Phase 2.

### Phase 4 — Learn (on skill complete)
Extract new event categories, parameter formats. Write L1. If applies to /qa test generation, flag L2.

### Health Check (Phase 0 — random trigger)
On skill start, before cache check:
1. Read `.claude/shared/framework-health.json`
2. If `random() < 0.25` AND `hours_since(last_check) > 2`: run 5 health checks, compute weighted score, append to history
3. If score < 0.90: STOP and alert user with failing checks and rollback options
4. Proceed to Phase 1 (Cache Check)

## External Data Sources

| Adapter | Location | Shared Layer Target | When to Pull |
|---------|----------|-------------------|--------------|
| ga4 | `.claude/integrations/ga4/` | metric-status.json, feature-registry.json | On `/analytics validate` or `/analytics report` |

**Fallback:** If adapter unavailable, continue with existing shared data. Log to change-log.json.

## Research Scope (Phase 2 — when cache misses)

1. Screen-prefix naming from CLAUDE.md
2. Existing taxonomy from analytics-taxonomy.csv
3. GA4 recommended events
4. Funnel definitions from PRD
5. Dashboard patterns from prior features

**Source priority:** L2 cache > L1 cache > shared layer (metric-status.json) > ga4 adapter > analytics-taxonomy.csv
