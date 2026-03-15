// Views/Auth/AccountPanelView.swift
// Slide-out panel from the top-right account button.
// Structure:
//   1. Profile card  — avatar / name / email / phone / sign-in provider
//   2. Settings      — button that opens SettingsView as a sheet
//   3. Sign Out

import SwiftUI

struct AccountPanelView: View {

    @EnvironmentObject var signIn:    SignInService
    @EnvironmentObject var settings:  AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var showLogoutConfirm = false
    @State private var showSettings = false

    private var session: UserSession? { signIn.currentSession }

    var body: some View {
        NavigationStack {
            List {

                // ─────────────────────────────────────────
                // MARK: ACCOUNT section
                // ─────────────────────────────────────────
                Section {
                    // Avatar + identity row
                    HStack(spacing: 16) {
                        avatarView
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session?.displayName ?? "User")
                                .font(.headline)
                            HStack(spacing: 6) {
                                providerBadge
                                Text(session?.provider.rawValue ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)

                    // Name
                    LabeledContent("Name") {
                        Text(session?.displayName ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Email
                    LabeledContent("Email") {
                        Text(session?.email ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    // Phone
                    LabeledContent("Phone") {
                        Text(session?.phone ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Account details are sourced from your active sign-in provider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Sign-in method chip
                    if session?.provider == .passkey {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.caption).foregroundStyle(.purple)
                            Text("Secured with Passkey / Hardware Key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                } header: {
                    Label("Account", systemImage: "person.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }

                // ─────────────────────────────────────────
                // MARK: SETTINGS button
                // ─────────────────────────────────────────
                Section {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }

                // ─────────────────────────────────────────
                // MARK: SIGN OUT
                // ─────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline)
                            Text("Sign Out")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
            .alert("Sign Out?", isPresented: $showLogoutConfirm) {
                Button("Sign Out", role: .destructive) {
                    signIn.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be returned to the welcome screen. Your encrypted data remains safely stored on this device and in iCloud.")
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
                    .presentationDetents([.large])
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: Sub-components
    // ─────────────────────────────────────────────────────

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [.green.opacity(0.8), .mint.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)

            Text(session?.initials ?? "—")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var providerBadge: some View {
        let provider = session?.provider ?? .apple
        HStack(spacing: 3) {
            Image(systemName: providerIcon(provider))
                .font(.system(size: 9, weight: .semibold))
            Text(provider.rawValue)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(providerColor(provider).opacity(0.12), in: Capsule())
        .foregroundStyle(providerColor(provider))
    }

    private func providerIcon(_ p: AuthProvider) -> String {
        switch p {
        case .apple:    "apple.logo"
        case .google:   "globe"
        case .facebook: "person.2.fill"
        case .passkey:  "key.fill"
        }
    }

    private func providerColor(_ p: AuthProvider) -> Color {
        switch p {
        case .apple:    .primary
        case .google:   Color(red: 0.26, green: 0.52, blue: 0.96)
        case .facebook: Color(red: 0.23, green: 0.35, blue: 0.60)
        case .passkey:  .purple
        }
    }
}
