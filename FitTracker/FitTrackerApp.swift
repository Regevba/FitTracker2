// FitTrackerApp.swift
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+
// Entry point — wires all services, drives auth state machine

import SwiftUI

// AI engine base URL — override via Info.plist key "AIEngineBaseURL" for staging/prod
private func makeAIEngineBaseURL() -> URL {
    let plistValue = Bundle.main.object(forInfoDictionaryKey: "AIEngineBaseURL") as? String ?? ""
    let urlString = plistValue.isEmpty ? "https://fittracker-ai-production.up.railway.app" : plistValue
    guard let url = URL(string: urlString) else {
        // Fallback to hardcoded default — only reachable if Info.plist value is malformed
        return URL(string: "https://fittracker-ai-production.up.railway.app")!
    }
    return url
}

@main
struct FitTrackerApp: App {

    // ── Services (owned here, passed down as EnvironmentObjects)
    @StateObject private var signIn        = SignInService()
    @StateObject private var biometricAuth = AuthManager()
    @StateObject private var healthService = HealthKitService()
    @StateObject private var dataStore     = EncryptedDataStore()
    @StateObject private var cloudSync     = CloudKitSyncService()
    @StateObject private var programStore  = TrainingProgramStore()
    @StateObject private var settings      = AppSettings()
    @StateObject private var watchService  = WatchConnectivityService()
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
            snapshot:        { LocalUserSnapshot() }
        )
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
                // Apply appearance preference from settings
                .preferredColorScheme(settings.appearance.colorScheme)
                .onChange(of: signIn.activeSession) { _, session in
                    if session != nil {
                        Task {
                            await dataStore.loadFromDisk()
                            if scenePhase == .active {
                                await cloudSync.fetchChanges(dataStore: dataStore)
                            }
                            // Kick off AI insight refresh for all segments on sign-in.
                            // JWT from the active session token (Supabase JWT).
                            let jwt = signIn.activeSession?.sessionToken
                            await aiOrchestrator.processAll(jwt: jwt, snapshot: buildSnapshot())
                        }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        signIn.restoreSession()
                        guard signIn.isAuthenticated else { break }
                        Task {
                            await dataStore.loadFromDisk()
                            await cloudSync.fetchChanges(dataStore: dataStore)
                        }
                    case .background:
                        if settings.requireBiometricUnlockOnReopen {
                            signIn.lockForReopen()
                            biometricAuth.lockOnBackground(clearCryptoSession: false)
                        }
                        Task {
                            await dataStore.persistToDisk()
                            await cloudSync.pushPendingChanges(dataStore: dataStore)
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
                    .environmentObject(settings)
                    .environmentObject(watchService)
        }
        #endif
    }

    // ── AI snapshot builder ───────────────────────────────
    // Populates the fields we can derive from existing stores.
    // HealthKit metrics and full profile fields will be added here
    // once the profile/onboarding screen is implemented.
    private func buildSnapshot() -> LocalUserSnapshot {
        var snap = LocalUserSnapshot()
        snap.programPhase = programStore.todayDayType.aiProgramPhase
        return snap
    }

    // ── Auth state machine ────────────────────────────────
    // welcome → signIn (sheet) → authenticated → biometricLock → app
    @ViewBuilder
    private var rootView: some View {
        if signIn.isAuthenticated {
            RootTabView()
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(healthService)
                .environmentObject(dataStore)
                .environmentObject(cloudSync)
                .environmentObject(programStore)
                .environmentObject(settings)
                .environmentObject(watchService)
                .environmentObject(aiOrchestrator)
        } else {
            AuthHubView()
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(settings)
        }
    }
}
