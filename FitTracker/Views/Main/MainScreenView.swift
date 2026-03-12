// Views/Main/MainScreenView.swift
// Tab 1: Home screen — everything visible above the tab bar, no scroll
//   - Gradient background (orange → blue by goal progress)
//   - Right-edge vertical progress tracker
//   - Greeting + play/pause training button in header
//   - Weight & Body Fat displayed side-by-side

import SwiftUI

struct MainScreenView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @State private var trainingActive     = false
    @State private var showExerciseSheet  = false
    @State private var manualEntry        = false
    @State private var selectedDayType:   DayType? = nil   // nil = follow today's schedule

    private var activeDayType: DayType {
        selectedDayType ?? programStore.todayDayType
    }

    private var profile:  UserProfile  { dataStore.userProfile }
    private var metrics:  LiveMetrics  { healthService.latest }
    private var todayLog: DailyLog?    { dataStore.todayLog() }

    private var currentWeight: Double? {
        metrics.weightKg ?? todayLog?.biometrics.weightKg
    }
    private var currentBF: Double? {
        if let hk = metrics.bodyFatPct { return hk * 100 }
        return todayLog?.biometrics.bodyFatPercent
    }
    private var goalProgress: Double {
        profile.overallProgress(currentWeight: currentWeight, currentBF: currentBF)
    }

    // Background palette
    private let bgOrange1 = Color(red: 1.0,  green: 0.89, blue: 0.73)
    private let bgOrange2 = Color(red: 1.0,  green: 0.78, blue: 0.54)
    private let bgBlue1   = Color(red: 0.73, green: 0.89, blue: 1.0)
    private let bgBlue2   = Color(red: 0.54, green: 0.78, blue: 1.0)

    var body: some View {
        ZStack {
            backgroundLayer
            progressTracker

            // All content in a VStack with flexible spacers — no scroll
            VStack(spacing: 0) {
                greetingHeader
                Spacer(minLength: 14)
                metricPair
                Spacer(minLength: 14)
                goalSection
                Spacer(minLength: 12)
                trainingButton
                Spacer(minLength: 12)
                quickStats
            }
            .padding(.horizontal, 20)
            .padding(.trailing, 28)   // room for right-edge tracker
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showExerciseSheet) {
            NavigationStack { TrainingPlanView() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $manualEntry) {
            ManualBiometricEntry()
                .presentationDetents([.medium])
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Background gradient
    // ─────────────────────────────────────────────────────

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [bgBlue1, bgBlue2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(goalProgress)
                .animation(.easeInOut(duration: 1.5), value: goalProgress)
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Vertical progress tracker
    // ─────────────────────────────────────────────────────

    private var progressTracker: some View {
        GeometryReader { proxy in
            let trackStart: CGFloat = 110
            let trackEnd:   CGFloat = proxy.size.height - 110
            let trackH   = max(1, trackEnd - trackStart)
            let orbY     = trackStart + trackH * goalProgress
            let x        = proxy.size.width - 16
            let fillH    = max(2, trackH * goalProgress)

            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 3, height: trackH)
                .position(x: x, y: trackStart + trackH / 2)

            Capsule()
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.65), .blue.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: fillH)
                .position(x: x, y: trackStart + fillH / 2)
                .animation(.spring(response: 1.2), value: goalProgress)

            Circle()
                .fill(goalProgress > 0.5 ? Color.blue.opacity(0.22) : Color.orange.opacity(0.22))
                .frame(width: 26, height: 26)
                .blur(radius: 6)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)

            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .shadow(color: goalProgress > 0.5 ? .blue.opacity(0.55) : .orange.opacity(0.55), radius: 5)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Greeting header + play/pause button
    // ─────────────────────────────────────────────────────

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(todayFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Day \(profile.daysSinceStart)")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                Text(profile.currentPhase.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.35), in: Capsule())
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning, \(profile.name) ☀️"
        case 12..<17: return "Good afternoon, \(profile.name) 🌤️"
        case 17..<21: return "Good evening, \(profile.name) 🌙"
        default:       return "Good night, \(profile.name) 🌑"
        }
    }

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: Date())
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Weight & Body Fat side by side
    // ─────────────────────────────────────────────────────

    private var metricPair: some View {
        HStack(alignment: .top, spacing: 0) {

            // Weight (left)
            VStack(alignment: .leading, spacing: 4) {
                Label("WEIGHT", systemImage: "scalemass.fill")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .tracking(1)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "—")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                    Text(settings.unitSystem.weightLabel())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(weightDelta)
                    .font(.system(size: 10))
                    .foregroundStyle(weightDelta.hasPrefix("+") ? .red : .green)
                Text("Target: \(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 1, height: 75)
                .padding(.horizontal, 14)

            // Body Fat (right)
            VStack(alignment: .leading, spacing: 4) {
                Label("BODY FAT", systemImage: "drop.fill")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .tracking(1)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(currentBF.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("%")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(bfDelta)
                    .font(.system(size: 10))
                    .foregroundStyle(bfDelta.hasPrefix("+") ? .red : .green)
                Text("Target: \(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))%")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button { manualEntry = true } label: {
                Image(systemName: "pencil.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weightDelta: String {
        guard let w = currentWeight else { return "" }
        let d = w - profile.startWeightKg
        let unit = settings.unitSystem.weightLabel()
        let displayD = settings.unitSystem == .metric ? d : d * 2.20462
        return String(format: "%+.1f \(unit) since start", displayD)
    }

    private var bfDelta: String {
        guard let b = currentBF else { return "" }
        let d = b - profile.startBodyFatPct
        return String(format: "%+.1f%% since start", d)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Goal section
    // ─────────────────────────────────────────────────────

    private var goalSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 8)
                    .frame(width: 74, height: 74)
                Circle()
                    .trim(from: 0, to: goalProgress)
                    .stroke(
                        AngularGradient(colors: [.orange, .blue, .orange], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0), value: goalProgress)
                VStack(spacing: 0) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    Text("Goal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GOAL PROGRESS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                GoalProgressRow(label: "Weight",   progress: profile.weightProgress(current: currentWeight), color: .blue)
                GoalProgressRow(label: "Body Fat", progress: profile.bfProgress(current: currentBF),         color: .orange)
            }
            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Training button with plan picker dropdown
    // ─────────────────────────────────────────────────────

    // Light blue matching the gradient's bgBlue1
    private let buttonBlue = Color(red: 0.73, green: 0.89, blue: 1.0)

    private var trainingButton: some View {
        HStack(spacing: 14) {
            // Play / Pause circle
            Button {
                trainingActive.toggle()
                if trainingActive { showExerciseSheet = true }
            } label: {
                ZStack {
                    Circle()
                        .fill(trainingActive
                              ? Color(red: 1.0, green: 0.65, blue: 0.3)   // warm orange when active
                              : buttonBlue)
                        .frame(width: 52, height: 52)
                        .shadow(color: (trainingActive ? Color.orange : buttonBlue).opacity(0.45),
                                radius: 10, x: 0, y: 4)
                    Image(systemName: trainingActive ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .offset(x: trainingActive ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            // Plan label + dropdown picker
            VStack(alignment: .leading, spacing: 3) {
                Text(trainingActive ? "Training Active" : "Start Training")
                    .font(.subheadline.weight(.semibold))

                Menu {
                    // "Follow today's schedule" option
                    Button {
                        selectedDayType = nil
                    } label: {
                        HStack {
                            Text("Today's Schedule (\(programStore.todayDayType.rawValue))")
                            if selectedDayType == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Divider()
                    ForEach(DayType.allCases, id: \.self) { day in
                        Button {
                            selectedDayType = day
                        } label: {
                            HStack {
                                Label(day.rawValue, systemImage: day.icon)
                                if activeDayType == day && selectedDayType != nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: activeDayType.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(activeDayType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Quick stats
    // ─────────────────────────────────────────────────────

    private var quickStats: some View {
        HStack(spacing: 10) {
            QuickStatPill(icon: "waveform.path.ecg",
                          value: metrics.hrv.map        { String(format: "%.0f ms", $0) } ?? "—",
                          label: "HRV",     color: metrics.hrvStatus.color)
            QuickStatPill(icon: "heart.fill",
                          value: metrics.restingHR.map  { String(format: "%.0f",    $0) } ?? "—",
                          label: "Rest HR", color: metrics.restingHRStatus.color)
            QuickStatPill(icon: "moon.fill",
                          value: metrics.sleepHours.map { String(format: "%.1f h",  $0) } ?? "—",
                          label: "Sleep",   color: .purple)
            QuickStatPill(icon: "figure.walk",
                          value: metrics.stepCount.map  { "\($0)" } ?? "—",
                          label: "Steps",   color: .blue)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Toolbar
    // ─────────────────────────────────────────────────────

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button { manualEntry = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                SyncStatusIndicator()
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – GoalProgressRow
// ─────────────────────────────────────────────────────────

struct GoalProgressRow: View {
    let label:    String
    let progress: Double
    let color:    Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%").font(.caption2.monospaced()).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 1.0), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – RecoveryBanner
// ─────────────────────────────────────────────────────────

struct RecoveryBanner: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text(text).font(.caption).foregroundStyle(.primary)
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – QuickStatPill
// ─────────────────────────────────────────────────────────

struct QuickStatPill: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.system(.caption2, design: .monospaced, weight: .semibold))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – SyncStatusIndicator
// ─────────────────────────────────────────────────────────

struct SyncStatusIndicator: View {
    @EnvironmentObject var cloud: CloudKitSyncService
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(cloud.status == .idle ? Color.green : cloud.status == .syncing ? Color.orange : Color.red)
                .frame(width: 6, height: 6)
            Text(cloud.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Manual biometric entry sheet
// ─────────────────────────────────────────────────────────

struct ManualBiometricEntry: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @Environment(\.dismiss) var dismiss

    @State private var weightText  = ""
    @State private var bfText      = ""
    @State private var hrText      = ""
    @State private var hrvText     = ""
    @State private var sleepText   = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Scale Readings — Xiaomi S400") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Body Fat")
                        Spacer()
                        TextField("%", text: $bfText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                Section("Manual Overrides (if Watch unavailable)") {
                    HStack {
                        Text("Resting HR")
                        Spacer()
                        TextField("bpm", text: $hrText).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("HRV")
                        Spacer()
                        TextField("ms", text: $hrvText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                    HStack {
                        Text("Sleep")
                        Spacer()
                        TextField("hrs", text: $sleepText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
            }
            .navigationTitle("Log Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .onAppear {
                if let b = dataStore.todayLog()?.biometrics {
                    weightText = b.weightKg.map         { String($0) } ?? ""
                    bfText     = b.bodyFatPercent.map   { String($0) } ?? ""
                    hrText     = b.manualRestingHR.map  { String($0) } ?? ""
                    hrvText    = b.manualHRV.map        { String($0) } ?? ""
                    sleepText  = b.manualSleepHours.map { String($0) } ?? ""
                }
            }
        }
    }

    private func save() {
        var log = dataStore.todayLog() ?? makeBlankLog()
        log.biometrics.weightKg         = Double(weightText)
        log.biometrics.bodyFatPercent   = Double(bfText)
        log.biometrics.manualRestingHR  = Double(hrText)
        log.biometrics.manualHRV        = Double(hrvText)
        log.biometrics.manualSleepHours = Double(sleepText)
        dataStore.upsertLog(log)
    }

    private func makeBlankLog() -> DailyLog {
        DailyLog(date: Date(), phase: dataStore.userProfile.currentPhase,
                 dayType: .restDay, recoveryDay: dataStore.userProfile.daysSinceStart)
    }
}
