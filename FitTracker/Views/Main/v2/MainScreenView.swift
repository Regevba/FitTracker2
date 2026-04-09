// FitTracker/Views/Main/v2/MainScreenView.swift
// Home v2 — scroll-based Today screen built bottom-up from design system tokens.
// Replaces the v1 GeometryReader-based fixed layout with a scrollable card stack.

import SwiftUI

struct MainScreenView: View {

    // MARK: - External dependencies

    @Binding var selectedTab: AppTab

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings
    @EnvironmentObject var analytics:     AnalyticsService

    // MARK: - Local state

    @State private var showExerciseSheet  = false
    @State private var manualEntry        = false
    @State private var showBodyCompDetail = false
    @State private var selectedRecoveryRoutine: RecoveryRoutine?
    @State private var selectedDayType: DayType? = nil

    @State private var readinessHapticDay: Date? = nil
    @State private var statusPulse = false
    @State private var shownMilestoneStreak: Int = 0
    @State private var shownMilestonePhase: ProgramPhase? = nil
    @State private var milestoneTitle: String? = nil
    @State private var milestoneMessage: String? = nil

    // MARK: - Derived data

    private var activeDayType: DayType {
        selectedDayType ?? programStore.todayDayType
    }

    private var profile: UserProfile  { dataStore.userProfile }
    private var metrics: LiveMetrics  { healthService.latest }
    private var todayLog: DailyLog?   { dataStore.todayLog() }

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

    private var readinessScore: Int? {
        dataStore.readinessScore(for: Date(), fallbackMetrics: metrics)
    }

    private var streakMilestone: Int? {
        let streak = dataStore.supplementStreak
        let milestones = [7, 14, 30, 60, 90]
        return milestones.first(where: { streak == $0 })
    }

    private var loggedMealCount: Int {
        todayLog?.nutritionLog.meals.filter { $0.status == .completed }.count ?? 0
    }

    private var completedSupplementStacks: Int {
        let morning = todayLog?.supplementLog.morningStatus == .completed ? 1 : 0
        let evening = todayLog?.supplementLog.eveningStatus == .completed ? 1 : 0
        return morning + evening
    }

    private var totalExerciseCount: Int {
        TrainingProgramData.exercises(for: activeDayType).count
    }

    private var recoveryRecommendation: RecoveryRecommendation {
        RecoveryRoutineLibrary.recommend(
            dayType: activeDayType,
            readinessScore: readinessScore,
            liveMetrics: metrics,
            log: todayLog,
            preferences: dataStore.userPreferences
        )
    }

    /// True when no meaningful data exists (first launch / no HealthKit / no logs).
    private var isEmpty: Bool {
        currentWeight == nil
            && currentBF == nil
            && metrics.hrv == nil
            && metrics.restingHR == nil
            && metrics.sleepHours == nil
            && metrics.stepCount == nil
            && todayLog == nil
    }

    private var emptyReason: EmptyReason {
        if dataStore.dailyLogs.isEmpty { return .firstLaunch }
        // If HealthKit metrics are all nil, likely not connected
        if metrics.hrv == nil && metrics.restingHR == nil && metrics.sleepHours == nil {
            return .noHealthKit
        }
        return .noData
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isEmpty {
                HomeEmptyStateView(
                    emptyReason: emptyReason,
                    onConnectHealth: {
                        Task { try? await healthService.requestAuthorization() }
                    },
                    onLogManually: {
                        manualEntry = true
                    }
                )
                .onAppear {
                    analytics.logHomeEmptyStateShown(
                        emptyReason: emptyReason.analyticsKey,
                        ctaShown: "both"
                    )
                }
            } else {
                scrollContent
            }
        }
        .analyticsScreen(AnalyticsScreen.home)
        .onAppear { checkMilestones() }
        .onChange(of: dataStore.supplementStreak) { _, _ in checkMilestones() }
        .onChange(of: dataStore.userProfile.currentPhase) { _, _ in checkMilestones() }
        .onChange(of: readinessScore) { _, newScore in
            guard newScore != nil else { return }
            let today: Date = Calendar.current.startOfDay(for: Date())
            let lastDay: Date? = readinessHapticDay.map { Calendar.current.startOfDay(for: $0) }
            guard lastDay != today else { return }
            readinessHapticDay = today
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        }
        .onChange(of: selectedTab) { _, _ in
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred()
        }
        .onChange(of: essentialMissingCount) { oldValue, newValue in
            guard oldValue != newValue else { return }
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(newValue < oldValue ? .success : .warning)
            withAnimation(AppSpring.snappy) {
                statusPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + AppDuration.long) {
                withAnimation(AppEasing.short) {
                    statusPulse = false
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { milestoneTitle != nil },
            set: { if !$0 { milestoneTitle = nil; milestoneMessage = nil } }
        )) {
            if let title = milestoneTitle, let msg = milestoneMessage {
                MilestoneModal(title: title, message: msg) {
                    milestoneTitle = nil
                    milestoneMessage = nil
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showExerciseSheet) {
            NavigationStack { TrainingPlanView(initialDay: activeDayType) }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $manualEntry) {
            ManualBiometricEntry()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBodyCompDetail) {
            NavigationStack {
                BodyCompositionDetailView()
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(AppRadius.large)
        }
        .sheet(item: $selectedRecoveryRoutine) { routine in
            NavigationStack {
                RecoveryRoutineSheet(
                    routine: routine,
                    reasons: routine.id == recoveryRecommendation.routine.id
                        ? recoveryRecommendation.reasons
                        : []
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { selectedRecoveryRoutine = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(AppRadius.large)
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                greetingSection
                readinessSection
                trainingNutritionCard
                bodyCompositionCard
                metricsRow
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Greeting section
    // ─────────────────────────────────────────────────────

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    LiveInfoStrip(slides: greetingSlides)
                        .accessibilityAddTraits(.isHeader)

                    Text(todayFormatted)
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Text.secondary)
                        .accessibilityLabel("Today is \(todayFormatted)")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.xxSmall) {
                    Text("Day \(profile.daysSinceStart)")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                        .accessibilityLabel("Day \(profile.daysSinceStart) of program")
                    Text(profile.currentPhase.rawValue)
                        .font(AppText.caption)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(AppColor.Surface.tertiary, in: Capsule())
                        .foregroundStyle(AppColor.Text.secondary)
                        .accessibilityLabel("Current phase: \(profile.currentPhase.rawValue)")
                }
            }
        }
    }

    private var greetingSlides: [InfoSlide] {
        var slides: [InfoSlide] = [
            InfoSlide(text: greeting)
        ]
        let streak = dataStore.supplementStreak
        if streak >= 3 {
            slides.append(InfoSlide(
                text: "\(streak)-day supplement streak",
                icon: AppIcon.fire,
                color: AppColor.Brand.primary
            ))
        }
        return slides
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Readiness section
    // ─────────────────────────────────────────────────────

    private var readinessSection: some View {
        ReadinessCard()
            .accessibilityLabel(readinessScore.map { "Readiness score: \($0) out of 100" } ?? "Readiness score unavailable")
            .accessibilityHint("Swipe to see training, nutrition, trends, achievements, and recovery details")
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Training & Nutrition card
    // ─────────────────────────────────────────────────────

    private var trainingNutritionCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            // Context line
            Text(trainingContextLine)
                .font(AppText.callout)
                .foregroundStyle(AppColor.Text.secondary)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Today's plan: \(trainingContextLine)")

            // Two equal-width CTA buttons
            HStack(spacing: AppSpacing.xSmall) {
                Button {
                    performHomeAction("start_workout") {
                        if recoveryRecommendation.shouldReplaceTraining {
                            selectedRecoveryRoutine = recoveryRecommendation.routine
                        } else {
                            showExerciseSheet = true
                        }
                    }
                } label: {
                    Text(primaryActionTitle)
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .background(
                            recommendationAccent,
                            in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primaryActionTitle)
                .accessibilityHint("Starts your recommended activity for today")

                Button {
                    performHomeAction("log_meal") {
                        selectedTab = .nutrition
                    }
                } label: {
                    Text("Log Meal")
                        .font(AppText.button)
                        .foregroundStyle(AppColor.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppSize.ctaHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                                .strokeBorder(AppColor.Accent.primary, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log Meal")
                .accessibilityHint("Navigates to the nutrition tab to log a meal")
            }
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private var trainingContextLine: String {
        let dayLabel = activeDayType.rawValue
        let minutes = estimatedSessionMinutes
        let recTitle = recommendation.title
        return "\(dayLabel) \u{00B7} \(minutes)m \u{00B7} \(recTitle)"
    }

    private var estimatedSessionMinutes: Int {
        if recoveryRecommendation.shouldReplaceTraining {
            return recoveryRecommendation.routine.durationMinutes
        }
        return max(20, totalExerciseCount * (activeDayType.isTrainingDay ? 6 : 4))
    }

    private var recommendation: HomeRecommendation {
        HomeRecommendationProvider.recommendation(
            readinessScore: readinessScore,
            isRestDay: !activeDayType.isTrainingDay,
            streakDays: dataStore.supplementStreak
        )
    }

    private var primaryActionTitle: String {
        recoveryRecommendation.shouldReplaceTraining ? "Start Recovery" : "Start Workout"
    }

    private var recommendationAccent: Color {
        switch readinessScore ?? 65 {
        case 80...:    return AppColor.Status.success
        case 60..<80:  return AppColor.Accent.primary
        case 40..<60:  return AppColor.Status.warning
        default:       return AppColor.Status.error
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Body Composition Card (replaces statusCard + goalCard)
    // ─────────────────────────────────────────────────────

    private var bodyCompositionCard: some View {
        BodyCompositionCard(
            currentWeight: currentWeight,
            currentBF: currentBF,
            weightTarget: (min: profile.targetWeightMin, max: profile.targetWeightMax),
            bfTarget: (min: profile.targetBFMin, max: profile.targetBFMax),
            overallProgress: goalProgress,
            proteinConsumed: nil, // TODO: wire protein from NutritionProfile when macro strip ships
            proteinTarget: nil,
            recommendation: HomeRecommendationProvider.recommendation(
                readinessScore: readinessScore,
                isRestDay: activeDayType == .restDay,
                streakDays: dataStore.supplementStreak
            ),
            onTap: {
                analytics.logHomeBodyCompTap(
                    hasWeight: currentWeight != nil,
                    hasBodyFat: currentBF != nil,
                    progressPercent: Int(goalProgress * 100)
                )
                showBodyCompDetail = true
            },
            onLogTap: { manualEntry = true }
        )
    }

    // MARK: - Status card (REPLACED by bodyCompositionCard — kept for reference)
    // ─────────────────────────────────────────────────────

    private var statusCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            AppMetricColumn(
                icon: AppIcon.weight,
                title: "WEIGHT",
                value: currentWeight.map { settings.unitSystem.displayWeightValue($0) },
                unit: settings.unitSystem.weightLabel(),
                target: "Goal \(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())",
                tintColor: AppColor.Chart.weight,
                onLogTap: { manualEntry = true }
            )

            Divider()
                .overlay(AppColor.Surface.tertiary)
                .padding(.vertical, AppSpacing.xxSmall)

            AppMetricColumn(
                icon: AppIcon.bodyFat,
                title: "BODY FAT",
                value: currentBF.map { String(format: "%.1f", $0) },
                unit: "%",
                target: "Goal \(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))%",
                tintColor: AppColor.Chart.body,
                onLogTap: { manualEntry = true }
            )
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
        .scaleEffect(statusPulse ? 1.01 : 1)
        .motionSafe(AppSpring.snappy, value: statusPulse)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Goal card
    // ─────────────────────────────────────────────────────

    private var goalCard: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            // Progress ring
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("GOAL")
                    .font(AppText.eyebrow)
                    .tracking(2.1)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)

                AppProgressRing(
                    value: goalProgress,
                    color: AppColor.Accent.primary,
                    label: "\(Int(goalProgress * 100))%",
                    lineWidth: 10
                )
                .frame(width: 96, height: 96)
                .accessibilityLabel("Overall goal progress")
                .accessibilityValue("\(Int(goalProgress * 100)) percent")
            }

            // Goal breakdown
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("GOAL PROGRESS")
                    .font(AppText.eyebrow)
                    .tracking(2.1)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)

                progressLine(
                    title: "Weight",
                    progress: profile.weightProgress(current: currentWeight),
                    tint: AppColor.Chart.weight
                )
                progressLine(
                    title: "Body Fat",
                    progress: profile.bfProgress(current: currentBF),
                    tint: AppColor.Chart.body
                )

                Text(essentialsSummary)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.tertiary)
                    .lineLimit(2)
                    .accessibilityLabel(essentialsSummary)
            }
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColor.Surface.elevated)
        )
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardYOffset)
    }

    private func progressLine(title: String, progress: Double, tint: Color) -> some View {
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
                    Capsule()
                        .fill(AppColor.Surface.tertiary)
                    Capsule()
                        .fill(tint.opacity(0.95))
                        .frame(width: max(8, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(height: AppSize.progressBarHeight * 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Metrics row
    // ─────────────────────────────────────────────────────

    private var metricsRow: some View {
        HStack(spacing: AppSpacing.xSmall) {
            AppMetricTile(
                icon: AppIcon.hrv,
                value: displayMetricNumber(hrvValue),
                label: "HRV",
                tintColor: AppColor.Chart.hrv,
                onLogTap: { manualEntry = true }
            )
            AppMetricTile(
                icon: AppIcon.heart,
                value: displayMetricNumber(restingHRValue),
                label: "RHR",
                tintColor: AppColor.Chart.heartRate,
                onLogTap: { manualEntry = true }
            )
            AppMetricTile(
                icon: AppIcon.sleep,
                value: displaySleepValue,
                label: "Sleep",
                tintColor: AppColor.Chart.sleep,
                onLogTap: { manualEntry = true }
            )
            AppMetricTile(
                icon: AppIcon.steps,
                value: displayStepsValue,
                label: "Steps",
                tintColor: AppColor.Chart.activity
            )
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Data display helpers
    // ─────────────────────────────────────────────────────

    private var hrvValue: Double? {
        metrics.hrv ?? todayLog?.biometrics.manualHRV
    }

    private var restingHRValue: Double? {
        metrics.restingHR ?? todayLog?.biometrics.manualRestingHR
    }

    private var sleepValue: Double? {
        metrics.sleepHours ?? todayLog?.biometrics.manualSleepHours
    }

    private var displaySleepValue: String? {
        guard let sleepValue else { return nil }
        return String(format: "%.1f", sleepValue)
    }

    private var displayStepsValue: String? {
        guard let steps = metrics.stepCount else { return nil }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    private func displayMetricNumber(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Essentials tracking
    // ─────────────────────────────────────────────────────

    private var essentialMissingCount: Int {
        var count = 0
        if currentWeight == nil && currentBF == nil { count += 1 }
        if loggedMealCount == 0 { count += 1 }
        if completedSupplementStacks < 2 { count += 1 }
        return count
    }

    private var essentialsSummary: String {
        if essentialMissingCount == 0 {
            return "Status is on track for today."
        }
        return "\(essentialMissingCount) core \(essentialMissingCount == 1 ? "item still needs" : "items still need") attention."
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Greeting helpers
    // ─────────────────────────────────────────────────────

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning, \(profile.name)"
        case 12..<17: return "Good afternoon, \(profile.name)"
        case 17..<21: return "Good evening, \(profile.name)"
        default:      return "Good night, \(profile.name)"
        }
    }

    private static let todayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    private var todayFormatted: String {
        Self.todayDateFormatter.string(from: Date())
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Milestones
    // ─────────────────────────────────────────────────────

    private func checkMilestones() {
        // Supplement streak
        if let milestone = streakMilestone, milestone != shownMilestoneStreak {
            shownMilestoneStreak = milestone
            milestoneTitle = "\(milestone)-Day Streak!"
            milestoneMessage = "\(milestone) days straight. Consistency beats intensity every time."
            return
        }
        // Phase transition
        let phase = dataStore.userProfile.currentPhase
        if shownMilestonePhase == nil {
            shownMilestonePhase = phase
            return
        }
        if phase != shownMilestonePhase {
            shownMilestonePhase = phase
            milestoneTitle = "Phase Complete!"
            milestoneMessage = "Welcome to \(phase.rawValue). A new chapter begins."
            let ng = UINotificationFeedbackGenerator()
            ng.prepare()
            ng.notificationOccurred(.success)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Action helpers
    // ─────────────────────────────────────────────────────

    private func performHomeAction(
        _ actionType: String,
        action: @escaping () -> Void
    ) {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()

        analytics.logHomeActionTap(
            actionType: actionType,
            dayType: activeDayType.rawValue,
            hasRecommendation: readinessScore != nil
        )

        action()
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Toolbar
    // ─────────────────────────────────────────────────────

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            SyncStatusIndicator()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sync status")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - EmptyReason analytics key

private extension EmptyReason {
    var analyticsKey: String {
        switch self {
        case .firstLaunch: return "first_launch"
        case .noHealthKit:  return "no_healthkit"
        case .noData:       return "no_data"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Home v2 — Filled") {
    NavigationStack {
        MainScreenView(selectedTab: .constant(.main))
            .environmentObject(EncryptedDataStore())
            .environmentObject(HealthKitService())
            .environmentObject(TrainingProgramStore())
            .environmentObject(AppSettings())
            .environmentObject(AnalyticsService.makeDefault())
            .environmentObject(WatchConnectivityService())
    }
    .background(AppGradient.screenBackground)
}
#endif
