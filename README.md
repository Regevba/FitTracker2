# FitTracker

FitTracker is a personal fitness command center for training, recovery, nutrition, and body-composition tracking across iPhone, iPad, and Mac.

The current app is built around a `Today`-first experience:
- a focused home screen with today's status and the next best action
- an active-session training flow with rest timing and previous-performance context
- smarter nutrition logging with adaptive targets, quick actions, label capture, and barcode lookup
- recovery recommendations and guided routines
- a cleaner stats hub for progress, trends, and body composition
- a rebuilt auth experience with a single light-mode entry hub, provider choosers, email registration, and biometric quick reopen

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
- richer progress storytelling in stats
- a redesigned stats screen with pinned `Weight` and `Body Fat %` charts
- a settings-driven `Track More` carousel so each user can choose which extra metrics matter most
- tighter, more Apple-style card density across stats surfaces and empty states

### Security and access
- all sensitive data is encrypted on device before disk persistence or CloudKit sync
- biometric unlock for encryption keys
- optional `Require Face ID/Touch ID on Reopen` behavior in Settings
- Apple Sign In, email auth, and passkey support
- a new auth hub with separate register and log-in paths
- conditional quick actions for Face ID/Touch ID and passkey sign-in
- email registration with password rules, verification-code flow, and AutoFill-friendly fields
- email auth is UI-ready today and still backed by mock development adapters
- simplified account and settings flows that keep passkey creation in Settings

## What Changed Recently

### Reliability fixes
- fixed selected-day training edits so they save to the correct date
- improved background save and lock sequencing
- improved stats refresh behavior after new data is logged
- added safer singleton sync handling for CloudKit profile and preferences data
- disabled CloudKit container initialization in simulator builds so the app no longer crashes on launch there

### Product and UX overhaul
- rebuilt Home into a focused `Today` screen
- redesigned Training around an active-session experience
- redesigned Nutrition around adaptive targets and smart meal capture
- added recovery recommendation surfaces
- reworked Stats into a simpler progress hub with permanent body charts, a focused metric carousel, and more compact cards

### Auth and settings cleanup
- removed the intrusive iPhone passcode fallback for app unlock
- added biometric reopen preference in Settings
- added passkey creation from Settings
- replaced the old `WelcomeView -> SignInView` split with a single auth hub and focused secondary auth screens
- added email sign-up, email verification, email login, provider chooser, and biometric/passkey quick-entry flows
- reorganized account and settings information architecture
- added stats-carousel controls in Settings so users can personalize which metrics appear on the stats screen

### Engineering and release readiness
- added a GitHub Actions CI workflow that builds and tests `FitTracker` on pushes and pull requests to `main`
- pinned CI to Xcode 26.3 with dynamic simulator resolution for current GitHub-hosted macOS runners
- fixed the unit-test target wiring so `FitTrackerTests` runs cleanly in CI and locally

### Nutrition intelligence
- added goal-based nutrition planning for fat loss, maintenance, and lean gain
- added nutrition goal controls in Settings for weight/body-fat target ranges and goal mode
- added OCR-backed nutrition-label parsing with consumed-weight scaling
- expanded food lookup with Open Food Facts plus built-in bilingual reference foods for common staples

## Architecture Overview

```text
FitTracker/
├── .github/
│   └── workflows/
│       └── ci.yml
├── FitTrackerApp.swift
├── Models/
│   └── DomainModels.swift
├── Services/
│   ├── AppSettings.swift
│   ├── AuthManager.swift
│   ├── TrainingProgramStore.swift
│   ├── WatchConnectivityService.swift
│   ├── Auth/
│   │   ├── AuthValidation.swift
│   │   └── SignInService.swift
│   ├── CloudKit/
│   │   └── CloudKitSyncService.swift
│   ├── Encryption/
│   │   └── EncryptionService.swift
│   └── HealthKit/
│       └── HealthKitService.swift
├── Views/
│   ├── Auth/
│   │   ├── AuthHubView.swift
│   │   ├── AccountPanelView.swift
│   │   └── SignInView.swift
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
- Biometrics on the auth hub are only used to reopen a previously stored local session.
- Passkey creation remains a Settings action; passkey sign-in only appears on the auth hub after passkey registration exists.

## Authentication Overview

- Unauthenticated users now land on a single auth hub instead of a welcome screen plus a separate modal sign-in step.
- The hub presents:
  - app name and lightweight value proposition
  - `Register`
  - `Log In`
  - conditional `Use Face ID/Touch ID`
  - conditional `Use Passkey`
- Registration and login use separate method choosers so provider selection and form entry are not mixed together.
- `Sign in with Apple` remains the live provider path.
- Email auth is implemented behind adapters so the UI and flow are production-shaped while backend exchange and verification services can be swapped in later.
- Email registration includes:
  - first name, last name, birthday, email, password, confirm password
  - password-rule guidance
  - strong-password and AutoFill affordances
  - a 5-digit verification code flow with one-time-code AutoFill support

## Continuous Integration

- GitHub Actions workflow: `.github/workflows/ci.yml`
- Triggers:
  - push to `main`
  - pull request to `main`
  - manual dispatch
- Current CI behavior:
  - pins Xcode 26.3 on `macos-15`
  - prints Xcode version, schemes, and available simulators
  - resolves the simulator destination dynamically
  - builds `FitTracker` with signing disabled
  - runs `FitTrackerTests`
  - uploads `.xcresult` diagnostics on failure

## Build

Open the project in Xcode 26.3+ and build the `FitTracker` scheme, or use:

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

To run the current unit-test suite locally:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -resultBundlePath /tmp/FitTrackerTests.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Project Notes

- HealthKit features require running on Apple platforms with Health permissions available.
- CloudKit sync depends on a signed-in iCloud account.
- CloudKit is intentionally disabled on simulator builds; use a signed physical device for end-to-end iCloud sync validation.
- Auth entry uses the new `AuthHubView` path in `FitTrackerApp`; older auth views remain in the project for compatibility while the new flow is the active root experience.
- Email verification is currently a mock-backed adapter flow until production backend/provider wiring is finalized.
- Passkey creation requires a valid `PasskeyRelyingPartyID` configuration.
- Barcode product lookup currently uses Open Food Facts as the primary free/public packaged-food database.
- Smart nutrition-label OCR uses Apple's Vision framework. English label photos are the best-supported path.
- Hebrew nutrition text is supported by the parser, but fully automatic Hebrew photo-label OCR can still depend on OS/runtime language support.
- Simulator-based test runs can still be flaky if local CoreSimulator services are unhealthy.

## Next Recommended Areas

- manual QA across Home, Training, Nutrition, Recovery, and Stats after major UI changes
- broader automated coverage for sync, auth, OCR parsing, and date-scoped logging flows
- a future `Education` surface for recovery content and live guidance that no longer belongs on Home
