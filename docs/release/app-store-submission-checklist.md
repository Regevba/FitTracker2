# App Store Submission Checklist — FitMe

**Last updated:** 2026-04-16  
**Target:** iOS App Store, initial release

---

## Pre-Submission

### App Icon
- [ ] 1024x1024 px PNG, no alpha channel, no rounded corners (Apple applies mask)
- [ ] Icon matches brand: orange FitMe mark on blue background
- [ ] All required icon sizes generated via Xcode asset catalog

### Screenshots
- [ ] 5 screenshots captured for iPhone 17 Pro (6.7", 1290x2796) — see `docs/product/app-store-screenshots.md`
- [ ] Screenshots reviewed: no placeholder data, no debug UI, no status bar anomalies
- [ ] Captions written (max 170 chars each)
- [ ] Optional: iPad screenshots (if iPad target is enabled)

### Metadata
- [ ] App name: **FitMe** (30 char max — confirmed)
- [ ] Subtitle: "Readiness-Powered Fitness Tracking" (30 char max)
- [ ] Description: complete, benefit-led, no competitor mentions (4000 char max)
- [ ] Keywords: comma-separated, 100 char max — e.g. `fitness,workout,HRV,recovery,nutrition,tracking`
- [ ] Promotional text: seasonal/updatable blurb (170 char max, no review required)
- [ ] What's New (version notes): concise, user-facing language

### Legal & Compliance
- [ ] Privacy policy URL live and accessible (required for HealthKit apps)
- [ ] Support URL live and returning 200
- [ ] Marketing URL (optional but recommended)
- [ ] HealthKit usage strings in Info.plist match actual data accessed
- [ ] App Tracking Transparency (ATT) prompt implemented if IDFA used
- [ ] GDPR / data deletion flow in Settings if EU users targeted

---

## Build Requirements

### Archive
- [ ] Scheme set to Release configuration
- [ ] Code signing: Distribution certificate + App Store provisioning profile
- [ ] Archive via Xcode: **Product → Archive**
- [ ] Bundle ID matches App Store Connect record: `com.fitme.app` (confirm)
- [ ] Version and build number incremented (CFBundleShortVersionString + CFBundleVersion)

### Upload
- [ ] Upload via **Xcode Organizer → Distribute App → App Store Connect**
- [ ] Or use `altool` / `xcrun altool` for CI pipelines
- [ ] Build passes Apple's automated checks (bitcode, entitlements, symbols)

### CI Gate (must be green before submitting)
- [ ] `make tokens-check` passes
- [ ] `xcodebuild build` passes (iOS Simulator)
- [ ] `xcodebuild test` passes (all XCTest targets)

---

## App Store Connect Configuration

### App Information
- [ ] Primary category: **Health & Fitness**
- [ ] Secondary category: Sports (optional)
- [ ] Age rating: **4+** (no objectionable content)
- [ ] Pricing: **Free** (no in-app purchases at launch unless implemented)
- [ ] Availability: All territories, or selected regions

### Review Information
- [ ] Demo account credentials provided (required if login is needed for review)
- [ ] Notes to reviewer: explain HealthKit permissions, any special setup
- [ ] Contact info: name + phone number for App Review team

---

## Post-Submission

### TestFlight Beta (recommended before public release)
- [ ] Internal testing group added (team members)
- [ ] External beta group created if broader testing desired
- [ ] Beta feedback channel monitored (TestFlight feedback + Sentry)

### Release Strategy
- [ ] Phased release enabled: 7-day rollout (1% → 2% → 5% → 10% → 20% → 50% → 100%)
- [ ] Manual release hold set if coordinating with a marketing launch
- [ ] Rollback plan: previous build archived and ready to re-submit if P0 found

### Post-Launch Monitoring (first 48h)
- [ ] Sentry crash-free rate > 99.5% (kill threshold: < 98%)
- [ ] App Store Connect — no sudden rating drops
- [ ] Firebase Analytics — `app_open` events flowing, cold start < 2s
- [ ] Support inbox monitored for launch-day issues
