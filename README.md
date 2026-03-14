# FitTracker v2.0 — iOS · iPadOS · macOS

## Regev's Personal Training, Recovery & Body Composition Tracker

---

## 📋 Changelog

### v2.0 — Full Redesign (March 2026)

#### Design System

- `AppTheme.swift`: added `Color.status` namespace (`success` #34C759, `warning` #FF9500, `error` #FF3B30) and `Color.accent` namespace (`cyan` #5AC8FA, `purple` #BF5AF2, `gold` #FFD60A)
- `AppTheme.swift`: added `AppType` enum with type scale — `display` (34/bold), `headline` (20/semibold), `body` (15/medium), `subheading` (13/regular), `caption` (11/regular)
- New shared components: `MetricCard`, `TrendIndicator`, `SectionHeader`, `StatusBadge`, `EmptyStateView`, `ChartCard`
- All views migrated from hardcoded color/font literals to semantic tokens

#### Home Screen

- `ReadinessCard`: 5-page `TabView` replacing the static quick-stats row — Score + context, weekly training bars, nutrition snapshot, 6-metric trend indicators, achievements panel. Auto-cycles every 5 s; swipe resets timer
- `readinessScore(for:fallbackMetrics:)`: 0–100 score from 30-day HRV/HR/sleep baseline; returns `nil` with <3 data points
- Visual polish: orb glow shadow, angular gradient ring (`appOrange1 → accent.cyan → appOrange1`), linear gradient fill on goal progress bars
- Weight/BF trend status dots (8pt circle) — green/red/yellow based on ±0.2 kg / ±0.3% BF over 7 days
- Training button shows active day type and exercise count: `"💪 {DayType} · {N} ex"`

#### Stats — Full Chart Implementation

- Period picker (7D / 30D / 90D / All) + category tab bar (Body / Training / Recovery / Nutrition)
- `StatsDataHelpers.swift`: pure data helpers — body composition points, training volume, Zone 2 minutes, recovery metrics, nutrition adherence, all-time PR records per exercise
- **Body Composition tab**: Weight, Body Fat %, Lean Mass — `LineMark + AreaMark` with 7-day rolling average, target `RuleMark`, tap tooltip, drag scrub
- **Training Performance tab**: Volume per session with PR annotations, per-exercise best set picker, Zone 2 minutes
- **Recovery tab**: HRV with zone bands, Resting HR, Sleep, Readiness Score chart
- **Nutrition Adherence tab**: Calories vs target (switches training/rest), Protein vs target, Supplement adherence %

#### Nutrition — Meal Tracking

- `MacroTargetBar`: stacked protein/carbs/fat bar with calorie target switching between training-day and rest-day targets
- `MealSectionView`: 4 meal slots (Breakfast / Lunch / Dinner / Snacks) with status borders and placeholders
- `MealEntrySheet`: 3-tab sheet — Manual entry with "Save as Template", Template library (persisted to disk), Search via OpenFoodFacts API + barcode scanner (iOS)
- `mealTemplates` persistence in `EncryptedDataStore` — AES-256-GCM encrypted, not CloudKit-synced
- Supplement row collapsed to pill buttons (Morning / Evening) + 🔥 streak badge + expand chevron

#### Training Plan

- 7-day week strip (Mon–Sun) replaces day type scroll picker — TODAY highlighted in orange, completion dot per day, rest days dimmed
- Session type picker grid (6 buttons) below week strip — orange = suggested, blue = selected
- Ghost weights: previous same-`dayType` session values shown as dimmed placeholders in empty set rows; tap to copy; "⚡ Copy Last" pre-fills all sets
- RPE tap bar replaces popover — 5 segments `[6 7 8 9 10]`, tap again to clear
- Session completion sheet: fires when all exercises marked complete — total volume + delta, exercises done, new PRs, session duration, "Log Notes" editor
- `TrainingProgramStore.restWeekdays`: `[1, 4]` (Sunday + Wednesday)

#### Auth Cleanup

- `WelcomeView`: removed "Create Account" button + "Coming Soon" alert
- `SignInView`: removed Google + Facebook sign-in rows; removed YubiKey info chip
- `Info.plist`: removed `NSMicrophoneUsageDescription`

---

### Code Quality & Security Hardening (March 2026)

#### Security — Critical Fixes

- `EncryptionService`: fix `loadKeyFromKeychain` to pass `LAContext` and remove `kSecAttrAccessible` from query — prevents silent key regeneration on cold launch (was causing all encrypted data to become permanently unreadable)
- `EncryptionService`: fix `rotateKeys` to re-encrypt all blobs before deleting old keys — prevents catastrophic data loss on partial failure
- `CloudKitSyncService`: replace `try?` with proper `do/catch` on decrypt calls — decryption errors now logged instead of silently dropping records
- `CloudKitSyncService`: removed 200-record hard limit — all records now fetched (was silently truncating data after ~6.5 months)
- `EncryptionService`: guard `completeFileProtectionUnlessOpen` with `#if os(iOS)` — fixes macOS build

#### Concurrency

- `HealthKitService`: call `done()` before `Task` in `HKObserverQuery` — fixes broken background delivery (future deliveries were silently stopping)
- `AuthManager`: replace `DispatchQueue.main.async` with `Task { @MainActor in }` inside `@MainActor` class

#### Correctness

- `SignInService`: cache window before `performRequests()` — prevents `DispatchQueue.main.sync` deadlock on macOS
- `SignInService`: store `userIdentifier` instead of `authorizationCode` as session token (single-use code must not be persisted)
- `HealthKitService`: check `authorizationStatus` after `requestAuthorization` — `isAuthorized` now reflects actual permission state
- `EncryptedDataStore`: add `@Published var loadError` surfaced via alert in `RootTabView` — disk-load failures are now visible to the user
- `TrainingPlanView`: re-sync `SetRowView` local strings on binding change — prevents stale UI after CloudKit merge
- `DomainModels`: replace `JSONEncoder`-based `DailyLog.==` with `id + date` comparison — fixes non-deterministic equality and unnecessary allocs

#### Architecture

- Extract `TrainingProgramStore` to its own file (`Services/TrainingProgramStore.swift`)
- Add `AppTheme.swift` with shared `Color.appOrange1/2` and `Color.appBlue1/2` — removes copy-pasted palette constants from all four views

#### UI & Accessibility

- Add `.accessibilityLabel` / `.accessibilityValue` to `QuickStatPill` and `GoalProgressRow`
- Dynamic Face ID / Touch ID label in `LockScreenView` via `LAContext.biometryType`
- `WatchConnectivityService`: add `isWatchAppInstalled` check and `appNotInstalled` status case

#### Performance

- Cache `DateFormatter` as `private static let` in `MainScreenView`, `NutritionView`, `CloudKitSyncService` — removes allocations on every body evaluation

#### Dead Code

- Remove unused `RecoveryBanner` component from `MainScreenView`

---

### Watch Connectivity & Navigation Bar (March 2026)

#### Watch Indicator (top-right)

- Replaced CloudKit sync status with Apple Watch connectivity indicator
- New `WatchConnectivityService` using `WCSession` delegate — updates in real-time
- 🟢 green dot + black **"Connected"** when watch is reachable
- Faded dot + black **"Offline"** when not connected (covers BT off, watch charging, not in training)
- Faded dot + black **"No Watch"** / **"App Not Installed"** for pairing states
- No pill/container background — blends into gradient

#### Hamburger Menu (top-left)

- Icon changed from white to blue
- No circular container or system background

---

### Home Screen Layout & Spacing (March 2026)

#### Equal Spacing

- Replace `Spacer(minLength: 10)` with `Spacer()` — SwiftUI now distributes remaining screen height equally across all four section gaps
- `QuickStatPill` HStack spacing set to `0` — pills fill equal widths via `.frame(maxWidth: .infinity)`

---

### UI Refresh (March 2026)

#### Home Screen — Layout & Design

- Replaced scrollable layout with a fixed no-scroll VStack that fills the screen
- Dynamic gradient background (orange → blue) that shifts based on overall goal progress
- Right-edge vertical progress tracker bar
- Side-by-side Weight / Body Fat status cards (replacing swipeable card)
- Goal section: circular ring + inline Weight/Body Fat progress bars
- Start Training: play/pause button + dropdown to override today's day type inline
- Renamed main tab from "Main" to "Home"

#### Navigation Bar

- Hamburger menu button added (top-left) — opens account/settings panel as a sheet
- Toolbar background hidden on Home tab — gradient shows through the nav bar

#### Colors & Contrast

- Replaced light blue tint with standard `.blue` across interactive elements for better contrast on the orange gradient
- Warm palette applied consistently across Training Plan, Nutrition, and Stats tabs

#### Section Headers

- Increased from 10pt semibold to 13pt black weight
- Color changed from `.secondary` to `black.opacity(0.75)`
- Added top/bottom padding for better spacing between header and content

#### Other

- `.gitignore` added; Xcode user state files removed from tracking
- Various navigation UX fixes (NavigationStack, tab title display modes)

---

## 📁 File Structure

```text
FitTracker/
├── FitTrackerApp.swift                     App entry point, lifecycle, service wiring
├── Models/
│   ├── DomainModels.swift                  All data types (Codable, Sendable) incl. MealTemplate
│   └── TrainingProgramData.swift           Complete 6-day program + supplements (static)
├── Services/
│   ├── AppTheme.swift                      Color tokens (appOrange, status.*, accent.*) + AppType scale
│   ├── AppSettings.swift                   Unit system, appearance preferences
│   ├── AuthManager.swift                   Face ID / Touch ID / Passcode biometric lock
│   ├── TrainingProgramStore.swift          Today's day type detection + restWeekdays constant
│   ├── WatchConnectivityService.swift      Apple Watch reachability via WCSession (iOS only)
│   ├── Encryption/
│   │   └── EncryptionService.swift         AES-256-GCM + ChaCha20-Poly1305 double encryption
│   │                                       + EncryptedDataStore (persist/load/export)
│   │                                       + mealTemplates persistence + supplementStreak
│   │                                       + readinessScore(for:fallbackMetrics:)
│   ├── CloudKit/
│   │   └── CloudKitSyncService.swift       iCloud Private DB — encrypts BEFORE upload
│   ├── HealthKit/
│   │   └── HealthKitService.swift          Apple Watch + Apple Health full integration
│   └── Auth/
│       └── SignInService.swift             Passkey / Apple Sign-In authentication
├── Views/
│   ├── RootTabView.swift                   4-tab navigation (iPhone tab bar / iPad sidebar)
│   ├── Shared/
│   │   ├── MetricCard.swift                Icon + value + unit + optional trend pill
│   │   ├── TrendIndicator.swift            Coloured delta pill (↑/↓ %, auto status colour)
│   │   ├── SectionHeader.swift             Bold section header with optional action button
│   │   ├── StatusBadge.swift               Capsule pill with colour + text
│   │   ├── EmptyStateView.swift            Icon + title + subtitle + optional CTA
│   │   ├── ChartCard.swift                 Titled chart container with period label + trend
│   │   └── ReadinessCard.swift             5-page auto-cycling readiness summary card
│   ├── Main/
│   │   └── MainScreenView.swift            Home: gradient bg, goal ring, ReadinessCard, training button
│   ├── Training/
│   │   └── TrainingPlanView.swift          7-day week strip, session picker, ghost weights,
│   │                                       RPE tap bar, completion summary sheet
│   ├── Nutrition/
│   │   ├── NutritionView.swift             MacroTargetBar + meal section + collapsible supplements
│   │   ├── MacroTargetBar.swift            Stacked macro bar with training/rest calorie targets
│   │   ├── MealSectionView.swift           4 meal slot cards with status borders
│   │   └── MealEntrySheet.swift            Manual / Template / Search (OpenFoodFacts + barcode)
│   ├── Stats/
│   │   ├── StatsView.swift                 Period picker + Body/Training/Recovery/Nutrition charts
│   │   └── StatsDataHelpers.swift          Pure data helpers for all chart data + PR records
│   └── Auth/
│       └── AccountPanelView.swift          Account sheet: profile, settings, sign out
├── FitTracker.entitlements                 HealthKit + CloudKit + Keychain + App Sandbox
└── Info.plist                              Privacy strings + background modes + iCloud containers
```

---

## 🛠 Xcode Setup — Step by Step

### Prerequisites

- **Xcode 15.2+** (download from Mac App Store or developer.apple.com)
- **Apple Developer Account** — any plan ($0/free for local testing, $99/yr for device + CloudKit)
- **Real iPhone or iPad** — HealthKit doesn't run in Simulator
- **macOS 14 Sonoma+** for the macOS target

### 1. Create the Xcode Project

```text
File → New → Project
Platform: iOS
Template: App
Product Name: FitTracker
Team: [your Apple ID / team]
Organization Identifier: com.fittracker.regev
Bundle Identifier: com.fittracker.regev
Interface: SwiftUI
Language: Swift
Minimum Deployments: iOS 17.0
```

### 2. Import Source Files

Drag the entire folder structure into Xcode's project navigator:

- Tick **"Copy items if needed"**
- Tick **"Add to target: FitTracker"**
- Tick **"Create groups"**

### 3. Signing & Capabilities

In **Xcode → Target → Signing & Capabilities**, add:

| Capability | Settings |
| --- | --- |
| **HealthKit** | Check "Background Delivery" + "Clinical Health Records" |
| **iCloud** | Select "CloudKit", add container: `iCloud.com.fittracker.regev` |
| **Keychain Sharing** | Add group: `com.fittracker.regev` |
| **App Sandbox** (macOS only) | Check "Network: Outgoing connections (client)" |

### 4. CloudKit Schema Setup

After adding iCloud capability:

1. Open **CloudKit Console** → cloudkit.apple.com
1. Select your container: `iCloud.com.fittracker.regev`
1. Go to **Development → Record Types**, create these types:

| Record Type | Fields |
| --- | --- |
| `EncryptedDailyLog` | `encryptedBlob` (Bytes), `logicDate` (Date/Time), `recordVersion` (Int64) |
| `EncryptedWeeklySnapshot` | `encryptedBlob` (Bytes), `logicDate` (Date/Time), `recordVersion` (Int64) |
| `EncryptedUserProfile` | `encryptedBlob` (Bytes), `recordVersion` (Int64) |
| `EncryptedCardioAsset` | `assetData` (Asset), `assetRef` (String), `recordVersion` (Int64) |

Add an index on `logicDate` (sortable) for each record type.

> **Important:** CloudKit stores only encrypted blobs. The field names are non-sensitive. Never add plaintext fields.
> **Note:** `mealTemplates` are stored on-device only — they are not synced to CloudKit.

### 5. Build & Run

```bash
# Command line (optional)
xcodebuild -project FitTracker.xcodeproj \
           -scheme FitTracker \
           -destination 'platform=iOS,id=YOUR_DEVICE_UDID' \
           build
```

Or press **⌘R** in Xcode with your device selected.

---

## 🔐 Encryption Architecture — Maximum Security

### Double Encryption (every piece of data, always)

```text
Plaintext  (DailyLog, ExerciseLog, CardioLog, MealTemplate, etc.)
    │
    ▼ JSONEncoder
Raw JSON bytes
    │
    ▼ Layer 1: AES-256-GCM  (CryptoKit)
    │   Key: 256-bit, Keychain (biometric-protected, device-only)
    │   Nonce: random per operation
    │   Authentication tag: 128-bit
    │
    ▼ Layer 2: ChaCha20-Poly1305  (CryptoKit)
    │   Key: 256-bit, Keychain (biometric-protected, device-only)
    │   Nonce: random per operation
    │   Authentication tag: 128-bit
    │
    ▼ HMAC-SHA512 integrity check
    │   Key: 256-bit, Keychain (biometric-protected, device-only)
    │
    ▼ [1B version][8B timestamp][64B HMAC][ciphertext]
    │
    ├──→ Disk: NSFileProtectionCompleteUnlessOpen
    │          (iOS hardware encryption layer 3)
    │
    └──→ CloudKit Private DB:
              Encrypted blob uploaded as opaque bytes
              CloudKit server NEVER sees plaintext
              Only decryptable on devices with your Apple ID + biometric key
```

### Three Separate Keys

- `AES-256 key` — stored in Keychain, ACL: biometric OR device passcode
- `ChaCha20 key` — stored in Keychain, ACL: biometric OR device passcode
- `HMAC-SHA512 key` — stored in Keychain, ACL: biometric OR device passcode

All three keys are: 256-bit random, device-only (not iCloud Keychain), access requires Face ID or passcode.

### Apple-Only Platform Enforcement

- **iOS/iPadOS**: App Store distribution = Apple devices only, no sideloading without Apple account
- **macOS**: Mac App Store + Hardened Runtime + App Sandbox
- **Code-level**: `HealthKit`, `CryptoKit`, `LocalAuthentication`, `CloudKit` = Apple frameworks only
- **Conditional compilation**: `#if os(iOS)`, `#if os(macOS)` throughout — won't compile on non-Apple
- **Entitlements**: `com.apple.security.app-sandbox` = macOS sandbox, requires Apple signing

---

## 📱 App Screens

### Tab 1 — Home Screen

- **Time-aware greeting**: Good morning / afternoon / evening / night
- **Today's date** + recovery day counter + phase badge
- **Dynamic gradient background**: orange → blue, shifts based on goal progress
- **Right-edge vertical progress tracker**: thin bar showing overall goal completion
- **Side-by-side status cards**: Weight (kg) and Body Fat (%) with trend status dots (↑/↓/flat)
- **Goal section**: circular ring with orb glow + Weight/Body Fat progress bars (angular gradient fill)
- **ReadinessCard** (5-page, auto-cycles every 5 s):
  - Page 1: Readiness score (0–100) + context label + HRV / Resting HR / Sleep
  - Page 2: Mon–Sun weekly training bars + next session name
  - Page 3: Protein progress + AM/PM supplement dots + water intake
  - Page 4: 6-metric trend indicators (Weight, BF, HRV, Sleep, Volume, Steps)
  - Page 5: Achievements — supplement streak 🔥, PRs this week 🏆, program day 📅
- **Training button**: `"💪 {DayType} · {N} ex"` — shows exercise count for today
- **Hamburger menu** (top-left): blue icon, no container
- **Watch indicator** (top-right): green dot = Connected, faded dot = Offline/No Watch

### Tab 2 — Training Plan

- **7-day week strip**: Mon–Sun with TODAY highlighted in orange; completion dot per day; rest days dimmed
- **Session type picker**: 6-button grid — orange = weekday suggestion, blue = user override
- **Session completion ring**: exercises done / total
- **Exercise sections**: Machines → Free Weights → Calisthenics → Core → Cardio
- **Per exercise**: coaching cue, muscle groups, target sets/reps/rest
- **Status dropdown**: Completed / Partial / Missed / Reset
- **On Completed → Lift panel**: set-by-set table with ghost weights from last same-type session; tap ghost to copy; "⚡ Copy Last" pre-fills all sets; RPE tap bar (6–10, tap to deselect)
- **On Completed → Cardio panel**: duration, avg HR, max HR, calories + type-specific fields; photo upload for Elliptical + Rowing
- **Session completion sheet**: triggers when all exercises done — volume + delta vs previous session, PRs detected, session duration, notes editor

### Tab 3 — Nutrition

- **MacroTargetBar**: stacked protein / carbs / fat bar; calorie target switches between training-day and rest-day targets from the active program phase
- **Meal section**: 4 meal slots (Breakfast / Lunch / Dinner / Snacks); tap to open `MealEntrySheet`
  - **Manual tab**: name + kcal + P/C/F; "Save as Template" persists entry for reuse
  - **Template tab**: saved templates list; tap to auto-fill Manual tab
  - **Search tab**: OpenFoodFacts API search + barcode scanner (iOS); results fill Manual tab
- **Supplement row** (collapsible): Morning / Evening pill buttons + 🔥 streak badge; expand for full supplement cards with checkboxes and ℹ️ benefit details
- **Haptic feedback** on every checkbox toggle

### Tab 4 — Stats

- **Period picker**: 7D / 30D / 90D / All (segmented, updates all charts)
- **Category tabs**: Body / Training / Recovery / Nutrition
- **Body Composition**: Weight (rolling avg + target line), Body Fat % (target line), Lean Mass — line + area charts; tap tooltip; drag scrub
- **Training Performance**: Volume per session with PR stars, per-exercise best set (exercise picker), Zone 2 minutes
- **Recovery**: HRV (zone bands), Resting HR, Sleep, Readiness Score trend
- **Nutrition Adherence**: Calories vs target, Protein vs target, Supplement adherence %
- Empty state shown for each chart when no data exists in the selected period

---

## 🎨 Figma → Xcode Workflow

FitTracker ships with a full design token system in `AppTheme.swift`.

### Token Reference

```swift
// Semantic status colours
Color.status.success   // #34C759 — green
Color.status.warning   // #FF9500 — orange
Color.status.error     // #FF3B30 — red

// Accent colours
Color.accent.cyan      // #5AC8FA
Color.accent.purple    // #BF5AF2
Color.accent.gold      // #FFD60A

// Type scale
AppType.display        // 34pt bold
AppType.headline       // 20pt semibold
AppType.body           // 15pt medium
AppType.subheading     // 13pt regular
AppType.caption        // 11pt regular
```

### Recommended Process

1. **Figma Desktop** → design at 390pt (iPhone 15 Pro canvas)
1. Install **iOS 17 UI Kit** from Figma Community
1. Map Figma styles to `AppTheme` tokens above
1. Export new tokens as JSON via **Tokens Studio** plugin, then add to `AppTheme.swift`

---

## 🖥 Cursor Integration

Cursor supports Swift natively. Add this `.cursorrules` file to the project root:

```text
# .cursorrules — FitTracker v2.0

## Project context
- SwiftUI app for iOS 17+, iPadOS 17+, macOS 14+
- Apple-only platform: no Android, no web, no Windows
- All data encrypted: AES-256-GCM + ChaCha20-Poly1305 double layer

## Architecture
- Entry: FitTrackerApp.swift
- Data models: Models/DomainModels.swift (all Codable + Sendable)
- Training data: Models/TrainingProgramData.swift (static, never modify in app)
- Encryption: Services/Encryption/EncryptionService.swift (actor, thread-safe)
- CloudKit: Services/CloudKit/CloudKitSyncService.swift (@MainActor)
- Health: Services/HealthKit/HealthKitService.swift (@MainActor)
- Design tokens: Services/AppTheme.swift (Color.status.*, Color.accent.*, AppType)

## Rules
- NEVER store plaintext health data to disk
- NEVER write to CloudKit without encrypting first
- Use async/await, never callbacks or DispatchQueue directly
- Use @EnvironmentObject for dataStore, healthService, cloudSync, programStore
- Use #if os(iOS) / #if os(macOS) for platform-specific code
- New UI components go in Views/Shared/ or the relevant Views/ subfolder
- All new models must be Codable + Sendable
- Encrypt any new persistent field before storage
- Use Color.status.* / Color.accent.* instead of hardcoded color literals
- Use AppType.* instead of .font(.system(size:))

## SwiftUI patterns used
- @StateObject for service ownership in FitTrackerApp
- @EnvironmentObject for consumption in views
- Binding<T> for form inputs that modify DailyLog
- .task {} for async on-appear work
- NavigationStack for all navigation
```

---

## 🚀 No External Dependencies

| Framework | Use | Source |
| --- | --- | --- |
| `SwiftUI` | All UI | Built-in |
| `Charts` | Stats charts (iOS 16+) | Built-in |
| `HealthKit` | Apple Watch / Health data | Built-in |
| `CryptoKit` | AES-256-GCM + ChaCha20 + HMAC | Built-in |
| `CloudKit` | iCloud encrypted sync | Built-in |
| `LocalAuthentication` | Face ID / Passcode | Built-in |
| `PhotosUI` | Photo picker for cardio images | Built-in |
| `AVFoundation` | Barcode scanner in MealEntrySheet (iOS) | Built-in |
| `WatchConnectivity` | Apple Watch reachability indicator | Built-in |

**Zero SPM / CocoaPods / Carthage dependencies required.**
