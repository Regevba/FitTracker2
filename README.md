# FitTracker

FitTracker is a personal fitness command center for training, recovery, nutrition, and body-composition tracking across iPhone, iPad, and Mac.

The current app is built around a `Today`-first experience:
- a focused home screen with today's status and the next best action
- an active-session training flow with rest timing and previous-performance context
- smarter nutrition logging with adaptive targets, quick actions, label capture, and barcode lookup
- recovery recommendations and guided routines
- a clearer stats hub for progress, trends, and body composition

## Current Highlights

### Today-first home
- no-scroll home layout designed to show the most important information above the fold
- simplified `Today's Status` hero with fast daily decision-making
- essential actions prioritized over exploratory content

### Training flow
- active workout session UI with focus state and exercise queue
- previous-performance context and faster set completion
- integrated rest timer controls
- date-aware workout editing so past days no longer overwrite today's log

### Nutrition flow
- adaptive daily calorie and macro targets based on goal mode, phase, and training/rest day
- quicker meal logging with repeat-last, remembered meals, barcode lookup, and saved templates
- smart nutrition-label capture with OCR plus scaling from label weight to consumed grams
- bilingual parsing support for English and Hebrew nutrition text
- day-aware nutrition navigation
- totals that stay consistent across nutrition, stats, and export flows

### Recovery and progress
- readiness-aware recovery recommendations
- guided routine support
- richer progress storytelling in stats, including body snapshots and weekly summaries

### Security and access
- all sensitive data is encrypted on device before disk persistence or CloudKit sync
- biometric unlock for encryption keys
- optional `Require Face ID/Touch ID on Reopen` behavior in Settings
- Apple Sign In plus passkey support
- simplified welcome, sign-in, lock, account, and settings flows

## What Changed Recently

### Reliability fixes
- fixed selected-day training edits so they save to the correct date
- improved background save and lock sequencing
- improved stats refresh behavior after new data is logged
- added safer singleton sync handling for CloudKit profile and preferences data

### Product and UX overhaul
- rebuilt Home into a focused `Today` screen
- redesigned Training around an active-session experience
- redesigned Nutrition around adaptive targets and smart meal capture
- added recovery recommendation surfaces
- reworked Stats into a clearer progress hub

### Auth and settings cleanup
- removed the intrusive iPhone passcode fallback for app unlock
- added biometric reopen preference in Settings
- added passkey creation from Settings
- simplified the welcome and sign-in experience
- reorganized account and settings information architecture

### Nutrition intelligence
- added goal-based nutrition planning for fat loss, maintenance, and lean gain
- added nutrition goal controls in Settings for weight/body-fat target ranges and goal mode
- added OCR-backed nutrition-label parsing with consumed-weight scaling
- expanded food lookup with Open Food Facts plus built-in bilingual reference foods for common staples

## Architecture Overview

```text
FitTracker/
├── FitTrackerApp.swift
├── Models/
│   └── DomainModels.swift
├── Services/
│   ├── AppSettings.swift
│   ├── AuthManager.swift
│   ├── TrainingProgramStore.swift
│   ├── WatchConnectivityService.swift
│   ├── Auth/
│   │   └── SignInService.swift
│   ├── CloudKit/
│   │   └── CloudKitSyncService.swift
│   ├── Encryption/
│   │   └── EncryptionService.swift
│   └── HealthKit/
│       └── HealthKitService.swift
├── Views/
│   ├── Auth/
│   ├── Main/
│   ├── Nutrition/
│   ├── Shared/
│   ├── Stats/
│   └── Training/
└── FitTracker.entitlements
```

## Security and Privacy Model

- Local persistence uses encrypted blobs.
- CloudKit receives encrypted payloads, not plaintext health or nutrition data.
- Encryption keys live in the Keychain with biometric protection.
- Cold launch can still require biometric unlock because the encryption keys must be unlocked before data can be read.
- Disabling biometric reopen in Settings only affects re-locking while the app stays alive in memory.

## Build

Open the project in Xcode 15.2+ and build the `FitTracker` scheme, or use:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FitTrackerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

## Project Notes

- HealthKit features require running on Apple platforms with Health permissions available.
- CloudKit sync depends on a signed-in iCloud account.
- Passkey creation requires a valid `PasskeyRelyingPartyID` configuration.
- Barcode product lookup currently uses Open Food Facts as the primary free/public packaged-food database.
- Smart nutrition-label OCR uses Apple's Vision framework. English label photos are the best-supported path.
- Hebrew nutrition text is supported by the parser, but fully automatic Hebrew photo-label OCR can still depend on OS/runtime language support.
- Simulator-based test runs can still be flaky if local CoreSimulator services are unhealthy.

## Next Recommended Areas

- manual QA across Home, Training, Nutrition, Recovery, and Stats after major UI changes
- broader automated coverage for sync, auth, OCR parsing, and date-scoped logging flows
- a future `Education` surface for recovery content and live guidance that no longer belongs on Home
