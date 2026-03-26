# FitTracker

A privacy-first personal fitness command center for training, recovery, nutrition, and body-composition tracking across iPhone, iPad, and Mac — with federated AI insights that keep all personal data on-device.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [AI Intelligence Layer](#ai-intelligence-layer)
- [iOS App — Views & UX](#ios-app--views--ux)
- [iOS App — Services](#ios-app--services)
- [Domain Models](#domain-models)
- [Backend — Supabase](#backend--supabase)
- [AI Engine — Railway](#ai-engine--railway)
- [Security & Privacy Model](#security--privacy-model)
- [Build & CI](#build--ci)
- [Project Notes](#project-notes)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│  iOS / iPadOS / macOS  (Swift 5, iOS 17+, Xcode 26.3)       │
├──────────────────────────────────────────────────────────────┤
│  FitTrackerApp                                               │
│  ├── Views        4-tab: Home · Training · Nutrition · Stats │
│  ├── Services     Auth · HealthKit · Encryption · CloudKit   │
│  ├── Models       DomainModels · TrainingProgramData         │
│  └── AI           AIOrchestrator · FoundationModelService    │
│                   AIEngineClient · AITypes                   │
└──────────────────┬───────────────────────────────────────────┘
                   │  banded categorical values only (no PII)
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  AI Engine  (Python 3.12 · FastAPI · Railway)                │
│  POST /v1/{training|nutrition|recovery|stats}/insight        │
│  ├── JWT validation  (Supabase JWKS, RS256)                  │
│  ├── Rate limiter    (10 req / segment / hour per user)      │
│  ├── CohortService   (Supabase RPC + SELECT)                 │
│  └── InsightService  (rule-based signal generation)          │
└──────────────────┬───────────────────────────────────────────┘
                   │  population-level signals only
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Supabase Backend                                            │
│  ├── Auth          email · Apple Sign In · passkeys          │
│  ├── cohort_stats  GDPR frequency-count table (no raw data)  │
│  └── CloudKit      encrypted private user data (iCloud)      │
└──────────────────────────────────────────────────────────────┘
```

---

## AI Intelligence Layer

FitTracker uses a **federated cohort intelligence** architecture — two layers that each do what they do best, with PII guaranteed to never leave the device.

### Layer 1 — On-device personalisation (Apple Foundation Models)

- Runs on-device via `FoundationModelService` using **Apple Foundation Models** (iOS 26+)
- Falls back to `FallbackFoundationModel` on pre-iOS 26 devices (confidence = 0.0, escalates to cloud)
- Takes the cloud recommendation and adapts it with real personal context (weight trends, sleep, HRV, training load)
- Only fires when the Foundation Model returns confidence ≥ 0.4 (`personalisationThreshold`)

### Layer 2 — Cloud population insights (AI Engine + Supabase)

- iOS sends only **banded categorical values** — no raw numbers ever leave the device
  - Age: `25-34`, BMI: `25-29.9`, sleep: `7-8h`, resting HR: `60-70`, etc.
- AI Engine queries `cohort_stats` for population frequency counts in matching buckets
- Returns insight signals with confidence, escalate-to-LLM flag, and supporting data
- Fire-and-forget cohort writes via `asyncio.create_task()` — insights never block on writes

### GDPR compliance

| Measure | Detail |
|---|---|
| Data minimisation | Only categorical bands (16 fields across 4 segments) are sent to cloud |
| Purpose limitation | `cohort_stats` stores frequency counts only — no user identifiers |
| Storage limitation | `pg_cron` daily job purges rows older than 90 days; rows with frequency < k=50 are also deleted |
| k-anonymity floor | k = 50; segments with < 50 matching users return no signal |

### Key files

| File | Responsibility |
|---|---|
| `FitTracker/AI/AITypes.swift` | `AnyCodable`, `AISegment`, `AIRecommendation`, `LocalUserSnapshot`, band extractors, `DayType.aiProgramPhase` |
| `FitTracker/AI/AIOrchestrator.swift` | `@MainActor ObservableObject`; orchestrates both layers per segment; `processAll(jwt:snapshot:)` |
| `FitTracker/AI/AIEngineClient.swift` | URLSession HTTP client; `AIEngineClientProtocol` testability seam; 15 s timeout |
| `FitTracker/AI/FoundationModelService.swift` | `FoundationModelProtocol`; `@available(iOS 26, *)` wrapper; `FallbackFoundationModel` |

---

## iOS App — Views & UX

Navigation is a 4-tab bar on iPhone and a sidebar on iPad/Mac. All layout decisions are driven by a **Today-first, action-first** philosophy — the most important information lives above the fold.

### Home — Today screen (`MainScreenView`)

- No-scroll above-the-fold design on iPhone
- **Today's Status** hero: readiness score, daily decision-making summary
- Quick-action buttons for workout, supplements, and meal logging
- Phase progress, milestone celebrations (7 / 14 / 30 / 60 / 90-day streaks)
- Adapts content by `DayType` (training vs rest vs cardio)

### Training (`TrainingPlanView`)

- Exercise queue for the selected day type with rest-timer controls
- Active-session focus state — one exercise at a time, with previous-performance context
- Set completion, RPE logging, warmup sets
- Date-aware editing — past-day edits save to the correct date and never overwrite today's log
- Phase-aware exercise definitions (Recovery / Stage 1 / Stage 2)

### Nutrition (`NutritionView` + helpers)

- **Adaptive targets** that recalculate daily based on goal mode, phase, and training/rest day
  - Fat loss: 170–420 kcal deficit, 2.3 g/kg LBM protein
  - Maintain: baseline + 2.0 g/kg protein
  - Lean gain: +180 kcal training / +120 kcal rest
- `MacroTargetBar` — visual protein / carbs / fat progress rings
- `MealSectionView` — grouped meal display with running totals
- `MealEntrySheet` — logging with repeat-last, saved templates, barcode lookup, and OCR label capture
- Bilingual (English + Hebrew) nutrition-label parser
- Day navigation — scroll back through previous days without losing context

### Stats (`StatsView`)

- Pinned **Weight** and **Body Fat %** charts always visible
- User-configurable metrics carousel (readiness, sleep, HRV, training volume, steps, protein)
- Carousel preferences saved in `AppSettings` → `UserPreferences.preferredStatsCarouselMetrics`
- `TrendIndicator` — directional arrows with colour coding
- Body-composition trend lines over rolling windows
- Apple-style compact card density; redesigned empty states

### Auth (`AuthHubView` · `SignInView` · `WelcomeView` · `AccountPanelView`)

- Single auth hub with **Log In** and **Create Account** on one screen
- Apple Sign In + email/password + passkeys
- Inline email registration, verification-resend, and password reset — no full-screen redirects
- Biometric quick-return (Face ID / Touch ID) after background lock
- `AccountPanelView` — profile, passkey management, sign out

### Settings (`SettingsView`)

- Biometric reopen preference
- Nutrition goal mode (fat loss / maintain / lean gain)
- Weight and body-fat target ranges
- Zone 2 HR thresholds
- Readiness HR/HRV thresholds
- Stats carousel controls — choose which extra metrics appear on the Stats screen
- Passkey creation

### Shared components

| Component | Purpose |
|---|---|
| `ReadinessCard` | Readiness score with HR / HRV status |
| `MetricCard` | Generic metric tile with value, unit, trend |
| `ChartCard` | Reusable chart container (wraps Swift Charts) |
| `TrendIndicator` | Up / down / flat arrow with colour |
| `StatusBadge` | Coloured pill for states (good / caution / alert) |
| `SectionHeader` | Section title with optional action |
| `EmptyStateView` | Consistent empty-state messaging |
| `RecoverySupport` | Recovery routine cards |

---

## iOS App — Services

| Service | Description |
|---|---|
| `SignInService` | Supabase auth — email, Apple Sign In, passkeys; session tokens; biometric quick-unlock |
| `AuthManager` | Face ID / Touch ID lock / unlock lifecycle; simulator bypass |
| `AuthValidation` | Email validation; password rules (passphrase-friendly) |
| `HealthKitService` | Full Apple Health + Watch sync — HR, HRV, resting HR, VO2max, weight, body fat, sleep, steps, active calories; background delivery; `LiveMetrics` readiness logic |
| `CloudKitSyncService` | iCloud Private Database sync; all payloads AES-256-GCM + ChaCha20-Poly1305 encrypted before upload; CloudKit never sees plaintext |
| `EncryptionService` | Dual-layer encryption (AES-256-GCM + ChaCha20-Poly1305); Secure Enclave (P-256) key storage; HKDF-SHA512 derivation; biometric ACL in Keychain |
| `TrainingProgramStore` | Weekly schedule management; phase transitions; `todayDayType` |
| `AppSettings` | User preferences persisted via `UserDefaults` + CloudKit sync |
| `WatchConnectivityService` | Apple Watch companion session management |
| `AppTheme` | Centralised colours, typography, gradients |

---

## Domain Models

All models live in `FitTracker/Models/DomainModels.swift`.

### Training & program

| Type | Key fields |
|---|---|
| `ProgramPhase` | Recovery · Stage 1 · Stage 2; training/rest calorie targets; protein targets |
| `DayType` | RestDay · UpperPush · LowerBody · UpperPull · FullBody · CardioOnly; icons; `isTrainingDay`; `aiProgramPhase` |
| `ExerciseDefinition` | Category, equipment, muscle groups, sets/reps/rest, coaching cue |
| `ExerciseLog` | Sets array, `totalVolume`, `bestSet` |
| `SetLog` | weight, reps, RPE, isWarmup, timestamp |
| `CardioLog` | Type, duration, HR avg/max, calories, machine-specific fields, compressed summary photo |

### Daily logging

| Type | Key fields |
|---|---|
| `DailyLog` | Phase, DayType, task statuses, exercise logs, cardio logs, supplement log, nutrition log, biometrics, mood/energy/craving (1–5), CloudKit sync metadata, `completionPct` |

### Nutrition

| Type | Key fields |
|---|---|
| `NutritionLog` | Meals array, total macros, waterML, alluloseTaken |
| `MealEntry` | Name, macros, serving grams, source (manual/template/search/barcode/photoLabel) |
| `MealTemplate` | Reusable meal spec |
| `NutritionGoalMode` | fatLoss · maintain · gain |

### Biometrics

| Type | Key fields |
|---|---|
| `DailyBiometrics` | Manual: weight, body fat, lean mass, BMI, BMR, metabolic age, visceral fat; HealthKit: resting HR, HRV, VO2max, active calories, steps, sleep (total/deep/REM); `effectiveX` computed properties prefer HealthKit with manual fallback |

### User

| Type | Key fields |
|---|---|
| `UserProfile` | Name, age, height, recovery start date, current phase, weight/BF targets; `nutritionPlan()` — calculates adaptive daily targets by goal mode + training day |
| `UserPreferences` | Zone 2 HR range, readiness thresholds, `NutritionGoalMode`, `preferredStatsCarouselMetrics` |
| `WeeklySnapshot` | Avg biometrics, total training days, volume, cardio minutes, task adherence (0–100), weight/BF change |

---

## Backend — Supabase

All SQL lives in `backend/supabase/migrations/` and runs in numbered order.

### Migrations

| File | Purpose |
|---|---|
| `000001_cohort_stats.sql` | `cohort_stats` table — composite PK `(segment, field_name, field_value)`, `frequency BIGINT`, indexes on segment and updated_at. GDPR Article 5 comment. |
| `000002_increment_cohort_frequency.sql` | `increment_cohort_frequency(p_segment, p_field_name, p_field_value)` — `SECURITY DEFINER` RPC; atomic upsert with `ON CONFLICT DO UPDATE SET frequency = frequency + 1`. Required because PostgREST merge-duplicates replaces rows rather than incrementing. |
| `000003_rls_cohort_stats.sql` | RLS: `authenticated` role → SELECT only; `service_role` → ALL |
| `000004_retention_pg_cron.sql` | Daily cron at 03:00 UTC — deletes rows with `frequency < 50` (k-anonymity floor) and rows with `updated_at < NOW() - INTERVAL '90 days'` (storage limitation). Requires Supabase Pro tier for `pg_cron`. |

### Seed data

`backend/supabase/seed/seed_cohort_stats.sql` — bootstrap frequency counts for training, nutrition, recovery, and stats segments. Used for development and CI.

### CI

`backend/.github/workflows/ci.yml` — spins up PostgreSQL 15, runs all migrations in order, verifies schema and row counts.

---

## AI Engine — Railway

Deployed at `https://fittracker-ai-production.up.railway.app`.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness check — returns `{"status": "ok"}` |
| `POST` | `/v1/training/insight` | Training segment cohort insight |
| `POST` | `/v1/nutrition/insight` | Nutrition segment cohort insight |
| `POST` | `/v1/recovery/insight` | Recovery segment cohort insight |
| `POST` | `/v1/stats/insight` | Stats segment cohort insight |

All insight endpoints require a valid Supabase JWT (`Authorization: Bearer <token>`, role = `authenticated`).

### Request shape (training example)

```json
{
  "age_band": "25-34",
  "bmi_band": "25-29.9",
  "program_phase": "build",
  "training_days_band": "3-4",
  "sleep_band": "7-8"
}
```

### Response shape

```json
{
  "signals": ["training_volume_high_for_phase"],
  "confidence": 0.73,
  "escalate_to_llm": false,
  "supporting_data": { "cohort_size": 312 }
}
```

### Key modules

| Module | Description |
|---|---|
| `app/auth/jwt_validator.py` | JWKS-cached (5 min TTL) RS256 validation; enforces `role == "authenticated"` |
| `app/middleware/rate_limiter.py` | In-memory rate limiter; 10 req / segment / hour keyed on JWT `sub` |
| `app/services/cohort_service.py` | Supabase RPC calls + k-floor gate (k = 50) |
| `app/services/insight_service.py` | Rule-based signal generation from population frequency counts |
| `app/models/common.py` | Shared `InsightResponse` Pydantic model |
| `app/models/training.py` | `program_phase: Literal["foundation", "build", "recovery"]` |

### Infrastructure

- **Dockerfile** — Python 3.12, `pip install .` (production deps only)
- **pyproject.toml** — Hatchling build; `[tool.hatch.build.targets.wheel] packages = ["app"]`
- **CI** — `ai-engine/.github/workflows/ci.yml`; pytest with mocked Supabase env; Docker build validation

---

## Security & Privacy Model

| Layer | Mechanism |
|---|---|
| **On-device storage** | All data encrypted with AES-256-GCM + ChaCha20-Poly1305 before disk write |
| **CloudKit payloads** | Encrypted blobs only — iCloud never sees plaintext health or nutrition data |
| **Encryption keys** | Stored in Secure Enclave (P-256) + Keychain with biometric ACL |
| **Key derivation** | HKDF-SHA512 |
| **File protection** | `NSFileProtectionCompleteUnlessOpen` |
| **Biometric lock** | Face ID / Touch ID required to unlock encryption keys on cold launch |
| **AI data** | Only banded categorical values leave the device; no raw metrics; no user identifiers |
| **Cloud cohort data** | Frequency counts only; k ≥ 50 anonymity floor; 90-day retention cap |

### Entitlements & capabilities

- Apple Sign In
- Associated Domains (`webcredentials:` + `applinks:` for `fittracker.regev.app`)
- HealthKit (read + background delivery)
- CloudKit (`iCloud.com.fittracker.regev` private database)
- Keychain Access Groups (`com.fittracker.regev`)
- iCloud Key-Value Storage
- Background modes: fetch · processing · remote-notification

---

## Build & CI

### iOS build

```bash
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Requires Xcode 26.3+. Deployment target: iOS 17.0.

### CI (`.github/workflows/ci.yml`)

- Trigger: PR or push to `main`
- macOS 15, Xcode 26.3
- Resolves simulator (iPhone 17 → iPhone 16e → iPhone 14 Pro fallback)
- Builds and runs `FitTrackerTests`; uploads `.xcresult` on failure

### AI Engine CI (`ai-engine/.github/workflows/ci.yml`)

- Trigger: push/PR to paths `ai-engine/**`
- Ubuntu, Python 3.12
- Runs pytest with mocked Supabase environment
- Builds Dockerfile to verify production image

### Backend CI (`backend/.github/workflows/ci.yml`)

- Trigger: push/PR to paths `backend/**`
- Ubuntu, PostgreSQL 15 service container
- Runs all 4 migrations in order
- Verifies schema and seed row counts

---

## Project Structure

```
FitTracker2/
├── FitTracker/
│   ├── FitTrackerApp.swift          # App entry point; wires all services + AI
│   ├── AI/
│   │   ├── AITypes.swift            # Core types, band extractors, AnyCodable
│   │   ├── AIOrchestrator.swift     # Two-layer AI coordination
│   │   ├── AIEngineClient.swift     # HTTP client for AI Engine
│   │   └── FoundationModelService.swift  # On-device Apple Foundation Models
│   ├── Models/
│   │   ├── DomainModels.swift       # All domain types
│   │   └── TrainingProgramData.swift
│   ├── Services/
│   │   ├── AppSettings.swift
│   │   ├── AppTheme.swift
│   │   ├── AuthManager.swift
│   │   ├── TrainingProgramStore.swift
│   │   ├── WatchConnectivityService.swift
│   │   ├── Auth/
│   │   │   ├── AuthValidation.swift
│   │   │   └── SignInService.swift
│   │   ├── CloudKit/
│   │   │   └── CloudKitSyncService.swift
│   │   ├── Encryption/
│   │   │   └── EncryptionService.swift
│   │   └── HealthKit/
│   │       └── HealthKitService.swift
│   └── Views/
│       ├── RootTabView.swift
│       ├── Auth/
│       ├── Main/
│       ├── Nutrition/
│       ├── Settings/
│       ├── Shared/
│       ├── Stats/
│       └── Training/
├── ai-engine/                       # Python FastAPI — Railway
│   ├── app/
│   │   ├── auth/
│   │   ├── middleware/
│   │   ├── models/
│   │   ├── routers/
│   │   └── services/
│   ├── tests/
│   ├── Dockerfile
│   └── pyproject.toml
└── backend/                         # Supabase SQL
    └── supabase/
        ├── migrations/
        └── seed/
```

---

## Project Notes

- HealthKit features require running on Apple platforms with Health permissions.
- CloudKit sync requires a signed-in iCloud account; intentionally disabled on simulator builds.
- Passkey creation requires a valid `PasskeyRelyingPartyID` in the entitlements.
- Barcode lookup uses Open Food Facts as the primary public packaged-food database.
- OCR nutrition-label parsing uses Apple Vision. English labels have the best accuracy; Hebrew is supported by the parser.
- `pg_cron` retention (`000004`) requires Supabase Pro tier — the migration is a no-op on free plans.
- The `LocalUserSnapshot` in `FitTrackerApp.buildSnapshot()` currently only populates `programPhase`; all other band fields are `nil` and will be silently skipped by the AI Engine until the full snapshot builder is implemented.
- Apple Foundation Models AI integration requires iOS 26+; `FallbackFoundationModel` handles all earlier versions with confidence = 0.0.
