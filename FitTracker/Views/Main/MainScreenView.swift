// Views/Main/MainScreenView.swift
// Tab 1: Home screen — everything visible above the tab bar, no scroll
//   - Gradient background (orange → blue by goal progress)
//   - Right-edge vertical progress tracker
//   - Greeting + play/pause training button in header
//   - Weight & Body Fat displayed side-by-side

import SwiftUI

struct MainScreenView: View {

    @Binding var selectedTab: AppTab

    @EnvironmentObject var dataStore:     EncryptedDataStore
    @EnvironmentObject var healthService: HealthKitService
    @EnvironmentObject var programStore:  TrainingProgramStore
    @EnvironmentObject var settings:      AppSettings

    @State private var trainingActive     = false
    @State private var showExerciseSheet  = false
    @State private var manualEntry        = false
    @State private var selectedRecoveryRoutine: RecoveryRoutine?
    @State private var selectedDayType:   DayType? = nil   // nil = follow today's schedule

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
    private var loggedMealCount: Int {
        todayLog?.nutritionLog.meals.filter { $0.status == .completed }.count ?? 0
    }
    private var completedSupplementStacks: Int {
        let morning = todayLog?.supplementLog.morningStatus == .completed ? 1 : 0
        let evening = todayLog?.supplementLog.eveningStatus == .completed ? 1 : 0
        return morning + evening
    }
    private var completedExerciseCount: Int {
        todayLog?.taskStatuses.values.filter { $0 == .completed }.count ?? 0
    }
    private var totalExerciseCount: Int {
        TrainingProgramData.exercises(for: activeDayType).count
    }
    private var recoveryRecommendation: RecoveryRecommendation {
        RecoveryRoutineLibrary.recommend(dayType: activeDayType, readinessScore: readinessScore, liveMetrics: metrics, log: todayLog)
    }

    // Background palette — defined centrally in AppTheme.swift
    private let bgOrange1 = Color.appOrange1
    private let bgOrange2 = Color.appOrange2
    private let bgBlue1   = Color.appBlue1
    private let bgBlue2   = Color.appBlue2

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    greetingHeader
                    recommendationCard

                    SectionHeader(title: "Today Actions")
                    actionGrid

                    SectionHeader(title: "At A Glance")
                    summaryGrid

                    SectionHeader(title: "Today Timeline")
                    todayTimeline

                    SectionHeader(title: "Recovery Studio")
                    recoveryStudio

                    SectionHeader(title: "Readiness")
                    quickStats
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
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
                .animation(.easeInOut(duration: 1.5), value: goalProgress)
        }
        .ignoresSafeArea()
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Vertical progress tracker
    // ─────────────────────────────────────────────────────

    private var progressTracker: some View {
        GeometryReader { proxy in
            let trackStart: CGFloat = 110
            let trackEnd:   CGFloat = proxy.size.height - 110
            let trackH   = max(1, trackEnd - trackStart)
            let orbY     = trackStart + trackH * goalProgress
            let x        = proxy.size.width - 16
            let fillH    = max(2, trackH * goalProgress)

            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 3, height: trackH)
                .position(x: x, y: trackStart + trackH / 2)

            Capsule()
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.65), .blue.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: fillH)
                .position(x: x, y: trackStart + fillH / 2)
                .animation(.spring(response: 1.2), value: goalProgress)

            Circle()
                .fill(goalProgress > 0.5 ? Color.blue.opacity(0.22) : Color.orange.opacity(0.22))
                .frame(width: 26, height: 26)
                .blur(radius: 6)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)

            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .shadow(color: .white.opacity(0.6), radius: 4)
                .shadow(color: goalProgress > 0.5 ? .blue.opacity(0.55) : .orange.opacity(0.55), radius: 5)
                .position(x: x, y: orbY)
                .animation(.spring(response: 1.2), value: goalProgress)
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Greeting header + play/pause button
    // ─────────────────────────────────────────────────────

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    statusChip(
                        title: "Scheduled",
                        value: activeDayType.rawValue,
                        tint: activeDayType.isTrainingDay ? Color.accent.cyan : Color.status.warning
                    )
                    statusChip(
                        title: "Readiness",
                        value: readinessScore.map { "\($0)" } ?? "—",
                        tint: readinessColor
                    )
                }
                Text("Today is built around the next best action: capture the essentials quickly, then drill into details only when you need them.")
                    .font(AppType.subheading)
                    .foregroundStyle(.black.opacity(0.65))
            }
        }
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
                ? "Use guided recovery today: calm the system, move a little, and tighten nutrition."
                : reasons
        }
        switch readinessScore ?? 65 {
        case 80...: return "Readiness supports a full effort day. Keep the plan intact and push the top sets."
        case 60..<80: return "You look good enough to stay on schedule. Aim for consistency over hero numbers."
        case 40..<60: return "Keep the session, but pull back one block or reduce load if the first work sets feel heavy."
        default: return "Treat today as a lighter practice day. Keep momentum, but protect recovery."
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

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended Right Now")
                        .font(AppType.caption)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(.black.opacity(0.45))
                    Text(recommendationTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                    Text(recommendationSubtitle)
                        .font(AppType.subheading)
                        .foregroundStyle(.black.opacity(0.62))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(estimatedSessionLength)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(recommendationAccent)
                    Text("estimated")
                        .font(AppType.caption)
                        .foregroundStyle(.black.opacity(0.45))
                }
            }

            HStack(spacing: 10) {
                Button {
                    if recoveryRecommendation.shouldReplaceTraining {
                        selectedRecoveryRoutine = recoveryRecommendation.routine
                    } else if activeDayType.isTrainingDay {
                        showExerciseSheet = true
                    } else {
                        selectedRecoveryRoutine = recoveryRecommendation.routine
                    }
                } label: {
                    Label(
                        recoveryRecommendation.shouldReplaceTraining ? "Start Recovery Flow" : "Start Session",
                        systemImage: recoveryRecommendation.shouldReplaceTraining ? recoveryRecommendation.routine.icon : "play.fill"
                    )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(recommendationAccent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

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
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black.opacity(0.78))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.72), recommendationAccent.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: recommendationAccent.opacity(0.18), radius: 18, y: 8)
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            TodayActionCard(
                title: "Weigh In",
                subtitle: currentWeight.map { "Latest \(settings.unitSystem.displayWeightValue($0)) \(settings.unitSystem.weightLabel())" } ?? "Capture weight and body fat",
                icon: "scalemass.fill",
                tint: .blue
            ) {
                manualEntry = true
            }

            TodayActionCard(
                title: recoveryRecommendation.shouldReplaceTraining ? "Recovery Flow" : "Start Workout",
                subtitle: recoveryRecommendation.shouldReplaceTraining
                    ? "\(recoveryRecommendation.routine.title) · \(recoveryRecommendation.routine.durationMinutes) min"
                    : (totalExerciseCount > 0 ? "\(activeDayType.rawValue) · \(totalExerciseCount) items" : "Open your plan for today"),
                icon: recoveryRecommendation.shouldReplaceTraining ? recoveryRecommendation.routine.icon : "figure.strengthtraining.traditional",
                tint: recommendationAccent
            ) {
                if recoveryRecommendation.shouldReplaceTraining {
                    selectedRecoveryRoutine = recoveryRecommendation.routine
                } else {
                    showExerciseSheet = true
                }
            }

            TodayActionCard(
                title: "Log Meals",
                subtitle: loggedMealCount > 0 ? "\(loggedMealCount) meals logged" : "Jump into nutrition tracking",
                icon: "fork.knife",
                tint: .accent.cyan
            ) {
                selectedTab = .nutrition
            }

            TodayActionCard(
                title: "Check Progress",
                subtitle: "Open trends, charts, and adherence",
                icon: "chart.line.uptrend.xyaxis",
                tint: .accent.gold
            ) {
                selectedTab = .stats
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            MetricCard(
                icon: "scalemass.fill",
                label: "Weight",
                value: currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "—",
                unit: currentWeight == nil ? nil : settings.unitSystem.weightLabel(),
                trendDelta: weightDelta.isEmpty ? nil : weightDelta,
                statusColor: weightTrendColor
            )
            MetricCard(
                icon: "drop.fill",
                label: "Body Fat",
                value: currentBF.map { String(format: "%.1f", $0) } ?? "—",
                unit: currentBF == nil ? nil : "%",
                trendDelta: bfDelta.isEmpty ? nil : bfDelta,
                statusColor: bfTrendColor
            )
            MetricCard(
                icon: "scope",
                label: "Goal Progress",
                value: "\(Int(goalProgress * 100))",
                unit: "%",
                trendDelta: recommendationTone,
                statusColor: recommendationAccent
            )
            MetricCard(
                icon: "sparkles",
                label: "Readiness",
                value: readinessScore.map { "\($0)" } ?? "—",
                unit: readinessScore == nil ? nil : "/100",
                trendDelta: readinessContextShort,
                statusColor: readinessColor
            )
        }
    }

    private var todayTimeline: some View {
        VStack(spacing: 12) {
            TodayTimelineRow(
                title: "Body check-in",
                detail: currentWeight != nil || currentBF != nil ? "Weight or body fat logged" : "Weight and body fat still missing",
                status: currentWeight != nil || currentBF != nil ? .complete : .pending,
                accent: .blue
            )
            TodayTimelineRow(
                title: activeDayType.isTrainingDay ? "Workout progress" : "Recovery day",
                detail: activeDayType.isTrainingDay
                    ? "\(completedExerciseCount) of \(totalExerciseCount) workout items complete"
                    : "Use \(recoveryRecommendation.routine.title.lowercased()) and easy movement today",
                status: activeDayType.isTrainingDay
                    ? (completedExerciseCount == 0 ? .pending : (completedExerciseCount >= totalExerciseCount ? .complete : .inProgress))
                    : .inProgress,
                accent: recommendationAccent
            )
            TodayTimelineRow(
                title: "Nutrition",
                detail: loggedMealCount > 0 ? "\(loggedMealCount) meals logged today" : "No meals logged yet",
                status: loggedMealCount == 0 ? .pending : .inProgress,
                accent: .accent.cyan
            )
            TodayTimelineRow(
                title: "Supplements",
                detail: "\(completedSupplementStacks) of 2 stacks completed",
                status: completedSupplementStacks == 0 ? .pending : (completedSupplementStacks == 2 ? .complete : .inProgress),
                accent: .accent.gold
            )
        }
        .padding(16)
        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var recoveryStudio: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                selectedRecoveryRoutine = recoveryRecommendation.routine
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recommended Flow")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.black.opacity(0.45))
                            .tracking(1.2)
                        Text(recoveryRecommendation.routine.title)
                            .font(.headline)
                            .foregroundStyle(.black.opacity(0.82))
                        Text(recoveryRecommendation.routine.focus)
                            .font(AppType.subheading)
                            .foregroundStyle(.black.opacity(0.62))
                        if let reason = recoveryRecommendation.reasons.first {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.6))
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Image(systemName: recoveryRecommendation.routine.icon)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(recoveryTint(for: recoveryRecommendation.routine))
                        Text("\(recoveryRecommendation.routine.durationMinutes)m")
                            .font(.system(.headline, design: .monospaced, weight: .bold))
                            .foregroundStyle(recoveryTint(for: recoveryRecommendation.routine))
                        Text(recoveryRecommendation.routine.intensityLabel)
                            .font(.caption2)
                            .foregroundStyle(.black.opacity(0.45))
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(recoveryTint(for: recoveryRecommendation.routine).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecoveryRoutineLibrary.all) { routine in
                        Button {
                            selectedRecoveryRoutine = routine
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: routine.icon)
                                        .font(.headline)
                                        .foregroundStyle(recoveryTint(for: routine))
                                    Spacer()
                                    Text("\(routine.durationMinutes)m")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.black.opacity(0.55))
                                }
                                Text(routine.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.black.opacity(0.82))
                                    .lineLimit(2)
                                Text(routine.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.black.opacity(0.6))
                                    .lineLimit(3)
                            }
                            .frame(width: 190, height: 140, alignment: .topLeading)
                            .padding(16)
                            .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(recoveryTint(for: routine).opacity(0.22), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Weight & Body Fat side by side
    // ─────────────────────────────────────────────────────

    private var metricPair: some View {
        HStack(alignment: .top, spacing: 0) {

            // Weight (left)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Label("WEIGHT", systemImage: "scalemass.fill")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.blue)
                        .tracking(1)
                    Circle()
                        .fill(weightTrendColor)
                        .frame(width: 8, height: 8)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(currentWeight.map { settings.unitSystem.displayWeightValue($0) } ?? "—")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue)
                    Text(settings.unitSystem.weightLabel())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(weightDelta)
                    .font(.system(size: 10))
                    .foregroundStyle(weightDelta.hasPrefix("+") ? Color.status.error : Color.status.success)
                Text("Target: \(settings.unitSystem.displayWeightValue(profile.targetWeightMin))–\(settings.unitSystem.displayWeightValue(profile.targetWeightMax)) \(settings.unitSystem.weightLabel())")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 1, height: 75)
                .padding(.horizontal, 14)

            // Body Fat (right)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Label("BODY FAT", systemImage: "drop.fill")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(1)
                    Circle()
                        .fill(bfTrendColor)
                        .frame(width: 8, height: 8)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(currentBF.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("%")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(bfDelta)
                    .font(.system(size: 10))
                    .foregroundStyle(bfDelta.hasPrefix("+") ? Color.status.error : Color.status.success)
                Text("Target: \(Int(profile.targetBFMin))–\(Int(profile.targetBFMax))%")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button { manualEntry = true } label: {
                Image(systemName: "pencil.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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

    // Returns a colour dot for weight trend over 7 days
    private var weightTrendColor: Color {
        let logs = dataStore.dailyLogs
            .filter { !Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(7)
        let vals = logs.compactMap { $0.biometrics.weightKg }
        guard vals.count >= 2 else { return Color.secondary }
        let delta = vals.first! - vals.last!  // sorted newest-first, so first=recent, last=older
        if delta < -0.2 { return Color.status.success }    // weight decreasing = good
        if delta > 0.2  { return Color.status.error }      // weight increasing = bad
        return Color.status.warning                         // flat
    }

    private var bfTrendColor: Color {
        let logs = dataStore.dailyLogs
            .filter { !Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(7)
        let vals = logs.compactMap { $0.biometrics.bodyFatPercent }
        guard vals.count >= 2 else { return Color.secondary }
        let delta = vals.first! - vals.last!
        if delta < -0.3 { return Color.status.success }
        if delta > 0.3  { return Color.status.error }
        return Color.status.warning
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Goal section
    // ─────────────────────────────────────────────────────

    private var goalSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 8)
                    .frame(width: 74, height: 74)
                Circle()
                    .trim(from: 0, to: goalProgress)
                    .stroke(
                        AngularGradient(colors: [Color.appOrange1, Color.accent.cyan, Color.appOrange1], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0), value: goalProgress)
                VStack(spacing: 0) {
                    Text("\(Int(goalProgress * 100))%")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    Text("Goal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("GOAL PROGRESS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                GoalProgressRow(label: "Weight",   progress: profile.weightProgress(current: currentWeight), color: .blue)
                GoalProgressRow(label: "Body Fat", progress: profile.bfProgress(current: currentBF),         color: .orange)
            }
            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Training button with plan picker dropdown
    // ─────────────────────────────────────────────────────

    // Light blue matching the gradient's bgBlue1
    private let buttonBlue = Color.blue

    private var trainingButton: some View {
        HStack(spacing: 14) {
            // Play / Pause circle
            Button {
                trainingActive.toggle()
                if trainingActive { showExerciseSheet = true }
            } label: {
                ZStack {
                    Circle()
                        .fill(trainingActive
                              ? Color(red: 1.0, green: 0.65, blue: 0.3)
                              : buttonBlue)
                        .frame(width: 52, height: 52)
                        .shadow(color: (trainingActive ? Color.orange : buttonBlue).opacity(0.45),
                                radius: 10, x: 0, y: 4)
                    Image(systemName: trainingActive ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .offset(x: trainingActive ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            // Day picker dropdown only
            Menu {
                Button {
                    selectedDayType = nil
                } label: {
                    HStack {
                        Text("Today's Schedule (\(programStore.todayDayType.rawValue))")
                        if selectedDayType == nil { Image(systemName: "checkmark") }
                    }
                }
                Divider()
                ForEach(DayType.allCases, id: \.self) { day in
                    Button {
                        selectedDayType = day
                    } label: {
                        HStack {
                            Label(day.rawValue, systemImage: day.icon)
                            if activeDayType == day && selectedDayType != nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: activeDayType.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("💪 \(activeDayType.rawValue) · \(TrainingProgramData.exercises(for: activeDayType).count) ex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Quick stats
    // ─────────────────────────────────────────────────────

    private var quickStats: some View {
        ReadinessCard()
    }

    private func recoveryTint(for routine: RecoveryRoutine) -> Color {
        switch routine.id {
        case RecoveryRoutineLibrary.nervousSystemReset.id:
            return Color.status.warning
        case RecoveryRoutineLibrary.mobilityFlush.id:
            return Color.accent.cyan
        default:
            return Color.accent.purple
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
                        .fill(LinearGradient(colors: [Color.appOrange1, Color.accent.cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 1.0), value: progress)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) goal progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – TodayActionCard
// ─────────────────────────────────────────────────────────

struct TodayActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.35))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.84))
                    Text(subtitle)
                        .font(AppType.subheading)
                        .foregroundStyle(.black.opacity(0.62))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(Color.white.opacity(0.24), in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – TodayTimelineRow
// ─────────────────────────────────────────────────────────

struct TodayTimelineRow: View {
    enum RowStatus {
        case pending
        case inProgress
        case complete

        var symbol: String {
            switch self {
            case .pending: "circle.dashed"
            case .inProgress: "arrow.trianglehead.clockwise"
            case .complete: "checkmark.circle.fill"
            }
        }
    }

    let title: String
    let detail: String
    let status: RowStatus
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.82))
                Text(detail)
                    .font(AppType.subheading)
                    .foregroundStyle(.black.opacity(0.6))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – QuickStatPill
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
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
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
        DailyLog(date: Date(), phase: dataStore.userProfile.currentPhase,
                 dayType: programStore.todayDayType, recoveryDay: dataStore.userProfile.daysSinceStart)
    }
}
