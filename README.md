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
- 87 exercises across a 6-day push/pull/legs split (Upper Push, Lower Body, Upper Pull, Full Body, Cardio Only)
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
- Action-first design with the most important daily decisions above the fold; the v2 screen now uses a purposeful scroll layout on iPhone
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
- Three-tier pipeline: local rules (always) → cloud cohort (banded data, k>=50) → Foundation Models (iOS 26+) when the real on-device layer is available
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
| AI — On-device | Apple Intelligence Foundation Models (iOS 26+, currently placeholder-gated in repo) |
| Analytics | Firebase Analytics (GA4) with GDPR consent |
| Design System | 125 semantic tokens, Style Dictionary pipeline, CI drift detection |
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
Repo-built Astro + Tailwind marketing site with Hero, Features, Screenshots, How It Works, Privacy, FAQ sections. This codebase is not yet the canonical live surface: the `fit-tracker2` Vercel project is currently rooted at `dashboard/`, and the website still has launch blockers such as placeholder GA4/App Store data and unverified review metadata.

### Development Dashboard (`dashboard/`)
Internal PM dashboard and current canonical live web surface on `fit-tracker2.vercel.app`. Astro + React + Tailwind with Kanban board (drag-drop), table view (sort/filter), pipeline overview chart, reconciliation alerts, control-room monitoring, and knowledge-hub access to repo + PM docs.

---

## Current Repo Status

Verification snapshot as of `2026-04-25`:

### PM Framework: v7.6 (Mechanical Enforcement)
- **8 SoC optimizations + Dispatch Intelligence (v5.2)** — skill-on-demand, cache compression, batch dispatch, model tiering, result forwarding, speculative preload, systolic chains, task complexity gate
- **Deterministic measurement instrumentation (v6.0)** — phase timing, cache hit tracking, eval gates, CU v2, rolling baselines
- **HADF Hardware-Aware Dispatch (v7.0, PR #82)** — 5-layer architecture: device detection → static profiles (17 chips, 6 vendors) → cloud fingerprinting (7 signatures, Mahalanobis distance) → dynamic adaptation → evolutionary learning. Confidence-gated (0.4/0.7), zero regression.
- **Mechanical enforcement (v7.6)** — pre-commit state/case-study gates, per-PR integrity status, weekly framework-status cron, explicit Class B gap inventory.
- **63% framework overhead reduction** — free context doubled (78K → 155K tokens)
- **Normalized velocity:** 3.6 min/CU average (+76% vs baseline)
- **Docs:** [`docs/architecture/soc-software-architecture-research.md`](docs/architecture/soc-software-architecture-research.md)

### V2 Screen Refactors (6/6 complete)

| Screen | PR | Tests | Analytics Events | Status |
|--------|----|-------|-----------------|--------|
| Onboarding v2 | #59 | 5 | 2 | Shipped 2026-04-06 |
| Home Today v2 | #61 | 21 | 7 | Shipped 2026-04-09 |
| Training Plan v2 | #74 | 16 | 12 | Shipped 2026-04-10 |
| Nutrition v2 | #75 | 12 | 5 | Shipped 2026-04-10 |
| Stats v2 | #76 | 10 | 4 | Shipped 2026-04-10 |
| Settings v2 | #77 | 8 | 3 | Shipped 2026-04-10 |

**Totals:** 119 findings addressed, 33 analytics events, 60+ tests across all screens.

### Design System
- 125+ semantic tokens (AppColor, AppText, AppSpacing, AppRadius, AppShadow, AppMotion)
- 100% token compliance across all v2 files (PR #78 fixed last 4 raw literals)
- Zero token drift (`make tokens-check` clean)
- All 6 v2 screens built in Figma via MCP (file key: `0Ai7s3fCFqR5JXDW8JvgmD`)

### Infrastructure
- iOS app builds with full Xcode; XCTest coverage last known passing 2026-04-15, rerun required to re-verify
- Design-token drift check passes (`make tokens-check`)
- Dashboard is the canonical deployed web surface (control room); marketing website code exists but is not yet live as the primary public property
- AI engine tests pass (`5/5`)
- Firebase bootstrap config-aware, Supabase graceful degradation
- Firebase runtime verification still requires local `FitTracker/GoogleService-Info.plist`
- Live signed-in Supabase sync still requires local runtime credentials

Detailed recovery notes: [`docs/master-plan/stabilization-report-2026-04-05.md`](docs/master-plan/stabilization-report-2026-04-05.md).

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
Last verified green on 2026-04-15 (commit 45b5b33). Re-verification required after each merge. Run `make verify-local` and check output before claiming green status.

### iOS Build

```bash
cd /path/to/FitTracker2
npm run tokens:check

# Build with full Xcode selected
# Note: All build artifacts go to .build/ on the SSD (NOT /tmp/)
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Targeted simulator regression coverage
xcodebuild test \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' \
  -only-testing:FitTrackerTests/FitTrackerCoreTests \
  -derivedDataPath .build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Easier: use the Makefile (uses .build/ automatically)
make verify-ios
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
source .build/ai-venv/bin/activate
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

Full RICE-prioritized roadmap: [`docs/master-plan/master-backlog-roadmap.md`](docs/master-plan/master-backlog-roadmap.md)

| Phase | Name | Status |
|-------|------|--------|
| 0 | Foundation (PRD, metrics, backlog, feature PRDs) | **Complete** |
| 1 | Design & Prototype (Figma, public README) | **Complete** (6/6 v2 screens + Figma) |
| 2 | Measurement & CX (Analytics, NPS, reviews) | **Mostly Complete** (GA4 shipped, 6 funnels, Sentry guide) |
| 3 | Platform Expansion (Android, health APIs, DEXA) | In progress (Android DS shipped) |
| 4 | Advanced Features (blood test reader, skills) | Locked (Gate D) |
| 5 | Marketing & Launch (website, App Store assets) | In progress (website built, assets in research) |

---

## Design System

125 semantic tokens across 7 categories, 13+ reusable components, WCAG AA contrast compliance, full UX foundations layer in `docs/design-system/ux-foundations.md`.

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
| [PRD](docs/product/PRD.md) | Product requirements — strategy, features, non-functional requirements |
| [Feature PRDs](docs/product/prd/) | 25 standalone PRDs for every feature, system, and tool |
| [Metrics Framework](docs/product/metrics-framework.md) | 40 metrics across 6 categories with instrumentation status |
| [Backlog](docs/product/backlog.md) | Complete backlog: done, planned, unscheduled, icebox |
| [Roadmap](docs/master-plan/master-backlog-roadmap.md) | RICE-prioritized roadmap with phase gates |
| [Master Plan](docs/master-plan/master-plan-2026-04-15.md) | Current master plan — 49+ shipped features, gate status, priorities |
| [Case Studies](docs/case-studies/) | 16 tracked case studies with normalized velocity analysis |
| [Stabilization Report](docs/master-plan/stabilization-report-2026-04-05.md) | Build recovery, verification results, setup requirements, and remaining gaps |
| [Analytics Taxonomy](docs/product/analytics-taxonomy.csv) | GA4 event taxonomy (CSV) |
| [Firebase Setup](docs/setup/firebase-setup-guide.md) | 20-step Firebase Analytics setup guide |
| [Changelog](CHANGELOG.md) | Milestone history |
| [Design System Docs](docs/design-system/) | Token architecture, components, review standards |
| [Android Token Mapping](docs/design-system/android-token-mapping.md) | iOS → MD3 token mapping |
| [PM Lifecycle](docs/process/product-management-lifecycle.md) | 10-phase product management workflow (0-9) |
| [Redesign Case Study](docs/case-studies/original-readme-redesign-casestudy.md) | How the app evolved from v1 to Apple-first design |

---

## License

License not yet specified. All rights reserved.
