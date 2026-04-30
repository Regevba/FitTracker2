// FitTrackerApp.swift
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+
// Entry point — wires all services, drives auth state machine

import SwiftUI
import FirebaseCore

// AI engine base URL — override via Info.plist key "AIEngineBaseURL" for staging/prod
private func makeAIEngineBaseURL() -> URL {
    let plistValue = Bundle.main.object(forInfoDictionaryKey: "AIEngineBaseURL") as? String ?? ""
    let urlString = plistValue.isEmpty ? "https://fittracker-ai-production.up.railway.app" : plistValue
    guard let url = URL(string: urlString) else {
        // Fallback to hardcoded default — only reachable if Info.plist value is malformed
        guard let fallback = URL(string: "https://fittracker-ai-production.up.railway.app") else {
            fatalError("Hardcoded AI engine URL is invalid — infrastructure error")
        }
        return fallback
    }
    return url
}

private var isScreenReviewModeEnabled: Bool {
    ["authenticated", "settings"].contains(
        ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_AUTH"]?.lowercased()
    )
}

private var isSettingsReviewModeEnabled: Bool {
    ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_AUTH"]?.lowercased() == "settings"
        || ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_SETTINGS"] == "1"
        || ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_TAB"]?.lowercased() == "settings"
        || ProcessInfo.processInfo.arguments.contains("--review-settings")
}

private var isForcedOnboardingModeEnabled: Bool {
    ProcessInfo.processInfo.environment["FITTRACKER_FORCE_ONBOARDING"] == "1"
}

// auth-polish-v2 D3 — UI test fixtures that mount the new auth screens
// directly so XCUITest can drive them without needing a real sign-in
// round-trip. Only consumed by the rootView + onAppear branches below.
private var isBiometricActivationReviewModeEnabled: Bool {
    ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_BIOMETRIC_OFFER"] == "1"
}

private var isBiometricLockReviewModeEnabled: Bool {
    ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_BIOMETRIC_LOCK"] == "1"
}

@main
struct FitTrackerApp: App {

    // ── Services (owned here, passed down as EnvironmentObjects)
    @StateObject private var signIn        = SignInService()
    @StateObject private var biometricAuth = AuthManager()
    @StateObject private var healthService = HealthKitService()
    @StateObject private var dataStore     = EncryptedDataStore()
    @StateObject private var cloudSync     = CloudKitSyncService()
    @StateObject private var supabaseSync  = SupabaseSyncService()
    @StateObject private var programStore  = TrainingProgramStore()
    @StateObject private var settings      = AppSettings()
    @StateObject private var watchService  = WatchConnectivityService()
    @StateObject private var analytics     = AnalyticsService.makeDefault()
    @State private var hasRestoredSession = false
    @State private var hasAppliedReviewFixtures = false
    @State private var showBiometricActivation = false
    @StateObject private var aiOrchestrator: AIOrchestrator = {
        let client: any AIEngineClientProtocol = AIEngineClient(baseURL: makeAIEngineBaseURL())
        let foundationModel: any FoundationModelProtocol = {
            if #available(iOS 26, *) {
                return FoundationModelService()
            } else {
                return FallbackFoundationModel()
            }
        }()
        return AIOrchestrator(
            engineClient:    client,
            foundationModel: foundationModel,
            snapshot: {
                #if DEBUG
                print("[AIOrchestrator] WARNING: Using empty fallback snapshot — caller should pass overrideSnapshot")
                #endif
                return LocalUserSnapshot()
            },
            goalMode: {
                // Default at init time. Updated to actual user preference
                // when dataStore.loadFromDisk() completes in onChange(.active).
                .fatLoss
            }
        )
    }()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        if AnalyticsRuntimeConfiguration.canUseFirebase {
            FirebaseApp.configure()
        }
        #if DEBUG
        ColorContrastValidator.validate()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootView
                // Apply appearance preference from settings
                .preferredColorScheme(settings.appearance.colorScheme)
                .task {
                    applyReviewFixturesIfNeeded()
                    if isBiometricActivationReviewModeEnabled {
                        // D3 fixture — surface BiometricActivationSheet on
                        // first frame so UI tests can assert + screenshot.
                        showBiometricActivation = true
                    }
                }
                .onChange(of: signIn.activeSession) { _, session in
                    if session != nil {
                        Task {
                            guard !isScreenReviewModeEnabled else { return }
                            await dataStore.loadFromDisk()
                            if scenePhase == .active {
                                await cloudSync.fetchChanges(dataStore: dataStore)
                                // First login on a new device — pull all records from Supabase
                                await supabaseSync.fetchAllRecords(dataStore: dataStore)
                                await supabaseSync.subscribeRealtime(dataStore: dataStore)
                            }
                            let jwt = signIn.activeSession?.backendAccessToken
                            await aiOrchestrator.processAll(jwt: jwt, snapshot: buildSnapshot())
                        }
                        // auth-polish-v2 B3 — first sign-in on this install gets
                        // the BiometricActivationSheet. Predicate gates on
                        // device support + the two AppSettings flags.
                        if biometricAuth.shouldOfferActivation(settings: settings) {
                            showBiometricActivation = true
                        }
                    } else {
                        // Session cleared (sign-out or lock) — wipe all in-memory sensitive state
                        Task {
                            dataStore.clearInMemory()
                            aiOrchestrator.clearRecommendations()
                            await EncryptionService.shared.clearSessionContext()
                        }
                    }
                }
                .onChange(of: biometricAuth.isAuthenticated) { _, unlocked in
                    // Biometric lock screen succeeded — resume the stored session
                    if unlocked { signIn.resumeStoredSession() }
                }
                .onOpenURL { url in
                    // Deep-link return for forgot-password flow (auth-polish-v2 A1+A4).
                    // URL scheme `fitme://reset-password?...` is registered in
                    // Info.plist (CFBundleURLTypes/PasswordReset). The async call
                    // exchanges the URL for a Supabase recovery session and then
                    // sets `pendingPasswordResetURL`, which the .fullScreenCover
                    // below observes to present SetNewPasswordView.
                    Task { await signIn.handleIncomingURL(url) }
                }
                .fullScreenCover(isPresented: Binding(
                    get: { signIn.pendingPasswordResetURL != nil },
                    set: { if !$0 { signIn.pendingPasswordResetURL = nil } }
                )) {
                    // auth-polish-v2 A4 — present at the app entry so the cover
                    // works from any auth state (onboarding, lock, app).
                    SetNewPasswordView {
                        signIn.pendingPasswordResetURL = nil
                    }
                    .environmentObject(signIn)
                    .environmentObject(analytics)
                }
                .sheet(isPresented: $showBiometricActivation) {
                    // auth-polish-v2 B3 — one-time post-sign-in offer. Predicate
                    // gating in `onChange(of: signIn.activeSession)` ensures
                    // this only triggers when shouldOfferActivation is true.
                    BiometricActivationSheet(
                        onEnable: {
                            await biometricAuth.requestActivation(settings: settings)
                        },
                        onDecline: {
                            settings.hasAskedForBiometricActivation = true
                            showBiometricActivation = false
                        }
                    )
                    .environmentObject(biometricAuth)
                    .environmentObject(signIn)
                    .environmentObject(analytics)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard !isScreenReviewModeEnabled else { return }
                    switch phase {
                    case .active:
                        Task {
                            // Only restore session once at launch — not on every .active transition
                            if !hasRestoredSession {
                                hasRestoredSession = true
                                await signIn.restoreSession(
                                    activateStoredSession: !settings.requireBiometricUnlockOnReopen
                                )
                            }
                            // Check if a clear-crypto flag was set before a potential OS kill
                            if UserDefaults.standard.bool(forKey: "ft.clearCryptoOnNextLaunch") {
                                UserDefaults.standard.removeObject(forKey: "ft.clearCryptoOnNextLaunch")
                                await EncryptionService.shared.clearSessionContext()
                            }
                            guard signIn.isAuthenticated else { return }
                            // Audit BE-016: if a previous persistToDisk failed, retry on foreground
                            // before any further reads/writes — recovers transient disk-pressure cases.
                            await dataStore.retryPersistIfFailed()
                            await dataStore.loadFromDisk()
                            // Update AI engine with actual user goal (was default .fatLoss at init)
                            aiOrchestrator.goalMode = { [weak dataStore] in
                                dataStore?.userPreferences.nutritionGoalMode ?? .fatLoss
                            }
                            // Ensure ReminderScheduler is initialised — actual trigger
                            // evaluation happens in MainScreenView when data is available.
                            _ = ReminderScheduler.shared
                            // CloudKit (unchanged)
                            await cloudSync.fetchChanges(dataStore: dataStore)
                            // Supabase — incremental pull + realtime subscription
                            await supabaseSync.fetchChanges(dataStore: dataStore)
                            await supabaseSync.subscribeRealtime(dataStore: dataStore)
                        }
                    case .background:
                        if settings.requireBiometricUnlockOnReopen {
                            signIn.lockForReopen()
                            biometricAuth.lockOnBackground(clearCryptoSession: false)
                            // Write flag synchronously so crypto context is cleared on next
                            // launch even if OS kills the app before the async Task completes
                            UserDefaults.standard.set(true, forKey: "ft.clearCryptoOnNextLaunch")
                        }
                        Task {
                            await dataStore.persistToDisk()
                            // CloudKit (unchanged)
                            await cloudSync.pushPendingChanges(dataStore: dataStore)
                            // Supabase — unsubscribe realtime, push pending
                            await supabaseSync.unsubscribeRealtime()
                            if signIn.isAuthenticated {
                                await supabaseSync.pushPendingChanges(dataStore: dataStore)
                            }
                            if settings.requireBiometricUnlockOnReopen {
                                await EncryptionService.shared.clearSessionContext()
                            }
                        }
                    case .inactive: break
                    @unknown default: break
                    }
                }
        }

        #if os(macOS)
            Settings {
                SettingsView()
                    .environmentObject(signIn)
                    .environmentObject(biometricAuth)
                    .environmentObject(dataStore)
                    .environmentObject(healthService)
                    .environmentObject(cloudSync)
                    .environmentObject(supabaseSync)
                    .environmentObject(settings)
                    .environmentObject(watchService)
                    .environmentObject(analytics)
        }
        #endif
    }

    private func buildSnapshot() -> LocalUserSnapshot {
        // Build snapshot with readiness data. Audit DEEP-AI-007: also wire the
        // adapter list into AIOrchestrator so `lastAdapters` is populated for
        // the validation evidence chain — previously the adapters were built
        // here and silently discarded.
        let readiness = dataStore.readinessResult(for: Date(), fallbackMetrics: healthService.latest)
        let (snapshot, adapters) = AISnapshotBuilder.build(
            profile: dataStore.userProfile,
            preferences: dataStore.userPreferences,
            liveMetrics: healthService.latest,
            dailyLogs: dataStore.dailyLogs,
            todayDayType: programStore.todayDayType,
            readiness: readiness
        )
        aiOrchestrator.setAdapters(adapters)
        return snapshot
    }

    private var reviewDatasetName: String? {
        guard isScreenReviewModeEnabled else { return nil }
        let rawValue = ProcessInfo.processInfo.environment["FITTRACKER_REVIEW_DATASET"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue?.isEmpty == false ? rawValue : "demo"
    }

    @MainActor
    private func applyReviewFixturesIfNeeded() {
        guard let reviewDatasetName, !hasAppliedReviewFixtures else { return }
        guard reviewDatasetName == "demo" else { return }

        hasAppliedReviewFixtures = true
        dataStore.applyReviewSeedData(named: reviewDatasetName, referenceDate: Date())
        settings.unitSystem = .metric
        settings.appearance = .light
        settings.requireBiometricUnlockOnReopen = false
        analytics.consent.grantConsent()
        analytics.syncConsentToProvider()
        watchService.status = .connected
        healthService.isAuthorized = true
        healthService.lastSyncDate = Date()
        healthService.latest = LiveMetrics(
            heartRate: 72,
            restingHR: 58,
            hrv: 43,
            vo2Max: 41.8,
            weightKg: 67.2,
            bodyFatPct: 0.182,
            leanMassKg: 55.0,
            stepCount: 12_487,
            activeCalories: 689,
            sleepHours: 7.8,
            deepSleepMin: 94,
            remSleepMin: 107,
            lastUpdated: Date()
        )
    }

    // ── Onboarding guard ─────────────────────────────────
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // ── Auth state machine ────────────────────────────────
    // onboarding (includes auth at step 5) → authenticated → biometricLock → app
    // Auth is embedded in onboarding — no separate AuthHubView.
    @ViewBuilder
    private var rootView: some View {
        if isScreenReviewModeEnabled, isSettingsReviewModeEnabled {
            SettingsView()
                .analyticsScreen(AnalyticsScreen.settings)
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(healthService)
                .environmentObject(dataStore)
                .environmentObject(cloudSync)
                .environmentObject(supabaseSync)
                .environmentObject(programStore)
                .environmentObject(settings)
                .environmentObject(watchService)
                .environmentObject(aiOrchestrator)
                .environmentObject(analytics)
        } else if (!hasCompletedOnboarding || isForcedOnboardingModeEnabled), !isScreenReviewModeEnabled {
            // First launch or sign-in smoke override — onboarding includes auth at step 5.
            OnboardingView {
                analytics.setOnboardingCompleted(true)
            }
            .environmentObject(healthService)
            .environmentObject(signIn)
            .environmentObject(analytics)
            .environmentObject(dataStore)
        } else if (signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen) || isBiometricLockReviewModeEnabled {
            // Session exists but was locked for reopen — require biometric to resume.
            // auth-polish-v2 B3 — replaces inline LockScreenView with the
            // foundations-aligned BiometricUnlockView per FR-7..8 + ux-spec §5.5.
            // D3 fixture — FITTRACKER_REVIEW_BIOMETRIC_LOCK=1 surfaces this view
            // unconditionally so UI tests can assert + screenshot it.
            BiometricUnlockView()
                .environmentObject(biometricAuth)
                .environmentObject(signIn)
                .environmentObject(analytics)
        } else {
            // Onboarding complete — show the app (user may be authenticated or guest)
            if analytics.consent.gdprConsent == .pending {
                ConsentView {
                    analytics.syncConsentToProvider()
                }
                .environmentObject(analytics)
            } else {
                RootTabView()
                    .environmentObject(signIn)
                    .environmentObject(biometricAuth)
                    .environmentObject(healthService)
                    .environmentObject(dataStore)
                    .environmentObject(cloudSync)
                    .environmentObject(supabaseSync)
                    .environmentObject(programStore)
                    .environmentObject(settings)
                    .environmentObject(watchService)
                    .environmentObject(aiOrchestrator)
                    .environmentObject(analytics)
            }
        }
    }
}
