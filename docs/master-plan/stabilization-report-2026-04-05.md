# Stabilization Report — 2026-04-05

This document records the recovery work completed during the 2026-04-05 stabilization pass, the exact local setup used for verification, and the gaps that still remain before the project can be treated as fully operational.

---

## What Was Recovered

The main repo was directionally strong but not operationally stable enough to trust on a clean machine. The following recovery work was completed:

- the Xcode project was repaired so the app target builds again
- Firebase packages were linked into the app target
- previously present analytics / GDPR source files were added back into the Xcode target
- a missing `FitTracker/Info.plist` was restored
- Firebase bootstrap is now config-aware so clean builds and XCTest runs do not crash when `GoogleService-Info.plist` is absent
- the data export service was reconciled with the current domain models
- `restoreSession()` was fixed so stored sessions can become active again when biometric reopen is disabled
- `signOut()` now revokes the local Supabase auth session instead of only clearing app state
- account deletion now has explicit deletion paths for:
  - Supabase `sync_records`
  - Supabase `cardio_assets`
  - Supabase private cardio image blobs
  - CloudKit private encrypted records
  - local encrypted `.ftenc` files
  - local encryption keys
- a new migration was added to repair `sync_records` uniqueness for dated rows:
  - [`000008_fix_sync_records_uniqueness.sql`](../../backend/supabase/migrations/000008_fix_sync_records_uniqueness.sql)
- targeted iOS core regression coverage was added for sign-out, simulator auto-login control, lock/resume auth flow, stale-session cleanup, local encrypted-data erasure, and deletion grace-period / partial-failure behavior:
  - [`FitTrackerTests/FitTrackerCoreTests.swift`](../../FitTrackerTests/FitTrackerCoreTests.swift)

---

## Local Setup Used

### iOS / Xcode

- full Xcode required, not Command Line Tools only
- verified with:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version`
- verified version during this pass:
  - `Xcode 26.4`
  - `Build version 17E192`

### Node Workspaces

Root:

```bash
npm install
npm run tokens:check
```

Dashboard:

```bash
cd dashboard
npm install
npm test
```

Website:

```bash
cd website
npm install
npm run build
```

Note: in sandboxed environments, Astro may need telemetry disabled to avoid writing preferences outside the workspace:

```bash
ASTRO_TELEMETRY_DISABLED=1 npm run build
```

### AI Engine

```bash
cd ai-engine
python3.12 -m venv /tmp/FitTracker2-ai-venv
source /tmp/FitTracker2-ai-venv/bin/activate
pip install -e '.[dev]'
pytest -q
```

Note: `/tmp` virtualenvs and derived-data folders are ephemeral. Recreate them if they disappear between sessions.

### One-Command Verification

```bash
make verify-local
```

What it covers:

- root token drift check
- dashboard test + production build
- website production build
- AI engine tests
- iOS build plus the targeted `FitTrackerCoreTests` and `SyncMergeTests` simulator pass

Current status:

- passes end to end
- latest verified XCTest bundle: `/tmp/FitTrackerTestsDD-verify/Logs/Test/Test-FitTracker-2026.04.06_07-15-38-+0300.xcresult`

---

## Runtime Config Still Required

The repo is buildable again, but several runtime values are intentionally still local-environment concerns:

- `FitTracker/GoogleService-Info.plist`
  - not committed in this clone
  - required for Firebase runtime verification
  - no longer required just to build the app or run unit tests
- `FitTracker/Info.plist`
  - currently restored with placeholder values for:
    - `SupabaseURL`
    - `SupabaseAnonKey`
  - these must be replaced locally before runtime Supabase validation
- `PasskeyRelyingPartyID`
  - must match the associated domains setup used for passkeys

---

## Verification Matrix

### Green

#### iOS Build

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/FitTrackerDerivedData-review \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Status:

- passes
- remaining warning seen in filtered output:
  - AppIntents metadata extraction skipped because `AppIntents.framework` is not linked

#### iOS XCTest

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=87E96E30-350E-46AC-AB34-B87AF8D1AB1E' \
  -only-testing:FitTrackerTests/FitTrackerCoreTests \
  -derivedDataPath /tmp/FitTrackerTestsDD \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Status:

- passes
- verifies the targeted `FitTrackerCoreTests` suite on simulator
- current focused suite size: `31` tests
- confirms Firebase/runtime bootstrap no longer aborts tests when local analytics config is absent
- now also covers successful JSON export generation, exported payload structure, and export analytics events
- now also covers graceful handling for missing local Supabase configuration

#### Focused Sync Merge Coverage

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project FitTracker.xcodeproj \
  -scheme FitTracker \
  -destination 'platform=iOS Simulator,id=87E96E30-350E-46AC-AB34-B87AF8D1AB1E' \
  -only-testing:FitTrackerTests/SyncMergeTests \
  -derivedDataPath /tmp/FitTrackerSyncTestsDD \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Status:

- passes
- current focused suite size: `9` tests
- verifies multiple dated `DailyLog` and `WeeklySnapshot` rows coexist instead of collapsing into one logical record
- surfaced and confirmed the fix for a real bug in [`EncryptionService.swift`](../../FitTracker/Services/Encryption/EncryptionService.swift), where `mergeDailyLog` had been comparing optional `logicDayKey` values directly instead of normalized `resolvedLogicDayKey` values
- combined with `FitTrackerCoreTests`, the current targeted simulator XCTest pass is `40/40`

#### iOS Simulator Runtime Spot Check

Date:

- `2026-04-06`

What was verified:

- the app builds and installs to the iPhone 14 Pro simulator
- the app launches successfully in simulator review mode
- authenticated review launch reaches the live app UI rather than crashing at startup
- the direct settings review launch now reaches the live Settings screen
- the nested Delete Account GDPR screen now renders through a deterministic review route
- the nested Export My Data portability screen now renders through a deterministic review route

What was observed:

- first launch surfaced the App Tracking Transparency system prompt, which can obscure the underlying screen during screenshot-based verification
- screenshot evidence captured the live app on simulator at:
  - `/tmp/ui-integration-settings-runtime-fresh.png`
- deeper screenshot evidence captured the live Delete Account screen at:
  - `/tmp/ui-integration-delete-account-runtime.png`
- deeper screenshot evidence captured the live Export My Data screen at:
  - `/tmp/ui-integration-export-data-runtime.png`
- the simulator review-launch path needed two runtime fixes before settings review would render reliably:
  - [`FitTrackerApp.swift`](../../FitTracker/FitTrackerApp.swift) now recognizes `FITTRACKER_REVIEW_TAB=settings` as a settings review trigger
  - [`SettingsView.swift`](../../FitTracker/Views/Settings/SettingsView.swift) now injects `AnalyticsService` explicitly into its GDPR destinations and settings category destinations
- after those fixes, the current settings review launch succeeds with the existing simulator convention:
  - `FITTRACKER_REVIEW_AUTH=authenticated`
  - `FITTRACKER_REVIEW_TAB=settings`
- nested deletion review now also succeeds with:
  - `FITTRACKER_REVIEW_SETTINGS_DESTINATION=delete-account`
- nested export review now also succeeds with:
  - `FITTRACKER_REVIEW_SETTINGS_DESTINATION=export-data`
- the deterministic nested route works by pushing the normal settings navigation stack into Account & Security and then into Delete Account, so it exercises the real GDPR destination wiring instead of a separate standalone wrapper
- the same deterministic routing approach now also pushes through Data & Sync into Export My Data, proving the portability screen’s environment-object wiring without requiring manual taps

What remains blocked:

- signed-in runtime verification is still pending because:
  - the simulator review route proves rendering and dependency wiring, but not a live backend-backed deletion execution
  - the simulator pass still does not prove end-to-end export sharing behavior or live backend-authenticated deletion on a real user session

#### Design Tokens

Command:

```bash
npm run tokens:check
```

Status:

- passes
- `DesignTokens.swift` is in sync with `tokens.json`

#### Dashboard

Command:

```bash
cd dashboard
npm test
```

Status:

- passes
- `1` test file
- `9` tests passing

Production build command:

```bash
cd dashboard
ASTRO_TELEMETRY_DISABLED=1 npm run build
```

Build status:

- passes
- Astro telemetry needed to be disabled in the sandbox because the default telemetry path writes under `~/Library/Preferences`

#### Marketing Website

Command:

```bash
cd website
ASTRO_TELEMETRY_DISABLED=1 npm run build
```

Status:

- passes
- Astro telemetry needed to be disabled in the sandbox because the default telemetry path writes under `~/Library/Preferences`

#### AI Engine

Command:

```bash
cd ai-engine
source /tmp/FitTracker2-ai-venv/bin/activate
pytest -q
```

Status:

- passes
- `5` tests passing

What changed:

- tests now use a shared stub `Settings` fixture through `tests/conftest.py`
- production config strictness remains intact in app code
- payload-validation and fire-and-forget tests now explicitly override auth where the test intent is not JWKS validation
- the unauthenticated-path expectation was aligned with the current FastAPI / HTTPBearer behavior (`401`)

---

## Source Files Changed In This Recovery Pass

Primary code/config changes:

- [`FitTracker.xcodeproj/project.pbxproj`](../../FitTracker.xcodeproj/project.pbxproj)
- [`FitTracker/FitTrackerApp.swift`](../../FitTracker/FitTrackerApp.swift)
- [`FitTracker/Info.plist`](../../FitTracker/Info.plist)
- [`FitTracker/Services/Analytics/AnalyticsService.swift`](../../FitTracker/Services/Analytics/AnalyticsService.swift)
- [`FitTracker/Services/Auth/SignInService.swift`](../../FitTracker/Services/Auth/SignInService.swift)
- [`FitTracker/Services/AccountDeletionService.swift`](../../FitTracker/Services/AccountDeletionService.swift)
- [`FitTracker/Services/Supabase/SupabaseClient.swift`](../../FitTracker/Services/Supabase/SupabaseClient.swift)
- [`FitTracker/Services/Supabase/SupabaseSyncService.swift`](../../FitTracker/Services/Supabase/SupabaseSyncService.swift)
- [`FitTracker/Services/CloudKit/CloudKitSyncService.swift`](../../FitTracker/Services/CloudKit/CloudKitSyncService.swift)
- [`FitTracker/Services/Encryption/EncryptionService.swift`](../../FitTracker/Services/Encryption/EncryptionService.swift)
- [`FitTracker/Services/DataExportService.swift`](../../FitTracker/Services/DataExportService.swift)
- [`FitTracker/Views/Settings/SettingsView.swift`](../../FitTracker/Views/Settings/SettingsView.swift)
- [`FitTracker/Views/Settings/DeleteAccountView.swift`](../../FitTracker/Views/Settings/DeleteAccountView.swift)
- [`FitTracker/Views/Auth/AccountPanelView.swift`](../../FitTracker/Views/Auth/AccountPanelView.swift)
- [`FitTracker/Views/RootTabView.swift`](../../FitTracker/Views/RootTabView.swift)
- [`backend/supabase/migrations/000008_fix_sync_records_uniqueness.sql`](../../backend/supabase/migrations/000008_fix_sync_records_uniqueness.sql)
- [`ai-engine/tests/conftest.py`](../../ai-engine/tests/conftest.py)
- [`ai-engine/tests/test_training.py`](../../ai-engine/tests/test_training.py)
- [`dashboard/src/scripts/reconcile.js`](../../dashboard/src/scripts/reconcile.js)
- [`dashboard/tests/reconcile.test.js`](../../dashboard/tests/reconcile.test.js)
- [`FitTrackerTests/FitTrackerCoreTests.swift`](../../FitTrackerTests/FitTrackerCoreTests.swift)
- [`Makefile`](../../Makefile)

Primary docs updated:

- [`README.md`](../../README.md)
- [`CHANGELOG.md`](../../CHANGELOG.md)
- [`docs/setup/firebase-setup-guide.md`](../setup/firebase-setup-guide.md)
- [`docs/master-plan/master-plan-reconciled-2026-04-05.md`](./master-plan-reconciled-2026-04-05.md)

---

## Remaining Gaps

High-priority remaining work:

- verify signed-in Supabase sync against a real backend session, not only merge-level correctness and simulator review mode
- verify signed-in deletion and export execution on a real runtime with local credentials and backend access
- supply local Firebase config and verify consent-gated analytics events in DebugView
- keep the deterministic review-routing approach for any future nested settings screens that need reliable simulator verification

Checkpoint note from 2026-04-06:

- a clean simulator reinstall now reaches the consent gate on first launch without crashing
- the earlier `Biometry is not enrolled` alert was traced to stale simulator app state rather than the real first-launch flow
- runtime verification should continue from a clean reinstall baseline after the project move to the external SSD

---

## Practical Next Step

The next best move is runtime verification with real local config, not more local build recovery.

The best next step is:

1. add a local `FitTracker/GoogleService-Info.plist` and verify consent-gated analytics in Firebase DebugView
2. sign in with local Supabase config and run one real sync plus deletion/export execution pass
3. tighten docs further only if that runtime verification surfaces new gaps
