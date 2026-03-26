# FitTracker App

Source of truth for the Apple-platform app. This repository is the staged home of the future `fittracker-app` repo.

## What This Repo Owns

- SwiftUI app code under `FitTracker/`
- app tests under `FitTrackerTests/`
- app CI in `.github/workflows/ci.yml`
- app-level architecture and product documentation

Related subsystem docs:

- AI service: [`ai-engine/README.md`](ai-engine/README.md)
- backend SQL: [`backend/README.md`](backend/README.md)
- split transition: [`docs/REPOSITORY_SPLIT.md`](docs/REPOSITORY_SPLIT.md)

Legal drafts are maintained in the separate `FitMe-GDPR-Docs` repository.

## Current Runtime Truth

- Primary data model: local-first encrypted storage plus CloudKit sync
- Auth model: Apple sign-in, passkeys, and local email flows establish app sessions
- Backend auth: cloud AI is only attempted when a real backend access token is present
- AI behavior:
  - local baseline recommendations always exist
  - cloud cohort insights require a valid backend JWT and complete banded data
  - on-device personalisation adapts the baseline when Foundation Models are available

## App Architecture

```text
FitTracker/
├── FitTrackerApp.swift
├── AI/
├── Models/
├── Services/
├── Views/
└── FitTracker.entitlements
```

Key areas:

- `FitTracker/Services/Auth/`: session management and local auth flows
- `FitTracker/Services/CloudKit/`: encrypted private-database sync
- `FitTracker/Services/Encryption/`: encrypted persistence and export
- `FitTracker/Services/HealthKit/`: live metrics, history, and readiness inputs
- `FitTracker/AI/`: snapshot building, cloud client, orchestration, and local fallback recommendations

## Build

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

## Testing

Primary app tests live in `FitTrackerTests/FitTrackerCoreTests.swift`.

The tracked CI workflow:

- builds the app on GitHub Actions
- runs `FitTrackerTests`
- uploads `.xcresult` diagnostics on failure

## Notes

- CloudKit is intentionally unavailable in simulator builds.
- App sessions and backend JWTs are intentionally modeled as different concepts.
- Archived historical planning material lives under `docs/archive/` and should not be treated as implementation truth.
