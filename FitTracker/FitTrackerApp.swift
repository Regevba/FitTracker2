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
                // Fallback snapshot — used when process(segment:) is called
                // without an explicit overrideSnapshot. Returns empty snapshot
                // rather than crashing. The primary path (processAll in
                // onChange(of: signIn.activeSession)) always passes
                // overrideSnapshot via buildSnapshot(), so this fallback
                // should rarely execute. If it does, the AI engine will
                // produce localFallback recommendations (safe degradation).
                #if DEBUG
                print("[AIOrchestrator] WARNING: Using empty fallback snapshot — caller should pass overrideSnapshot")
                #endif
                return LocalUserSnapshot()
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
                .onChange(of: scenePhase) { _, phase in
                    guard !isScreenReviewModeEnabled else { return }
                    switch phase {
                    case .active:
                        Task {
                            await signIn.restoreSession(
                                activateStoredSession: !settings.requireBiometricUnlockOnReopen
                            )
                            // Check if a clear-crypto flag was set before a potential OS kill
                            if UserDefaults.standard.bool(forKey: "ft.clearCryptoOnNextLaunch") {
                                UserDefaults.standard.removeObject(forKey: "ft.clearCryptoOnNextLaunch")
                                await EncryptionService.shared.clearSessionContext()
                            }
                            guard signIn.isAuthenticated else { return }
                            await dataStore.loadFromDisk()
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
        // Build snapshot with readiness data
        let readiness = dataStore.readinessResult(for: Date(), fallbackMetrics: healthService.latest)
        return AISnapshotBuilder.build(
            profile: dataStore.userProfile,
            preferences: dataStore.userPreferences,
            liveMetrics: healthService.latest,
            dailyLogs: dataStore.dailyLogs,
            todayDayType: programStore.todayDayType,
            readiness: readiness
        )
    }

    // ── Onboarding guard ─────────────────────────────────
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // ── Auth state machine ────────────────────────────────
    // onboarding (first launch) → welcome → signIn (sheet) → authenticated → biometricLock → app
    @ViewBuilder
    private var rootView: some View {
        if !hasCompletedOnboarding, !isScreenReviewModeEnabled {
            OnboardingView {
                analytics.setOnboardingCompleted(true)
            }
            .environmentObject(healthService)
            .environmentObject(analytics)
        } else if isScreenReviewModeEnabled, isSettingsReviewModeEnabled {
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
        } else if signIn.isAuthenticated {
            if analytics.consent.gdprConsent == .pending && hasCompletedOnboarding {
                // Fallback: user completed onboarding before consent was added,
                // or consent state was reset. Show standalone consent screen.
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
        } else if signIn.hasStoredSession && settings.requireBiometricUnlockOnReopen {
            // Session exists but was locked for reopen — require biometric to resume
            LockScreenView()
                .environmentObject(biometricAuth)
        } else {
            AuthHubView()
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(settings)
                .environmentObject(analytics)
                .analyticsScreen(AnalyticsScreen.signIn)
        }
    }
}
