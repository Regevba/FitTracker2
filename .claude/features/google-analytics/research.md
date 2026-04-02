# Research: Google Analytics Integration

> Feature: google-analytics | Phase 0 | RICE: 8.0
> Date: 2026-04-02

---

## 1. What is this solution?

Add Google Analytics 4 (GA4) via Firebase Analytics SDK to FitMe, enabling product analytics across all user flows: training, nutrition, recovery, stats, auth, and settings. This unlocks 14 of 40 metrics defined in the metrics framework that currently have no instrumentation.

---

## 2. Why this approach?

**Problem:** FitMe is instrumentation-blind. The app has 11 shipped features, 40 defined metrics, but zero analytics. We can't measure:
- DAU/WAU/MAU
- Retention (D1/D7/D30)
- Cross-feature WAU (North Star metric)
- Session length
- Screen-level engagement
- Conversion funnels (onboarding → first workout → first meal → weekly streak)

**User pain:** Without data, product decisions are based on intuition, not evidence. We can't identify drop-off points, measure feature adoption, or validate kill criteria for new features.

---

## 3. Why this over alternatives?

| Approach | Pros | Cons | Effort | Chosen? |
|----------|------|------|--------|---------|
| **GA4 + Firebase** | Free <10M events/mo, enterprise features, real-time, funnels, retention, cross-platform, Google ecosystem | Requires GDPR consent, ATT dialog, binary size +5-8MB | 2 weeks | **Yes** |
| **TelemetryDeck** | Privacy-first (no consent needed), EU-hosted, native Swift SDK, minimal setup | Basic funnels, limited retention analysis, no free tier for teams, less ecosystem | 1 week | No (but strong runner-up) |
| **Mixpanel** | Best funnel/cohort analysis, great iOS SDK | Event-based pricing gets expensive fast, requires consent | 2 weeks | No |
| **Amplitude** | Best retention analysis, free tier generous | User-based pricing, requires consent, heavier SDK | 2 weeks | No |
| **PostHog** | Open source, self-hostable, generous free tier (1M events) | Self-hosting complexity, younger iOS SDK | 2.5 weeks | No |
| **Apple App Analytics** | Free, built-in, no consent needed, device-level privacy | No custom events, no funnels, no retention cohorts, very limited | 0 effort | No (insufficient) |

**Decision:** GA4 + Firebase. It's free at our scale, has the richest feature set for product analytics, and integrates with the Google ecosystem (BigQuery, Looker, Ads). The consent overhead is a one-time cost that we need regardless for GDPR compliance.

**Fallback:** If privacy-first positioning becomes a brand differentiator, TelemetryDeck can be swapped in via the analytics protocol abstraction (no code changes needed beyond the adapter).

---

## 4. External Sources

- [Firebase iOS SDK Installation](https://firebase.google.com/docs/ios/installation-methods) — SPM recommended, v12.8+
- [Firebase Automatic Events](https://support.google.com/analytics/answer/9234069) — first_open, app_open, screen_view auto-tracked
- [ATT vs GDPR Compliance](https://secureprivacy.ai/blog/mobile-app-consent-ios-2025) — ATT is for IDFA only, GDPR requires separate consent
- [GA4 Data Processing Terms](https://business.safety.google/processorterms/) — Standard Contractual Clauses for EU data transfer
- [iOS Analytics Architecture Patterns](https://medium.com/ios-os-x-development/architecting-an-analytics-layer-7cdacb5f74af) — protocol abstraction pattern

---

## 5. Market Examples

| App | Analytics Approach | What They Do Well | What They Do Poorly |
|-----|--------------------|-------------------|---------------------|
| **Strava** | Firebase + custom | Rich segment tracking, workout completion funnels | Heavy consent flow, complex opt-out |
| **MyFitnessPal** | Mixpanel + Firebase | Food logging funnels, streak analytics | Over-instrumented, slow app |
| **Strong** | Amplitude | Clean workout tracking events | Limited nutrition integration |
| **Hevy** | TelemetryDeck | Privacy-first, no consent popup | Basic analytics, can't do cohort analysis |

---

## 6. UI Component

**Yes, this feature has UI:**
- GDPR consent screen (first launch or settings)
- ATT permission dialog (iOS native)
- Analytics opt-out toggle in Settings
- Privacy Nutrition Label updates in App Store Connect

**Design:** Consent screen should follow progressive disclosure — brief explanation, clear accept/decline, link to privacy policy. No dark patterns.

---

## 7. Data & Demand Signals

- **14 of 40 metrics** in the metrics framework require GA4 (DAU, WAU, MAU, retention, session length, screen views, readiness check-in rate, recommendation acceptance rate)
- **PRD Section 1.8** defines Cross-feature WAU as the North Star — unmeasurable without analytics
- **Every future feature's PRD** depends on baseline metrics that GA4 provides
- **Kill criteria** for all features require analytics data to evaluate

---

## 8. Technical Feasibility

**Dependencies:**
- Firebase iOS SDK (SPM) — FirebaseAnalytics package
- GoogleService-Info.plist — Firebase project config file
- ATT framework (built into iOS 14.5+)

**Risks:**
- Firebase Performance Monitoring conflicts with SwiftUI previews — mitigation: only use Analytics, not Performance
- Automatic screen_view tracking is UIViewController-based — SwiftUI needs manual `.onAppear` tracking
- GDPR consent must gate ALL analytics calls — need consent check wrapper

**Existing patterns to follow:**
- Service pattern: `@MainActor` + `ObservableObject` + `@EnvironmentObject` (like SupabaseSyncService, HealthKitService)
- Privacy: GDPR-aware codebase (AITypes.swift already cites Article 5)
- Init: Add to `FitTrackerApp.swift` alongside existing 10 services

**Platform constraints:**
- iOS 15+ (app minimum) — Firebase supports iOS 11+, no issue
- SwiftUI — manual screen tracking needed
- No Firebase project exists yet — need to create one in Firebase Console

---

## 9. Proposed Success Metrics

**Primary:** Analytics event delivery rate — % of user actions that successfully log to GA4 (target: >99%)

**Secondary:**
- DAU measurability — can we report DAU within 24h of deploy? (yes/no)
- Event taxonomy coverage — % of 40 framework metrics with instrumentation (target: 14/40 = 35%)
- Consent acceptance rate — % of users who accept analytics (target: >70%)

**Guardrails:**
- Cold start time must not increase >200ms
- Crash-free rate must stay >99.5%
- App binary size increase <10MB

---

## 10. Decision

**Recommended approach:** GA4 via Firebase Analytics SDK with protocol-based abstraction layer.

**Architecture:**
```
AnalyticsProtocol (interface)
    ├── FirebaseAnalyticsAdapter (GA4 implementation)
    ├── MockAnalyticsAdapter (testing/previews)
    └── (future: TelemetryDeckAdapter, MixpanelAdapter)

ConsentManager (gates all analytics calls)
    ├── ATT permission check
    ├── GDPR consent state (UserDefaults + Supabase sync)
    └── Settings toggle
```

**Scope:** ~25 screen events, ~15 custom events, consent flow, Settings toggle, Privacy Nutrition Label.

**Effort estimate:** 2 weeks (10 working days).
