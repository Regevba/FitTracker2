// FitTrackerApp.swift
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+
// Entry point — wires all services, drives auth state machine

import SwiftUI
import HealthKit
import CloudKit

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
                // Load encrypted data after biometric auth — EncryptionService has a valid
                // session context at this point, so no extra biometric prompts fire.
                .onChange(of: biometricAuth.isAuthenticated) { _, authenticated in
                    if authenticated {
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
                        guard biometricAuth.isAuthenticated else { break }
                        Task { await cloudSync.fetchChanges(dataStore: dataStore) }
                    case .background:
                        biometricAuth.lockOnBackground(clearCryptoSession: false)
                        Task {
                            await dataStore.persistToDisk()
                            await cloudSync.pushPendingChanges(dataStore: dataStore)
                            await EncryptionService.shared.clearSessionContext()
                        }
                    case .inactive: break
                    @unknown default: break
                    }
                }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(dataStore)
                .environmentObject(healthService)
                .environmentObject(cloudSync)
                .environmentObject(settings)
        }
        #endif
    }

    // ── Auth state machine ────────────────────────────────
    // welcome → signIn (sheet) → authenticated → biometricLock → app
    @ViewBuilder
    private var rootView: some View {
        switch signIn.state {

        case .welcome, .signIn, .error:
            // Not yet signed in → show welcome / sign-in flow
            WelcomeView()
                .environmentObject(signIn)

        case .authenticated:
            // Signed in → check biometric lock
            if !biometricAuth.isAuthenticated {
                LockScreenView()
                    .environmentObject(biometricAuth)
            } else {
                RootTabView()
                    .environmentObject(signIn)
                    .environmentObject(biometricAuth)
                    .environmentObject(healthService)
                    .environmentObject(dataStore)
                    .environmentObject(cloudSync)
                    .environmentObject(programStore)
                    .environmentObject(settings)
                    .environmentObject(watchService)
            }
        }
    }
}
