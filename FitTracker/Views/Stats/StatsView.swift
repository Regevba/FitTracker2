// HISTORICAL — superseded by v2/StatsView.swift on 2026-04-10 per
// UX Foundations alignment pass. See
// .claude/features/stats-v2/v2-audit-report.md for the gap analysis.
// This file is no longer in the build target; it stays in the repo
// as a reviewable reference for the v1 → v2 diff.

import SwiftUI
import Charts

enum StatsPeriod_V1_Historical: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case threeMonths = "3M"
    case sixMonths = "6M"

    var periodLabel: String {
        switch self {
        case .daily:
            return "Today"
        case .weekly:
            return "Last 7 days"
        case .monthly:
            return "This month"
        case .threeMonths:
            return "Last 3 months"
        case .sixMonths:
            return "Last 6 months"
        }
    }

    var dateRange: (from: Date, to: Date) {
        let calendar = Calendar.current
        let now = Date()
        let todayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        switch self {
        case .daily:
            return (calendar.startOfDay(for: now), todayEnd)
        case .weekly:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return (start, todayEnd)
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return (monthStart, todayEnd)
        case .threeMonths:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .month, value: -2, to: monthStart) ?? monthStart
            return (start, todayEnd)
        case .sixMonths:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .month, value: -5, to: monthStart) ?? monthStart
            return (start, todayEnd)
        }
    }
}

enum StatsFocusMetric_V1_Historical: String, CaseIterable, Identifiable {
    case weight
    case bodyFat
    case readiness
    case sleep
    case hrv
    case restingHeartRate
    case trainingVolume
    case zone2
    case steps
    case activeCalories
    case vo2Max
    case leanMass
    case muscleMass
    case bodyWater
    case visceralFat
    case protein
    case calories
    case supplementAdherence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .bodyFat:
            return "Body Fat %"
        case .readiness:
            return "Readiness"
        case .sleep:
            return "Sleep"
        case .hrv:
            return "HRV"
        case .restingHeartRate:
            return "Resting HR"
        case .trainingVolume:
            return "Training Volume"
        case .zone2:
            return "Zone 2"
        case .steps:
            return "Steps"
        case .activeCalories:
            return "Active Calories"
        case .vo2Max:
            return "VO2 Max"
        case .leanMass:
            return "Lean Mass"
        case .muscleMass:
            return "Muscle Mass"
        case .bodyWater:
            return "Body Water"
        case .visceralFat:
            return "Visceral Fat"
        case .protein:
            return "Protein"
        case .calories:
            return "Calories"
        case .supplementAdherence:
            return "Supplement Adherence"
        }
    }

    var icon: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .bodyFat:
            return "drop.fill"
        case .readiness:
            return "sparkles"
        case .sleep:
            return "bed.double.fill"
        case .hrv:
            return "waveform.path.ecg"
        case .restingHeartRate:
            return "heart.fill"
        case .trainingVolume:
            return "dumbbell.fill"
        case .zone2:
            return "heart.circle.fill"
        case .steps:
            return "figure.walk"
        case .activeCalories:
            return "flame.fill"
        case .vo2Max:
            return "lungs.fill"
        case .leanMass:
            return "figure.arms.open"
        case .muscleMass:
            return "figure.strengthtraining.traditional"
        case .bodyWater:
            return "drop.circle.fill"
        case .visceralFat:
            return "dot.scope"
        case .protein:
            return "fork.knife"
        case .calories:
            return "flame.circle.fill"
        case .supplementAdherence:
            return "pill.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight:
            return AppColor.Brand.warm
        case .bodyFat:
            return AppColor.Status.warning
        case .readiness:
            return AppColor.Accent.recovery
        case .sleep:
            return AppColor.Accent.sleep
        case .hrv:
            return AppColor.Accent.recovery
        case .restingHeartRate:
            return AppColor.Status.error
        case .trainingVolume:
            return AppColor.Accent.recovery
        case .zone2:
            return AppColor.Status.success
        case .steps:
            return AppColor.Brand.secondary
        case .activeCalories:
            return AppColor.Brand.warmSoft
        case .vo2Max:
            return AppColor.Status.success
        case .leanMass:
            return AppColor.Accent.recovery
        case .muscleMass:
            return AppColor.Status.success
        case .bodyWater:
            return AppColor.Brand.secondary
        case .visceralFat:
            return AppColor.Accent.sleep
        case .protein:
            return AppColor.Status.success
        case .calories:
            return AppColor.Brand.warmSoft
        case .supplementAdherence:
            return AppColor.Accent.achievement
        }
    }

    var positiveIsGood: Bool {
        switch self {
        case .weight, .bodyFat, .restingHeartRate, .visceralFat:
            return false
        case .calories:
            return true
        default:
            return true
        }
    }

    var usesBars: Bool {
        switch self {
        case .trainingVolume, .zone2, .steps, .activeCalories, .supplementAdherence:
            return true
        default:
            return false
        }
    }

    var isPermanent: Bool {
        self == .weight || self == .bodyFat
    }

    var emptyStateTitle: String {
        "No \(title.lowercased()) data"
    }

    var emptyStateSubtitle: String {
        switch self {
        case .weight, .bodyFat, .leanMass, .muscleMass, .bodyWater, .visceralFat:
            return "Log body metrics or sync a smart scale to populate this chart."
        case .readiness, .sleep, .hrv, .restingHeartRate, .steps, .activeCalories, .vo2Max:
            return "Apple Health and Apple Watch data will show here once available."
        case .trainingVolume, .zone2:
            return "Log workouts and cardio sessions to populate this chart."
        case .protein, .calories, .supplementAdherence:
            return "Log nutrition and supplements to populate this chart."
        }
    }
}

private struct MetricSeriesPoint_V1_Historical: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct StatsView_V1_Historical: View {
    var initialMetric: StatsFocusMetric?

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService

    @State private var period: StatsPeriod = .monthly
    @State private var selectedMetric: StatsFocusMetric = .readiness

    @State private var showBiometricEntry = false
    @State private var showTrainingPlan = false
    @State private var showNutritionAlert = false
    @State private var chartSelection: (date: Date, label: String)?

    private var carouselMetrics: [StatsFocusMetric] {
        let preferred = dataStore.userPreferences.preferredStatsCarouselMetrics
            .compactMap(StatsFocusMetric.init(rawValue:))
            .filter { !$0.isPermanent }

        return preferred.isEmpty ? UserPreferences.defaultStatsCarouselMetrics.compactMap(StatsFocusMetric.init(rawValue:)) : preferred
    }

    private var dateRange: (from: Date, to: Date) { period.dateRange }

    private var bodyData: [(date: Date, weightKg: Double?, bodyFatPercent: Double?, leanBodyMassKg: Double?)] {
        dataStore.bodyCompositionPoints(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var bodyDetailData: [(date: Date, bodyWaterPercent: Double?, muscleMassKg: Double?, visceralFatRating: Double?)] {
        dataStore.bodyCompositionDetailPoints(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var volumeData: [(date: Date, volumeKg: Double)] {
        dataStore.trainingVolumePoints(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var zone2Data: [(date: Date, minutes: Double)] {
        dataStore.zone2Minutes(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var activityData: [(date: Date, steps: Double?, activeCalories: Double?, vo2Max: Double?)] {
        dataStore.activityPoints(
            from: dateRange.from,
            to: dateRange.to,
            period: period,
            fallbackMetrics: healthService.latest
        )
    }

    private var recoveryData: [(date: Date, hrv: Double?, restingHR: Double?, sleepHours: Double?)] {
        dataStore.recoveryPoints(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var nutritionData: [(date: Date, calories: Double?, proteinG: Double?, supplementPct: Double)] {
        dataStore.nutritionAdherencePoints(from: dateRange.from, to: dateRange.to, period: period)
    }

    private var readinessData: [(date: Date, score: Int)] {
        dataStore.readinessPoints(
            from: dateRange.from,
            to: dateRange.to,
            period: period,
            fallbackMetrics: healthService.latest
        )
    }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    periodPicker
                    permanentBodyCharts
                    metricCarouselSection
                    selectedMetricSection
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.top, AppSpacing.xSmall)
                .padding(.bottom, AppSpacing.large)
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let initialMetric {
                selectedMetric = initialMetric
            } else {
                syncSelectedMetric()
            }
        }
        .onChange(of: period) { _, _ in
            chartSelection = nil
        }
        .onChange(of: dataStore.userPreferences.preferredStatsCarouselMetrics) { _, _ in
            syncSelectedMetric()
        }
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
            Text("Switch to the Nutrition tab to log meals and supplements.")
        }
    }

    private var periodPicker: some View {
        HStack(spacing: AppSpacing.xSmall) {
            ForEach(StatsPeriod.allCases, id: \.self) { option in
                let isSelected = option == period

                Button {
                    period = option
                } label: {
                    Text(option.rawValue)
                        .font(AppText.captionStrong)
                        .foregroundStyle(isSelected ? AppColor.Text.primary : AppColor.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.small)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? AppColor.Surface.elevated : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.xSmall)
        .background(
            Capsule(style: .continuous)
                .fill(AppColor.Surface.materialStrong)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppColor.Border.subtle, lineWidth: 1)
        )
    }

    private var permanentBodyCharts: some View {
        VStack(spacing: AppSpacing.xSmall) {
            metricCard(for: .weight)
            metricCard(for: .bodyFat)
        }
    }

    private var metricCarouselSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                Text("Track More")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
                Text("Choose what appears here in Settings, then tap a metric to update the chart below.")
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xxSmall) {
                    ForEach(carouselMetrics) { metric in
                        metricChip(metric)
                    }
                }
                .padding(.vertical, AppSpacing.micro)
            }
        }
    }

    private var selectedMetricSection: some View {
        metricCard(for: selectedMetric)
    }

    @ViewBuilder
    private func metricCard(for metric: StatsFocusMetric) -> some View {
        let points = series(for: metric)
        ChartCard(
            title: metric.title,
            periodLabel: period.periodLabel,
            trendDelta: deltaValue(from: points.map(\.value)),
            positiveIsGood: metric.positiveIsGood
        ) {
            if points.isEmpty {
                EmptyStateView(
                    icon: metric.icon,
                    title: metric.emptyStateTitle,
                    subtitle: metric.emptyStateSubtitle,
                    ctaLabel: ctaLabel(for: metric),
                    ctaAction: ctaAction(for: metric)
                )
                .frame(height: 128)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    metricHeader(for: metric, points: points)
                    chartBody(points: points, metric: metric)
                }
            }
        }
    }

    private func metricChip(_ metric: StatsFocusMetric) -> some View {
        let selected = selectedMetric == metric
        let value = metricPrimaryValue(for: metric)
        let subtitle = metricChipSubtitle(for: metric)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMetric = metric
                chartSelection = nil
            }
        } label: {
            AppSelectionTile(isSelected: selected, tint: metric.tint, cornerRadius: AppRadius.large) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    HStack {
                        Image(systemName: metric.icon)
                            .font(AppText.captionStrong)
                        Spacer()
                        Circle()
                            .fill(metric.tint)
                            .frame(width: 8, height: 8)
                    }
                    .foregroundStyle(selected ? metric.tint : AppColor.Text.secondary)

                    Text(metric.title)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.primary)
                        .lineLimit(1)

                    Text(value)
                        .font(AppText.metricCompact)
                        .foregroundStyle(selected ? metric.tint : AppColor.Text.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 128, idealWidth: 144, maxWidth: 168, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.title) metric")
        .accessibilityValue(subtitle)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint("Tap to view chart for \(metric.title)")
    }

    private func metricHeader(for metric: StatsFocusMetric, points: [MetricSeriesPoint]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack(alignment: .lastTextBaseline, spacing: AppSpacing.xxSmall) {
                Text(metricPrimaryValue(for: metric))
                    .font(AppText.metric)
                    .foregroundStyle(metric.tint)
                    .lineLimit(1)

                Text(metricChipSubtitle(for: metric))
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(2)
            }

            Text(metricSummaryText(for: metric, points: points))
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }

    @ViewBuilder
    private func chartBody(points: [MetricSeriesPoint], metric: StatsFocusMetric) -> some View {
        let chart = Chart {
            if let goal = goalValue(for: metric) {
                RuleMark(y: .value("Target", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(metric.tint.opacity(0.45))
                    .annotation(position: .trailing) {
                        Text(goalLabel(for: metric))
                            .font(AppText.caption)
                            .foregroundStyle(metric.tint)
                    }
            }

            if metric.usesBars {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(metric.tint.gradient)
                }
            } else {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(metric.tint.opacity(0.18).gradient)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(metric.tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(metric == .readiness ? .catmullRom : .monotone)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(metric.tint)
                    .symbolSize(period == .daily ? 48 : 28)
                }
            }
        }
        .frame(height: 158)
        .chartXAxis { statsXAxis() }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(AppColor.Border.subtle.opacity(0.7))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let frame = proxy.plotFrame.map { geometry[$0] } ?? .zero
                                let localX = value.location.x - frame.origin.x
                                guard let date: Date = proxy.value(atX: localX) else { return }

                                if let point = nearestPoint(to: date, in: points) {
                                    chartSelection = (
                                        date: point.date,
                                        label: formattedValue(point.value, for: metric)
                                    )
                                }
                            }
                            .onEnded { _ in
                                chartSelection = nil
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if let selection = chartSelection {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(selection.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                    Text(selection.label)
                        .font(AppText.body.weight(.semibold))
                }
                .padding(AppSpacing.xxSmall)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.xSmall))
                .padding(.top, AppSpacing.xxxSmall)
                .padding(.leading, AppSpacing.xxxSmall)
            }
        }

        if metric == .readiness || metric == .supplementAdherence {
            chart
                .chartYScale(domain: 0...100)
        } else {
            chart
        }
    }

}

private extension StatsView {
    func syncSelectedMetric() {
        if let firstVisible = carouselMetrics.first, !carouselMetrics.contains(selectedMetric) {
            selectedMetric = firstVisible
        }
    }

    func series(for metric: StatsFocusMetric) -> [MetricSeriesPoint] {
        switch metric {
        case .weight:
            return bodyData.compactMap { row in
                row.weightKg.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .bodyFat:
            return bodyData.compactMap { row in
                row.bodyFatPercent.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .readiness:
            return readinessData.map { MetricSeriesPoint(date: $0.date, value: Double($0.score)) }
        case .sleep:
            return recoveryData.compactMap { row in
                row.sleepHours.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .hrv:
            return recoveryData.compactMap { row in
                row.hrv.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .restingHeartRate:
            return recoveryData.compactMap { row in
                row.restingHR.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .trainingVolume:
            return volumeData.map { MetricSeriesPoint(date: $0.date, value: $0.volumeKg) }
        case .zone2:
            return zone2Data.map { MetricSeriesPoint(date: $0.date, value: $0.minutes) }
        case .steps:
            return activityData.compactMap { row in
                row.steps.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .activeCalories:
            return activityData.compactMap { row in
                row.activeCalories.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .vo2Max:
            return activityData.compactMap { row in
                row.vo2Max.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .leanMass:
            return bodyData.compactMap { row in
                row.leanBodyMassKg.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .muscleMass:
            return bodyDetailData.compactMap { row in
                row.muscleMassKg.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .bodyWater:
            return bodyDetailData.compactMap { row in
                row.bodyWaterPercent.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .visceralFat:
            return bodyDetailData.compactMap { row in
                row.visceralFatRating.map { MetricSeriesPoint(date: row.date, value: Double($0)) }
            }
        case .protein:
            return nutritionData.compactMap { row in
                row.proteinG.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .calories:
            return nutritionData.compactMap { row in
                row.calories.map { MetricSeriesPoint(date: row.date, value: $0) }
            }
        case .supplementAdherence:
            return nutritionData.map { MetricSeriesPoint(date: $0.date, value: $0.supplementPct * 100) }
        }
    }

    func metricPrimaryValue(for metric: StatsFocusMetric) -> String {
        guard let latest = series(for: metric).last?.value else { return "—" }
        return formattedValue(latest, for: metric)
    }

    func metricChipSubtitle(for metric: StatsFocusMetric) -> String {
        let points = series(for: metric)
        guard !points.isEmpty else { return "No data yet" }

        if let delta = deltaValue(from: points.map(\.value)) {
            let change = formattedDelta(delta, for: metric)
            return change == "Stable" ? "Stable in this window" : change
        }

        return "\(points.count) \(points.count == 1 ? "reading" : "readings")"
    }

    func metricSummaryText(for metric: StatsFocusMetric, points: [MetricSeriesPoint]) -> String {
        let averageValue = average(of: points.map(\.value))
        let readingCount = "\(points.count) \(points.count == 1 ? "reading" : "readings")"

        if let averageValue {
            return "Average \(formattedValue(averageValue, for: metric)) across \(readingCount.lowercased())."
        }

        return "Collected \(readingCount.lowercased()) in this timeframe."
    }

    func formattedValue(_ value: Double, for metric: StatsFocusMetric) -> String {
        switch metric {
        case .weight, .leanMass, .muscleMass:
            return String(format: "%.1f kg", value)
        case .bodyFat, .bodyWater:
            return String(format: "%.1f%%", value)
        case .readiness, .supplementAdherence:
            return String(format: "%.0f%%", value == floor(value) ? value : value)
                .replacingOccurrences(of: "%", with: metric == .readiness ? "/100" : "%")
        case .sleep:
            return String(format: "%.1f h", value)
        case .hrv:
            return String(format: "%.0f ms", value)
        case .restingHeartRate:
            return String(format: "%.0f bpm", value)
        case .trainingVolume:
            return value >= 1000 ? String(format: "%.1fk kg", value / 1000) : String(format: "%.0f kg", value)
        case .zone2:
            return String(format: "%.0f min", value)
        case .steps:
            return value >= 1000 ? String(format: "%.1fk", value / 1000) : String(format: "%.0f", value)
        case .activeCalories, .calories:
            return String(format: "%.0f kcal", value)
        case .vo2Max:
            return String(format: "%.1f", value)
        case .visceralFat:
            return String(format: "%.0f", value)
        case .protein:
            return String(format: "%.0f g", value)
        }
    }

    func formattedDelta(_ delta: Double, for metric: StatsFocusMetric) -> String {
        guard abs(delta) > 0.001 else { return "Stable" }

        let sign = delta > 0 ? "+" : "-"
        switch metric {
        case .weight, .leanMass, .muscleMass:
            return String(format: "%@%.1f kg", sign, abs(delta))
        case .bodyFat, .bodyWater:
            return String(format: "%@%.1f%%", sign, abs(delta))
        case .readiness, .supplementAdherence:
            return String(format: "%@%.0f pts", sign, abs(delta))
        case .sleep:
            return String(format: "%@%.1f h", sign, abs(delta))
        case .hrv:
            return String(format: "%@%.0f ms", sign, abs(delta))
        case .restingHeartRate:
            return String(format: "%@%.0f bpm", sign, abs(delta))
        case .trainingVolume:
            return String(format: "%@%.0f kg", sign, abs(delta))
        case .zone2:
            return String(format: "%@%.0f min", sign, abs(delta))
        case .steps:
            return String(format: "%@%.0f", sign, abs(delta))
        case .activeCalories, .calories:
            return String(format: "%@%.0f kcal", sign, abs(delta))
        case .vo2Max:
            return String(format: "%@%.1f", sign, abs(delta))
        case .visceralFat:
            return String(format: "%@%.0f", sign, abs(delta))
        case .protein:
            return String(format: "%@%.0f g", sign, abs(delta))
        }
    }

    func goalValue(for metric: StatsFocusMetric) -> Double? {
        switch metric {
        case .weight:
            return dataStore.userProfile.targetWeightMax
        case .bodyFat:
            return dataStore.userProfile.targetBFMax
        case .protein:
            return dataStore.userProfile.currentPhase.proteinTargetG.upperBound
        case .calories:
            return Double(dataStore.userProfile.currentPhase.trainingCalories)
        default:
            return nil
        }
    }

    func goalLabel(for metric: StatsFocusMetric) -> String {
        switch metric {
        case .weight, .bodyFat, .protein, .calories:
            return "Target"
        default:
            return "Goal"
        }
    }

    func ctaLabel(for metric: StatsFocusMetric) -> String? {
        switch metric {
        case .weight, .bodyFat, .leanMass, .muscleMass, .bodyWater, .visceralFat:
            return "Log Metrics"
        case .trainingVolume, .zone2:
            return "Open Training"
        case .protein, .calories, .supplementAdherence:
            return "Go to Nutrition"
        default:
            return nil
        }
    }

    func ctaAction(for metric: StatsFocusMetric) -> (() -> Void)? {
        switch metric {
        case .weight, .bodyFat, .leanMass, .muscleMass, .bodyWater, .visceralFat:
            return { showBiometricEntry = true }
        case .trainingVolume, .zone2:
            return { showTrainingPlan = true }
        case .protein, .calories, .supplementAdherence:
            return { showNutritionAlert = true }
        default:
            return nil
        }
    }

    func nearestPoint(to date: Date, in points: [MetricSeriesPoint]) -> MetricSeriesPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func deltaValue(from values: [Double]) -> Double? {
        guard values.count >= 2, let first = values.first, let last = values.last else { return nil }
        return last - first
    }

    @AxisContentBuilder
    func statsXAxis() -> some AxisContent {
        switch period {
        case .daily:
            AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColor.Border.subtle.opacity(0.7))
                AxisValueLabel(format: .dateTime.hour())
            }
        case .weekly:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine().foregroundStyle(AppColor.Border.subtle.opacity(0.7))
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        case .monthly:
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine().foregroundStyle(AppColor.Border.subtle.opacity(0.7))
                AxisValueLabel(format: .dateTime.day())
            }
        case .threeMonths, .sixMonths:
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine().foregroundStyle(AppColor.Border.subtle.opacity(0.7))
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
    }
}
