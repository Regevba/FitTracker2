// Views/Stats/StatsView.swift
// Tab 4: Stats — Workout Volume / Body Trends / Health Metrics
// Uses Swift Charts (iOS 16+)

import SwiftUI
import Charts

struct StatsView: View {

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var settings:      AppSettings

    @State private var selectedSegment: StatsSegment = .volume
    @State private var volumeRange:  VolumeRange  = .weeks12
    @State private var bodyRange:    BodyRange    = .days30
    @State private var healthRange:  HealthRange  = .days7

    enum StatsSegment: String, CaseIterable { case volume = "Volume"; case body = "Body"; case health = "Health" }
    enum VolumeRange: String, CaseIterable  { case weeks4 = "4W"; case weeks8 = "8W"; case weeks12 = "12W" }
    enum BodyRange:   String, CaseIterable  { case days30 = "30D"; case days90 = "90D"; case days180 = "180D" }
    enum HealthRange: String, CaseIterable  { case days7  = "7D";  case days30 = "30D" }

    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Segment picker
                    Picker("Segment", selection: $selectedSegment) {
                        ForEach(StatsSegment.allCases, id: \.self) { seg in
                            Text(seg.rawValue).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    switch selectedSegment {
                    case .volume: volumeContent
                    case .body:   bodyContent
                    case .health: healthContent
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Volume Tab
    // ─────────────────────────────────────────────────────

    private var volumeContent: some View {
        VStack(spacing: 16) {
            // Range picker
            rangePicker(cases: VolumeRange.allCases, selected: $volumeRange)

            // Summary cards
            let (thisWeek, lastWeek) = weeklyVolumeSummary()
            HStack(spacing: 12) {
                summaryCard(title: "THIS WEEK", value: "\(Int(thisWeek)) kg",
                            delta: deltaString(current: thisWeek, previous: lastWeek, unit: "kg"),
                            deltaUp: thisWeek >= lastWeek, color: .blue)
                summaryCard(title: "LAST WEEK", value: "\(Int(lastWeek)) kg",
                            delta: nil, deltaUp: true, color: .secondary)
            }
            .padding(.horizontal, 16)

            // Weekly tonnage bar chart
            statsCard(title: "WEEKLY TONNAGE") {
                let data = weeklyTonnageData()
                if data.isEmpty {
                    emptyChartPlaceholder(message: "Log workouts to see tonnage")
                } else {
                    Chart(data) { item in
                        BarMark(
                            x: .value("Week", item.label),
                            y: .value("kg", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.blue.opacity(0.7), .blue],
                                           startPoint: .bottom, endPoint: .top)
                        )
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel("kg lifted")
                    .frame(height: 180)
                }
            }

            // Top exercises volume breakdown
            statsCard(title: "TOP EXERCISES (VOLUME)") {
                let exercises = topExerciseVolume()
                if exercises.isEmpty {
                    emptyChartPlaceholder(message: "Log exercises to see breakdown")
                } else {
                    Chart(exercises) { item in
                        BarMark(
                            x: .value("Volume", item.value),
                            y: .value("Exercise", item.label)
                        )
                        .foregroundStyle(.orange.opacity(0.85))
                        .cornerRadius(4)
                    }
                    .chartXAxisLabel("kg total volume")
                    .frame(height: CGFloat(exercises.count * 44 + 20))
                }
            }

            // Sets/reps summary
            statsCard(title: "SETS THIS WEEK") {
                let (sets, reps) = setsRepsThisWeek()
                HStack(spacing: 0) {
                    volumeStatCell(value: "\(sets)", label: "Sets")
                    Divider().frame(height: 40)
                    volumeStatCell(value: "\(reps)", label: "Total Reps")
                    Divider().frame(height: 40)
                    let sessions = sessionsThisWeek()
                    volumeStatCell(value: "\(sessions)", label: "Sessions")
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Body Tab
    // ─────────────────────────────────────────────────────

    private var bodyContent: some View {
        VStack(spacing: 16) {
            rangePicker(cases: BodyRange.allCases, selected: $bodyRange)

            let days = bodyRangeDays()
            let weightData = weightTrendData(days: days)
            let bfData     = bfTrendData(days: days)

            // Weight trend
            statsCard(title: "WEIGHT TREND") {
                if weightData.isEmpty {
                    emptyChartPlaceholder(message: "Log weight to see trend")
                } else {
                    Chart(weightData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("kg", item.value)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("kg", item.value)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                        // Target range band
                        RuleMark(y: .value("Target min", dataStore.userProfile.targetWeightMin))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                        RuleMark(y: .value("Target max", dataStore.userProfile.targetWeightMax))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                    .chartYAxisLabel("kg")
                    .frame(height: 180)
                }
            }

            // Body fat trend
            statsCard(title: "BODY FAT TREND") {
                if bfData.isEmpty {
                    emptyChartPlaceholder(message: "Log body fat to see trend")
                } else {
                    Chart(bfData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("%", item.value)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("%", item.value)
                        )
                        .foregroundStyle(.orange.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                        RuleMark(y: .value("Target min", dataStore.userProfile.targetBFMin))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                        RuleMark(y: .value("Target max", dataStore.userProfile.targetBFMax))
                            .foregroundStyle(.green.opacity(0.5))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                    .chartYAxisLabel("%")
                    .frame(height: 180)
                }
            }

            // Latest measurements preview + nav link
            statsCard(title: "MEASUREMENTS") {
                if let m = dataStore.bodyMeasurements.first {
                    VStack(spacing: 8) {
                        measurementRow("Waist",  value: m.waistCm,  unit: "cm")
                        measurementRow("Chest",  value: m.chestCm,  unit: "cm")
                        measurementRow("L. Arm", value: m.leftArmCm, unit: "cm")
                        measurementRow("Hips",   value: m.hipsCm,   unit: "cm")
                    }
                } else {
                    Text("No measurements logged yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                NavigationLink(destination:
                    BodyMeasurementsView()
                        .environmentObject(dataStore)
                        .environmentObject(settings)
                ) {
                    Label("View all measurements", systemImage: "ruler")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Health Tab
    // ─────────────────────────────────────────────────────

    private var healthContent: some View {
        VStack(spacing: 16) {
            rangePicker(cases: HealthRange.allCases, selected: $healthRange)

            let days = healthRangeDays()
            let hrvData  = hrvTrendData(days: days)
            let rhrData  = rhrTrendData(days: days)
            let sleepData = sleepTrendData(days: days)

            // HRV trend
            statsCard(title: "HRV TREND") {
                if hrvData.isEmpty {
                    emptyChartPlaceholder(message: "Connect Apple Watch for HRV data")
                } else {
                    Chart(hrvData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("ms", item.value)
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("ms", item.value)
                        )
                        .foregroundStyle(.purple.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                        RuleMark(y: .value("Target", 28))
                            .foregroundStyle(.green.opacity(0.6))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                            .annotation(position: .trailing) {
                                Text("28 ms").font(.system(size: 9)).foregroundStyle(.green)
                            }
                    }
                    .chartYAxisLabel("ms")
                    .frame(height: 160)
                }
            }

            // Resting HR trend
            statsCard(title: "RESTING HEART RATE") {
                if rhrData.isEmpty {
                    emptyChartPlaceholder(message: "Apple Watch required for HR data")
                } else {
                    Chart(rhrData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("bpm", item.value)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("bpm", item.value)
                        )
                        .foregroundStyle(.red.opacity(0.08))
                        .interpolationMethod(.catmullRom)
                        RuleMark(y: .value("Target", 75))
                            .foregroundStyle(.green.opacity(0.6))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                    .chartYAxisLabel("bpm")
                    .frame(height: 160)
                }
            }

            // Sleep chart
            statsCard(title: "SLEEP DURATION") {
                if sleepData.isEmpty {
                    emptyChartPlaceholder(message: "Apple Watch required for sleep data")
                } else {
                    Chart(sleepData) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Hours", item.value)
                        )
                        .foregroundStyle(.indigo.opacity(0.75))
                        .cornerRadius(4)
                        RuleMark(y: .value("Target", 7.5))
                            .foregroundStyle(.green.opacity(0.6))
                            .lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                    .chartYAxisLabel("hrs")
                    .frame(height: 160)
                }
            }

            // Current live metrics summary
            statsCard(title: "TODAY'S METRICS") {
                let m = healthService.latest
                HStack(spacing: 0) {
                    volumeStatCell(value: m.hrv.map { String(format: "%.0f", $0) } ?? "—",
                                   label: "HRV (ms)")
                    Divider().frame(height: 40)
                    volumeStatCell(value: m.restingHR.map { String(format: "%.0f", $0) } ?? "—",
                                   label: "Rest HR")
                    Divider().frame(height: 40)
                    volumeStatCell(value: m.sleepHours.map { String(format: "%.1f", $0) } ?? "—",
                                   label: "Sleep (h)")
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Shared UI helpers
    // ─────────────────────────────────────────────────────

    private func rangePicker<T: RawRepresentable & CaseIterable & Hashable>(
        cases: [T], selected: Binding<T>
    ) -> some View where T.RawValue == String {
        HStack(spacing: 8) {
            ForEach(cases, id: \.self) { opt in
                Button(opt.rawValue) { selected.wrappedValue = opt }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected.wrappedValue == opt ? .white : .secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        selected.wrappedValue == opt
                            ? Color.blue.opacity(0.8)
                            : Color.white.opacity(0.1),
                        in: Capsule()
                    )
                    .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func statsCard<Content: View>(title: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.7))
                .tracking(1.5)
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func summaryCard(title: String, value: String,
                              delta: String?, deltaUp: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
            if let d = delta {
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(deltaUp ? Color.green : Color.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func volumeStatCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyChartPlaceholder(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private func measurementRow(_ label: String, value: Double?, unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.1f \(unit)", $0) } ?? "—")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Data computation helpers
    // ─────────────────────────────────────────────────────

    // ChartPoint used for all charts
    struct ChartPoint: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let value: Double
    }

    private func weeklyTonnageData() -> [ChartPoint] {
        let calendar = Calendar.current
        let weeksBack = volumeRange == .weeks4 ? 4 : volumeRange == .weeks8 ? 8 : 12
        let now = Date()

        return (0..<weeksBack).reversed().compactMap { w -> ChartPoint? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -w, to: now),
                  let weekEnd   = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return nil }
            let tonnage = dataStore.dailyLogs
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .flatMap { $0.exerciseLogs.values }
                .map { $0.totalVolume }
                .reduce(0, +)
            let label = "W-\(w == 0 ? "0" : "\(w)")"
            return ChartPoint(label: label, date: weekStart, value: tonnage)
        }
    }

    private func topExerciseVolume() -> [ChartPoint] {
        let weeksBack = volumeRange == .weeks4 ? 4 : volumeRange == .weeks8 ? 8 : 12
        let cutoff = Date().addingTimeInterval(-Double(weeksBack) * 7 * 86400)
        var totals: [String: (Double, String)] = [:]
        for log in dataStore.dailyLogs where log.date >= cutoff {
            for exLog in log.exerciseLogs.values {
                let cur = totals[exLog.exerciseID]?.0 ?? 0
                totals[exLog.exerciseID] = (cur + exLog.totalVolume, exLog.exerciseName)
            }
        }
        return totals.sorted { $0.value.0 > $1.value.0 }
            .prefix(5)
            .map { ChartPoint(label: $0.value.1, date: Date(), value: $0.value.0) }
    }

    private func weeklyVolumeSummary() -> (Double, Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else {
            return (0, 0)
        }
        let thisWeek = dataStore.dailyLogs
            .filter { $0.date >= thisWeekStart }
            .flatMap { $0.exerciseLogs.values }.map { $0.totalVolume }.reduce(0, +)
        let lastWeek = dataStore.dailyLogs
            .filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
            .flatMap { $0.exerciseLogs.values }.map { $0.totalVolume }.reduce(0, +)
        return (thisWeek, lastWeek)
    }

    private func setsRepsThisWeek() -> (Int, Int) {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return (0, 0)
        }
        let logs = dataStore.dailyLogs.filter { $0.date >= weekStart }
        let sets = logs.flatMap { $0.exerciseLogs.values }.map { $0.sets.count }.reduce(0, +)
        let reps = logs.flatMap { $0.exerciseLogs.values }
            .flatMap { $0.sets }
            .compactMap { $0.repsCompleted }
            .reduce(0, +)
        return (sets, reps)
    }

    private func sessionsThisWeek() -> Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return dataStore.dailyLogs.filter { $0.date >= weekStart && $0.dayType.isTrainingDay && $0.completionPct > 0 }.count
    }

    private func bodyRangeDays() -> Int {
        switch bodyRange { case .days30: 30; case .days90: 90; case .days180: 180 }
    }

    private func healthRangeDays() -> Int {
        switch healthRange { case .days7: 7; case .days30: 30 }
    }

    private func weightTrendData(days: Int) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return dataStore.dailyLogs
            .filter { $0.date >= cutoff }
            .compactMap { log -> ChartPoint? in
                guard let w = log.biometrics.weightKg else { return nil }
                return ChartPoint(label: "", date: log.date, value: w)
            }
            .sorted { $0.date < $1.date }
    }

    private func bfTrendData(days: Int) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return dataStore.dailyLogs
            .filter { $0.date >= cutoff }
            .compactMap { log -> ChartPoint? in
                guard let bf = log.biometrics.bodyFatPercent else { return nil }
                return ChartPoint(label: "", date: log.date, value: bf)
            }
            .sorted { $0.date < $1.date }
    }

    private func hrvTrendData(days: Int) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return dataStore.dailyLogs
            .filter { $0.date >= cutoff }
            .compactMap { log -> ChartPoint? in
                guard let v = log.biometrics.effectiveHRV else { return nil }
                return ChartPoint(label: "", date: log.date, value: v)
            }
            .sorted { $0.date < $1.date }
    }

    private func rhrTrendData(days: Int) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return dataStore.dailyLogs
            .filter { $0.date >= cutoff }
            .compactMap { log -> ChartPoint? in
                guard let v = log.biometrics.effectiveRestingHR else { return nil }
                return ChartPoint(label: "", date: log.date, value: v)
            }
            .sorted { $0.date < $1.date }
    }

    private func sleepTrendData(days: Int) -> [ChartPoint] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return dataStore.dailyLogs
            .filter { $0.date >= cutoff }
            .compactMap { log -> ChartPoint? in
                guard let v = log.biometrics.effectiveSleep else { return nil }
                return ChartPoint(label: "", date: log.date, value: v)
            }
            .sorted { $0.date < $1.date }
    }

    private func deltaString(current: Double, previous: Double, unit: String) -> String? {
        guard previous > 0 else { return nil }
        let d = current - previous
        return String(format: "%+.0f \(unit) vs last week", d)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Settings View (macOS)
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
