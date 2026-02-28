// Views/Main/MainScreenView.swift
// Tab 1: Main screen
//   - Time-based greeting + today's date
//   - Current weight ↔ body fat swipeable card
//   - Goal progress ring
//   - Start Exercise button

import SwiftUI

struct MainScreenView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    // Metric card slide state
    @State private var metricPage:       Int  = 0         // 0 = weight, 1 = body fat
    @State private var dragOffset:       CGFloat = 0
    @State private var showExerciseSheet = false
    @State private var manualEntry       = false

    private var profile:  UserProfile   { dataStore.userProfile }
    private var metrics:  LiveMetrics   { healthService.latest }
    private var todayLog: DailyLog?     { dataStore.todayLog() }

    // Effective values: HealthKit > manual biometrics from today's log
    private var currentWeight: Double? {
        metrics.weightKg ?? todayLog?.biometrics.weightKg
    }
    private var currentBF: Double? {
        // HealthKit returns 0–1 fraction; scale manual returns percentage
        if let hk = metrics.bodyFatPct { return hk * 100 }
        return todayLog?.biometrics.bodyFatPercent
    }

    private var goalProgress: Double {
        profile.overallProgress(currentWeight: currentWeight, currentBF: currentBF)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                greetingHeader
                metricSlider
                goalRing
                recoveryStatus
                startExerciseButton
                quickStats
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
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
    // MARK: – Greeting header
    // ─────────────────────────────────────────────────────

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(todayFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Day \(profile.daysSinceStart)")
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.green)
                    Text(profile.currentPhase.rawValue)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.green.opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.green.opacity(0.12), in: Capsule())
                }
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
    // MARK: – Swipeable metric card (weight ↔ body fat)
    // ─────────────────────────────────────────────────────

    private var metricSlider: some View {
        VStack(spacing: 10) {
            ZStack {
                weightCard.opacity(metricPage == 0 ? 1 : 0).offset(x: metricPage == 0 ? 0 : -30)
                bodyFatCard.opacity(metricPage == 1 ? 1 : 0).offset(x: metricPage == 1 ? 0 : 30)
            }
            .animation(.easeInOut(duration: 0.3), value: metricPage)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { val in
                        if val.translation.width < -40 && metricPage == 0 { metricPage = 1 }
                        if val.translation.width >  40 && metricPage == 1 { metricPage = 0 }
                    }
            )

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(i == metricPage ? Color.green : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut, value: metricPage)
                }
            }
        }
    }

    private var weightCard: some View {
        MetricBigCard(
            icon: "scalemass.fill",
            label: "CURRENT WEIGHT",
            value: currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "—",
            unit: settings.unitSystem.weightLabel(),
            delta: weightDelta,
            targetLabel: "Target: \(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())",
            color: .blue,
            onTap: { metricPage = 1 },
            onManualEntry: { manualEntry = true }
        )
    }

    private var bodyFatCard: some View {
        MetricBigCard(
            icon: "drop.fill",
            label: "BODY FAT",
            value: currentBF.map { String(format: "%.1f", $0) } ?? "—",
            unit: "%",
            delta: bfDelta,
            targetLabel: "Target: \(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))%",
            color: .orange,
            onTap: { metricPage = 0 },
            onManualEntry: { manualEntry = true }
        )
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
    // MARK: – Goal progress ring
    // ─────────────────────────────────────────────────────

    private var goalRing: some View {
        HStack(spacing: 20) {
            // Animated ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: goalProgress)
                    .stroke(
                        AngularGradient(colors: [.green, .teal, .green], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0), value: goalProgress)
                VStack(spacing: 0) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.system(.headline, design: .monospaced, weight: .bold))
                        .foregroundStyle(.green)
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("GOAL PROGRESS")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                GoalProgressRow(label: "Weight", progress: profile.weightProgress(current: currentWeight), color: .blue)
                GoalProgressRow(label: "Body Fat", progress: profile.bfProgress(current: currentBF), color: .orange)
            }
            Spacer()
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Recovery status banner
    // ─────────────────────────────────────────────────────

    private var recoveryStatus: some View {
        Group {
            if metrics.isReadyForTraining {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Recovery metrics in range — ready for training")
                        .font(.caption).fontWeight(.medium)
                    Spacer()
                }
                .padding(12)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 6) {
                    if (metrics.restingHR ?? 0) > 75 || metrics.restingHR == nil {
                        RecoveryBanner(icon: "heart.fill",
                                       text: metrics.restingHR != nil
                                           ? "Resting HR \(Int(metrics.restingHR!)) bpm — above 75 threshold"
                                           : "Resting HR: no data from Watch",
                                       color: .orange)
                    }
                    if (metrics.hrv ?? 0) < 28 || metrics.hrv == nil {
                        RecoveryBanner(icon: "waveform.path.ecg",
                                       text: metrics.hrv != nil
                                           ? "HRV \(Int(metrics.hrv!)) ms — below 28 ms threshold"
                                           : "HRV: no data from Watch",
                                       color: .orange)
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Start Exercise button
    // ─────────────────────────────────────────────────────

    private var startExerciseButton: some View {
        Button {
            showExerciseSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.black.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: programStore.todayDayType.icon)
                        .font(.title3.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Exercise")
                        .font(.headline)
                    Text("Today: \(programStore.todayDayType.rawValue)")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(16)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Quick stats row
    // ─────────────────────────────────────────────────────

    private var quickStats: some View {
        HStack(spacing: 10) {
            QuickStatPill(icon: "waveform.path.ecg", value: metrics.hrv.map { String(format: "%.0f ms", $0) } ?? "—", label: "HRV", color: metrics.hrvStatus.color)
            QuickStatPill(icon: "heart.fill", value: metrics.restingHR.map { String(format: "%.0f", $0) } ?? "—", label: "Rest HR", color: metrics.restingHRStatus.color)
            QuickStatPill(icon: "moon.fill", value: metrics.sleepHours.map { String(format: "%.1f h", $0) } ?? "—", label: "Sleep", color: .purple)
            QuickStatPill(icon: "figure.walk", value: metrics.stepCount.map { "\($0)" } ?? "—", label: "Steps", color: .blue)
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
// MARK: – Sub-components
// ─────────────────────────────────────────────────────────

struct MetricBigCard: View {
    let icon:         String
    let label:        String
    let value:        String
    let unit:         String
    let delta:        String
    let targetLabel:  String
    let color:        Color
    let onTap:        () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption2.monospaced())
                    .foregroundStyle(color)
                    .tracking(1)
                Spacer()
                Button {
                    onManualEntry()
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.secondary)
                }
                Button {
                    onTap()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(delta)
                    .font(.caption)
                    .foregroundStyle(delta.hasPrefix("+") ? .red : .green)
                Text(targetLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

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
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.15)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 1.0), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

struct RecoveryBanner: View {
    let icon:  String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text(text).font(.caption).foregroundStyle(.primary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct QuickStatPill: View {
    let icon: String; let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value).font(.system(.caption2, design: .monospaced, weight: .semibold))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

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
                    weightText = b.weightKg.map { String($0) } ?? ""
                    bfText     = b.bodyFatPercent.map { String($0) } ?? ""
                    hrText     = b.manualRestingHR.map { String($0) } ?? ""
                    hrvText    = b.manualHRV.map { String($0) } ?? ""
                    sleepText  = b.manualSleepHours.map { String($0) } ?? ""
                }
            }
        }
    }

    private func save() {
        var log = dataStore.todayLog() ?? makeBlankLog()
        log.biometrics.weightKg        = Double(weightText)
        log.biometrics.bodyFatPercent  = Double(bfText)
        log.biometrics.manualRestingHR = Double(hrText)
        log.biometrics.manualHRV       = Double(hrvText)
        log.biometrics.manualSleepHours = Double(sleepText)
        dataStore.upsertLog(log)
    }

    private func makeBlankLog() -> DailyLog {
        DailyLog(date: Date(), phase: dataStore.userProfile.currentPhase,
                 dayType: .restDay, recoveryDay: dataStore.userProfile.daysSinceStart)
    }
}
