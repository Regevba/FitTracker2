# Profile Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild ProfileView as a simplified hybrid — hero card at top + collapsed summary cards for Goals/Training, Account/Data, and Appearance, replacing the current card-heavy layout and eliminating Home duplicates.

**Architecture:** ProfileView becomes a ScrollView with: simplified hero (name + personal details + goal badge), two tappable summary cards (Goals & Training opens GoalEditorSheet, Account & Data pushes to detail view), one single-row appearance picker, sign out button, and minimal about footer. Settings v2 content is absorbed — no more separate Settings sheet.

**Tech Stack:** SwiftUI, existing design system tokens (AppColor, AppText, AppSpacing, AppRadius, AppShadow), existing GoalEditorSheet + SettingsView detail screens.

---

### Task 1: Update ProfileHeroSection — add personal details, remove clutter

**Files:**
- Modify: `FitTracker/Views/Profile/ProfileHeroSection.swift`

- [ ] **Step 1: Update the init parameters**

Remove `email`, `streakDays`, `totalWorkouts`. Add `age`, `heightCm`, `experienceLevel`.

```swift
struct ProfileHeroSection: View {
    let displayName: String
    let age: Int
    let heightCm: Double
    let experienceLevel: ExperienceLevel?
    let fitnessGoal: FitnessGoal?
    let programPhase: ProgramPhase
    let daysSinceStart: Int
    let onGoalTap: () -> Void
    let onAvatarTap: () -> Void
```

- [ ] **Step 2: Rewrite the body — centered avatar, inline details**

Replace the HStack avatar+name layout with a centered VStack:

```swift
var body: some View {
    VStack(spacing: AppSpacing.small) {
        // Avatar
        Button(action: onAvatarTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.Accent.recovery.opacity(0.88), AppColor.Brand.secondary.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Text(initials)
                    .font(AppText.titleStrong)
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Profile picture, \(displayName)")

        // Name
        Text(displayName)
            .font(AppText.titleStrong)
            .foregroundStyle(AppColor.Text.primary)

        // Personal details line
        Text(personalDetailsLine)
            .font(AppText.caption)
            .foregroundStyle(AppColor.Text.secondary)

        // Badges row
        HStack(spacing: AppSpacing.xSmall) {
            if let goal = fitnessGoal {
                Button(action: onGoalTap) {
                    Text(goal.rawValue)
                        .font(AppText.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(AppColor.Accent.primary, in: Capsule())
                }
                .accessibilityLabel("Fitness goal: \(goal.rawValue)")
                .accessibilityHint("Double tap to edit goal")
            }

            Text("\(programPhase.rawValue) · Day \(daysSinceStart)")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xxxSmall)
                .background(AppColor.Surface.secondary, in: Capsule())
        }
    }
    .frame(maxWidth: .infinity)
    .padding(AppSpacing.medium)
    .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
}

private var personalDetailsLine: String {
    var parts: [String] = []
    parts.append("\(age)")
    parts.append("\(Int(heightCm)) cm")
    if let exp = experienceLevel {
        parts.append(exp.rawValue)
    }
    return parts.joined(separator: " · ")
}
```

- [ ] **Step 3: Verify the initials computed property still works (unchanged)**

The existing `initials` property is fine — no changes needed.

- [ ] **Step 4: Build to check compilation**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|BUILD"`

Expected: Build errors in ProfileView.swift (calling site passes old params) — that's expected, we fix it in Task 4.

- [ ] **Step 5: Commit**

```bash
git add FitTracker/Views/Profile/ProfileHeroSection.swift
git commit -m "refactor(profile): simplify hero — centered avatar, add age/height/exp, remove email/stat row"
```

---

### Task 2: Create GoalsTrainingCard — collapsed summary

**Files:**
- Create: `FitTracker/Views/Profile/GoalsTrainingCard.swift`

- [ ] **Step 1: Create the collapsed summary card**

```swift
// FitTracker/Views/Profile/GoalsTrainingCard.swift
import SwiftUI

struct GoalsTrainingCard: View {
    let fitnessGoal: FitnessGoal?
    let targetWeightMin: Double
    let targetWeightMax: Double
    let trainingDaysPerWeek: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                // Colored icon
                Image(systemName: "target")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.achievement)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.achievement.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Goals & Training")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(summaryLine)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Goals and Training")
        .accessibilityValue(summaryLine)
        .accessibilityHint("Double tap to edit")
    }

    private var summaryLine: String {
        let goal = fitnessGoal?.rawValue ?? "Not set"
        let weight = "\(Int(targetWeightMin))–\(Int(targetWeightMax)) kg"
        return "\(goal) · \(weight) · \(trainingDaysPerWeek) days/week"
    }
}
```

- [ ] **Step 2: Add to Xcode project**

Add `GoalsTrainingCard.swift` to the Profile group in `project.pbxproj` (same group as ProfileHeroSection).

- [ ] **Step 3: Commit**

```bash
git add FitTracker/Views/Profile/GoalsTrainingCard.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(profile): add GoalsTrainingCard — collapsed summary with accent color"
```

---

### Task 3: Create AccountDataCard — collapsed summary

**Files:**
- Create: `FitTracker/Views/Profile/AccountDataCard.swift`

- [ ] **Step 1: Create the collapsed summary card**

```swift
// FitTracker/Views/Profile/AccountDataCard.swift
import SwiftUI

struct AccountDataCard: View {
    let signInProvider: String?
    let biometricEnabled: Bool
    let syncStatus: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "lock.shield.fill")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.primary)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Account & Data")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(summaryLine)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account and Data")
        .accessibilityValue(summaryLine)
        .accessibilityHint("Double tap to manage account, sync, and privacy")
    }

    private var summaryLine: String {
        let provider = signInProvider ?? "Not signed in"
        let lock = biometricEnabled ? "Face ID" : "No lock"
        return "\(provider) · \(lock) · \(syncStatus)"
    }
}
```

- [ ] **Step 2: Add to Xcode project**

Add `AccountDataCard.swift` to the Profile group in `project.pbxproj`.

- [ ] **Step 3: Commit**

```bash
git add FitTracker/Views/Profile/AccountDataCard.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(profile): add AccountDataCard — collapsed summary with accent color"
```

---

### Task 4: Rewrite ProfileView — assemble the new layout

**Files:**
- Modify: `FitTracker/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Rewrite ProfileView with new structure**

```swift
// FitTracker/Views/Profile/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var signIn: SignInService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var analytics: AnalyticsService
    @EnvironmentObject var cloudSync: CloudKitSyncService

    @State private var showGoalEditor = false
    @State private var showSettings = false
    @State private var showAppearance = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.medium) {
                        // 1. Hero
                        ProfileHeroSection(
                            displayName: displayName,
                            age: dataStore.userProfile.age,
                            heightCm: dataStore.userProfile.heightCm,
                            experienceLevel: dataStore.userProfile.experienceLevel,
                            fitnessGoal: dataStore.userProfile.fitnessGoal,
                            programPhase: dataStore.userProfile.currentPhase,
                            daysSinceStart: dataStore.userProfile.daysSinceStart,
                            onGoalTap: { showGoalEditor = true },
                            onAvatarTap: { analytics.logProfileAvatarTap() }
                        )

                        // 2. Goals & Training card
                        GoalsTrainingCard(
                            fitnessGoal: dataStore.userProfile.fitnessGoal,
                            targetWeightMin: dataStore.userProfile.targetWeightMin,
                            targetWeightMax: dataStore.userProfile.targetWeightMax,
                            trainingDaysPerWeek: dataStore.userProfile.trainingDaysPerWeek,
                            onTap: {
                                analytics.logProfileSettingsSectionOpened(section: "goals_training")
                                showGoalEditor = true
                            }
                        )

                        // 3. Account & Data card
                        AccountDataCard(
                            signInProvider: signIn.activeSession?.provider,
                            biometricEnabled: settings.requireBiometricUnlockOnReopen,
                            syncStatus: cloudSync.status.rawValue,
                            onTap: {
                                analytics.logProfileSettingsSectionOpened(section: "account_data")
                                showSettings = true
                            }
                        )

                        // 4. Appearance & Units row
                        appearanceRow

                        // 5. Sign Out
                        signOutButton
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.xLarge)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            analytics.logProfileTabViewed(source: "hamburger_menu")
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAppearance) {
            AppearanceUnitsSheet()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task { await signIn.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Appearance Row

    private var appearanceRow: some View {
        Button {
            showAppearance = true
        } label: {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "paintpalette.fill")
                    .font(AppText.titleMedium)
                    .foregroundStyle(AppColor.Accent.sleep)
                    .frame(width: 36, height: 36)
                    .background(AppColor.Accent.sleep.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.small))

                Text("Appearance & Units")
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.primary)

                Spacer(minLength: 0)

                Text(appearanceSummary)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)

                Image(systemName: "chevron.right")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
            }
            .padding(AppSpacing.medium)
            .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Appearance and Units")
        .accessibilityValue(appearanceSummary)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            Text("Sign Out")
                .font(AppText.body)
                .foregroundStyle(AppColor.Status.error)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.medium)
                .background(AppColor.Surface.primary, in: RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign out")
        .accessibilityHint("Double tap to confirm sign out")
    }

    // MARK: - About Footer

    private var aboutFooter: some View {
        VStack(spacing: AppSpacing.xxxSmall) {
            Text("FitMe v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
            // Terms · Privacy · Support links added when URLs are available
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.small)
    }

    // MARK: - Helpers

    private var displayName: String {
        if let dn = dataStore.userProfile.displayName { return dn }
        if let sn = signIn.activeSession?.displayName { return sn }
        let name = dataStore.userProfile.name
        return name.isEmpty ? "FitMe User" : name
    }

    private var appearanceSummary: String {
        let theme = settings.appearanceMode.rawValue
        let units = settings.unitSystem.rawValue
        return "\(theme) · \(units)"
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|BUILD"`

Expected: May fail on `AppearanceUnitsSheet` (not yet created) or `settings.appearanceMode` / `settings.unitSystem` (need to verify property names). Fix any compilation errors.

- [ ] **Step 3: Commit**

```bash
git add FitTracker/Views/Profile/ProfileView.swift
git commit -m "refactor(profile): rewrite ProfileView — hero + 2 summary cards + appearance row + sign out"
```

---

### Task 5: Create AppearanceUnitsSheet

**Files:**
- Create: `FitTracker/Views/Profile/AppearanceUnitsSheet.swift`

- [ ] **Step 1: Create the sheet**

```swift
// FitTracker/Views/Profile/AppearanceUnitsSheet.swift
import SwiftUI

struct AppearanceUnitsSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Units") {
                    Picker("Unit System", selection: $settings.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.rawValue).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Appearance & Units")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

Note: Verify the exact enum names (`AppearanceMode`, `UnitSystem`) by checking `AppSettings.swift`. Adjust if they differ.

- [ ] **Step 2: Add to Xcode project**

Add `AppearanceUnitsSheet.swift` to the Profile group in `project.pbxproj`.

- [ ] **Step 3: Build + verify**

Run full build. Fix any mismatched property names.

- [ ] **Step 4: Commit**

```bash
git add FitTracker/Views/Profile/AppearanceUnitsSheet.swift FitTracker.xcodeproj/project.pbxproj
git commit -m "feat(profile): add AppearanceUnitsSheet — theme + units picker"
```

---

### Task 6: Remove unused ProfileBodyCompCard import from ProfileView

**Files:**
- Verify: `FitTracker/Views/Profile/ProfileView.swift` no longer references `ProfileBodyCompCard`
- Verify: `ProfileBodyCompCard.swift` stays in the build target (still used by Home BodyCompositionDetailView or other views)

- [ ] **Step 1: Grep for ProfileBodyCompCard references**

Run: `grep -rn "ProfileBodyCompCard" FitTracker/Views/Profile/ProfileView.swift`

Expected: No matches (we removed it in Task 4).

- [ ] **Step 2: Verify ProfileBodyCompCard is still used elsewhere**

Run: `grep -rn "ProfileBodyCompCard" FitTracker/`

Expected: Should still appear in at least one other file. If not, consider removing from build target.

- [ ] **Step 3: Remove AIOrchestrator dependency from ProfileView**

ProfileView no longer uses `AIInsightCard`, so the `@EnvironmentObject var aiOrchestrator: AIOrchestrator` can be removed if present.

- [ ] **Step 4: Build + verify**

Run full build. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add FitTracker/Views/Profile/ProfileView.swift
git commit -m "chore(profile): remove unused ProfileBodyCompCard + AIOrchestrator deps"
```

---

### Task 7: Update ProfileEvals for new hero parameters

**Files:**
- Modify: `FitTrackerTests/EvalTests/ProfileEvals.swift`

- [ ] **Step 1: Update any tests that reference old ProfileHeroSection parameters**

Check if any eval tests instantiate `ProfileHeroSection` directly. If so, update parameters to match new signature (remove `email`, `streakDays`, `totalWorkouts`; add `age`, `heightCm`, `experienceLevel`).

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:FitTrackerTests/ProfileEvals -derivedDataPath .build/TestDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "Test.*passed|Test.*failed|error:"`

Expected: All pass.

- [ ] **Step 3: Commit**

```bash
git add FitTrackerTests/EvalTests/ProfileEvals.swift
git commit -m "test(profile): update ProfileEvals for new hero parameters"
```

---

### Task 8: Full build + verification

- [ ] **Step 1: Full iOS build**

Run: `xcodebuild build -project FitTracker.xcodeproj -scheme FitTracker -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -project FitTracker.xcodeproj -scheme FitTracker -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .build/TestDerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | grep -E "Test Suite.*passed|Test Suite.*failed|Executed"`

Expected: All tests pass (197+).

- [ ] **Step 3: Dashboard build + tests**

Run: `cd dashboard && npm run build && npx vitest run`

Expected: Build succeeds, 35 tests pass.

- [ ] **Step 4: Final commit + push**

```bash
git add -A
git commit -m "feat(profile): complete v3 redesign — simplified hero + summary cards + merged settings

Profile redesign per spec (docs/superpowers/specs/2026-04-15-profile-redesign-design.md):
- Hero: centered avatar, name, age/height/experience, goal badge, phase
- Goals & Training: collapsed summary card, tap → GoalEditorSheet
- Account & Data: collapsed summary card, tap → SettingsView
- Appearance & Units: single row, tap → picker sheet
- Sign Out + About footer

Cut: readiness card, body comp card, AI insight card (Home duplicates),
email in hero, stat row, meal slots, notifications (deferred).
Section colors: achievement (goals), primary (account), sleep (appearance).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```
