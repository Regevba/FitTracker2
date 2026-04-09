# Feature Verification Prompts — Claude Console

> **Purpose:** Copy-paste prompts for Claude Console to audit each shipped feature, verify implementation quality, and identify gaps.
> **How to use:** Open Claude Console (claude.ai), paste the relevant prompt, attach the codebase or use Claude Code.
> **Date:** 2026-04-04

---

## A. Shipped iOS Features

### A1. Training Tracking

```
AUDIT: FitMe Training Tracking Feature

Read and analyze the following files:
- FitTracker/Views/Training/TrainingPlanView.swift
- FitTracker/Services/TrainingProgramStore.swift
- FitTracker/Models/TrainingProgramData.swift
- FitTracker/Models/DomainModels.swift (ExerciseLog, SetLog, CardioLog, DailyLog)

Verify:
1. Count all ExerciseDefinition entries — how many unique exercises exist? (README says 87, PRD says 49)
2. Verify RPE tracking works (6-10 scale per set)
3. Verify PR detection logic — does it correctly exclude warmup sets?
4. Verify rest timer implementation — are haptic alerts at 10s and 0s?
5. Verify CardioLog photo capture — is the image encrypted before storage?
6. Verify Zone 2 HR validation — what HR range is used?
7. Check for accessibility: VoiceOver labels, Dynamic Type support
8. Check for edge cases: empty exercise list, zero sets, negative weights

Report: exercise count, features working/broken, edge case handling, accessibility gaps.
```

### A2. Nutrition Logging

```
AUDIT: FitMe Nutrition Logging Feature

Read and analyze:
- FitTracker/Views/Nutrition/NutritionView.swift
- FitTracker/Views/Nutrition/MealEntrySheet.swift
- FitTracker/Views/Nutrition/MealSectionView.swift
- FitTracker/Views/Nutrition/MacroTargetBar.swift
- FitTracker/Models/DomainModels.swift (NutritionLog, MealEntry, SupplementLog, MealTemplate)

Verify:
1. All 4 meal entry tabs work: Smart (OCR), Manual, Template, Search/Barcode
2. Barcode scanning — does it use Vision framework for UPC/EAN extraction?
3. OCR label parsing — does it support both English and Hebrew?
4. Supplement AM/PM stacks — does individual checkbox override work?
5. Supplement streak detection — are milestones at 7/14/30/60/90 days?
6. Hydration tracking — are targets different for training (3500ml) vs rest (2800ml)?
7. Macro progress bar — does it correctly compute from individual meals?
8. Template save/reuse — does it persist via EncryptedDataStore?

Report: tab functionality, OCR capabilities, streak logic, edge cases.
```

### A3. Recovery & Biometrics

```
AUDIT: FitMe Recovery & Biometrics Feature

Read and analyze:
- FitTracker/Services/HealthKitService.swift
- FitTracker/Models/DomainModels.swift (DailyBiometrics, LiveMetrics)
- FitTracker/Views/Main/MainScreenView.swift (ManualBiometricEntry section)

Verify:
1. HealthKit metrics: confirm HR, HRV, VO2Max, steps, sleep (total/deep/REM) are all fetched
2. Readiness scoring formula: is it 40% HRV + 30% RHR + 30% Sleep?
3. RHR thresholds: <60 excellent, <75 good, <85 caution, else alert?
4. HRV thresholds: ≥45 excellent, ≥35 good, ≥28 caution, else alert?
5. isReadyForTraining: RHR < 75 AND HRV ≥ 28?
6. Manual fallback: can users enter RHR, HRV, sleep when Apple Watch is unavailable?
7. Smart scale fields: weight, BF%, lean mass, muscle mass, bone mass, visceral fat, body water, BMI, metabolic age, BMR?
8. HealthKit debounce: is it 500ms to handle multiple observer callbacks?

Report: data sources, readiness formula accuracy, fallback paths.
```

### A4. Home / Today Screen

```
AUDIT: FitMe Home / Today Screen

Read and analyze:
- FitTracker/Views/Main/MainScreenView.swift
- FitTracker/Views/Main/ReadinessCard.swift
- FitTracker/Views/Shared/LiveInfoStrip.swift

Verify:
1. No-scroll design: does the home screen fit without scrolling on iPhone?
2. ReadinessCard pages: are there exactly 6 pages (readiness, training chart, nutrition, trends, achievements, recovery)?
3. LiveInfoStrip: does it cycle every 5 seconds?
4. Start Training CTA: does it show today's day type with override menu?
5. Metrics tiles: HRV, RHR, Sleep, Steps — do they pull from LiveMetrics with manual fallback?
6. Milestone modals: do they trigger at 7/14/30/60/90 day supplement streaks?
7. Goal progress card: does it show weight and body fat progress separately?
8. Responsive design: does it adapt to compact/tight screen heights?

Report: layout fidelity, auto-cycling, CTA functionality, responsiveness.
```

### A5. Stats / Progress Hub

```
AUDIT: FitMe Stats / Progress Hub

Read and analyze:
- FitTracker/Views/Stats/StatsView.swift
- FitTracker/Services/StatsDataHelpers.swift
- FitTracker/Views/Shared/ChartCard.swift
- FitTracker/Views/Shared/MetricCard.swift

Verify:
1. 18 metrics: list all StatsFocusMetric enum cases — are there exactly 18?
2. 5 time periods: Daily, Weekly, Monthly, 3 Months, 6 Months?
3. Chart types: AreaMark+LineMark for trends, BarMark for volume/steps?
4. Interactive overlay: tap/drag to inspect individual data points?
5. Target lines: dashed lines for weight/BF/protein/calorie goals?
6. Coverage summary: shows "{N}/14 days logged" with category breakdown?
7. Source badges: displays data sources active in selected range?
8. PR detection: all-time best weight per exercise (excluding warmups)?

Report: metric completeness, chart accuracy, interaction quality.
```

### A6. Authentication

```
AUDIT: FitMe Authentication System

Read and analyze:
- FitTracker/Services/Auth/SignInService.swift
- FitTracker/Services/Auth/AuthManager.swift
- FitTracker/Services/Auth/SupabaseAppleAuthProvider.swift
- FitTracker/Services/Auth/EmailAuthProvider.swift
- FitTracker/Views/Auth/ (all views)

Verify:
1. Apple Sign In: OAuth nonce exchange → Supabase JWT?
2. Passkey: platform (Face ID/Touch ID) + hardware (YubiKey) support?
3. Email/OTP: registration flow with 5-digit code verification?
4. Biometric lock: auto-lock on background, unlock on reopen?
5. Session persistence: encrypted JSON in Keychain?
6. Three-way session merge: Supabase JWT + local metadata + Keychain?
7. Simulator auto-login: works in DEBUG builds?
8. Security: no passwords stored in plaintext, no hardcoded secrets?

Report: auth flows, session management, security posture.
```

### A7. Settings

```
AUDIT: FitMe Settings

Read and analyze:
- FitTracker/Views/Settings/SettingsView.swift
- FitTracker/Services/AppSettings.swift
- FitTracker/Views/Settings/DeleteAccountView.swift
- FitTracker/Views/Settings/ExportDataView.swift

Verify:
1. Count all settings categories and individual options
2. GDPR: Delete Account works (10-step cascade, 30-day grace, biometric re-auth)?
3. GDPR: Export Data works (JSON format, iOS share sheet)?
4. Analytics toggle: runtime enable/disable via ConsentManager?
5. Unit system: metric/imperial with conversion helpers?
6. Appearance: system/light/dark?
7. Zone 2 HR boundaries: configurable?
8. Biometric unlock toggle: works?

Report: settings completeness, GDPR compliance, persistence.
```

### A8. Data & Sync

```
AUDIT: FitMe Data & Sync (Encrypted)

Read and analyze:
- FitTracker/Services/Encryption/EncryptionService.swift
- FitTracker/Services/EncryptedDataStore.swift
- FitTracker/Services/Supabase/SupabaseSyncService.swift
- FitTracker/Services/CloudKit/CloudKitSyncService.swift

Verify:
1. Double-layer encryption: AES-256-GCM then ChaCha20-Poly1305?
2. HMAC-SHA512 integrity per record?
3. Container format: [version][timestamp 8B][HMAC 64B][ChaCha20 ciphertext]?
4. Key storage: Keychain with biometric ACL?
5. CloudKit sync: fetchChanges on active, pushPending on background?
6. Supabase sync: base64 encrypted payloads with SHA-256 checksum?
7. Conflict resolution: last-modified-wins for DailyLogs, three-way merge for singletons?
8. Key rotation: decrypt all → new keys → re-encrypt → persist?
9. Data stores: count all 9 (DailyLog, WeeklySnapshot, UserProfile, UserPreferences, MealTemplates, ExerciseLog, CardioLog, NutritionLog, SupplementLog)?

Report: encryption layers, sync reliability, conflict resolution, key management.
```

### A9. AI / Cohort Intelligence

```
AUDIT: FitMe AI / Cohort Intelligence

Read and analyze:
- FitTracker/AI/AIOrchestrator.swift
- FitTracker/AI/AIEngineClient.swift
- FitTracker/AI/AITypes.swift
- FitTracker/AI/AISnapshotBuilder.swift
- FitTracker/AI/FoundationModelService.swift

Verify:
1. Three-tier pipeline: Local Rules → Cloud Cohort → Foundation Models?
2. Banding functions: age, BMI, sleep, training frequency discretized to categorical ranges?
3. k-anonymity: k≥50 minimum before returning cohort signals?
4. Confidence threshold: Foundation Model results discarded if <0.4?
5. JWT authentication: JWKS validation for cloud requests?
6. Error handling: rate limited, unauthenticated, network error all fall back to local?
7. Foundation Model: is it a placeholder (FallbackFoundationModel) for pre-iOS 26?
8. 4 segments: training, nutrition, recovery, stats?
9. No PII in banded data: verify no names, emails, device IDs transmitted?

Report: privacy guarantees, fallback chains, confidence gating, production readiness.
```

### A10. Design System

```
AUDIT: FitMe Design System v2

Read and analyze:
- FitTracker/Services/AppTheme.swift
- FitTracker/DesignSystem/DesignTokens.swift
- FitTracker/DesignSystem/AppPalette.swift
- FitTracker/DesignSystem/AppComponents.swift
- FitTracker/DesignSystem/AppMotion.swift
- FitTracker/DesignSystem/AppViewModifiers.swift
- design-tokens/tokens.json
- sd.config.js

Verify:
1. Count all tokens in AppTheme (colors, spacing, radius, typography, motion, shadow, icons)
2. Verify DesignTokens.swift has "DO NOT EDIT" header and is auto-generated
3. Verify AppPalette is never used directly in views (only via AppTheme)
4. Count all reusable components in AppComponents.swift
5. WCAG AA: ColorContrastValidator in DEBUG — are ratios correct?
6. Motion: respects isReduceMotionEnabled?
7. Token pipeline: make tokens generates correctly?
8. Style Dictionary: does sd.config.js support both iOS and Android output?

Report: token count (exact), component count, accessibility compliance, pipeline health.
```

---

## B. PM Workflow Features

### B1. Google Analytics (GA4)

```
AUDIT: FitMe Google Analytics Integration

Read and analyze:
- FitTracker/Services/Analytics/AnalyticsService.swift
- FitTracker/Services/Analytics/AnalyticsProvider.swift
- FitTracker/Services/Analytics/ConsentManager.swift
- FitTracker/Services/Analytics/AnalyticsEvents.swift
- FitTracker/Views/Auth/ConsentView.swift
- docs/product/analytics-taxonomy.csv

Verify:
1. Count all defined events — are there exactly 20?
2. Count all screen views tracked — are there 9+ primary views?
3. ConsentManager: GDPR consent persists in UserDefaults?
4. AnalyticsService: events blocked when consent denied?
5. Settings toggle: runtime enable/disable works?
6. MockAnalyticsAdapter: exists for testing?
7. Firebase SDK: imported via SPM?
8. ATT (App Tracking Transparency): implemented?

Report: event count, screen count, consent flow, test coverage.
```

### B2. GDPR Compliance

```
AUDIT: FitMe GDPR Compliance

Read and analyze:
- FitTracker/Services/AccountDeletionService.swift
- FitTracker/Services/DataExportService.swift
- FitTracker/Views/Settings/DeleteAccountView.swift
- FitTracker/Views/Settings/ExportDataView.swift

Verify:
1. Deletion cascade: does it hit all 9 data stores?
2. 30-day grace period: can user cancel?
3. Biometric re-auth: required before deletion?
4. "I understand" toggle: prevents accidental deletion?
5. Data export: JSON format with all user data?
6. Share sheet: iOS native share for export?
7. 5 analytics events: delete requested/completed/cancelled, export requested/completed?
8. Test coverage: 6 GDPR-specific tests?

Report: GDPR Article compliance (15, 17, 20), deletion completeness, export accuracy.
```

### B3. Development Dashboard

```
AUDIT: FitMe Development Dashboard

Read and analyze the dashboard/ directory:
- dashboard/src/components/ (all React components)
- dashboard/src/lib/parsers/ (all markdown parsers)
- dashboard/src/lib/reconciliation.js
- dashboard/src/lib/github.js

Verify:
1. Kanban board: 8 columns, drag-drop with dnd-kit, undo toast?
2. Table view: @tanstack/react-table, sortable, filterable, searchable?
3. Pipeline overview: stacked bar chart?
4. Reconciliation engine: detects state.json vs GitHub drift?
5. 6 markdown parsers: backlog, roadmap, PRD, metrics, state, unified?
6. Dark mode: localStorage + system preference?
7. Responsive: desktop, tablet, mobile?
8. Build: npm run build succeeds?

Report: component functionality, parser coverage, reconciliation accuracy.
```

### B4. Android Design System

```
AUDIT: FitMe Android Design System Research

Read and analyze:
- docs/design-system/android-token-mapping.md
- docs/design-system/android-adaptation.md
- sd.config.js (Android platform output)

Verify:
1. Token mapping: all 92 iOS tokens mapped to MD3 equivalents?
2. Color system: Brand → MD3 primary/secondary/tertiary?
3. Typography: iOS type scale → MD3 type scale?
4. Spacing: iOS scale → MD3 8dp grid?
5. Motion: iOS springs → MD3 motion tokens?
6. Style Dictionary: Android output generates Kotlin/Compose + XML?
7. Component parity: 13 iOS components mapped to MD3 composables?
8. Dark mode: iOS opacity-based → MD3 tonal elevation?

Report: mapping completeness, Style Dictionary output, gap analysis.
```

### B5. Marketing Website

```
AUDIT: FitMe Marketing Website

Read and analyze the website/ directory:
- website/src/pages/index.astro
- website/src/components/ (all 9 .astro components)
- website/src/layouts/Layout.astro
- website/src/scripts/analytics.js
- website/src/styles/global.css

Verify:
1. All 9 sections render: Nav, Hero, Features, Screenshots, HowItWorks, Privacy, FAQ, CTA, Footer?
2. SEO: JSON-LD SoftwareApplication, OG tags, Twitter Card, canonical URL?
3. GA4: gtag.js loaded, G-XXXXXXXXXX placeholder present?
4. 3 custom events: cta_click (with cta_location, cta_type), section_view (section_name), faq_expand (question_index)?
5. Mobile responsive: hamburger menu, responsive grid?
6. App Store badge: links to correct URL?
7. robots.txt and favicon.svg exist?
8. Build: npm run build succeeds?

Report: section completeness, SEO score, analytics instrumentation, build status.
```

---

## C. Infrastructure

### C1. CI Pipeline

```
AUDIT: FitMe CI Pipeline

Read and analyze:
- .github/workflows/ci.yml
- Makefile
- scripts/check-tokens.js
- sd.config.js

Verify:
1. Three stages: token check → build → test?
2. Token check: make tokens-check correctly detects drift?
3. Build: xcodebuild with correct flags (no code signing)?
4. Test: XCTest suite runs and reports results?
5. Triggers: PR to main + push to main?
6. Failure handling: artifacts captured, error summary?
7. Makefile targets: tokens, tokens-check, install all work?

Report: pipeline reliability, gate effectiveness, failure recovery.
```

### C2. PM Workflow Skill

```
AUDIT: FitMe PM Workflow Skill (/pm-workflow)

Read and analyze:
- .claude/skills/pm-workflow/SKILL.md
- CLAUDE.md (PM-related rules)
- .claude/features/*/state.json (all 5 features)

Verify:
1. 9 phases: research → prd → tasks → ux → implement → test → review → merge → docs?
2. Analytics gate: requires_analytics flag enforces spec validation?
3. Design system compliance gateway: validates tokens, components, accessibility?
4. State.json: full transition audit trail for all 5 features?
5. GitHub Issue sync: auto-label on phase transition?
6. Manual override: skip and rollback work?
7. Templates: research.md, prd.md, tasks.md, ux-spec.md all generated?
8. All 5 features completed all 9 phases?

Report: phase completeness, gate enforcement, audit trail integrity.
```

---

## D. Quick Reference: What Each Prompt Validates

| Feature | Prompt | Key Verification | Risk Level |
|---------|--------|-----------------|------------|
| Training | A1 | Exercise count, PR logic, encryption | Medium |
| Nutrition | A2 | OCR, barcode, 4 tabs, streaks | Medium |
| Recovery | A3 | Readiness formula, HealthKit sync | High |
| Home | A4 | No-scroll layout, 6-page card | Low |
| Stats | A5 | 18 metrics, chart types, periods | Medium |
| Auth | A6 | Apple OAuth, passkeys, session | **Critical** |
| Settings | A7 | GDPR options, persistence | Medium |
| Data & Sync | A8 | Double encryption, conflict resolution | **Critical** |
| AI | A9 | Privacy (no PII), k-anonymity, fallback | **Critical** |
| Design System | A10 | Token count, pipeline, WCAG | Medium |
| GA4 | B1 | Event count, consent, ATT | High |
| GDPR | B2 | Deletion cascade, grace period | **Critical** |
| Dashboard | B3 | Drag-drop, parsers, reconciliation | Low |
| Android DS | B4 | Token mapping, Style Dictionary | Low |
| Website | B5 | SEO, GA4, responsive | Medium |
| CI | C1 | Three gates, failure handling | High |
| PM Skill | C2 | Phase completeness, audit trail | Medium |
