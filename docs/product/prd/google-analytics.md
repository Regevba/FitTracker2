# PRD: Google Analytics (GA4) Integration

> **ID:** Task 4 | **Status:** Shipped | **Priority:** HIGH (RICE 8.0)
> **Last Updated:** 2026-04-04 | **Branch:** feature/google-analytics (merged to main)

---

## Purpose

Integrate Firebase Analytics (GA4) into the iOS app with GDPR-compliant consent management, a typed event taxonomy, screen tracking, and a settings toggle — enabling data-driven product decisions.

## Business Objective

Without analytics, product decisions are based on assumptions. GA4 provides: DAU/WAU/MAU, retention curves, feature adoption rates, conversion funnels, and user properties. This is the measurement foundation for all future A/B testing and growth optimization.

## What Was Built

### Core Infrastructure
- **AnalyticsProvider protocol** — adapter pattern with FirebaseAnalyticsAdapter (prod) and MockAnalyticsAdapter (test)
- **ConsentManager** — GDPR consent + ATT authorization, UserDefaults persistence
- **AnalyticsService** — consent-gated orchestrator with 20 typed convenience methods
- **ConsentView** — GDPR consent screen on first launch (Accept & Continue / Continue Without)

### Event Taxonomy (GA4 2025 Naming Conventions)
- **20 events** across 6 categories (Training, Nutrition, Recovery, Navigation, Auth, System)
- **24 screen views** mapped to all primary views
- **6 user properties** (training_frequency, nutrition_logging_active, etc.)
- **5 conversion events** (first_training, first_meal, sign_up, etc.)

### Screen Tracking
- `.analyticsScreen()` ViewModifier on 9 primary views
- Automatic screen name + class capture

### Settings Integration
- Analytics toggle in Data & Sync settings
- Disable/enable at runtime, respects GDPR consent

### Testing
- 17 unit tests — event firing, consent gating, taxonomy validation
- 6 GDPR analytics tests (added during GDPR feature)
- Total: 23 analytics tests

## Key Files
| File | Purpose |
|------|---------|
| `FitTracker/Services/Analytics/AnalyticsService.swift` | Consent-gated event orchestrator |
| `FitTracker/Services/Analytics/AnalyticsProvider.swift` | Protocol + adapters |
| `FitTracker/Services/Analytics/ConsentManager.swift` | GDPR consent state |
| `FitTracker/Services/Analytics/AnalyticsEvents.swift` | Typed event definitions |
| `FitTracker/Views/Auth/ConsentView.swift` | GDPR consent screen |
| `docs/product/analytics-taxonomy.csv` | Full taxonomy spreadsheet |
| `docs/setup/firebase-setup-guide.md` | 20-step setup guide |

## Success Metrics

| Metric | Baseline | Target | Status |
|--------|----------|--------|--------|
| Events flowing in GA4 | 0 | All 20 events | Instrumented |
| Screen tracking | 0 | 9 primary views | Shipped |
| Consent opt-in rate | 0 | >60% | ConsentManager |
| Test coverage | 0 | 23 tests | 23 tests passing |

## Dependencies
- Firebase Analytics SDK (SPM)
- Firebase project setup (documented in setup guide)
- GA4 property + data stream configuration

## Known Issues
- Firebase requires real device for full testing (Simulator has limited analytics)
- App Store Connect analytics attribution not yet configured
