// FitTrackerApp.swift
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+
// Entry point — wires all services, drives auth state machine

import SwiftUI

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
        } else {
            AuthHubView()
                .environmentObject(signIn)
                .environmentObject(biometricAuth)
                .environmentObject(settings)
        }
    }
}
