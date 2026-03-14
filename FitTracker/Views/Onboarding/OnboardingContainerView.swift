// Views/Onboarding/OnboardingContainerView.swift
// First-launch guided setup: profile, goals, HealthKit permissions
// Shown once, then AppSettings.hasCompletedOnboarding = true

import SwiftUI
import PhotosUI

struct OnboardingContainerView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var settings: AppSettings

    @State private var page = 0
    @State private var profileName     = ""
    @State private var profileAge      = ""
    @State private var profileHeight   = ""
    @State private var targetWeightMin = ""
    @State private var targetWeightMax = ""
    @State private var targetBFMin     = ""
    @State private var targetBFMax     = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    @State private var healthRequested = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [
                Color(red: 0.04, green: 0.08, blue: 0.06),
                Color(red: 0.06, green: 0.14, blue: 0.10),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i <= page ? Color.green : Color.white.opacity(0.2))
                            .frame(width: i == page ? 24 : 8, height: 6)
                            .animation(.spring(response: 0.4), value: page)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Page content
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    profilePage.tag(1)
                    goalsPage.tag(2)
                    healthKitPage.tag(3)
                    completePage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                // Navigation buttons
                HStack(spacing: 16) {
                    if page > 0 {
                        Button("Back") { withAnimation { page -= 1 } }
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                    }
                    Spacer()
                    Button(page == totalPages - 1 ? "Get Started" : "Continue") {
                        if page == totalPages - 1 {
                            finishOnboarding()
                        } else {
                            withAnimation { page += 1 }
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.green, Color(red: 0.2, green: 0.85, blue: 0.5)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .shadow(color: .green.opacity(0.35), radius: 8, y: 3)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .padding(.top, 12)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 0: Welcome
    // ─────────────────────────────────────────────────────

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                Circle()
                    .stroke(
                        AngularGradient(colors: [.green, .mint, .green.opacity(0.3), .green],
                                        center: .center),
                        lineWidth: 1.5
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                    )
            }
            VStack(spacing: 12) {
                Text("Welcome to FitTracker")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Your personal fitness companion.\nLet's get you set up in a few steps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                ForEach(["🔒 Encrypted", "☁️ CloudKit", "⌚ Apple Watch"], id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.08)))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 1: Profile
    // ─────────────────────────────────────────────────────

    private var profilePage: some View {
        ScrollView {
            VStack(spacing: 28) {
                pageHeader(icon: "person.fill", title: "Your Profile",
                           subtitle: "Tell us a bit about yourself")

                // Profile photo
                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if let data = photoData,
                               let img = platformImage(from: data) {
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                        }
                        .overlay(Circle().stroke(Color.green.opacity(0.4), lineWidth: 2))
                    }
                    Text("Add Photo (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    onboardingField(label: "Name", placeholder: "Your name", text: $profileName)
                    onboardingField(label: "Age", placeholder: "Years", text: $profileAge,
                                    keyboard: .numberPad)
                    onboardingField(label: "Height", placeholder: settings.unitSystem == .metric ? "cm" : "inches",
                                    text: $profileHeight, keyboard: .decimalPad)

                    // Unit system toggle
                    HStack {
                        Text("Units")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Units", selection: $settings.unitSystem) {
                            ForEach(UnitSystem.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 2: Goals
    // ─────────────────────────────────────────────────────

    private var goalsPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                pageHeader(icon: "target", title: "Set Your Goals",
                           subtitle: "We'll track your progress toward these targets")

                VStack(spacing: 14) {
                    Text("WEIGHT GOAL")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min").font(.caption).foregroundStyle(.secondary)
                            TextField(settings.unitSystem == .metric ? "kg" : "lbs",
                                      text: $targetWeightMin)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max").font(.caption).foregroundStyle(.secondary)
                            TextField(settings.unitSystem == .metric ? "kg" : "lbs",
                                      text: $targetWeightMax)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                    }

                    Text("BODY FAT GOAL")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min %").font(.caption).foregroundStyle(.secondary)
                            TextField("%", text: $targetBFMin)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max %").font(.caption).foregroundStyle(.secondary)
                            TextField("%", text: $targetBFMax)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Text("These can be updated any time in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 3: HealthKit
    // ─────────────────────────────────────────────────────

    private var healthKitPage: some View {
        VStack(spacing: 32) {
            Spacer()
            pageHeader(icon: "heart.text.square.fill", title: "Connect Apple Health",
                       subtitle: "FitTracker reads heart rate, HRV, sleep, and body weight from the Health app")

            VStack(spacing: 12) {
                ForEach([
                    ("heart.fill", "Heart Rate & HRV", "Real-time from Apple Watch"),
                    ("moon.fill", "Sleep Analysis", "Automatic from your Watch"),
                    ("scalemass.fill", "Body Metrics", "Weight and body fat %"),
                    ("figure.walk", "Activity", "Steps and active calories"),
                ], id: \.0) { icon, title, sub in
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                            Text(sub).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 28)

            if !healthRequested {
                Button {
                    healthRequested = true
                    Task { try? await healthService.requestAuthorization() }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Authorize Health Access")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Health access requested").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Text("You can skip this step — HealthKit permissions can be granted in Settings later.")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 4: Complete
    // ─────────────────────────────────────────────────────

    private var completePage: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                    )
            }
            VStack(spacing: 12) {
                Text("You're all set\(profileName.isEmpty ? "" : ", \(profileName)")!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Your profile is saved. Start tracking your\ntraining, nutrition, and body metrics.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                ForEach(["Log today's workout", "Track supplements", "Monitor body metrics", "Sync with Apple Watch"],
                        id: \.self) { tip in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                        Text(tip).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Helpers
    // ─────────────────────────────────────────────────────

    private func pageHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient(colors: [.green, .mint],
                                                startPoint: .top, endPoint: .bottom))
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func onboardingField(label: String, placeholder: String,
                                  text: Binding<String>,
                                  keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
    }

    private func finishOnboarding() {
        var profile = dataStore.userProfile
        if !profileName.isEmpty { profile.name = profileName }
        if let a = Int(profileAge) { profile.age = a }
        if let h = Double(profileHeight) {
            profile.heightCm = settings.unitSystem == .metric ? h : h * 2.54
        }
        if let wMin = Double(targetWeightMin) {
            profile.targetWeightMin = settings.unitSystem == .metric ? wMin : wMin / 2.20462
        }
        if let wMax = Double(targetWeightMax) {
            profile.targetWeightMax = settings.unitSystem == .metric ? wMax : wMax / 2.20462
        }
        if let bfMin = Double(targetBFMin) { profile.targetBFMin = bfMin }
        if let bfMax = Double(targetBFMax) { profile.targetBFMax = bfMax }
        if let photo = photoData { profile.profilePhotoData = photo }
        dataStore.saveProfile(profile)
        settings.hasCompletedOnboarding = true
    }

    @ViewBuilder
    private func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        if let ui = UIImage(data: data) { Image(uiImage: ui) } else { nil }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) { Image(nsImage: ns) } else { nil }
        #endif
    }
}
