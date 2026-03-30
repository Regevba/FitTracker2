// Views/Main/MainScreenView.swift
// Action-first Today screen — kept above the fold with no scroll on iPhone.

import SwiftUI

struct MainScreenView: View {

    @Binding var selectedTab: AppTab

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @State private var showExerciseSheet  = false
    @State private var manualEntry        = false
    @State private var selectedRecoveryRoutine: RecoveryRoutine?
    @State private var selectedDayType:   DayType? = nil   // nil = follow today's schedule

    @State private var readinessHapticDay: Date? = nil
    @State private var highlightedActionID: String? = nil
    @State private var statusPulse = false
    @State private var shownMilestoneStreak: Int = 0
    @State private var shownMilestonePhase: ProgramPhase? = nil
    @State private var milestoneTitle: String? = nil
    @State private var milestoneMessage: String? = nil

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
        RecoveryRoutineLibrary.recommend(dayType: activeDayType, readinessScore: readinessScore, liveMetrics: metrics, log: todayLog, preferences: dataStore.userPreferences)
    }

    private let bodyFatTint = AppColor.Status.warning

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
            shownMilestonePhase = phase   // initialize on first appear, no modal
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

    var body: some View {
        ZStack {
            backgroundLayer
            GeometryReader { proxy in
                let compact = proxy.size.height < 860
                let tight = proxy.size.height < 760
                let horizontalPadding = screenHorizontalPadding(for: proxy.size.width)

                VStack(alignment: .leading, spacing: cardStackSpacing(compact: compact, tight: tight)) {
                    greetingHeader(tight: tight)
                    statusOverviewCard(compact: compact, tight: tight)
                    goalProgressCard(compact: compact, tight: tight)
                    startTrainingCard(compact: compact, tight: tight)
                    metricsCard(compact: compact, tight: tight)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, tight ? 4 : 8)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, tight ? 16 : 20))
            }
        }
        .onAppear { checkMilestones() }
        .onChange(of: dataStore.supplementStreak) { _, _ in checkMilestones() }
        .onChange(of: dataStore.userProfile.currentPhase) { _, _ in checkMilestones() }
        .onChange(of: readinessScore) { _, newScore in
            guard newScore != nil else { return }
            let today = Calendar.current.startOfDay(for: Date())
            guard readinessHapticDay.map({ Calendar.current.startOfDay(for: $0) }) != today else { return }
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                statusPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeOut(duration: 0.22)) {
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
        .sheet(item: $selectedRecoveryRoutine) { routine in
            NavigationStack {
                RecoveryRoutineSheet(
                    routine: routine,
                    reasons: routine.id == recoveryRecommendation.routine.id ? recoveryRecommendation.reasons : []
                )
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(24)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Background gradient
    // ─────────────────────────────────────────────────────

    private var backgroundLayer: some View {
        AppGradient.screenBackground
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Greeting header
    // ─────────────────────────────────────────────────────

    private func greetingHeader(tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(AppText.pageTitle)
                        .foregroundStyle(AppColor.Text.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text(todayFormatted)
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Day \(profile.daysSinceStart)")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(profile.currentPhase.rawValue)
                        .font(AppText.captionStrong)
                        .padding(.horizontal, tight ? 9 : 11)
                        .padding(.vertical, tight ? 5 : 6)
                        .background(AppColor.Surface.elevated, in: Capsule())
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }
        }
    }

    private func statusOverviewCard(compact: Bool, tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: cardInnerSpacing(compact: compact, tight: tight)) {
            HStack {
                sectionEyebrow("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(recommendationAccent)
                        .frame(width: 8, height: 8)
                    Text(readinessContextShort)
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                }
            }

            HStack(alignment: .top, spacing: 0) {
                statusValueColumn(
                    title: "Weight",
                    icon: "scalemass.fill",
                    tint: .blue,
                    value: currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "—",
                    unit: settings.unitSystem.weightLabel(),
                    target: "Target: \(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())",
                    isMissing: currentWeight == nil,
                    compact: tight
                )

                Divider()
                    .overlay(Color.white.opacity(0.4))
                    .padding(.vertical, 8)

                statusValueColumn(
                    title: "Body Fat",
                    icon: "drop.fill",
                    tint: bodyFatTint,
                    value: currentBF.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "%",
                    target: "Target: \(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))%",
                    isMissing: currentBF == nil,
                    compact: tight
                )
            }

            HStack {
                Text(recommendationTitle)
                        .font(tight ? AppType.subheading : AppType.body)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(2)
                Spacer()
                Button {
                    performHomeAction("metrics", action: { manualEntry = true })
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Accent.secondary)
                        .frame(width: 34, height: 34)
                        .background(AppColor.Surface.primary, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(cardPadding(compact: compact, tight: tight))
        .modifier(BlendedSectionStyle())
        .scaleEffect(statusPulse ? 1.01 : 1)
    }

    private func goalProgressCard(compact: Bool, tight: Bool) -> some View {
        HStack(alignment: .center, spacing: splitSectionSpacing(compact: compact, tight: tight)) {
            VStack(alignment: .leading, spacing: 12) {
                sectionEyebrow("Goal")
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.38), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: max(goalProgress, 0.02))
                        .stroke(
                            AngularGradient(colors: [AppColor.Accent.secondary, bodyFatTint, AppColor.Accent.secondary], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(goalProgress * 100))%")
                            .font(AppText.metricCompact)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Goal")
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                }
                .frame(width: tight ? 86 : (compact ? 100 : 116), height: tight ? 86 : (compact ? 100 : 116))
            }

            VStack(alignment: .leading, spacing: goalColumnSpacing(compact: compact, tight: tight)) {
                sectionEyebrow("Goal Progress")
                progressLine(
                    title: "Weight",
                    progress: profile.weightProgress(current: currentWeight),
                    tint: .appBlue1,
                    compact: tight
                )
                progressLine(
                    title: "Body Fat",
                    progress: profile.bfProgress(current: currentBF),
                    tint: bodyFatTint,
                    compact: tight
                )
                Text(essentialsSummary)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
                    .lineLimit(2)
            }
        }
        .padding(cardPadding(compact: compact, tight: tight))
        .modifier(BlendedSectionStyle())
    }

    private func startTrainingCard(compact: Bool, tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: cardInnerSpacing(compact: compact, tight: tight)) {
            sectionEyebrow("Start Training")

            HStack(spacing: splitSectionSpacing(compact: compact, tight: tight)) {
                Button {
                    performHomeAction("primary", style: .medium, action: runPrimaryAction)
                } label: {
                    ZStack {
                        Circle()
                            .fill(recommendationAccent)
                            .frame(width: tight ? 64 : (compact ? 76 : 88), height: tight ? 64 : (compact ? 76 : 88))
                        Image(systemName: primaryActionIcon)
                            .font(AppText.metricCompact)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(highlightedActionID == "primary" ? 0.97 : 1)
                .shadow(color: recommendationAccent.opacity(0.24), radius: 16, y: 10)

                VStack(alignment: .leading, spacing: trainingTextSpacing(compact: compact, tight: tight)) {
                    Text(primaryActionTitle)
                        .font(AppText.titleStrong)
                        .foregroundStyle(AppColor.Text.primary)

                    Menu {
                        Button("Use Today's Schedule") { selectedDayType = nil }
                        Divider()
                        ForEach(DayType.allCases, id: \.self) { day in
                            Button(day.rawValue) { selectedDayType = day }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: activeDayType.icon)
                            Text(activeDayType.rawValue)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(AppText.captionStrong)
                        }
                        .font(AppText.callout)
                        .foregroundStyle(AppColor.Accent.secondary)
                    }

                    Text("\(estimatedSessionLength) • \(recommendationTone)")
                        .font(tight ? .caption : AppType.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                    if !tight {
                        Text(recommendationSubtitle)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(cardPadding(compact: compact, tight: tight))
        .modifier(BlendedSectionStyle())
    }

    private func metricsCard(compact: Bool, tight: Bool) -> some View {
        VStack(alignment: .leading, spacing: cardInnerSpacing(compact: compact, tight: tight)) {
            sectionEyebrow("Metrics")
            HStack(spacing: metricsTileSpacing(compact: compact, tight: tight)) {
                metricTile(icon: "waveform.path.ecg", value: displayMetricNumber(hrvValue), label: "HRV", tint: .gray, compact: tight)
                metricTile(icon: "heart.fill", value: displayMetricNumber(restingHRValue), label: "Rest HR", tint: .brown, compact: tight)
                metricTile(icon: "moon.fill", value: displaySleepValue, label: "Sleep", tint: .purple, compact: tight)
                metricTile(icon: "figure.walk", value: displayStepsValue, label: "Steps", tint: .blue, compact: tight)
            }
        }
        .padding(cardPadding(compact: compact, tight: tight))
        .modifier(BlendedSectionStyle(showDivider: false))
    }

    private func statusValueColumn(
        title: String,
        icon: String,
        tint: Color,
        value: String,
        unit: String,
        target: String,
        isMissing: Bool,
        compact: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppText.captionStrong)
                Text(title)
                    .font(AppText.eyebrow)
                    .tracking(1.8)
                if isMissing {
                    Text("Missing")
                        .font(AppText.captionStrong)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(tint)
                }
            }
            .foregroundStyle(tint)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppText.metricCompact)
                    .monospacedDigit()
                    .foregroundStyle(AppColor.Text.primary)
                Text(unit)
                    .font(AppText.subheading)
                    .foregroundStyle(AppColor.Text.tertiary)
            }

            Text(target)
                .font(AppText.caption)
                .foregroundStyle(isMissing ? tint.opacity(0.88) : AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressLine(title: String, progress: Double, tint: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 5) {
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
                        .fill(Color.white.opacity(0.42))
                    Capsule()
                        .fill(tint.opacity(0.95))
                        .frame(width: max(proxy.size.width * progress, 8))
                }
            }
            .frame(height: 8)
        }
    }

    private func metricTile(icon: String, value: String, label: String, tint: Color, compact: Bool) -> some View {
        VStack(spacing: compact ? 5 : 8) {
            Image(systemName: icon)
                .font(AppText.callout)
                .foregroundStyle(tint)
            Text(value)
                .font(AppText.titleMedium)
                .monospacedDigit()
                .foregroundStyle(AppColor.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 7 : 9)
    }

    private func sectionEyebrow(_ title: String) -> some View {
        Text(title)
            .font(AppText.eyebrow)
            .tracking(2.1)
            .foregroundStyle(AppColor.Text.tertiary)
            .textCase(.uppercase)
    }

    private func screenHorizontalPadding(for width: CGFloat) -> CGFloat {
        width <= 390 ? 18 : 20
    }

    private func cardStackSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 12 : (compact ? 14 : 16)
    }

    private func cardPadding(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 14 : (compact ? 16 : 18)
    }

    private func cardInnerSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 10 : (compact ? 12 : 14)
    }

    private func splitSectionSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 14 : (compact ? 18 : 22)
    }

    private func goalColumnSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 10 : (compact ? 12 : 16)
    }

    private func trainingTextSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 8 : (compact ? 9 : 10)
    }

    private func metricsTileSpacing(compact: Bool, tight: Bool) -> CGFloat {
        tight ? 6 : (compact ? 8 : 10)
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

    private static let todayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    private var todayFormatted: String {
        Self.todayDateFormatter.string(from: Date())
    }

    private var recommendationAccent: Color {
        switch readinessScore ?? 65 {
        case 80...: Color.status.success
        case 60..<80: Color.accent.cyan
        case 40..<60: Color.status.warning
        default: Color.status.error
        }
    }

    private var recommendationTitle: String {
        if recoveryRecommendation.shouldReplaceTraining {
            return "Run the \(recoveryRecommendation.routine.title.lowercased())"
        }
        switch readinessScore ?? 65 {
        case 80...: return "Push the full \(activeDayType.rawValue.lowercased()) session"
        case 60..<80: return "Run the planned \(activeDayType.rawValue.lowercased()) session"
        case 40..<60: return "Train, but trim the volume"
        default: return "Bias toward recovery and technique"
        }
    }

    private var recommendationSubtitle: String {
        if recoveryRecommendation.shouldReplaceTraining {
            let reasons = recoveryRecommendation.reasons.joined(separator: " ")
            return reasons.isEmpty
                ? "Use recovery today, move a little, and keep nutrition tight."
                : reasons
        }
        switch readinessScore ?? 65 {
        case 80...: return "Readiness supports a full effort day. Keep the plan intact."
        case 60..<80: return "Stay on plan and prioritize consistency over hero numbers."
        case 40..<60: return "Keep the session, but trim one block if the work sets feel heavy."
        default: return "Treat today as a lighter practice day and protect recovery."
        }
    }

    private var estimatedSessionLength: String {
        if recoveryRecommendation.shouldReplaceTraining {
            return "\(recoveryRecommendation.routine.durationMinutes)m"
        }
        let minutes = max(20, totalExerciseCount * (activeDayType.isTrainingDay ? 6 : 4))
        return "\(minutes)m"
    }

    private var recommendationTone: String {
        guard let score = readinessScore else { return "Baseline building" }
        switch score {
        case 80...: return "Full send"
        case 60..<80: return "On plan"
        case 40..<60: return "Trim load"
        default: return "Recover"
        }
    }

    private var readinessContextShort: String {
        guard let score = readinessScore else { return "Need more data" }
        switch score {
        case 80...: return "Green light"
        case 60..<80: return "Steady"
        case 40..<60: return "Moderate"
        default: return "Back off"
        }
    }

    private var primaryActionTitle: String {
        recoveryRecommendation.shouldReplaceTraining ? "Start Recovery" : "Start Workout"
    }

    private var primaryActionIcon: String {
        recoveryRecommendation.shouldReplaceTraining ? recoveryRecommendation.routine.icon : "play.fill"
    }

    private func runPrimaryAction() {
        if recoveryRecommendation.shouldReplaceTraining {
            selectedRecoveryRoutine = recoveryRecommendation.routine
        } else {
            showExerciseSheet = true
        }
    }

    private var essentialsNeedAttention: Bool {
        essentialMissingCount > 0
    }

    private var essentialMissingCount: Int {
        var missingCount = 0
        if currentWeight == nil && currentBF == nil { missingCount += 1 }
        if loggedMealCount == 0 { missingCount += 1 }
        if completedSupplementStacks < 2 { missingCount += 1 }
        return missingCount
    }

    private var essentialsSummary: String {
        if !essentialsNeedAttention {
            return "Status is on track for today."
        }
        return "\(essentialMissingCount) core \(essentialMissingCount == 1 ? "item still needs" : "items still need") attention."
    }

    private var hrvValue: Double? {
        metrics.hrv ?? todayLog?.biometrics.manualHRV
    }

    private var restingHRValue: Double? {
        metrics.restingHR ?? todayLog?.biometrics.manualRestingHR
    }

    private var sleepValue: Double? {
        metrics.sleepHours ?? todayLog?.biometrics.manualSleepHours
    }

    private var displaySleepValue: String {
        guard let sleepValue else { return "—" }
        return String(format: "%.1f", sleepValue)
    }

    private var displayStepsValue: String {
        guard let steps = metrics.stepCount else { return "—" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000)
        }
        return "\(steps)"
    }

    private func displayMetricNumber(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.rounded() == value
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private func performHomeAction(
        _ id: String,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        action: @escaping () -> Void
    ) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()

        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
            highlightedActionID = id
        }
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.18)) {
                if highlightedActionID == id {
                    highlightedActionID = nil
                }
            }
        }
    }
    // ─────────────────────────────────────────────────────
    // MARK: – Toolbar
    // ─────────────────────────────────────────────────────

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            SyncStatusIndicator()
        }
    }

}

private struct BlendedSectionStyle: ViewModifier {
    var showDivider: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if showDivider {
                    Rectangle()
                        .fill(Color.white.opacity(0.34))
                        .frame(height: 1)
                        .padding(.top, 12)
                }
            }
    }
}

struct RecoveryRoutineSheet: View {
    let routine: RecoveryRoutine
    let reasons: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(routine.title)
                                .font(AppText.pageTitle)
                            Text(routine.subtitle)
                                .font(AppType.body)
                                .foregroundStyle(AppColor.Text.secondary)
                        }
                        Spacer()
                        Text("\(routine.durationMinutes)m")
                            .font(AppText.monoMetric)
                            .foregroundStyle(AppColor.Accent.primary)
                    }

                    HStack(spacing: 10) {
                        RecoveryMetaPill(label: routine.intensityLabel, icon: "dial.low")
                        RecoveryMetaPill(label: routine.focus, icon: routine.icon)
                    }
                }

                if !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why today")
                            .font(.headline)
                        ForEach(reasons, id: \.self) { reason in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.top, 2)
                                Text(reason)
                                    .font(AppType.subheading)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Flow")
                        .font(.headline)
                    ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                                    .frame(width: 30, height: 30)
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(step.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(step.minutes) min")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text(step.detail)
                                    .font(AppType.subheading)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Coaching note")
                        .font(.headline)
                    Text(routine.coachingNote)
                        .font(AppType.subheading)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(20)
        }
        .navigationTitle("Recovery Flow")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct RecoveryMetaPill: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.1), in: Capsule())
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – SyncStatusIndicator
// ─────────────────────────────────────────────────────────

struct SyncStatusIndicator: View {
    @EnvironmentObject var watchService: WatchConnectivityService
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(watchService.status.dotColor)
                .frame(width: 6, height: 6)
            Text(watchService.status.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.black.opacity(0.72))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.34))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .tint(.clear)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Manual biometric entry sheet
// ─────────────────────────────────────────────────────────

struct ManualBiometricEntry: View {
    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var programStore:  TrainingProgramStore
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
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        compactMetricField("kg", text: $weightText, keyboardType: .decimalPad)
                    }
                    HStack {
                        Text("Body Fat")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        compactMetricField("%", text: $bfText, keyboardType: .decimalPad)
                    }
                }
                Section("Manual Overrides (if Watch unavailable)") {
                    HStack {
                        Text("Resting HR")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        compactMetricField("bpm", text: $hrText, keyboardType: .numberPad)
                    }
                    HStack {
                        Text("HRV")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        compactMetricField("ms", text: $hrvText, keyboardType: .decimalPad)
                    }
                    HStack {
                        Text("Sleep")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.primary)
                        Spacer()
                        compactMetricField("hrs", text: $sleepText, keyboardType: .decimalPad)
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

    private func compactMetricField(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        AppInputShell {
            TextField(placeholder, text: text)
                .font(AppText.body)
                .foregroundStyle(AppColor.Text.primary)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minWidth: 92, idealWidth: 112, maxWidth: 128)
    }

    private func save() {
        var log = dataStore.todayLog() ?? .scheduled(
            profile: dataStore.userProfile,
            dayType: programStore.todayDayType
        )
        log.biometrics.weightKg         = Double(weightText)
        log.biometrics.bodyFatPercent   = Double(bfText)
        log.biometrics.manualRestingHR  = Double(hrText)
        log.biometrics.manualHRV        = Double(hrvText)
        log.biometrics.manualSleepHours = Double(sleepText)
        dataStore.upsertLog(log)
    }
}
