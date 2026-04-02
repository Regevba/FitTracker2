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
- 87 exercises across a 6-day push/pull/legs split
- Set-by-set logging with weight, reps, RPE, and per-set notes
- Automatic PR detection and progressive overload tracking
- Floating rest timer with haptic feedback
- Cardio tracking with heart rate zone detection and machine photo capture

### Nutrition
- Dynamic macro targets that adapt to training day, program phase, and body composition goals
- 4-tab meal entry: smart label parsing, manual, templates, search/barcode
- Morning + evening supplement tracking with streak detection
- Quick-log favorites for fast re-logging
- Hydration tracking

### Recovery & Biometrics
- HealthKit integration for HR, HRV, VO2Max, steps, sleep (total/deep/REM)
- Manual entry for Xiaomi S400 smart scale body composition
- Daily readiness scoring based on HRV, resting HR, and sleep
- Color-coded status dots with configurable thresholds

### Stats & Progress
- 18 metrics across body, recovery, training, and nutrition
- Multi-period views: daily, weekly, monthly, 3-month, 6-month
- Charts with trend deltas and data source attribution
- All-time PR records with estimated 1RM (Epley formula)

### AI Intelligence
- Federated cohort AI: population insights computed on anonymized aggregates
- On-device personalization via Apple Intelligence Foundation Models (iOS 26+)
- Privacy-preserving bands — only categorical values leave the device
- 4 recommendation segments: training, nutrition, recovery, stats

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
| Auth | Apple Sign In, Passkeys (WebAuthn), Email/OTP |
| Encryption | AES-256-GCM + ChaCha20-Poly1305 via CryptoKit |
| Key Storage | Secure Enclave (P-256 with biometric ACL) |
| Sync | CloudKit (iCloud Private DB) + Supabase (PostgreSQL + Realtime) |
| AI — Cloud | FastAPI on Railway, JWT-authenticated, JWKS validation |
| AI — On-device | Apple Intelligence Foundation Models (iOS 26+) |
| Design System | 92 semantic tokens, Style Dictionary pipeline, CI drift detection |
| CI | GitHub Actions, Xcode 16+, `make tokens-check` gate |

---

## Architecture

```
                          iPhone (on-device)
┌─────────────────────────────────────────────────────┐
│  SwiftUI Views                                      │
│       ↕                                             │
│  EncryptedDataStore ← AES-256-GCM (CryptoKit)      │
│       ↕                    ↕                        │
│  HealthKit Service    Secure Enclave (keys)         │
│       ↕                                             │
│  AI Orchestrator                                    │
│    ├── Local rules (always available)               │
│    ├── Cloud cohort (banded values only) ──────────→│── AI Engine (FastAPI)
│    └── Foundation Model (private, on-device)        │      k≥50 anonymity
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

## Privacy & Security

- **AES-256-GCM** encryption for all personal data at rest
- **Secure Enclave** for cryptographic key management with biometric ACL
- **Zero-knowledge architecture** — servers never see unencrypted health data
- **Federated AI** — no PII leaves the device; only categorical bands sent to cloud
- **k-anonymity floor** — cohort signals require k=50 minimum before returning
- **Apple Sign In + Passkeys** — no password database to breach

---

## Getting Started

### Prerequisites
- Xcode 16+ (macOS 15+)
- iOS 17.0+ deployment target
- Node.js (for design token pipeline)

### Build

```bash
# Install token pipeline dependencies
npm install

# Verify design tokens are in sync
make tokens-check

# Build with Xcode
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FitTrackerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

### Notes
- HealthKit requires device runtime permissions (not available on Simulator for all queries)
- CloudKit requires iCloud entitlements (disabled on Simulator builds)
- Simulator builds auto-login in DEBUG mode for faster development

---

## Roadmap

Full RICE-prioritized roadmap: [`docs/project/master-backlog-roadmap.md`](docs/project/master-backlog-roadmap.md)

| Phase | Name | Status |
|-------|------|--------|
| 0 | Foundation (PRD, metrics, backlog) | Active |
| 1 | Design & Prototype (Figma, public README) | Next |
| 2 | Measurement & CX (Analytics, NPS, reviews) | Locked |
| 3 | Platform Expansion (Android, health APIs, DEXA) | Locked |
| 4 | Advanced Features (blood test reader, skills) | Locked |
| 5 | Marketing & Launch (website, App Store assets) | Locked |

---

## Design System

92 semantic tokens across 8 namespaces, 13 reusable components, WCAG AA contrast compliance.

- **Figma:** [FitMe Design System Library](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)
- **Docs:** [`docs/design-system/`](docs/design-system/)
- **Tokens:** [`design-tokens/tokens.json`](design-tokens/tokens.json) (source of truth)
- **Pipeline:** `tokens.json` → Style Dictionary → `DesignTokens.swift`
- **CI gate:** `make tokens-check` prevents token drift

---

## Documentation

| Document | Description |
|----------|-------------|
| [PRD](docs/product/PRD.md) | Product requirements — strategy, 11 features, non-functional requirements |
| [Metrics Framework](docs/product/metrics-framework.md) | 40 metrics across 6 categories with instrumentation status |
| [Backlog](docs/product/backlog.md) | Complete backlog: done, planned, unscheduled, icebox |
| [Roadmap](docs/project/master-backlog-roadmap.md) | RICE-prioritized 18-task roadmap with phase gates |
| [Changelog](CHANGELOG.md) | Milestone history |
| [Design System Docs](docs/design-system/) | Token architecture, components, review standards |
| [Redesign Case Study](docs/project/original-readme-redesign-casestudy.md) | How the app evolved from v1 to Apple-first design |

---

## License

License not yet specified. All rights reserved.
