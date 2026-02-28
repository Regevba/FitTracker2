// Views/Auth/AccountPanelView.swift
// Slide-out panel from the top-right account button.
// Sections:
//   1. Account  — avatar / name / email / phone
//   2. Settings — units (metric ↔ imperial) + appearance (light/dark/system)
//   3. Sign Out

import SwiftUI

struct AccountPanelView: View {

    @EnvironmentObject var signIn:    SignInService
    @EnvironmentObject var settings:  AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var editingName  = false
    @State private var editingPhone = false
    @State private var nameText:    String = ""
    @State private var phoneText:   String = ""
    @State private var showLogoutConfirm = false
    @State private var expandAccount  = true
    @State private var expandSettings = false

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
                            Text(session?.displayName ?? "Regev")
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

                    // Name (editable placeholder)
                    LabeledContent("Name") {
                        if editingName {
                            TextField("Your name", text: $nameText,
                                      onCommit: { editingName = false })
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .submitLabel(.done)
                        } else {
                            Button {
                                nameText = session?.displayName ?? "Regev"
                                editingName = true
                            } label: {
                                Text(session?.displayName ?? "—")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Email
                    LabeledContent("Email") {
                        Text(session?.email ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    // Phone (editable placeholder)
                    LabeledContent("Phone") {
                        if editingPhone {
                            TextField("+972 XX XXX XXXX", text: $phoneText,
                                      onCommit: { editingPhone = false })
                                .multilineTextAlignment(.trailing)
                                .font(.subheadline)
                                .keyboardType(.phonePad)
                        } else {
                            Button {
                                phoneText = session?.phone ?? ""
                                editingPhone = true
                            } label: {
                                Text(session?.phone.map { $0 } ?? "Add phone number")
                                    .font(.subheadline)
                                    .foregroundStyle(session?.phone != nil ? Color.secondary : Color.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }

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
                // MARK: SETTINGS section
                // ─────────────────────────────────────────
                Section {

                    // Unit system
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Units", systemImage: "ruler")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 8) {
                            ForEach(UnitSystem.allCases, id: \.self) { system in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        settings.unitSystem = system
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(system.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                        Text(system == .metric ? "kg · cm · km" : "lbs · in · mi")
                                            .font(.system(size: 10))
                                            .opacity(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(settings.unitSystem == system ? .black : .primary)
                                    .background(
                                        settings.unitSystem == system
                                            ? Color.green
                                            : Color.secondary.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Appearance
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Appearance", systemImage: "paintpalette")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 8) {
                            ForEach(AppAppearance.allCases, id: \.self) { mode in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        settings.appearance = mode
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: mode.icon)
                                            .font(.title3)
                                        Text(mode.rawValue)
                                            .font(.caption2.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(settings.appearance == mode ? .black : .primary)
                                    .background(
                                        settings.appearance == mode
                                            ? Color.green
                                            : Color.secondary.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                } header: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
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

            Text(session?.initials ?? "R")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.black)
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
