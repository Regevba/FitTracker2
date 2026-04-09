# `/analytics` — Analytics & Data

> **Role in the ecosystem:** The measurement layer. Owns the GA4 event taxonomy, instrumentation specs, dashboards, funnels, and metric reporting.

**Agent-facing prompt:** [`.claude/skills/analytics/SKILL.md`](../../.claude/skills/analytics/SKILL.md)

---

## What it does

Manages the GA4 event taxonomy, generates instrumentation specs from PRDs, validates that code events match the taxonomy CSV, creates dashboard templates, defines funnels, and produces metric reports. Ensures every feature that ships is measurable — `/analytics spec` is a non-negotiable Phase 1 gate whenever `state.json.requires_analytics == true`.

## Sub-commands

| Command | Purpose | Standalone Example | Hub Context |
|---|---|---|---|
| `/analytics spec {feature}` | Generate analytics spec | "What events should onboarding fire?" | Phase 1 (PRD) |
| `/analytics validate` | Verify events match taxonomy | "Are all our events properly instrumented?" | Phase 5 (Test) |
| `/analytics dashboard {feature}` | Dashboard template | "Create a GA4 dashboard for training metrics" | Phase 8 (Docs) |
| `/analytics report` | Weekly metrics digest | "How are our metrics trending?" | Phase 9 (Learn) |
| `/analytics funnel {name}` | Define conversion funnel | "Define the onboarding completion funnel" | Phase 1 (PRD) |

## Shared data

**Reads:** `metric-status.json` (targets, baselines), `feature-registry.json` (what's launched), `cx-signals.json` (qualitative context), `campaign-tracker.json` (attribution).

**Writes:** `metric-status.json` (updated values, instrumentation status).

## PM workflow integration

| Phase | Dispatches |
|---|---|
| Phase 1 (PRD) | `/analytics spec` — the instrumentation plan is part of the PRD gate |
| Phase 5 (Test) | `/analytics validate` — runs alongside `/qa run` in the same test suite |
| Phase 7 (Merge) | Post-merge analytics regression check |
| Phase 8 (Docs) | `/analytics dashboard` for monitoring setup |
| Phase 9 (Learn) | `/analytics report` + correlation with `/cx` signals |

## Upstream / Downstream

- Reads qualitative context from `/cx` (via `cx-signals.json`) to correlate quant + qual
- Reads attribution from `/marketing` (via `campaign-tracker.json`)
- Feeds metric status to `/ops` for alert thresholds
- Feeds post-launch delta to `/pm-workflow` for kill-criteria evaluation

## Standalone usage examples

1. **Taxonomy audit:** `/analytics validate` → cross-references `AnalyticsEvent` enum ↔ taxonomy CSV ↔ test coverage
2. **Metric check:** `/analytics report` → weekly digest: active metrics, instrumentation coverage, gaps highlighted
3. **Funnel definition:** `/analytics funnel onboarding` → defines steps: app_open → profile_setup → healthkit_connect → first_workout

## Recent usage

- **50+ analytics events** instrumented across shipped features:
  - 7 `home_*` events (Home v2: tile taps, empty states, action interactions)
  - 3 `body_comp_*` events (Body Composition card: detail view, metric updates)
  - 12 `training_*` events (Training v2: workout start/complete, set logging, exercise views)
  - Plus onboarding, auth, and global lifecycle events
- **Screen-prefix naming convention** established as project rule (2026-04-08) — every screen-scoped event must include its screen name as a prefix. Enforced in PRD analytics spec gate.
- **`/analytics validate`** run across all features during Phase 5 testing.

## Key references

- [`FitTracker/Services/Analytics/AnalyticsProvider.swift`](../../FitTracker/Services/Analytics/AnalyticsProvider.swift) — event/param/screen enums
- [`docs/product/analytics-taxonomy.csv`](../product/analytics-taxonomy.csv) — full event taxonomy
- [`docs/product/metrics-framework.md`](../product/metrics-framework.md) — 40 metric definitions
- [`FitTrackerTests/AnalyticsTests.swift`](../../FitTrackerTests/AnalyticsTests.swift) — analytics unit tests

## Related documents

- [README.md](README.md) · [architecture.md](architecture.md) — §10
- [cx.md](cx.md), [qa.md](qa.md), [marketing.md](marketing.md) — correlated partners
- [pm-workflow.md](pm-workflow.md)
- [`.claude/skills/analytics/SKILL.md`](../../.claude/skills/analytics/SKILL.md)
