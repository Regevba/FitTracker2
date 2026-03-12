// Views/Main/MainScreenView.swift
// Tab 1: Main screen
//   - Dynamic gradient background: light orange → light blue as goal progress increases
//   - Right-edge vertical tracker: orb descends top → bottom with progress
//   - All elements blended directly on gradient (no card containers)

import SwiftUI

struct MainScreenView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @State private var metricPage:       Int  = 0
    @State private var showExerciseSheet = false
    @State private var manualEntry       = false

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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    greetingHeader
                    metricSlider
                    goalSection
                    recoveryStatus
                    startExerciseButton
                    quickStats
                }
                .padding(.horizontal, 20)
                .padding(.trailing, 28)   // leave room for right-edge tracker
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
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
            // Base: light orange (always present)
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Overlay: light blue, fades in as goalProgress increases → 0 = full orange, 1 = full blue
            LinearGradient(colors: [bgBlue1, bgBlue2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(goalProgress)
                .animation(.easeInOut(duration: 1.5), value: goalProgress)
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Vertical progress tracker
    // Orb starts at the top and descends to the bottom as
    // goalProgress goes from 0 → 1
    // ─────────────────────────────────────────────────────

    private var progressTracker: some View {
        GeometryReader { proxy in
            let trackStart: CGFloat = 110
            let trackEnd:   CGFloat = proxy.size.height - 110
            let trackH   = max(1, trackEnd - trackStart)
            let orbY     = trackStart + trackH * goalProgress
            let x        = proxy.size.width - 16
            let fillH    = max(2, trackH * goalProgress)

            // Rail
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 3, height: trackH)
                .position(x: x, y: trackStart + trackH / 2)

            // Filled portion (orange at top → blue at bottom)
            Capsule()
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.65), .blue.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: fillH)
                .position(x: x, y: trackStart + fillH / 2)
                .animation(.spring(response: 1.2), value: goalProgress)

            // Glow halo behind orb
            Circle()
                .fill(goalProgress > 0.5
                      ? Color.blue.opacity(0.22)
                      : Color.orange.opacity(0.22))
                .frame(width: 26, height: 26)
                .blur(radius: 6)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)

            // Orb
            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .shadow(color: goalProgress > 0.5
                        ? .blue.opacity(0.55)
                        : .orange.opacity(0.55),
                        radius: 5)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Greeting header
    // ─────────────────────────────────────────────────────

    private var greetingHeader: some View {
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
                Text(profile.currentPhase.rawValue)
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 8).padding(.vertical, 3)
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
    // MARK: – Swipeable metric display (no card background)
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

            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(i == metricPage ? Color.primary.opacity(0.55) : Color.primary.opacity(0.2))
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
    // MARK: – Goal section (no card background)
    // ─────────────────────────────────────────────────────

    private var goalSection: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 10)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: goalProgress)
                    .stroke(
                        AngularGradient(colors: [.orange, .blue, .orange], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0), value: goalProgress)
                VStack(spacing: 0) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.system(.headline, design: .monospaced, weight: .bold))
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
                GoalProgressRow(label: "Weight",   progress: profile.weightProgress(current: currentWeight), color: .blue)
                GoalProgressRow(label: "Body Fat", progress: profile.bfProgress(current: currentBF),         color: .orange)
            }
            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Recovery status
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
                .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
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
        Button { showExerciseSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.black.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: programStore.todayDayType.icon)
                        .font(.title3.weight(.semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Exercise").font(.headline)
                    Text("Today: \(programStore.todayDayType.rawValue)").font(.caption).opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
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
    // MARK: – Quick stats (no pill backgrounds)
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
// MARK: – MetricBigCard (no background — floats on gradient)
// ─────────────────────────────────────────────────────────

struct MetricBigCard: View {
    let icon:          String
    let label:         String
    let value:         String
    let unit:          String
    let delta:         String
    let targetLabel:   String
    let color:         Color
    let onTap:         () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption2.monospaced())
                    .foregroundStyle(color)
                    .tracking(1)
                Spacer()
                Button { onManualEntry() } label: {
                    Image(systemName: "pencil.circle").foregroundStyle(.secondary)
                }
                Button { onTap() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption).foregroundStyle(.secondary)
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
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
// MARK: – RecoveryBanner (subtle white-glass background)
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
// MARK: – QuickStatPill (no background — floats on gradient)
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
        .padding(.vertical, 10)
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
