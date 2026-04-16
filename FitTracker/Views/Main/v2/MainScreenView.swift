// FitTracker/Views/Main/v2/MainScreenView.swift
// Home v2 — scroll-based Today screen built bottom-up from design system tokens.
// Replaces the v1 GeometryReader-based fixed layout with a scrollable card stack.

import SwiftUI

struct MainScreenView: View {

    // MARK: - External dependencies

    @Binding var selectedTab: AppTab
    @Binding var statsMetric: StatsFocusMetric?

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings
    @EnvironmentObject var analytics:     AnalyticsService
    @EnvironmentObject var signIn:        SignInService

    // MARK: - Reminder trigger evaluator (T10)
    // Owned here so it has access to all data context after the screen loads.
    private let reminderEvaluator = ReminderTriggerEvaluator()

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

    // MARK: - Body

    var body: some View {
        scrollContent
        .background(AppGradient.screenBackground.ignoresSafeArea())
        .analyticsScreen(AnalyticsScreen.home)
        .onAppear { checkMilestones() }
        .task { await evaluateReminders() }
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
                sectionDivider
                AIInsightCard()
                sectionDivider
                trainingNutritionCard
                sectionDivider
                bodyCompositionCard
                sectionDivider
                metricsRow
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Section divider
    // ─────────────────────────────────────────────────────

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColor.Text.tertiary.opacity(0.3))
            .frame(height: 0.5)
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
        // Use real data if available, otherwise show sample data for visual context
        let weight = currentWeight ?? 71.5
        let bf = currentBF ?? 18.2
        let hasRealData = currentWeight != nil || currentBF != nil

        return BodyCompositionCard(
            currentWeight: weight,
            currentBF: bf,
            weightTarget: (min: profile.targetWeightMin, max: profile.targetWeightMax),
            bfTarget: (min: profile.targetBFMin, max: profile.targetBFMax),
            overallProgress: hasRealData ? goalProgress : 0.42,
            proteinConsumed: 120,
            proteinTarget: 180,
            recommendation: HomeRecommendationProvider.recommendation(
                readinessScore: readinessScore,
                isRestDay: activeDayType == .restDay,
                streakDays: dataStore.supplementStreak
            ),
            isHealthKitAuthorized: healthService.isAuthorized,
            onTap: {
                analytics.logHomeBodyCompTap(
                    hasWeight: currentWeight != nil,
                    hasBodyFat: currentBF != nil,
                    progressPercent: Int(goalProgress * 100)
                )
                showBodyCompDetail = true
            },
            onLogTap: { manualEntry = true },
            onConnectHealthKit: {
                Task {
                    try? await healthService.requestAuthorization()
                    if !healthService.isAuthorized {
                        manualEntry = true
                    }
                }
            }
        )
    }

    // statusCard + goalCard + progressLine removed — replaced by bodyCompositionCard (PR #65)

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
                onLogTap: { manualEntry = true },
                onTileTap: { navigateToStats(metric: .hrv, label: "hrv") }
            )
            AppMetricTile(
                icon: AppIcon.heart,
                value: displayMetricNumber(restingHRValue),
                label: "RHR",
                tintColor: AppColor.Chart.heartRate,
                onLogTap: { manualEntry = true },
                onTileTap: { navigateToStats(metric: .restingHeartRate, label: "resting_heart_rate") }
            )
            AppMetricTile(
                icon: AppIcon.sleep,
                value: displaySleepValue,
                label: "Sleep",
                tintColor: AppColor.Chart.sleep,
                onLogTap: { manualEntry = true },
                onTileTap: { navigateToStats(metric: .sleep, label: "sleep") }
            )
            AppMetricTile(
                icon: AppIcon.steps,
                value: displayStepsValue,
                label: "Steps",
                tintColor: AppColor.Chart.activity,
                onTileTap: { navigateToStats(metric: .steps, label: "steps") }
            )
        }
    }

    private func navigateToStats(metric: StatsFocusMetric, label: String) {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()

        analytics.logHomeMetricTileTap(
            metricType: label,
            hasValue: true
        )

        statsMetric = metric
        selectedTab = .stats
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
    // MARK: - Smart reminder evaluation (T10)
    // Called once via .task{} when the screen loads and data is available.
    // ─────────────────────────────────────────────────────

    private func evaluateReminders() async {
        let onboardingDate = UserDefaults.standard.object(forKey: "ft.onboardingCompletedDate") as? Date ?? Date()
        let daysSinceOnboarding = Calendar.current.dateComponents([.day], from: onboardingDate, to: Date()).day ?? 0

        let lastOpenDate = UserDefaults.standard.object(forKey: "ft.lastAppOpenDate") as? Date ?? Date()
        let daysSinceLastOpen = Calendar.current.dateComponents([.day], from: lastOpenDate, to: Date()).day ?? 0
        UserDefaults.standard.set(Date(), forKey: "ft.lastAppOpenDate")

        let todayNutrition = todayLog?.nutritionLog
        let currentProtein = todayNutrition?.resolvedProteinG ?? 0.0
        let targetProtein = 180.0 // Fallback; UserPreferences does not yet expose a per-user protein target

        let hasLoggedWorkout = !(todayLog?.exerciseLogs.isEmpty ?? true)

        let dayType = activeDayType.rawValue
        let exerciseCount = totalExerciseCount
        let durationMinutes = estimatedSessionMinutes

        await reminderEvaluator.evaluateAll(
            currentProtein:       currentProtein,
            targetProtein:        targetProtein > 0 ? targetProtein : 180,
            isTrainingDay:        activeDayType.isTrainingDay,
            hasLoggedWorkout:     hasLoggedWorkout,
            readinessScore:       readinessScore,
            dayType:              dayType,
            exerciseCount:        exerciseCount,
            durationMinutes:      durationMinutes,
            isHealthKitAuthorized: healthService.isAuthorized,
            isSignedIn:           signIn.isAuthenticated,
            daysSinceLastOpen:    daysSinceLastOpen,
            daysSinceOnboarding:  daysSinceOnboarding
        )
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Toolbar
    // ─────────────────────────────────────────────────────

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // Intentionally empty — sync indicator removed per UX simplification
        ToolbarItem(placement: .navigationBarTrailing) {
            EmptyView()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Home v2 — Filled") {
    NavigationStack {
        MainScreenView(selectedTab: .constant(.main), statsMetric: .constant(nil))
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
