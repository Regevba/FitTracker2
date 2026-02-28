# FitTracker v2.0 — iOS · iPadOS · macOS
## Regev's Personal Training, Recovery & Body Composition Tracker

---

## 📁 File Structure

```
FitTracker/
├── FitTrackerApp.swift                     App entry point, lifecycle, service wiring
├── Models/
│   ├── DomainModels.swift                  All data types (Codable, Sendable)
│   └── TrainingProgramData.swift           Complete 6-day program + supplements (static)
├── Services/
│   ├── Encryption/
│   │   └── EncryptionService.swift         AES-256-GCM + ChaCha20-Poly1305 double encryption
│   ├── CloudKit/
│   │   └── CloudKitSyncService.swift       iCloud Private DB — encrypts BEFORE upload
│   ├── HealthKit/
│   │   └── HealthKitService.swift          Apple Watch + Apple Health full integration
│   └── AuthManager.swift                   Face ID / Passcode lock + TrainingProgramStore
├── Views/
│   ├── RootTabView.swift                   4-tab navigation (iPhone tab bar / iPad sidebar)
│   ├── Main/
│   │   └── MainScreenView.swift            Main screen: greeting, weight↔BF slider, goal ring, start button
│   ├── Training/
│   │   └── TrainingPlanView.swift          Training plan: exercises + set/rep/weight log + cardio photo
│   ├── Nutrition/
│   │   └── NutritionView.swift             Supplement tracking: morning + evening stacks
│   └── Stats/
│       └── StatsView.swift                 Stats (placeholder) + Settings view
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

```
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
|---|---|
| **HealthKit** | Check "Background Delivery" + "Clinical Health Records" |
| **iCloud** | Select "CloudKit", add container: `iCloud.com.fittracker.regev` |
| **Keychain Sharing** | Add group: `com.fittracker.regev` |
| **App Sandbox** (macOS only) | Check "Network: Outgoing connections (client)" |

### 4. CloudKit Schema Setup

After adding iCloud capability:
1. Open **CloudKit Console** → cloudkit.apple.com
2. Select your container: `iCloud.com.fittracker.regev`
3. Go to **Development → Record Types**, create these types:

| Record Type | Fields |
|---|---|
| `EncryptedDailyLog` | `encryptedBlob` (Bytes), `logicDate` (Date/Time), `recordVersion` (Int64) |
| `EncryptedWeeklySnapshot` | `encryptedBlob` (Bytes), `logicDate` (Date/Time), `recordVersion` (Int64) |
| `EncryptedUserProfile` | `encryptedBlob` (Bytes), `recordVersion` (Int64) |
| `EncryptedCardioAsset` | `assetData` (Asset), `assetRef` (String), `recordVersion` (Int64) |

4. Add an index on `logicDate` (sortable) for each record type.

> **Important:** CloudKit stores only encrypted blobs. The field names are non-sensitive. Never add plaintext fields.

### 5. PhotosUI Permission (for cardio image capture)

Already in `Info.plist`. No additional steps needed.

### 6. Build & Run

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

```
Plaintext  (DailyLog, ExerciseLog, CardioLog, etc.)
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

### Tab 1 — Main Screen
- **Time-aware greeting**: Good morning / afternoon / evening / night
- **Today's date** + recovery day counter + phase badge
- **Swipeable metric card**: slide between Current Weight (kg) and Body Fat (%). Tap pencil to enter manually from Xiaomi S400
- **Goal progress ring**: combined weight + body fat progress toward 65–68 kg @ 13–15% BF
- **Recovery status banners**: real-time from Apple Watch (HRV + Resting HR)
- **Start Exercise button**: opens Training Plan for today's session
- **Quick stats row**: HRV · Resting HR · Sleep · Steps (all from Apple Watch)

### Tab 2 — Training Plan
- **Day type picker**: scroll horizontally to switch between all 6 day types
- **Session completion ring**: exercises done / total
- **Exercise sections**: Machines → Free Weights → Calisthenics → Core → Cardio
- **Per exercise**: coaching cue, muscle groups, target sets/reps/rest
- **Status dropdown**: Completed / Partial / Missed / Reset
- **On Completed → Lift panel**: set-by-set table (weight × reps × RPE × notes)
- **On Completed → Cardio panel**: duration, avg HR, max HR, calories + type-specific fields
- **Photo upload for Elliptical + Rowing**: Take Photo (camera) or Choose from Library
- Uploaded photo stored as encrypted JPEG in `CardioLog.summaryImageData` and synced via CloudKit as `CKAsset`

### Tab 3 — Nutrition
- **Morning Stack** (7 supplements): per-supplement checkboxes + bulk "Mark all" dropdown
- **Evening Stack** (3 supplements): same pattern
- **Progress bar**: taken / total supplements for today
- **Expandable rows**: tap ℹ️ to see full benefit rationale and timing notes
- **Haptic feedback** on every checkbox toggle

### Tab 4 — Stats
- Empty placeholder, shows data counts
- Scaffolded for future Charts integration (Apple Charts framework, iOS 16+ built-in)

---

## 🎨 Figma → Xcode Workflow

FitTracker ships with minimal styling — you style it in Figma, then bring tokens into Xcode.

### Recommended process:
1. **Figma Desktop** → design at 390pt (iPhone 15 Pro canvas)
2. Install **iOS 17 UI Kit** from Figma Community
3. Use **Figma Variables** for colors/typography:
   - Create a `FitTracker` library
   - Define tokens: `color/accent`, `color/surface`, `color/background`, etc.
4. Export tokens as JSON via **Tokens Studio** Figma plugin
5. Convert to Swift using this pattern:

```swift
// Generated from Figma tokens
extension Color {
    static let ftAccent      = Color("ftAccent")       // in Assets.xcassets
    static let ftSurface     = Color("ftSurface")
    static let ftBackground  = Color("ftBackground")
}
```

6. Add color sets to `Assets.xcassets` in Xcode (light + dark variants)

### Figma Dev Mode API (optional):
- `api.figma.com/v1/files/{fileKey}` → JSON of all design tokens
- Use this to auto-generate `Assets.xcassets` color sets if you want full automation

---

## 🖥 Cursor Integration

Cursor supports Swift natively. Add this `.cursorrules` file to the project root:

```
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

## Rules
- NEVER store plaintext health data to disk
- NEVER write to CloudKit without encrypting first
- Use async/await, never callbacks or DispatchQueue directly
- Use @EnvironmentObject for dataStore, healthService, cloudSync, programStore
- Use #if os(iOS) / #if os(macOS) for platform-specific code
- New UI components go in the relevant Views/ subfolder
- All new models must be Codable + Sendable
- Encrypt any new persistent field before storage

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
|---|---|---|
| `SwiftUI` | All UI | Built-in |
| `HealthKit` | Apple Watch / Health data | Built-in |
| `CryptoKit` | AES-256-GCM + ChaCha20 + HMAC | Built-in |
| `CloudKit` | iCloud encrypted sync | Built-in |
| `LocalAuthentication` | Face ID / Passcode | Built-in |
| `PhotosUI` | Photo picker for cardio images | Built-in |
| `WatchConnectivity` | Watch companion (future) | Built-in |
| `Charts` | Stats charts (future) | Built-in (iOS 16+) |

**Zero SPM / CocoaPods / Carthage dependencies required.**
