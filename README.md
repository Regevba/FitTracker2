![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/Regevba/FitTracker2/actions/workflows/ci.yml/badge.svg)

# FitMe

**The iPhone-first fitness command center that unifies training, nutrition, recovery, and body composition into a single privacy-first experience — powered by federated AI.**

FitMe replaces your training log, meal tracker, and recovery dashboard with one app that knows what you should do today — without ever seeing your private health data.

> Repo name is `FitTracker2` for historical reasons. The product brand is **FitMe**.

---

## Demo

> Animated demo and device screenshots coming soon. Live story site: **[fitme-story.vercel.app](https://fitme-story.vercel.app)**.

| Home | Training | Nutrition | Stats | Settings |
|------|----------|-----------|-------|----------|
| *coming soon* | *coming soon* | *coming soon* | *coming soon* | *coming soon* |

Design source: [FitMe Design System Library on Figma](https://www.figma.com/design/0Ai7s3fCFqR5JXDW8JvgmD)

---

## Features

**Training** — 87 exercises across a 6-day push/pull/legs split, set-by-set logging with weight/reps/RPE, automatic PR detection with 1RM estimation, floating rest timer with haptics, cardio with heart-rate Zone 2 detection.

**Nutrition** — Dynamic macros that adapt to training day and program phase, 4-tab meal entry (label OCR with English + Hebrew, manual, templates, barcode via Open Food Facts), supplement streak tracking, hydration with training-day vs rest-day targets.

**Recovery & Biometrics** — HealthKit (HR, HRV, VO2Max, sleep stages), Xiaomi S400 smart-scale entries (10 metrics), daily readiness score (40% HRV / 30% RHR / 30% Sleep), Recovery Studio with personalized routines.

**Stats & Progress** — 18 metrics across body, recovery, training, and nutrition; daily / weekly / monthly / 3-month / 6-month views; interactive charts; all-time PRs with Epley 1RM.

**AI Intelligence** — Three-tier pipeline: local rules → cloud cohort (banded values, k≥50) → on-device Foundation Models (iOS 26+). Confidence-gated, privacy-preserving, graceful offline fallback.

**Privacy & Security** — Double-layer encryption (AES-256-GCM + ChaCha20-Poly1305 with HMAC-SHA512), Secure Enclave key storage with biometric ACL, zero-knowledge sync (`.ftenc` blobs only), Apple Sign In + Passkeys (WebAuthn), GDPR-oriented account deletion + data export.

---

## Tech Stack

| Layer | Technology |
| ----- | ---------- |
| UI | SwiftUI, SF Symbols |
| Health | HealthKit |
| Auth | Apple Sign In (Supabase OAuth), Passkeys (WebAuthn), Email/OTP |
| Encryption | AES-256-GCM + ChaCha20-Poly1305 via CryptoKit, HMAC-SHA512 |
| Key Storage | Keychain with biometric ACL, Secure Enclave (P-256) |
| Sync | CloudKit (iCloud Private DB) + Supabase (PostgreSQL + Realtime) |
| AI — Cloud | FastAPI on Railway, JWT + JWKS validation, k≥50 anonymity |
| AI — On-device | Apple Intelligence Foundation Models (iOS 26+) |
| Analytics | Firebase Analytics (GA4) with GDPR consent |
| Design System | 125 semantic tokens, Style Dictionary pipeline, CI drift detection |

---

## Architecture

```text
                          iPhone (on-device)
┌─────────────────────────────────────────────────────┐
│  SwiftUI Views                                      │
│       ↕                                             │
│  EncryptedDataStore ← AES-256-GCM + ChaCha20        │
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

**Zero-knowledge sync:** servers store only encrypted `.ftenc` blobs — no plaintext health data ever leaves the device.

---

## Getting Started

```bash
# iOS app — open in Xcode 16+ (iOS 17.0+ deployment target)
open FitTracker.xcodeproj

# Token pipeline (design system)
npm install && npm run tokens:check

# Run a full local verification (tokens + dashboard + iOS targeted tests)
make verify-local
```

Full setup including SSD-relocated build artifacts, web sub-projects, and AI engine: see [`docs/setup/`](docs/setup/).

---

## How this was built

FitMe is a portfolio project built by a Product Manager transitioning into engineering, using Claude Code as a pair-programmer. Every feature was designed, reviewed, and tested by me; AI accelerated implementation. The `Co-Authored-By: Claude` trailer in commits makes that collaboration visible by design.

The repo runs a custom PM lifecycle (Research → PRD → Tasks → UX → Implement → Test → Review → Merge → Docs) with measurement instrumentation at every phase. Process docs and case studies that show the lifecycle in action live in [`docs/case-studies/`](docs/case-studies/).

---

## More

| Topic | Link |
| ----- | ---- |
| Product PRD + per-feature PRDs | [`docs/product/`](docs/product/) |
| Design system + UX foundations | [`docs/design-system/`](docs/design-system/) |
| Architecture deep-dive | [`docs/architecture/`](docs/architecture/) |
| Case studies | [`docs/case-studies/`](docs/case-studies/) |
| Roadmap | [`docs/master-plan/master-backlog-roadmap.md`](docs/master-plan/master-backlog-roadmap.md) |
| Changelog | [`CHANGELOG.md`](CHANGELOG.md) |

---

## License

[MIT](LICENSE) © 2026 Regev Barak.
