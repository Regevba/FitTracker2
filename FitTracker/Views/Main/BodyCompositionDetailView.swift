// FitTracker/Views/Main/BodyCompositionDetailView.swift
// Full-screen body composition detail — weight & body fat charts, time-range
// picker, progress bars, and manual-entry CTA.
// Launched from the Home status card tap.

import SwiftUI
import Charts

struct BodyCompositionDetailView: View {

    // MARK: - External dependencies

    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var analytics: AnalyticsService

    @Environment(\.dismiss) var dismiss

    // MARK: - Local state

    @State private var selectedPeriod = 0  // 0=7d, 1=30d, 2=90d, 3=all
    @State private var showManualEntry = false

    // MARK: - Period helpers

    private let periodLabels = ["7d", "30d", "90d", "All"]

    private var periodDays: Int? {
        switch selectedPeriod {
        case 0: return 7
        case 1: return 30
        case 2: return 90
        default: return nil // all
        }
    }

    private var cutoffDate: Date? {
        guard let days = periodDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }

    // MARK: - Derived data

    private var profile: UserProfile { dataStore.userProfile }

    private var filteredLogs: [DailyLog] {
        let logs = dataStore.dailyLogs
        guard let cutoff = cutoffDate else { return logs }
        return logs.filter { $0.date >= cutoff }
    }

    /// Weight data points: (date, kg value).
    private var weightDataPoints: [(date: Date, value: Double)] {
        filteredLogs.compactMap { log in
            guard let w = log.biometrics.weightKg else { return nil }
            return (date: log.date, value: w)
        }.sorted { $0.date < $1.date }
    }

    /// Body fat data points: (date, percentage).
    private var bodyFatDataPoints: [(date: Date, value: Double)] {
        filteredLogs.compactMap { log in
            guard let bf = log.biometrics.bodyFatPercent else { return nil }
            return (date: log.date, value: bf)
        }.sorted { $0.date < $1.date }
    }

    private var currentWeight: Double? {
        weightDataPoints.last?.value
    }

    private var currentBF: Double? {
        bodyFatDataPoints.last?.value
    }

    private var weightProgress: Double {
        profile.weightProgress(current: currentWeight)
    }

    private var bfProgress: Double {
        profile.bfProgress(current: currentBF)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    periodPicker
                    weightChartSection
                    bodyFatChartSection
                    progressBarsSection
                    logMetricsCTA
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppColor.Background.appPrimary)
            .navigationTitle("Body Composition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Accent.primary)
                }
            }
            .analyticsScreen(AnalyticsScreen.bodyCompDetail)
            .sheet(isPresented: $showManualEntry) {
                ManualBiometricEntry()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("Time Range", selection: $selectedPeriod) {
            ForEach(0..<periodLabels.count, id: \.self) { index in
                Text(periodLabels[index]).tag(index)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _, newValue in
            let label = newValue < periodLabels.count ? periodLabels[newValue] : "unknown"
            analytics.logHomeBodyCompPeriodChanged(period: label)
        }
        .accessibilityLabel("Time range selector")
    }

    // MARK: - Weight chart section

    private var weightChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            // Section header
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: AppIcon.weight)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Chart.weight)
                Text("Weight")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
            }

            // Chart
            if weightDataPoints.isEmpty {
                chartEmptyState(metric: "weight")
            } else {
                Chart {
                    ForEach(weightDataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", settings.unitSystem == .metric ? point.value : point.value * 2.20462)
                        )
                        .foregroundStyle(AppColor.Chart.weight)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", settings.unitSystem == .metric ? point.value : point.value * 2.20462)
                        )
                        .foregroundStyle(AppColor.Chart.weight)
                        .symbolSize(30)
                    }

                    // Goal range rule marks
                    let targetMin = settings.unitSystem == .metric
                        ? profile.targetWeightMin
                        : profile.targetWeightMin * 2.20462
                    let targetMax = settings.unitSystem == .metric
                        ? profile.targetWeightMax
                        : profile.targetWeightMax * 2.20462

                    RuleMark(y: .value("Goal Min", targetMin))
                        .foregroundStyle(AppColor.Status.success.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                    RuleMark(y: .value("Goal Max", targetMax))
                        .foregroundStyle(AppColor.Status.success.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.Border.hairline)
                        AxisValueLabel()
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.Border.hairline)
                        AxisValueLabel()
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .frame(height: 200)
            }

            // Current vs goal summary
            weightSummaryLine
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private var weightSummaryLine: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Text("Current:")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Text(currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "--")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.primary)
                .monospacedDigit()
            Text(settings.unitSystem.weightLabel())
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)

            Spacer()

            Text("Goal:")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Text("\(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax))")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Status.success)
                .monospacedDigit()
            Text(settings.unitSystem.weightLabel())
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current weight \(currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "unknown") \(settings.unitSystem.weightLabel()), " +
            "goal \(settings.unitSystem.displayWeightValue(profile.targetWeightMin)) to \(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())"
        )
    }

    // MARK: - Body fat chart section

    private var bodyFatChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            // Section header
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: AppIcon.bodyFat)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Chart.body)
                Text("Body Fat")
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
            }

            // Chart
            if bodyFatDataPoints.isEmpty {
                chartEmptyState(metric: "body fat")
            } else {
                Chart {
                    ForEach(bodyFatDataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Body Fat", point.value)
                        )
                        .foregroundStyle(AppColor.Chart.body)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Body Fat", point.value)
                        )
                        .foregroundStyle(AppColor.Chart.body)
                        .symbolSize(30)
                    }

                    // Goal range rule marks
                    RuleMark(y: .value("Goal Min", profile.targetBFMin))
                        .foregroundStyle(AppColor.Status.success.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                    RuleMark(y: .value("Goal Max", profile.targetBFMax))
                        .foregroundStyle(AppColor.Status.success.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.Border.hairline)
                        AxisValueLabel()
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(AppColor.Border.hairline)
                        AxisValueLabel()
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                .frame(height: 200)
            }

            // Current vs goal summary
            bodyFatSummaryLine
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private var bodyFatSummaryLine: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Text("Current:")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Text(currentBF.map { String(format: "%.1f", $0) } ?? "--")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.primary)
                .monospacedDigit()
            Text("%")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)

            Spacer()

            Text("Goal:")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Text("\(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))")
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Status.success)
                .monospacedDigit()
            Text("%")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current body fat \(currentBF.map { String(format: "%.1f", $0) } ?? "unknown") percent, " +
            "goal \(Int(profile.targetBFMin)) to \(Int(profile.targetBFMax)) percent"
        )
    }

    // MARK: - Chart empty state

    private func chartEmptyState(metric: String) -> some View {
        VStack(spacing: AppSpacing.xSmall) {
            Image(systemName: AppIcon.chart)
                .font(AppText.iconLarge)
                .foregroundStyle(AppColor.Text.tertiary.opacity(0.5))
            Text("No \(metric) data yet")
                .font(AppText.callout)
                .foregroundStyle(AppColor.Text.tertiary)
            Text("Log your first measurement to see trends")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No \(metric) data available. Log a measurement to see trends.")
    }

    // MARK: - Progress bars section

    private var progressBarsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text("PROGRESS")
                .font(AppText.eyebrow)
                .tracking(2.1)
                .foregroundStyle(AppColor.Text.tertiary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            progressBar(
                title: "Weight",
                progress: weightProgress,
                tint: AppColor.Chart.weight
            )

            progressBar(
                title: "Body Fat",
                progress: bfProgress,
                tint: AppColor.Chart.body
            )
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private func progressBar(title: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
            HStack {
                Text(title)
                    .font(AppText.callout)
                    .foregroundStyle(AppColor.Text.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(AppText.callout)
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.micro, style: .continuous)
                        .fill(AppColor.Surface.tertiary)
                    RoundedRectangle(cornerRadius: AppRadius.micro, style: .continuous)
                        .fill(tint)
                        .frame(width: max(AppSize.progressBarHeight, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(height: AppSize.progressBarHeight)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    // MARK: - Log Metrics CTA

    private var logMetricsCTA: some View {
        Button {
            analytics.logHomeBodyCompLogTap()
            showManualEntry = true
        } label: {
            Text("Log Metrics")
                .font(AppText.button)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.ctaHeight)
                .background(
                    AppColor.Accent.primary,
                    in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                )
                .shadow(color: AppShadow.ctaColor, radius: AppShadow.ctaRadius, y: AppShadow.ctaYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log body composition metrics")
        .accessibilityHint("Opens the manual entry form for weight and body fat")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Body Composition Detail") {
    BodyCompositionDetailView()
        .environmentObject(EncryptedDataStore())
        .environmentObject(HealthKitService())
        .environmentObject(AppSettings())
        .environmentObject(AnalyticsService.makeDefault())
}
#endif
