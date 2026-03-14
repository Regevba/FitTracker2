// Views/Stats/StatsView.swift

import SwiftUI
import Charts

// MARK: – Supporting enums

enum StatsPeriod: String, CaseIterable {
    case sevenDays    = "7D"
    case thirtyDays   = "30D"
    case ninetyDays   = "90D"
    case allTime      = "All"

    var dateRange: (from: Date, to: Date) {
        let to = Date()
        switch self {
        case .sevenDays:   return (Calendar.current.date(byAdding: .day, value: -7, to: to)!, to)
        case .thirtyDays:  return (Calendar.current.date(byAdding: .day, value: -30, to: to)!, to)
        case .ninetyDays:  return (Calendar.current.date(byAdding: .day, value: -90, to: to)!, to)
        case .allTime:     return (Date.distantPast, to)
        }
    }
}

enum StatsCategory: String, CaseIterable {
    case body      = "Body"
    case training  = "Training"
    case recovery  = "Recovery"
    case nutrition = "Nutrition"
}

// MARK: – StatsView

struct StatsView: View {
    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService

    @State private var period:   StatsPeriod   = .thirtyDays
    @State private var category: StatsCategory = .body

    // Body section data
    @State private var bodyData: [(date: Date, weightKg: Double?, bodyFatPercent: Double?, leanBodyMassKg: Double?)] = []

    // Training section data
    @State private var volumeData:        [(date: Date, volumeKg: Double)] = []
    @State private var zone2Data:         [(date: Date, minutes: Double)]  = []
    @State private var selectedExercise:  String? = nil

    // Recovery section data
    @State private var recoveryData: [(date: Date, hrv: Double?, restingHR: Double?, sleepHours: Double?)] = []

    // Nutrition section data
    @State private var nutritionData: [(date: Date, calories: Double?, proteinG: Double?, supplementPct: Double)] = []

    private var dateRange: (from: Date, to: Date) { period.dateRange }

    var body: some View {
        ZStack {
            // Background gradient (same warm orange palette as rest of app)
            LinearGradient(
                colors: [Color.appOrange1, Color.appOrange2],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Period picker
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Category tab buttons
                HStack(spacing: 0) {
                    ForEach(StatsCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { category = cat }
                        } label: {
                            Text(cat.rawValue)
                                .font(AppType.body)
                                .foregroundStyle(category == cat ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    category == cat
                                        ? Color.white.opacity(0.25)
                                        : Color.clear
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Chart content area
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch category {
                        case .body:
                            bodySection
                        case .training:
                            trainingSection
                        case .recovery:
                            recoverySection
                        case .nutrition:
                            nutritionSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Body Section

    private var bodySection: some View {
        VStack(spacing: 16) {
            // Weight chart
            ChartCard(title: "Weight", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.weightKg).isEmpty {
                    EmptyStateView(icon: "scalemass", title: "No weight data", subtitle: "Log your weight to see the chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(bodyData.filter { $0.weightKg != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("kg", p.weightKg!))
                                .foregroundStyle(Color.appOrange1.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("kg", p.weightKg!))
                                .foregroundStyle(Color.appOrange1)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        RuleMark(y: .value("Target", dataStore.userProfile.targetWeightMax))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.appOrange1.opacity(0.5))
                            .annotation(position: .trailing) {
                                Text("Goal").font(AppType.caption).foregroundStyle(Color.appOrange1)
                            }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Body Fat chart
            ChartCard(title: "Body Fat %", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.bodyFatPercent).isEmpty {
                    EmptyStateView(icon: "drop", title: "No body fat data", subtitle: "Log your body fat to see the chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(bodyData.filter { $0.bodyFatPercent != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("%", p.bodyFatPercent!))
                                .foregroundStyle(Color.status.warning.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("%", p.bodyFatPercent!))
                                .foregroundStyle(Color.status.warning)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        RuleMark(y: .value("Target", dataStore.userProfile.targetBFMax))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.status.warning.opacity(0.5))
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Lean Mass chart
            ChartCard(title: "Lean Mass", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.leanBodyMassKg).isEmpty {
                    EmptyStateView(icon: "figure.arms.open", title: "No lean mass data", subtitle: "Log your body composition to see the chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(bodyData.filter { $0.leanBodyMassKg != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("kg", p.leanBodyMassKg!))
                                .foregroundStyle(Color.accent.cyan.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("kg", p.leanBodyMassKg!))
                                .foregroundStyle(Color.accent.cyan)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }
        }
        .task(id: period) {
            let range = dateRange
            bodyData = dataStore.bodyCompositionPoints(from: range.from, to: range.to)
        }
    }

    // MARK: – Training Section

    private var trainingSection: some View {
        VStack(spacing: 16) {
            // Training Volume chart
            ChartCard(title: "Training Volume", periodLabel: period.rawValue) {
                if volumeData.isEmpty {
                    EmptyStateView(icon: "dumbbell.fill", title: "No training data", subtitle: "Log a workout to see your volume chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(volumeData, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("kg", p.volumeKg))
                                .foregroundStyle(Color.accent.cyan.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("kg", p.volumeKg))
                                .foregroundStyle(Color.accent.cyan)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        // TODO: Add gold ★ annotations at PR dates once exercise selection UI is added
                        // prRecords()[selectedExercise]?.date matching a volumeData point
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Zone 2 chart
            ChartCard(title: "Zone 2 Cardio", periodLabel: period.rawValue) {
                if zone2Data.isEmpty {
                    EmptyStateView(icon: "heart.circle", title: "No Zone 2 data", subtitle: "Log cardio with HR 106–124 bpm to see this chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(zone2Data, id: \.date) { p in
                            BarMark(x: .value("Date", p.date), y: .value("min", p.minutes))
                                .foregroundStyle(Color.status.success)
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }
        }
        .task(id: period) {
            let range = dateRange
            volumeData = dataStore.trainingVolumePoints(from: range.from, to: range.to)
            zone2Data  = dataStore.zone2Minutes(from: range.from, to: range.to)
        }
    }

    // MARK: – Recovery Section

    private var recoverySection: some View {
        VStack(spacing: 16) {
            // HRV chart with zone bands
            ChartCard(title: "HRV", periodLabel: period.rawValue) {
                if recoveryData.compactMap(\.hrv).isEmpty {
                    EmptyStateView(icon: "waveform.path.ecg", title: "No HRV data", subtitle: "HRV is recorded via Apple Watch or manual entry")
                        .frame(height: 120)
                } else {
                    Chart {
                        // Zone bands behind the line
                        RectangleMark(
                            xStart: .value("Start", dateRange.from),
                            xEnd:   .value("End",   dateRange.to),
                            yStart: .value("Low",   35.0),
                            yEnd:   .value("High",  100.0)
                        )
                        .foregroundStyle(Color.status.success.opacity(0.08))

                        RectangleMark(
                            xStart: .value("Start", dateRange.from),
                            xEnd:   .value("End",   dateRange.to),
                            yStart: .value("Low",   28.0),
                            yEnd:   .value("High",  35.0)
                        )
                        .foregroundStyle(Color.status.warning.opacity(0.08))

                        RectangleMark(
                            xStart: .value("Start", dateRange.from),
                            xEnd:   .value("End",   dateRange.to),
                            yStart: .value("Low",   0.0),
                            yEnd:   .value("High",  28.0)
                        )
                        .foregroundStyle(Color.status.error.opacity(0.08))

                        ForEach(recoveryData.filter { $0.hrv != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("ms", p.hrv!))
                                .foregroundStyle(Color.accent.cyan.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("ms", p.hrv!))
                                .foregroundStyle(Color.accent.cyan)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Resting HR chart
            ChartCard(title: "Resting Heart Rate", periodLabel: period.rawValue) {
                if recoveryData.compactMap(\.restingHR).isEmpty {
                    EmptyStateView(icon: "heart.fill", title: "No resting HR data", subtitle: "Resting HR is recorded via Apple Watch or manual entry")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(recoveryData.filter { $0.restingHR != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("bpm", p.restingHR!))
                                .foregroundStyle(Color.status.error.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("bpm", p.restingHR!))
                                .foregroundStyle(Color.status.error)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Sleep Hours chart
            ChartCard(title: "Sleep Hours", periodLabel: period.rawValue) {
                if recoveryData.compactMap(\.sleepHours).isEmpty {
                    EmptyStateView(icon: "bed.double.fill", title: "No sleep data", subtitle: "Sleep is recorded via Apple Watch or manual entry")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(recoveryData.filter { $0.sleepHours != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("hrs", p.sleepHours!))
                                .foregroundStyle(Color.accent.purple.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("hrs", p.sleepHours!))
                                .foregroundStyle(Color.accent.purple)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Readiness Score — filled in step 5.6
            ChartCard(title: "Readiness Score", periodLabel: period.rawValue) {
                let range = period.dateRange
                let days: [Date] = {
                    var result: [Date] = []
                    var d = range.from
                    while d <= range.to {
                        result.append(d)
                        d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
                    }
                    return result
                }()
                let pts: [(date: Date, score: Int)] = days.compactMap { day in
                    guard let s = dataStore.readinessScore(for: day, fallbackMetrics: healthService.latest) else { return nil }
                    return (date: day, score: s)
                }
                if pts.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "Not Enough Data",
                        subtitle: "Log biometrics for 3+ days to see your readiness trend"
                    )
                    .frame(height: 120)
                } else {
                    Chart(pts, id: \.date) { pt in
                        LineMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Score", pt.score)
                        )
                        .foregroundStyle(Color.accent.cyan)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Score", pt.score)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [Color.accent.cyan.opacity(0.3), Color.accent.cyan.opacity(0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: max(1, pts.count / 5))) {
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 40, 60, 80, 100]) { v in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
        .task(id: period) {
            let range = dateRange
            recoveryData = dataStore.recoveryPoints(from: range.from, to: range.to)
        }
    }

    // MARK: – Nutrition Section

    private var nutritionSection: some View {
        VStack(spacing: 16) {
            // Calories chart
            ChartCard(title: "Calories", periodLabel: period.rawValue) {
                if nutritionData.compactMap(\.calories).isEmpty {
                    EmptyStateView(icon: "fork.knife", title: "No calorie data", subtitle: "Log your meals to see the chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(nutritionData.filter { $0.calories != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("kcal", p.calories!))
                                .foregroundStyle(Color.appOrange1.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("kcal", p.calories!))
                                .foregroundStyle(Color.appOrange1)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        RuleMark(y: .value("Target", Double(dataStore.userProfile.currentPhase.trainingCalories)))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.appOrange1.opacity(0.5))
                            .annotation(position: .trailing) {
                                Text("Target").font(AppType.caption).foregroundStyle(Color.appOrange1)
                            }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Protein chart
            ChartCard(title: "Protein", periodLabel: period.rawValue) {
                if nutritionData.compactMap(\.proteinG).isEmpty {
                    EmptyStateView(icon: "fork.knife", title: "No protein data", subtitle: "Log your meals to see the chart")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(nutritionData.filter { $0.proteinG != nil }, id: \.date) { p in
                            AreaMark(x: .value("Date", p.date), y: .value("g", p.proteinG!))
                                .foregroundStyle(Color.accent.cyan.opacity(0.2).gradient)
                            LineMark(x: .value("Date", p.date), y: .value("g", p.proteinG!))
                                .foregroundStyle(Color.accent.cyan)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        RuleMark(y: .value("Target", dataStore.userProfile.currentPhase.proteinTargetG.upperBound))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.accent.cyan.opacity(0.5))
                            .annotation(position: .trailing) {
                                Text("Target").font(AppType.caption).foregroundStyle(Color.accent.cyan)
                            }
                    }
                    .frame(height: 140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }

            // Supplement adherence chart
            ChartCard(title: "Supplement Adherence", periodLabel: period.rawValue) {
                if nutritionData.isEmpty {
                    EmptyStateView(icon: "pill.fill", title: "No supplement data", subtitle: "Log your supplements to see adherence")
                        .frame(height: 120)
                } else {
                    Chart {
                        ForEach(nutritionData, id: \.date) { p in
                            BarMark(x: .value("Date", p.date), y: .value("%", p.supplementPct * 100))
                                .foregroundStyle(Color.accent.gold)
                        }
                    }
                    .frame(height: 140)
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(Color.white.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                }
            }
        }
        .task(id: period) {
            let range = dateRange
            nutritionData = dataStore.nutritionAdherencePoints(from: range.from, to: range.to)
        }
    }
}

struct StatPreviewPill: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundStyle(Color.status.success)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Settings View
// ─────────────────────────────────────────────────────────

struct SettingsView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var cloudSync:     CloudKitSyncService
    @EnvironmentObject var settings:      AppSettings

    @State private var showResetAlert = false

    var body: some View {
        #if os(macOS)
        NavigationStack { settingsForm }
        #else
        settingsForm
        #endif
    }

    private var settingsForm: some View {
        Form {
            Section("Profile") {
                LabeledContent("Name",          value: dataStore.userProfile.name)
                LabeledContent("Recovery Start", value: "Jan 29, 2026")
                LabeledContent("Phase",         value: dataStore.userProfile.currentPhase.rawValue)
                LabeledContent("Recovery Day",  value: "Day \(dataStore.userProfile.daysSinceStart)")
                LabeledContent("Goal Weight",   value: "\(Int(dataStore.userProfile.targetWeightMin))–\(Int(dataStore.userProfile.targetWeightMax)) kg")
                LabeledContent("Goal Body Fat", value: "\(Int(dataStore.userProfile.targetBFMin))–\(Int(dataStore.userProfile.targetBFMax))%")
            }

            Section("Apple Health") {
                LabeledContent("HealthKit", value: healthService.isAuthorized ? "Authorized ✓" : "Not authorized")
                LabeledContent("Apple Watch", value: "Background delivery active")
                Button("Re-authorize HealthKit") {
                    Task { try? await healthService.requestAuthorization() }
                }
            }

            Section("iCloud Sync") {
                LabeledContent("Status",     value: cloudSync.status.rawValue)
                LabeledContent("iCloud",     value: cloudSync.iCloudAvailable ? "Available ✓" : "Unavailable")
                if let last = cloudSync.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSyncFormatted(last))
                }
                Button("Sync Now") {
                    Task { await cloudSync.pushPendingChanges(dataStore: dataStore) }
                }
                Button("Fetch from iCloud") {
                    Task { await cloudSync.fetchChanges(dataStore: dataStore) }
                }
            }

            Section("Security") {
                LabeledContent("Encryption",      value: "AES-256-GCM + ChaCha20-Poly1305")
                LabeledContent("Key Storage",     value: "Keychain (biometric-protected)")
                LabeledContent("Cloud Storage",   value: "Encrypted before upload ✓")
                LabeledContent("Data Protection", value: "NSFileProtectionCompleteUnlessOpen")
                LabeledContent("Platforms",       value: "iOS · iPadOS · macOS only")
            }

            Section("Data") {
                LabeledContent("Daily Logs",       value: "\(dataStore.dailyLogs.count) entries")
                LabeledContent("Weekly Snapshots", value: "\(dataStore.weeklySnapshots.count) entries")
                Button("Delete All Local Data", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Data?", isPresented: $showResetAlert) {
            Button("Delete", role: .destructive) {
                dataStore.dailyLogs = []
                dataStore.weeklySnapshots = []
                Task { await dataStore.persistToDisk() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all locally stored logs. iCloud copies are not deleted.")
        }
    }

    private static let lastSyncFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short; f.timeStyle = .short
        return f
    }()

    private func lastSyncFormatted(_ date: Date) -> String {
        Self.lastSyncFormatter.string(from: date)
    }
}
