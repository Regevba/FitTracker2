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

    private var aiTip: String {
        let logs = Array(dataStore.dailyLogs.prefix(28))
        let r7 = logs.prefix(7)
        let prefs = dataStore.userPreferences
        // dailyLogs is always kept sorted descending; first == most recent
        if let hrv = logs.first?.biometrics.effectiveHRV, hrv < prefs.hrvReadyThreshold {
            return "HRV below threshold — consider a walk instead of lifting"
        }
        let r7CardioLogs = r7.flatMap { $0.cardioLogs.values }
        let r7Zone2Logs = r7CardioLogs.filter { $0.wasInZone2(lower: prefs.zone2LowerHR, upper: prefs.zone2UpperHR) == true }
        let z2min: Double = r7Zone2Logs.compactMap(\.durationMinutes).reduce(0, +)
        if z2min < 90 {
            return "Under 90 min Zone 2 — a 20-min walk fills the gap"
        }
        let adh = logs.isEmpty ? 0.0 : logs.map { $0.completionPct }.reduce(0, +) / Double(logs.count)
        if adh < 70 {
            return "Consistency gap this month — partial sessions count too"
        }
        return "All signals green — push hard today"
    }

    // Background palette — defined centrally in AppTheme.swift
    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2
    private let bgBlue1   = Color.appBlue1
    private let bgBlue2   = Color.appBlue2

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
                let compact = proxy.size.height < 820

                VStack(alignment: .leading, spacing: compact ? 14 : 18) {
                    greetingHeader
                    todayStatusCard(compact: compact)
                    essentialsCard
                    secondaryActionsRow(compact: compact)
                    syncFooter
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 12, 24))
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
        ZStack {
            LinearGradient(colors: [bgOrange1, bgOrange2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [bgBlue1, bgBlue2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(goalProgress)
                .animation(.easeOut(duration: 0.6), value: goalProgress)
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Greeting header
    // ─────────────────────────────────────────────────────

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(todayFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.65))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadge(text: "Day \(profile.daysSinceStart)", color: .appOrange2)
                    StatusBadge(text: profile.currentPhase.rawValue, color: .appBlue1)
                }
            }
            Text("See your status, take the next action, and close what is still missing today.")
                .font(AppType.subheading)
                .foregroundStyle(.black.opacity(0.65))
        }
    }

    private func todayStatusCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Today's Status")
                            .font(AppType.caption)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .foregroundStyle(.black.opacity(0.45))
                        Text(essentialsNeedAttention ? "Needs focus" : "On track")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background((essentialsNeedAttention ? Color.status.warning : recommendationAccent).opacity(0.14), in: Capsule())
                            .foregroundStyle(essentialsNeedAttention ? Color.status.warning : recommendationAccent)
                    }
                    Text(recommendationTitle)
                        .font(.system(size: compact ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                        .lineLimit(2)
                    Text(recommendationSubtitle)
                        .font(AppType.subheading)
                        .foregroundStyle(.black.opacity(0.62))
                        .lineLimit(compact ? 2 : 3)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(readinessScore.map { "\($0)" } ?? "—")
                        .font(.system(size: compact ? 34 : 40, weight: .bold, design: .rounded))
                        .foregroundStyle(readinessColor)
                    Text(readinessContextShort)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }

            HStack(spacing: 8) {
                statusChip(
                    title: "Scheduled",
                    value: activeDayType.rawValue,
                    tint: activeDayType.isTrainingDay ? Color.accent.cyan : Color.status.warning
                )
                statusChip(
                    title: "Focus",
                    value: recommendationTone,
                    tint: recommendationAccent
                )
                statusChip(
                    title: "Time",
                    value: estimatedSessionLength,
                    tint: Color.appBlue1
                )
            }

            HStack(spacing: 10) {
                Button {
                    performHomeAction("primary", style: .medium, action: runPrimaryAction)
                } label: {
                    Label(primaryActionTitle, systemImage: primaryActionIcon)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 12 : 14)
                        .background(recommendationAccent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .scaleEffect(highlightedActionID == "primary" ? 0.985 : 1)
                .shadow(color: recommendationAccent.opacity(0.22), radius: highlightedActionID == "primary" ? 8 : 14, y: 6)

                Menu {
                    Button("Use Today's Schedule") { selectedDayType = nil }
                    Divider()
                    ForEach(DayType.allCases, id: \.self) { day in
                        Button(day.rawValue) { selectedDayType = day }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Adjust")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, compact ? 12 : 14)
                    .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black.opacity(0.78))
                }
            }
        }
        .padding(compact ? 16 : 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), recommendationAccent.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Circle()
                    .fill(recommendationAccent.opacity(0.18))
                    .frame(width: compact ? 136 : 164, height: compact ? 136 : 164)
                    .blur(radius: 18)
                    .offset(x: compact ? 80 : 92, y: compact ? -42 : -52)
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(1)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: recommendationAccent.opacity(0.18), radius: 18, y: 8)
        .scaleEffect(statusPulse ? 1.01 : 1)
    }

    private var essentialsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Essentials")
                    .font(AppType.caption)
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(.black.opacity(0.45))
                Text(essentialsSummary)
                    .font(AppType.subheading)
                    .foregroundStyle(essentialsNeedAttention ? Color.status.warning : .black.opacity(0.58))
            }

            essentialRow(
                title: "Body Check-In",
                detail: bodyCheckDetail,
                status: bodyCheckStatus,
                tint: .blue,
                actionTitle: currentWeight == nil && currentBF == nil ? "Log" : "Edit",
                isMissing: currentWeight == nil && currentBF == nil
            ) {
                manualEntry = true
            }

            essentialRow(
                title: "Nutrition",
                detail: nutritionDetail,
                status: nutritionStatus,
                tint: .accent.cyan,
                actionTitle: "Open",
                isMissing: loggedMealCount == 0
            ) {
                selectedTab = .nutrition
            }

            essentialRow(
                title: "Supplements",
                detail: supplementDetail,
                status: supplementStatus,
                tint: .accent.gold,
                actionTitle: "Track",
                isMissing: completedSupplementStacks < 2
            ) {
                selectedTab = .nutrition
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            essentialsNeedAttention ? Color.status.warning.opacity(0.1) : Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    private func essentialRow(
        title: String,
        detail: String,
        status: String,
        tint: Color,
        actionTitle: String,
        isMissing: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            performHomeAction(title, action: action)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(tint.opacity(isMissing ? 0.2 : 0.14))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(isMissing ? 0.55 : 0.35), lineWidth: isMissing ? 1.4 : 1)
                    )
                    .overlay(
                        Circle()
                            .fill(tint)
                            .frame(width: 10, height: 10)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.82))
                        if isMissing {
                            Text("Needs attention")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.status.warning.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.status.warning)
                        }
                    }
                    Text(detail)
                        .font(AppType.subheading)
                        .foregroundStyle(.black.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    HStack(spacing: 6) {
                        Text(actionTitle)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isMissing ? tint.opacity(0.1) : Color.white.opacity(0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        highlightedActionID == title
                            ? tint.opacity(0.58)
                            : tint.opacity(isMissing ? 0.28 : 0.18),
                        lineWidth: highlightedActionID == title ? 1.6 : 1
                    )
            )
            .shadow(color: highlightedActionID == title ? tint.opacity(0.18) : .clear, radius: 10, y: 4)
            .scaleEffect(highlightedActionID == title ? 0.99 : 1)
        }
        .buttonStyle(.plain)
    }

    private func secondaryActionsRow(compact: Bool) -> some View {
        HStack(spacing: 12) {
            secondaryActionCard(
                actionID: "plan",
                title: "Open Plan",
                subtitle: activeDayType.isTrainingDay ? "\(activeDayType.rawValue) • \(totalExerciseCount) items" : "Review today's training decision",
                icon: "figure.strengthtraining.traditional",
                tint: recommendationAccent,
                compact: compact
            ) {
                showExerciseSheet = true
            }

            secondaryActionCard(
                actionID: "progress",
                title: "View Progress",
                subtitle: "Weight, body fat, training, and adherence trends",
                icon: "chart.line.uptrend.xyaxis",
                tint: .accent.gold,
                compact: compact
            ) {
                selectedTab = .stats
            }
        }
    }

    private func secondaryActionCard(
        actionID: String,
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            performHomeAction(actionID, action: action)
        } label: {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.35))
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.black.opacity(0.84))

                Text(subtitle)
                    .font(AppType.subheading)
                    .foregroundStyle(.black.opacity(0.62))
                    .lineLimit(compact ? 2 : 3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: compact ? 124 : 136, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [tint.opacity(0.14), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(highlightedActionID == actionID ? tint.opacity(0.58) : tint.opacity(0.28), lineWidth: highlightedActionID == actionID ? 1.6 : 1)
            )
            .shadow(color: highlightedActionID == actionID ? tint.opacity(0.18) : .clear, radius: 12, y: 5)
            .scaleEffect(highlightedActionID == actionID ? 0.99 : 1)
        }
        .buttonStyle(.plain)
    }

    private var syncFooter: some View {
        HStack(spacing: 8) {
            if !syncLabel.isEmpty {
                Text(syncLabel)
                    .font(AppType.caption)
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            Spacer()
            Text(aiTip)
                .font(AppType.caption)
                .foregroundStyle(Color.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.45))
                .tracking(1.2)
            Text(value)
                .font(AppType.body)
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
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

    private var readinessColor: Color { recommendationAccent }

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

    private func makeBlankLog() -> DailyLog {
        .scheduled(profile: dataStore.userProfile, dayType: programStore.todayDayType)
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

    private var bodyCheckDetail: String {
        if let currentWeight, let currentBF {
            return "\(settings.unitSystem.displayWeightValue(currentWeight)) \(settings.unitSystem.weightLabel()) • \(String(format: "%.1f", currentBF))% body fat"
        }
        if let currentWeight {
            return "\(settings.unitSystem.displayWeightValue(currentWeight)) \(settings.unitSystem.weightLabel()) recorded today"
        }
        if let currentBF {
            return "\(String(format: "%.1f", currentBF))% body fat recorded today"
        }
        return "Weight and body composition are still missing today."
    }

    private var bodyCheckStatus: String {
        (currentWeight != nil || currentBF != nil) ? "Logged" : "Missing"
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
            return "The main daily checkboxes are on track."
        }
        return "\(essentialMissingCount) core \(essentialMissingCount == 1 ? "item needs" : "items need") attention before the day is complete."
    }

    private var nutritionDetail: String {
        if loggedMealCount == 0 {
            return "No meals logged yet. Protein and calories still need attention."
        }
        return "\(loggedMealCount) meals logged • \(Int(remainingProteinForHome))g protein left"
    }

    private var nutritionStatus: String {
        loggedMealCount == 0 ? "Open" : "Active"
    }

    private var supplementDetail: String {
        "\(completedSupplementStacks) of 2 stacks completed today."
    }

    private var supplementStatus: String {
        completedSupplementStacks == 2 ? "Done" : (completedSupplementStacks == 0 ? "Open" : "Partial")
    }

    private var remainingProteinForHome: Double {
        let target = todayLog?.biometrics.leanBodyMassKg.map { $0 * 2 } ?? 135
        let consumed = todayLog?.nutritionLog.resolvedProteinG ?? 0
        return max(target - consumed, 0)
    }

    private var syncLabel: String {
        guard let lastSync = healthService.lastSyncDate else { return "" }
        let elapsed = Date().timeIntervalSince(lastSync)
        if elapsed < 120 { return "⌚ Just now" }
        else if elapsed < 3600 { return "⌚ Synced \(Int(elapsed / 60))m ago" }
        else { return "⌚ Synced today" }
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
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(routine.subtitle)
                                .font(AppType.body)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(routine.durationMinutes)m")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Color.accentColor)
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
                .foregroundStyle(.black.opacity(0.75))
        }
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
        .scheduled(profile: dataStore.userProfile, dayType: programStore.todayDayType)
    }
}
