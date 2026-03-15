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

    // CTA sheet state
    @State private var showBiometricEntry = false
    @State private var showTrainingPlan   = false
    @State private var showNutritionAlert = false

    // Shared chart tooltip state — one tooltip shows at a time
    @State private var chartSelection: (date: Date, label: String)? = nil

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

    private var latestBodyLog: DailyLog? {
        let (from, to) = dateRange
        return dataStore.dailyLogs
            .filter { log in
                log.date >= from && log.date <= to &&
                (log.biometrics.weightKg != nil ||
                 log.biometrics.bodyFatPercent != nil ||
                 log.biometrics.leanBodyMassKg != nil ||
                 log.biometrics.bodyWaterPercent != nil ||
                 log.biometrics.visceralFatRating != nil)
            }
            .sorted { $0.date > $1.date }
            .first
    }

    private var bodyInsights: [String] {
        guard !bodyData.isEmpty else {
            return ["Log body metrics a few times this period to unlock period averages and trend stories."]
        }

        var notes: [String] = []

        let recentWeight = bodyData.compactMap(\.weightKg)
        let recentBF = bodyData.compactMap(\.bodyFatPercent)
        let recentLean = bodyData.compactMap(\.leanBodyMassKg)

        if recentWeight.count >= 2 {
            let delta = recentWeight.last! - recentWeight.first!
            if abs(delta) < 0.2 {
                notes.append("Weight has been steady over the selected period, which usually means the trend is reliable.")
            } else if delta < 0 {
                notes.append(String(format: "Weight is down %.1f kg across entries this period, which is aligned with the cut.", abs(delta)))
            } else {
                notes.append(String(format: "Weight is up %.1f kg across entries this period, so review calorie consistency before changing training.", delta))
            }
        }

        if recentBF.count >= 2 {
            let delta = recentBF.last! - recentBF.first!
            if delta < -0.2 {
                notes.append(String(format: "Body fat is trending down by %.1f%%, which is a strong signal that the plan is working.", abs(delta)))
            } else if delta > 0.2 {
                notes.append(String(format: "Body fat is up %.1f%% this period, so use nutrition and recovery consistency as the first correction.", delta))
            }
        }

        if recentLean.count >= 2 {
            let delta = recentLean.last! - recentLean.first!
            if delta > 0.2 {
                notes.append(String(format: "Lean mass is up %.1f kg across entries this period, which is the best sign the cut is preserving muscle.", delta))
            } else if delta < -0.2 {
                notes.append(String(format: "Lean mass is off by %.1f kg, so keep protein and recovery high while you monitor the next few entries.", abs(delta)))
            }
        }

        if let latest = latestBodyLog?.biometrics.bodyWaterPercent, latest < 50 {
            notes.append(String(format: "Body water is %.1f%%, so hydration probably needs attention before interpreting the next weigh-in too aggressively.", latest))
        }

        if notes.isEmpty {
            notes.append("The current body data set is still small, so focus on logging a few more consistent check-ins before reacting to single-day swings.")
        }

        return Array(notes.prefix(3))
    }

    private var weeklyAverageSummary: [(label: String, value: String, tint: Color)] {
        let weightAvg = average(of: bodyData.compactMap(\.weightKg))
        let bfAvg = average(of: bodyData.compactMap(\.bodyFatPercent))
        let leanAvg = average(of: bodyData.compactMap(\.leanBodyMassKg))

        return [
            ("Avg Weight", weightAvg.map { String(format: "%.1f kg", $0) } ?? "—", Color.appOrange2),
            ("Avg Body Fat", bfAvg.map { String(format: "%.1f%%", $0) } ?? "—", Color.status.warning),
            ("Avg Lean Mass", leanAvg.map { String(format: "%.1f kg", $0) } ?? "—", Color.accent.cyan)
        ]
    }

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
        .sheet(isPresented: $showBiometricEntry) {
            ManualBiometricEntry()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTrainingPlan) {
            TrainingPlanView()
                .presentationDetents([.large])
        }
        .alert("Log Your Nutrition", isPresented: $showNutritionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Switch to the Nutrition tab to log your meals and supplements.")
        }
    }

    // MARK: – Body Section

    private var bodySection: some View {
        VStack(spacing: 16) {
            if !bodyData.isEmpty {
                bodyStoryCard
                insightFeedCard
            }
            latestSnapshotCard

            // Weight chart
            ChartCard(title: "Weight", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.weightKg).isEmpty {
                    EmptyStateView(icon: "scalemass", title: "No weight data", subtitle: "Log your weight to see the chart",
                                   ctaLabel: "Log Weight", ctaAction: { showBiometricEntry = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = bodyData.filter({ $0.weightKg != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.1f kg", pt.weightKg!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // Body Fat chart
            ChartCard(title: "Body Fat %", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.bodyFatPercent).isEmpty {
                    EmptyStateView(icon: "drop", title: "No body fat data", subtitle: "Log your body fat to see the chart",
                                   ctaLabel: "Log Body Fat", ctaAction: { showBiometricEntry = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = bodyData.filter({ $0.bodyFatPercent != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.1f%%", pt.bodyFatPercent!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // Lean Mass chart
            ChartCard(title: "Lean Mass", periodLabel: period.rawValue) {
                if bodyData.compactMap(\.leanBodyMassKg).isEmpty {
                    EmptyStateView(icon: "figure.arms.open", title: "No lean mass data", subtitle: "Log your body composition to see the chart",
                                   ctaLabel: "Log Body Composition", ctaAction: { showBiometricEntry = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = bodyData.filter({ $0.leanBodyMassKg != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.1f kg", pt.leanBodyMassKg!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
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

    private var bodyStoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress Story")
                        .font(AppType.headline)
                    Text("Period averages make the signal easier to trust than any single weigh-in.")
                        .font(AppType.subheading)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let latestDate = latestBodyLog?.date {
                    Text(latestDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                ForEach(weeklyAverageSummary, id: \.label) { item in
                    StatPreviewPill(value: item.value, label: item.label, color: item.tint)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.16))
        )
    }

    private var latestSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest Body Snapshot")
                    .font(AppType.headline)
                Spacer()
                Text(latestBodyLog?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let latest = latestBodyLog?.biometrics {
                let items: [(String, String, Color)] = [
                    ("Weight", latest.weightKg.map { String(format: "%.1f kg", $0) } ?? "—", Color.appOrange2),
                    ("Body Fat", latest.bodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "—", Color.status.warning),
                    ("Lean Mass", latest.leanBodyMassKg.map { String(format: "%.1f kg", $0) } ?? "—", Color.accent.cyan),
                    ("Body Water", latest.bodyWaterPercent.map { String(format: "%.1f%%", $0) } ?? "—", Color.appBlue2),
                    ("Muscle Mass", latest.muscleMassKg.map { String(format: "%.1f kg", $0) } ?? "—", Color.status.success),
                    ("Visceral Fat", latest.visceralFatRating.map(String.init) ?? "—", Color.accent.purple)
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.0) { item in
                        bodySnapshotTile(title: item.0, value: item.1, tint: item.2)
                    }
                }
            } else {
                EmptyStateView(
                    icon: "figure.arms.open",
                    title: "No composition snapshot yet",
                    subtitle: "Once you log weight and body composition, this section becomes your latest trusted check-in.",
                    ctaLabel: "Log Metrics",
                    ctaAction: { showBiometricEntry = true }
                )
                .frame(height: 120)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.14))
        )
    }

    private var insightFeedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insight Feed")
                .font(AppType.headline)

            ForEach(Array(bodyInsights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accent.cyan)
                        .padding(.top, 2)
                    Text(insight)
                        .font(AppType.subheading)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.12))
        )
    }

    // MARK: – Training Section

    private var trainingSection: some View {
        VStack(spacing: 16) {
            // Training Volume chart
            ChartCard(title: "Training Volume", periodLabel: period.rawValue) {
                if volumeData.isEmpty {
                    EmptyStateView(icon: "dumbbell.fill", title: "No training data", subtitle: "Log a workout to see your volume chart",
                                   ctaLabel: "Open Training Plan", ctaAction: { showTrainingPlan = true })
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
                        // PR gold star annotations — one star per date a personal record was set
                        let prDates: Set<Date> = {
                            let (from, to) = dateRange
                            let cal = Calendar.current
                            return Set(
                                dataStore.prRecords().values
                                    .filter { $0.date >= from && $0.date <= to }
                                    .map { cal.startOfDay(for: $0.date) }
                            )
                        }()
                        ForEach(volumeData.filter { prDates.contains(Calendar.current.startOfDay(for: $0.date)) }, id: \.date) { p in
                            PointMark(x: .value("Date", p.date), y: .value("kg", p.volumeKg))
                                .foregroundStyle(Color.accent.gold)
                                .symbolSize(120)
                                .annotation(position: .top) {
                                    Text("★")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.accent.gold)
                                }
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = volumeData
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    let formatted = pt.volumeKg >= 1000
                                                        ? String(format: "%,.0f kg vol", pt.volumeKg)
                                                        : String(format: "%.0f kg vol", pt.volumeKg)
                                                    chartSelection = (date: pt.date, label: formatted)
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // Zone 2 chart
            ChartCard(title: "Zone 2 Cardio", periodLabel: period.rawValue) {
                if zone2Data.isEmpty {
                    EmptyStateView(icon: "heart.circle", title: "No Zone 2 data", subtitle: "Log cardio with HR 106–124 bpm to see this chart",
                                   ctaLabel: "Open Training Plan", ctaAction: { showTrainingPlan = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = recoveryData.filter({ $0.hrv != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.0f ms", pt.hrv!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = recoveryData.filter({ $0.restingHR != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.0f bpm", pt.restingHR!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = recoveryData.filter({ $0.sleepHours != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.1f hrs", pt.sleepHours!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = pts
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: "Score: \(pt.score)"
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
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
                    EmptyStateView(icon: "fork.knife", title: "No calorie data", subtitle: "Log your meals to see the chart",
                                   ctaLabel: "Go to Nutrition", ctaAction: { showNutritionAlert = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = nutritionData.filter({ $0.calories != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    let kcal = pt.calories!
                                                    let formatted = kcal >= 1000
                                                        ? String(format: "%,.0f kcal", kcal)
                                                        : String(format: "%.0f kcal", kcal)
                                                    chartSelection = (date: pt.date, label: formatted)
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // Protein chart
            ChartCard(title: "Protein", periodLabel: period.rawValue) {
                if nutritionData.compactMap(\.proteinG).isEmpty {
                    EmptyStateView(icon: "fork.knife", title: "No protein data", subtitle: "Log your meals to see the chart",
                                   ctaLabel: "Go to Nutrition", ctaAction: { showNutritionAlert = true })
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
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotAreaFrame].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let pt = nutritionData.filter({ $0.proteinG != nil })
                                                    .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    chartSelection = (
                                                        date: pt.date,
                                                        label: String(format: "%.0f g", pt.proteinG!)
                                                    )
                                                }
                                            }
                                        }
                                        .onEnded { _ in chartSelection = nil }
                                )
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let sel = chartSelection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(AppType.caption)
                                    .foregroundStyle(.secondary)
                                Text(sel.label)
                                    .font(AppType.body.weight(.semibold))
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 4)
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // Supplement adherence chart
            ChartCard(title: "Supplement Adherence", periodLabel: period.rawValue) {
                if nutritionData.isEmpty {
                    EmptyStateView(icon: "pill.fill", title: "No supplement data", subtitle: "Log your supplements to see adherence",
                                   ctaLabel: "Go to Nutrition", ctaAction: { showNutritionAlert = true })
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
    let value: String
    let label: String
    var color: Color = Color.status.success
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension StatsView {
    func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    @ViewBuilder
    func bodySnapshotTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .tracking(1)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
