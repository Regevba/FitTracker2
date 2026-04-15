# PRD: App Icon + App Store Assets

> **ID:** app-store-assets | **Status:** In Progress | **Priority:** HIGH (Release Readiness)
> **Last Updated:** 2026-04-15 | **Phase:** PRD → Tasks

---

## Purpose

Produce the complete release-visual package for FitMe: a production-quality app icon derived from the existing brand system, a full-resolution screenshot set covering the required App Store device sizes, and the store metadata copy (title, subtitle, keywords, description). Without this package the app cannot be submitted to App Store Connect regardless of feature completeness.

## Business Objective

App Store first impressions are decisive. The icon and screenshots are the primary conversion surface between an impression and a download. A truthful, polished visual package that reflects the v2 UI quality:

1. Enables App Store submission (hard dependency — zero launch without assets).
2. Drives impression-to-download conversion above the fitness-app category median (~3–4%).
3. Creates a reusable, repeatable pipeline so future releases refresh assets in under 2 hours rather than starting from scratch.

## Problem Statement

The app currently has no production app icon asset set checked into the repo. The App Store screenshot pipeline is missing entirely. The v2 UI surfaces are now strong enough to support truthful screenshot capture, but the release-visual layer does not yet exist. This is a hard blocker for any public distribution.

## Success Metrics

| Metric | Baseline | Target | Kill Criteria |
|---|---|---|---|
| Asset pipeline completeness | 0% | 100% (all required sizes exported + checked in) | Any missing required size at launch = blocked |
| Impression-to-download rate | 0 (no listing) | ≥ 4% within 30 days post-launch | < 2% at D+30 → screenshot redesign |
| Screenshot refresh time | N/A | ≤ 2 hours for a full new-release refresh | > 8 hours → rebuild pipeline |
| Keyword ranking (primary: "fitness tracker") | Unranked | Top 100 within 60 days | No movement at D+60 → metadata rewrite |
| App Store listing conversion (product page views → downloads) | 0 | ≥ 30% | < 15% at D+30 → A/B metadata test |

**North Star:** impression-to-download rate. Every other metric is a lever to improve it.

---

## Requirements

### P0 — Launch Blockers

| ID | Requirement | Detail |
|---|---|---|
| ASA-1 | App icon master (1024×1024 px) | PNG, no alpha, sRGB, 1024×1024. Derived from Figma node 635:2 (4-circle FitMe brand mark). |
| ASA-2 | AppIcon.appiconset complete | All iOS required sizes generated and checked into `FitTracker/Assets.xcassets/AppIcon.appiconset/`. Sizes: 20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt, 1024pt at required @1x/@2x/@3x scales per Apple guidelines. |
| ASA-3 | Screenshots — 6.7" device (iPhone 15 Pro Max) | Minimum 3, maximum 10 screenshots at 1290×2796 px. Required screens: Today/Home, Training, Nutrition. |
| ASA-4 | Screenshots — 6.5" device (iPhone 14 Plus / 13 Pro Max) | Same 3+ screenshots at 1242×2688 px. Required for App Store Connect compatibility. |
| ASA-5 | App Store metadata: title | Max 30 characters. Must include "FitMe" + 1–2 high-value keywords. |
| ASA-6 | App Store metadata: subtitle | Max 30 characters. Keyword-rich value proposition. |
| ASA-7 | App Store metadata: description | Max 4000 characters. Above-the-fold hook + feature list + CTA. |
| ASA-8 | App Store metadata: keywords | Max 100 characters, comma-separated. No repetition of title/subtitle terms. |
| ASA-9 | Age rating questionnaire answers | Completed in App Store Connect for Health & Fitness category. |

### P1 — Quality Bar

| ID | Requirement | Detail |
|---|---|---|
| ASA-10 | Screenshots show real app UI, not mockups | All screenshots captured from live simulator or device running the actual app. Light device framing and caption overlays allowed. |
| ASA-11 | Screenshot captions | Each screenshot includes a 1-line headline (≤ 25 chars) and optional sub-caption. Text uses AppTheme tokens (colors, fonts) for consistency. |
| ASA-12 | Additional screenshot sizes — 5.5" (iPhone 8 Plus) | 1242×2208 px. Required if 6.5" not submitted as universal. Submit all three sets to maximise device coverage. |
| ASA-13 | iPad screenshots (12.9" 2nd gen) | 2048×2732 px. Required for universal app listing. Minimum 1 screenshot per required iPad size if iPad target is declared. |
| ASA-14 | Screenshot Figma template system | Reusable Figma frames (device frame + caption layer) checked into the design file for future refresh cycles. |
| ASA-15 | Promotional text | Max 170 characters. Not keyword-indexed by Apple; used for time-sensitive messaging. Optional at launch but drafted. |
| ASA-16 | What's New (release notes) | Max 4000 characters. First-launch version drafted. |

### P2 — Nice to Have

| ID | Requirement | Detail |
|---|---|---|
| ASA-17 | App Preview video — 6.7" | 15–30 second MP4 (1290×2796, H.264, 30fps). Demonstrates onboarding → Today → Training flow. |
| ASA-18 | App Preview video — 6.5" | Same video downscaled/re-exported for 1242×2688. |
| ASA-19 | Localised metadata (EN-GB) | English (UK) subtitle and description variant. |
| ASA-20 | App Store Connect screenshot annotation | In-app screenshot overlays highlight key interactions (e.g. readiness ring, macro ring) with pointer callouts. |

---

## Asset Specifications

### App Icon

| Property | Value |
|---|---|
| Master file | `AppStore/AppIcon-1024.png` (tracked in repo) |
| Format | PNG-24, no alpha channel, no rounded corners (Apple applies mask) |
| Color space | sRGB |
| Brand source | Figma file, node 635:2 (4-circle intertwined mark + "FitMe" gradient text) |
| Background | Dark gradient matching brand (no transparency) |
| Required output sizes | 20×20, 29×29, 40×40, 60×60, 76×76, 83.5×83.5, 120×120, 152×152, 167×167, 180×180, 1024×1024 |
| Generation method | Script or Makefile target (`make icon`) from 1024 master |

### Screenshots

| Size class | Device | Resolution | Orientation |
|---|---|---|---|
| 6.7" (required) | iPhone 15 Pro Max | 1290×2796 px | Portrait |
| 6.5" (required) | iPhone 14 Plus | 1242×2688 px | Portrait |
| 5.5" (required if no 6.5") | iPhone 8 Plus | 1242×2208 px | Portrait |
| 12.9" iPad (required if iPad declared) | iPad Pro 6th gen | 2048×2732 px | Portrait |

**Minimum screenshot count per size:** 3  
**Maximum:** 10  
**Required screens (in order):** Today/Home → Training → Nutrition → Stats → Onboarding (optional)

### Metadata Fields

| Field | Limit | Notes |
|---|---|---|
| Name (title) | 30 chars | Appears below icon in search results. Keyword weight = highest. |
| Subtitle | 30 chars | Appears below name in search. Second-highest keyword weight. |
| Keywords | 100 chars | Comma-separated. No spaces after commas. Do not repeat title/subtitle words. |
| Description | 4000 chars | First 255 chars shown before "more". Lead with strongest benefit. |
| Promotional text | 170 chars | Not keyword-indexed. Can be updated without a new build submission. |
| What's New | 4000 chars | Shown on update page. First release: launch announcement. |
| Support URL | URL | Required. Can point to marketing site or GitHub. |
| Privacy Policy URL | URL | Required for any app collecting user data. |

---

## Screenshot Story (Canonical Order)

1. **Today Screen** — "Your day, at a glance." Readiness ring, training CTA, macro summary.
2. **Training** — "Built for your program." Active workout or plan view.
3. **Nutrition** — "Every macro, tracked." Meal log with ring and goals.
4. **Stats** — "See your progress." Chart view with a trend line.
5. **Onboarding** (optional, last slot) — "Set up in 60 seconds." Goal-selection step.

Each screenshot: device frame (optional) + 1-line headline + optional sub-caption. Clean, real app state — no fabricated data.

---

## Dependencies

| Dependency | Owner | Blocker? |
|---|---|---|
| Apple Developer Program enrollment (paid, $99/yr) | Regev | Yes — required for App Store Connect access and TestFlight |
| App Store Connect app record created | Regev | Yes — bundle ID must be registered before asset upload |
| Figma file access (node 635:2) | Regev | Yes — icon master derived from brand node |
| v2 UI surfaces in buildable state | Engineering | Yes — screenshots must come from real app |
| Privacy Policy URL live | Regev | Yes — required field before submission |
| Auth runtime verification complete | Engineering | Recommended — screenshots should reflect a fully working product |
| Marketing website live (Support URL) | Marketing | Recommended — referenced in metadata |

---

## Key Files

| File | Purpose |
|---|---|
| `FitTracker/Assets.xcassets/AppIcon.appiconset/` | Xcode asset catalog for compiled icon |
| `AppStore/AppIcon-1024.png` | Master icon export (to be created) |
| `AppStore/screenshots/6.7/` | 6.7" screenshot outputs (to be created) |
| `AppStore/screenshots/6.5/` | 6.5" screenshot outputs (to be created) |
| `AppStore/metadata/` | Metadata copy files (title, subtitle, keywords, description) |
| `Makefile` | `make icon` target for icon size generation |
| `docs/product/prd/app-store-assets.md` | This PRD |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Screenshots show stale or inconsistent app state | Medium | High | Capture from a freshly seeded simulator state; define canonical seed data |
| Icon fails Apple review (alpha channel, wrong size) | Low | High | Generate from validated 1024 master; run through validator before submission |
| Metadata rejected for keyword stuffing | Low | Medium | Follow Apple metadata guidelines; avoid competitor names |
| Screenshot art overpromises missing runtime features | Medium | High | Only show features that are fully working at time of capture |
| Asset pipeline not maintained across releases | Medium | Medium | Makefile target + Figma template system makes refresh < 2 hours |

---

## Out of Scope

- App Clips icon
- macOS or tvOS asset variants
- Paid Apple Search Ads campaigns (separate marketing feature)
- App Store localisation beyond EN-US and EN-GB (P2)
- App Review information / demo account setup (handled at submission time)
