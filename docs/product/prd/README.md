# Feature PRDs — Index

> Individual PRDs for every core feature, system, and operating layer in FitMe.
> Maintained against the canonical repo and PM-flow v4.3 shared truth.
> Last updated: 2026-04-12

---

## Core iOS Features

| # | Feature | Status | PRD |
|---|---------|--------|-----|
| 18.1 | [Training Tracking](18.1-training-tracking.md) | Shipped | Complete |
| 18.2 | [Nutrition Logging](18.2-nutrition-logging.md) | Shipped | Complete |
| 18.3 | [Recovery & Biometrics](18.3-recovery-biometrics.md) | Shipped | Complete |
| 18.4 | [Home / Today Screen](18.4-home-today-screen.md) | Shipped | Complete |
| 18.5 | [Stats / Progress Hub](18.5-stats-progress-hub.md) | Shipped | Complete |
| 18.6 | [Authentication](18.6-authentication.md) | In Progress | Runtime verification remains open |
| 18.7 | [Settings](18.7-settings.md) | Shipped | Complete |
| 18.8 | [Data & Sync](18.8-data-sync.md) | Shipped | Complete |
| 18.9 | [AI / Cohort Intelligence](18.9-ai-cohort-intelligence.md) | Shipped | Complete |
| 18.10 | [Design System](18.10-design-system.md) | Shipped | Complete |
| 18.11 | [Onboarding](18.11-onboarding.md) | Shipped | Complete |

## Product Operations & Growth

| Feature | Status | PRD |
|---------|--------|-----|
| [Google Analytics (GA4)](google-analytics.md) | Shipped | Complete |
| [GDPR Compliance](gdpr-compliance.md) | Shipped | Complete |
| [Development Dashboard](development-dashboard.md) | Shipped | Complete |
| [Android Design System](android-design-system.md) | Research Complete | Complete |
| [Marketing Website](marketing-website.md) | In Progress | Implemented in code; launch truth cleanup still open |

## Infrastructure & PM Framework

| System | Status | PRD |
|--------|--------|-----|
| [AI Engine Backend](ai-engine-backend.md) | Shipped | Complete |
| [CI Pipeline](ci-pipeline.md) | Shipped | Complete |
| [PM Workflow Skill](pm-workflow-skill.md) | Shipped (v4.3) | Complete |

---

## Discrepancies Still Worth Tracking

| Item | Description | Action Needed |
|------|-------------|---------------|
| Auth runtime proof | Repo wiring and compile verification are done, but real Supabase + Google end-to-end validation is still pending | Finish `FIT-6` runtime verification |
| Marketing launch truth | Marketing site code exists, but the canonical live surface is still the control room/dashboard | Revisit after critical/high-priority maintenance work |

## Totals

- **18 PRDs** covering the current product, tooling, and framework surface
- **15 shipped** features/systems
- **2 in progress** items (Authentication runtime verification, Marketing Website launch truth)
- **1 research-complete** platform artifact (Android Design System)
