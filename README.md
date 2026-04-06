![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue)
![CI](https://github.com/Regevba/FitTracker2/actions/workflows/ci.yml/badge.svg)

# FitMe

**The iPhone-first fitness command center that unifies training, nutrition, recovery, and body composition into a single privacy-first experience — powered by federated AI.**

FitMe replaces your training log, meal tracker, and recovery dashboard with one app that knows what you should do today — without ever seeing your private health data.

> Repo name is `FitTracker2` for historical reasons. The product brand is **FitMe**.

---

## Features

### Training
- 49 exercises across a 6-day push/pull/legs split (Upper Push, Lower Body, Upper Pull, Full Body, Cardio Only)
- Set-by-set logging with weight, reps, RPE (6-10), and per-set notes
- Automatic PR detection and progressive overload tracking with 1RM estimation
- Floating rest timer with haptic feedback (customizable presets)
- Cardio tracking with heart rate Zone 2 detection and machine photo capture (encrypted JPEG)
- Focus mode for distraction-free data entry
- Session completion summary with volume delta and milestone celebrations

### Nutrition
- Dynamic macro targets that adapt to training day, program phase, and body composition goals
- 4-tab meal entry: smart label parsing (English + Hebrew OCR), manual, templates, search/barcode (Open Food Facts)
- Morning + evening supplement tracking with streak detection and milestone celebrations (7/14/30/60/90 days)
- Quick-log favorites for fast re-logging
- Hydration tracking with training-day (3500ml) vs rest-day (2800ml) targets

### Recovery & Biometrics
- HealthKit integration for HR, HRV, VO2Max, steps, sleep (total/deep/REM)
- Manual entry for Xiaomi S400 smart scale (weight, body fat, lean mass, muscle mass, bone mass, visceral fat, body water, BMI, metabolic age, BMR)
- Daily readiness scoring: 40% HRV + 30% RHR + 30% Sleep quality (0-100 scale)
- Recovery Studio with personalized recommendations and routine steps
- Color-coded status dots with configurable thresholds

### Home / Today Screen
- Action-first design — no scrolling required on iPhone
- 6-page auto-cycling ReadinessCard (readiness, training chart, nutrition snapshot, 7-day trends, achievements, recovery recommendation)
- Animated LiveInfoStrip cycling greeting, readiness score, and supplement streak
- Start Training CTA with day type override and recovery context

### Stats & Progress
- 18 metrics across body, recovery, training, and nutrition
- Multi-period views: daily, weekly, monthly, 3-month, 6-month
- Interactive charts with tap/drag inspection and target lines
- Coverage summary with data source attribution
- All-time PR records with estimated 1RM (Epley formula)

### AI Intelligence
- Three-tier pipeline: local rules (always) → cloud cohort (banded data, k>=50) → Foundation Models (iOS 26+)
- Privacy-preserving bands — only categorical values leave the device (age "25-34", BMI "18.5-24.9")
- Confidence-gated: discards low-confidence personalized results (threshold 0.4)
- 4 recommendation segments: training, nutrition, recovery, stats
- Graceful degradation: always has local fallback, even offline

### Privacy & Security
- **Double-layer encryption:** AES-256-GCM + ChaCha20-Poly1305 with HMAC-SHA512 integrity
- **Secure Enclave** key storage with biometric ACL
- **Zero-knowledge sync** — servers store only encrypted `.ftenc` blobs
- **Federated AI** — no PII leaves the device
- **GDPR-oriented flows** — account deletion (30-day grace), data export (JSON), consent management; runtime verification is still being tightened
- **Apple Sign In + Passkeys (WebAuthn)** — no password database to breach

### Analytics
- Firebase Analytics (GA4) integration with GDPR-compliant consent management
- 20 typed events across 6 categories, 24 screen views, 6 user properties, 5 conversions
- Consent-gated: respects user opt-in/out via `ConsentManager`
- Settings toggle for runtime enable/disable
- Falls back to `MockAnalyticsAdapter` during XCTest or when a local Firebase plist is absent
- Clean simulator reinstall now verifies first launch reaches the consent gate without crashing
- Requires a local `GoogleService-Info.plist` for real Firebase runtime verification

---

## Screenshots

> Screenshots from the interactive Figma prototype will be added here.

| Home | Training | Nutrition | Stats | Settings |
|------|----------|-----------|-------|----------|
| *coming soon* | *coming soon* | *coming soon* | *coming soon* | *coming soon* |

Design file: [FitMe Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI, SF Symbols |
| Health | HealthKit |
| Auth | Apple Sign In (Supabase OAuth), Passkeys (WebAuthn), Email/OTP |
| Encryption | AES-256-GCM + ChaCha20-Poly1305 via CryptoKit, HMAC-SHA512 |
| Key Storage | Keychain with biometric ACL, Secure Enclave (P-256) |
| Sync | CloudKit (iCloud Private DB) + Supabase (PostgreSQL + Realtime) |
| AI — Cloud | FastAPI on Railway, JWT + JWKS validation, k>=50 anonymity |
| AI — On-device | Apple Intelligence Foundation Models (iOS 26+) |
| Analytics | Firebase Analytics (GA4) with GDPR consent |
| Design System | ~120 semantic tokens, Style Dictionary pipeline, CI drift detection |
| CI | GitHub Actions, Xcode 16+, `make tokens-check` gate |
| Web | Astro + Tailwind v4 + Vercel (dashboard + marketing website) |

---

## Architecture

```
                          iPhone (on-device)
┌─────────────────────────────────────────────────────┐
│  SwiftUI Views                                      │
│       ↕                                             │
│  EncryptedDataStore ← AES-256-GCM + ChaCha20       │
│       ↕                    ↕                        │
│  HealthKit Service    Keychain / Secure Enclave     │
│       ↕                                             │
│  AI Orchestrator                                    │
│    ├── Local rules (always available)               │
│    ├── Cloud cohort (banded values only) ──────────→│── AI Engine (FastAPI)
│    └── Foundation Model (private, on-device)        │      k≥50 anonymity
│                                                     │
│  AnalyticsService ← ConsentManager (GDPR)           │
│    └── FirebaseAnalyticsAdapter ────────────────────→│── GA4 (Firebase)
└─────────────────────────────────────────────────────┘
       ↕ encrypted .ftenc blobs only
┌──────────────┐  ┌──────────────┐
│  CloudKit    │  │  Supabase    │
│  (iCloud)    │  │  (PostgreSQL)│
└──────────────┘  └──────────────┘
```

**Zero-knowledge sync:** Servers store only encrypted `.ftenc` blobs. No plaintext health data ever leaves the device.

**Design system pipeline:** `tokens.json` → Style Dictionary → `DesignTokens.swift` (CI validates drift with `make tokens-check`).

---

## Web Properties

### Marketing Website (`website/`)
Public-facing marketing site at [fitme.app](https://fitme.app). Single-page Astro + Tailwind site with Hero, Features, Screenshots, How It Works, Privacy, FAQ sections. GA4 web analytics with 3 custom events (cta_click, section_view, faq_expand).

### Development Dashboard (`dashboard/`)
Internal PM dashboard. Astro + React + Tailwind with Kanban board (drag-drop), table view (sort/filter), pipeline overview chart, reconciliation alerts. Tracks 37 features across 8 lifecycle phases.

---

## Current Repo Status

Verification snapshot as of `2026-04-06`:

- iOS app builds again with full Xcode after Firebase/Xcode project recovery
- targeted iOS core XCTest coverage passes on simulator (`FitTrackerTests/FitTrackerCoreTests`, `31` tests)
- simulator settings review launch now reaches the live Settings screen
- simulator nested delete-account review route now reaches the live GDPR deletion screen
- simulator nested export-data review route now reaches the live portability/export screen
- export generation is now covered in the targeted iOS core XCTest suite
- sync merge coverage now verifies multiple dated daily logs and weekly snapshots coexist correctly
- design-token drift check passes
- dashboard tests pass (`9/9`) and the production build now passes
- marketing website production build now passes
- AI engine tests pass (`5/5`) with a self-contained test harness and stub settings override
- Firebase bootstrap is now config-aware, so missing local plist no longer blocks unit tests or clean builds
- Supabase runtime now degrades gracefully when local config is missing instead of crashing on placeholder values
- Firebase runtime verification still requires a local `FitTracker/GoogleService-Info.plist`
- live signed-in Supabase sync and deletion/export execution still require local runtime credentials and backend validation

Detailed recovery and verification notes live in [`docs/project/stabilization-report-2026-04-05.md`](docs/project/stabilization-report-2026-04-05.md).

---

## Getting Started

### Prerequisites
- Full Xcode installed and selected, not Command Line Tools only
- Xcode 26.4 verified during the current stabilization pass
- iOS 17.0+ deployment target
- Node.js for the root token pipeline and both web projects
- Python 3.12 for `ai-engine`

### Bootstrap

```bash
# Root token pipeline
npm install

# Dashboard
cd dashboard && npm install

# Marketing site
cd ../website && npm install

# AI engine (venv goes to .build/ on the SSD automatically)
cd ../ai-engine
python3.12 -m venv .build/ai-venv
source .build/ai-venv/bin/activate
pip install -e '.[dev]'
```

### SSD Development Environment

All build artifacts (DerivedData, SPM cache, npm cache, Python venv) are stored in `.build/` alongside the project source, keeping your internal drive clean.

**One-time Mac setup (optional):**
```bash
# Override Xcode default DerivedData to SSD
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation "/Volumes/DevSSD/FitTracker2/.build/DerivedData"

# Redirect Homebrew cache to SSD (if Homebrew is used)
echo 'export HOMEBREW_CACHE="/Volumes/DevSSD/.cache/homebrew"' >> ~/.zshrc
```

### One-Command Verification

```bash
make verify-local
```

This runs the token check, dashboard test/build, marketing-site build, AI engine tests, and the targeted iOS simulator verification pass. All output goes to `.build/` on the SSD.
The current verified result is green end to end, including `40` passing XCTest cases across `FitTrackerCoreTests` and `SyncMergeTests`.

### iOS Build

```bash
cd /path/to/FitTracker2
npm run tokens:check

# Build with full Xcode selected
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FitTrackerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Targeted simulator regression coverage
xcodebuild test \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=87E96E30-350E-46AC-AB34-B87AF8D1AB1E' \
  -only-testing:FitTrackerTests/FitTrackerCoreTests \
  -derivedDataPath /tmp/FitTrackerTestsDD \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

### Web Projects

```bash
# Development dashboard
cd dashboard && npm test && npm run build

# Marketing website
cd ../website && npm run build
```

### AI Engine

```bash
cd ai-engine
source /tmp/FitTracker2-ai-venv/bin/activate
pytest -q
```

### Notes
- HealthKit requires device runtime permissions (not available on Simulator for all queries)
- CloudKit requires iCloud entitlements (disabled on Simulator builds)
- Simulator builds auto-login in DEBUG mode for faster development
- `FitTracker/Info.plist` is restored, but the repo still ships placeholder values for `SupabaseURL` and `SupabaseAnonKey`; replace them locally before runtime Supabase verification
- when those Supabase values are still placeholders, the app now surfaces configuration-disabled behavior instead of crashing on access
- `PasskeyRelyingPartyID` must match the associated-domains setup you use for passkeys
- `FitTracker/GoogleService-Info.plist` is intentionally not present in this clone; add your Firebase app config locally before verifying analytics
- `/tmp` virtualenvs and derived-data folders are convenient but ephemeral; recreate them if they disappear between sessions

---

## Roadmap

Full RICE-prioritized roadmap: [`docs/project/master-backlog-roadmap.md`](docs/project/master-backlog-roadmap.md)

| Phase | Name | Status |
|-------|------|--------|
| 0 | Foundation (PRD, metrics, backlog, feature PRDs) | **Complete** |
| 1 | Design & Prototype (Figma, public README) | **Active** |
| 2 | Measurement & CX (Analytics, NPS, reviews) | In progress (GA4 shipped) |
| 3 | Platform Expansion (Android, health APIs, DEXA) | In progress (Android DS research shipped) |
| 4 | Advanced Features (blood test reader, skills) | Locked |
| 5 | Marketing & Launch (website, App Store assets) | In progress (website shipped) |

---

## Design System

~120 semantic tokens across 7 categories, 13+ reusable components, WCAG AA contrast compliance.

- **Figma:** [FitMe Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)
- **Docs:** [`docs/design-system/`](docs/design-system/)
- **Tokens:** [`design-tokens/tokens.json`](design-tokens/tokens.json) (source of truth)
- **Pipeline:** `tokens.json` → Style Dictionary → `DesignTokens.swift` + Android XML/Kotlin
- **CI gate:** `make tokens-check` prevents token drift
- **Android mapping:** 92 iOS tokens mapped to MD3 equivalents ([docs/design-system/android-token-mapping.md](docs/design-system/android-token-mapping.md))

---

## Documentation

| Document | Description |
|----------|-------------|
| [PRD](docs/product/PRD.md) | Product requirements — strategy, 11 features, non-functional requirements |
| [Feature PRDs](docs/product/prd/) | 18 standalone PRDs for every feature, system, and tool |
| [Metrics Framework](docs/product/metrics-framework.md) | 40 metrics across 6 categories with instrumentation status |
| [Backlog](docs/product/backlog.md) | Complete backlog: done, planned, unscheduled, icebox |
| [Roadmap](docs/project/master-backlog-roadmap.md) | RICE-prioritized 19-task roadmap with phase gates |
| [Stabilization Report](docs/project/stabilization-report-2026-04-05.md) | Build recovery, verification results, setup requirements, and remaining gaps |
| [Analytics Taxonomy](docs/product/analytics-taxonomy.csv) | GA4 event taxonomy (CSV) |
| [Firebase Setup](docs/project/firebase-setup-guide.md) | 20-step Firebase Analytics setup guide |
| [Changelog](CHANGELOG.md) | Milestone history |
| [Design System Docs](docs/design-system/) | Token architecture, components, review standards |
| [Android Token Mapping](docs/design-system/android-token-mapping.md) | iOS → MD3 token mapping |
| [PM Lifecycle](docs/process/product-management-lifecycle.md) | 9-phase product management workflow |
| [Redesign Case Study](docs/project/original-readme-redesign-casestudy.md) | How the app evolved from v1 to Apple-first design |

---

## License

License not yet specified. All rights reserved.
