# Firebase + Google Analytics Setup Guide for FitMe

> Complete step-by-step instructions to connect GA4 via Firebase to the FitMe iOS app.
> Estimated time: 30-45 minutes

---

## Prerequisites

- Apple Developer account (for bundle ID)
- Google account (for Firebase Console)
- Xcode 15+ installed
- FitMe project opens and builds in Xcode

---

## Part 1: Create Firebase Project

### Step 1: Go to Firebase Console

1. Open https://console.firebase.google.com
2. Click **"Create a project"** (or "Add project")
3. Project name: **FitMe** (or "FitMe-Production")
4. Click **Continue**

### Step 2: Enable Google Analytics

1. Toggle **"Enable Google Analytics for this project"** → ON
2. Click **Continue**
3. Select or create a Google Analytics account:
   - Account name: **FitMe Analytics**
   - Analytics location: **Israel** (or your country)
   - Accept Google Analytics terms
4. Click **Create project**
5. Wait for provisioning (~30 seconds)
6. Click **Continue** when done

---

## Part 2: Register iOS App

### Step 3: Add iOS App to Firebase

1. On the Firebase project overview page, click the **iOS+ icon** (Apple icon)
2. Fill in:
   - **Apple bundle ID:** `com.regevba.FitTracker` (check your Xcode project → General → Bundle Identifier)
   - **App nickname:** `FitMe iOS`
   - **App Store ID:** (leave blank for now)
3. Click **Register app**

### Step 4: Download GoogleService-Info.plist

1. Click **"Download GoogleService-Info.plist"**
2. Save the file — you'll need it in Part 3
3. Click **Next** (don't follow the CocoaPods instructions — we'll use SPM)
4. Click **Next** again
5. Click **Continue to console**

---

## Part 3: Add Firebase SDK to Xcode

### Step 5: Add Firebase SPM Package

1. Open `FitTracker2.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. In the search bar, paste:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. Click **Add Package**
5. Wait for Xcode to resolve the package (may take 1-2 minutes)
6. In the **"Choose Package Products"** dialog, select ONLY:
   - ✅ **FirebaseAnalytics**
   - ❌ Everything else (uncheck all others)
7. Click **Add Package**

### Step 6: Add GoogleService-Info.plist to Project

1. Drag `GoogleService-Info.plist` from your Downloads into the Xcode project navigator
2. Drop it into the **FitTracker** folder (same level as `FitTrackerApp.swift`)
3. In the dialog:
   - ✅ Copy items if needed
   - ✅ Add to targets: FitTracker
4. Click **Finish**
5. Verify: the file should appear in the project navigator under `FitTracker/`

### Step 7: Add -ObjC Linker Flag

1. Click on the **FitTracker2** project in the navigator (blue icon at top)
2. Select the **FitTracker** target
3. Go to **Build Settings** tab
4. Search for **"Other Linker Flags"**
5. Add `-ObjC` to the list
6. This is required for Firebase to work correctly

### Step 8: Disable Automatic Screen Reporting

Firebase auto-tracks UIViewController screen views, which doesn't work well with SwiftUI. We handle screen tracking manually via `.analyticsScreen()`.

1. Open `Info.plist` (or the Info tab in target settings)
2. Add a new row:
   - Key: `FirebaseAutomaticScreenReportingEnabled`
   - Type: Boolean
   - Value: `NO`

---

## Part 4: Configure Firebase in Code

### Step 9: Uncomment Firebase Imports

Open `FitTracker/Services/Analytics/FirebaseAnalyticsAdapter.swift` and uncomment the Firebase lines:

```swift
// Change this:
// import FirebaseCore
// import FirebaseAnalytics

// To this:
import FirebaseCore
import FirebaseAnalytics
```

Then uncomment ALL the method bodies in that file (remove the `//` before each `Analytics.` and `FirebaseApp.` call).

### Step 10: Add FirebaseApp.configure() to App Entry

Open `FitTracker/FitTrackerApp.swift` and add Firebase configuration in the `init()`:

```swift
init() {
    #if DEBUG
    ColorContrastValidator.validate()
    #endif
    
    // Configure Firebase (must be called before any Firebase service)
    FirebaseApp.configure()
}
```

Add the import at the top of the file:
```swift
import FirebaseCore
```

### Step 11: Add AnalyticsService to FitTrackerApp

In `FitTrackerApp.swift`, add the analytics service alongside the other `@StateObject` services:

```swift
@StateObject private var analytics = AnalyticsService.makeDefault()
```

Then add `.environmentObject(analytics)` to all the view hierarchies where other environment objects are passed. There are 3 places in `rootView`:

```swift
// In the RootTabView branch:
RootTabView()
    .environmentObject(signIn)
    // ... existing environment objects ...
    .environmentObject(analytics)   // ← Add this

// In the SettingsView branch:
SettingsView()
    .environmentObject(signIn)
    // ... existing environment objects ...
    .environmentObject(analytics)   // ← Add this

// In the AuthHubView branch:
AuthHubView()
    .environmentObject(signIn)
    // ... existing environment objects ...
    .environmentObject(analytics)   // ← Add this
```

### Step 12: Add Consent Check to Auth Flow

After the user signs in/up, show the ConsentView if consent hasn't been granted:

In the `rootView` computed property, add a consent check before showing `RootTabView`:

```swift
} else if signIn.isAuthenticated {
    if analytics.consent.needsConsentPrompt {
        ConsentView(onComplete: { /* consent handled internally */ })
            .environmentObject(analytics)
    } else {
        RootTabView()
            .environmentObject(signIn)
            // ... all other environment objects ...
            .environmentObject(analytics)
    }
}
```

---

## Part 5: Add ATT Permission String

### Step 13: Add App Tracking Transparency Usage Description

1. Open `Info.plist`
2. Add a new row:
   - Key: `NSUserTrackingUsageDescription`
   - Type: String
   - Value: `FitMe uses this to understand how the app is used and improve your experience. No health data is shared.`

---

## Part 6: Verify It Works

### Step 14: Build and Run

1. **Build:** `Cmd + B` — should compile without errors
2. **Run:** `Cmd + R` on a simulator or device
3. Check the Xcode console for:
   ```
   [Analytics:Firebase] screen_view: consent
   [Analytics:Firebase] consent_granted {"consent_type": "gdpr"}
   [Analytics:Firebase] screen_view: home
   ```

### Step 15: Enable Firebase DebugView

To see real-time events in Firebase Console during development:

1. In Xcode, go to **Product → Scheme → Edit Scheme**
2. Select **Run** → **Arguments** tab
3. Add to **Arguments Passed On Launch:**
   ```
   -FIRDebugEnabled
   ```
4. Run the app
5. Go to Firebase Console → **Analytics → DebugView**
6. You should see events appearing in real-time (may take 1-2 minutes)

### Step 16: Verify in GA4 Dashboard

Events take **24-48 hours** to appear in the main GA4 reports. But you can verify immediately via:

1. **Firebase Console → Analytics → DebugView** — real-time (with debug flag)
2. **Firebase Console → Analytics → Realtime** — within 1 hour
3. **Firebase Console → Analytics → Events** — within 24-48 hours

---

## Part 7: Mark Conversion Events

### Step 17: Configure Conversions in GA4

Once events are flowing (after 24-48 hours):

1. Go to **Firebase Console → Analytics → Events**
2. Find these events and toggle **"Mark as conversion"**:
   - `sign_up`
   - `workout_complete`
   - `meal_log`
   - `tutorial_complete`
   - `cross_feature_engagement`

---

## Part 8: Register Custom Dimensions

### Step 18: Register Custom Parameters as Dimensions

Custom event parameters are **NOT visible in GA4 reports** until registered as custom dimensions.

1. Go to **GA4 (analytics.google.com)** → Admin → Custom definitions
2. Click **"Create custom dimension"** for each:

| Dimension Name | Scope | Event Parameter |
|---------------|-------|-----------------|
| Workout Type | Event | workout_type |
| Exercise Name | Event | exercise_name |
| Muscle Group | Event | muscle_group |
| Meal Type | Event | meal_type |
| Entry Method | Event | entry_method |
| Metric Type | Event | metric_type |
| Data Source | Event | source |
| Stat Type | Event | stat_type |
| Time Period | Event | time_period |
| Goal Type | Event | goal_type |
| Auth Method | Event | method |
| Content Type | Event | content_type |
| Setting Name | Event | setting_name |
| PR Type | Event | pr_type |
| Consent Type | Event | consent_type |

3. Click **"Create custom metric"** for each:

| Metric Name | Scope | Event Parameter | Unit |
|------------|-------|-----------------|------|
| Duration (seconds) | Event | duration_seconds | Standard |
| Exercise Count | Event | exercise_count | Standard |
| Set Count | Event | set_count | Standard |
| Weight (kg) | Event | weight | Standard |
| Reps | Event | reps | Standard |
| Streak Length | Event | streak_length | Standard |

---

## Part 9: App Store Privacy Nutrition Label

### Step 19: Update Privacy Labels

When submitting to App Store Connect, declare:

**Data Types Collected:**

| Data Type | Linked to Identity | Used for Tracking |
|-----------|-------------------|-------------------|
| Usage Data (Product Interaction) | No | No |
| Diagnostics (Performance Data) | No | No |

**Data NOT collected:**
- Health & Fitness (never sent to analytics)
- Precise Location
- Contact Info
- Identifiers (if ATT denied)

---

## Part 10: Data Retention Settings

### Step 20: Configure Data Retention

1. Go to **GA4 → Admin → Data Settings → Data Retention**
2. Set event data retention to **14 months** (maximum)
3. Toggle **"Reset user data on new activity"** → ON

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Events not appearing in DebugView | Ensure `-FIRDebugEnabled` launch argument is set |
| "No data yet" in GA4 | Wait 24-48 hours for processing |
| Build error: "No such module 'FirebaseCore'" | Clean build folder (Cmd+Shift+K), resolve packages (File → Packages → Resolve) |
| Build error: "-ObjC linker flag" | Add `-ObjC` to Other Linker Flags in Build Settings |
| ATT dialog not showing | Only appears once per install. Reset: Settings → General → Transfer or Reset → Reset Location & Privacy |
| Events logged but consent_status = denied | Check ConsentManager.isAnalyticsAllowed — consent must be granted first |

---

## Quick Reference

| Item | Value |
|------|-------|
| Firebase Console | https://console.firebase.google.com |
| GA4 Dashboard | https://analytics.google.com |
| Bundle ID | `com.regevba.FitTracker` (verify in Xcode) |
| Firebase SPM URL | `https://github.com/firebase/firebase-ios-sdk` |
| Package to add | `FirebaseAnalytics` only |
| Debug flag | `-FIRDebugEnabled` (launch argument) |
| Events until GA4 reports | 24-48 hours |
| Max custom dimensions | 50 event-scoped + 25 user-scoped |
| Max custom metrics | 50 |
| Data retention | 14 months (configurable) |
