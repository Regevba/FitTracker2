// Services/AuthManager.swift
// Biometric lock AFTER sign-in — Face ID / Touch ID / Passcode
// Separate from SignInService (social/passkey auth)
// Also houses TrainingProgramStore

import Foundation
import LocalAuthentication
import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Biometric Lock Manager
// ─────────────────────────────────────────────────────────

@MainActor
final class AuthManager: ObservableObject {

    @Published var isAuthenticated = false
    @Published var authError: String?

    init() { authenticate() }

    func authenticate() {
        let ctx = LAContext()
        var err: NSError?

        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock FitTracker to access your encrypted health data") { ok, e in
                DispatchQueue.main.async {
                    self.isAuthenticated = ok
                    self.authError = ok ? nil : e?.localizedDescription
                }
            }
        } else {
            // Simulator / no biometrics
            isAuthenticated = true
        }
    }

    func lockOnBackground() {
        isAuthenticated = false
        authError = nil
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Biometric lock screen (shown after sign-in)
// ─────────────────────────────────────────────────────────

struct LockScreenView: View {

    @EnvironmentObject var auth: AuthManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)

                VStack(spacing: 8) {
                    Text("FitTracker")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Your health data is encrypted\nand protected on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button { auth.authenticate() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid").font(.title3)
                            Text("Unlock with Face ID").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 32)

                    if let err = auth.authError {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Training Program Store
// ─────────────────────────────────────────────────────────

@MainActor
final class TrainingProgramStore: ObservableObject {

    @Published var todayDayType: DayType = .restDay

    init() { detectToday() }

    func detectToday() {
        let wd = Calendar.current.component(.weekday, from: Date())
        todayDayType = switch wd {
        case 2: .upperPush
        case 3: .lowerBody
        case 5: .upperPull
        case 6: .fullBody
        case 7: .cardioOnly
        default: .restDay
        }
    }

    func exercises(for day: DayType) -> [ExerciseDefinition] {
        TrainingProgramData.exercises(for: day)
    }
}
