// Views/Shared/ReadinessCard.swift
// Multi-page auto-cycling readiness/health summary card.
// iOS, iPadOS, macOS

import SwiftUI

struct ReadinessCard: View {
    @EnvironmentObject var dataStore: EncryptedDataStore
    @EnvironmentObject var healthKit: HealthKitService

    @State private var currentPage = 0
    @State private var timer: Timer?
    @State private var showReadinessInfo = false
    @State private var displayedScore: Int = 0

    // ── Timer helpers ─────────────────────────────────────

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            withAnimation(.easeInOut) {
                currentPage = (currentPage + 1) % 6
            }
        }
    }

    // ── Body ──────────────────────────────────────────────

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                scorePage.tag(0)
                weeklyTrainingPage.tag(1)
                nutritionPage.tag(2)
                trendsPage.tag(3)
                achievementsPage.tag(4)
                recoveryPage.tag(5)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            .tabViewStyle(.automatic)
            #endif
            .frame(height: 180)

            // Custom page dots
            pageDots
                .padding(.bottom, 6)
        }
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xLarge, style: .continuous)
                .fill(AppColor.Surface.inverse)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xLarge, style: .continuous)
                        .fill(AppGradient.darkAccent.opacity(0.78))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xLarge, style: .continuous)
                .stroke(AppColor.Border.hairline, lineWidth: 1)
        )
        .shadow(color: AppShadow.cardColor, radius: 8, y: 4)
        .onAppear { startTimer() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: currentPage) { _, _ in
            startTimer()
        }
    }

    // ── Page dots ─────────────────────────────────────────

    private var pageDots: some View {
        HStack(spacing: AppSpacing.xxxSmall) {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? AppColor.Selection.active : AppColor.Selection.inactive)
                    .frame(width: i == currentPage ? 7 : 5, height: i == currentPage ? 7 : 5)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 0: Readiness Score
    // ─────────────────────────────────────────────────────

    private var scorePage: some View {
        let score = dataStore.readinessScore(for: Date(), fallbackMetrics: healthKit.latest)
        let today = dataStore.todayLog()
        let live  = healthKit.latest

        let hrv    = live.hrv          ?? today?.biometrics.effectiveHRV
        let rhr    = live.restingHR    ?? today?.biometrics.effectiveRestingHR
        let sleep  = live.sleepHours   ?? today?.biometrics.effectiveSleep

        return VStack(spacing: AppSpacing.xxxSmall) {
            HStack(alignment: .lastTextBaseline, spacing: AppSpacing.xxxSmall) {
                Text(score != nil ? "\(displayedScore)" : "–")
                    .font(AppText.metricDisplay)
                    .foregroundStyle(AppColor.Text.inversePrimary)
                    .contentTransition(.numericText())
                if score != nil {
                    Text("/ 100")
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.inverseSecondary)
                }
            }

            if score == nil {
                Text("Add 3+ days of data")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
            }

            Text(contextLabel(for: score))
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 4)

            HStack(spacing: AppSpacing.small) {
                biometricRow(icon: "waveform.path.ecg", label: hrv.map { String(format: "%.0f ms", $0) } ?? "–", title: "HRV")
                biometricRow(icon: "heart.fill", label: rhr.map { String(format: "%.0f bpm", $0) } ?? "–", title: "RHR")
                biometricRow(icon: "moon.fill", label: sleep.map { String(format: "%.1f hrs", $0) } ?? "–", title: "Sleep")
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xxSmall)
        .onAppear {
            guard let target = score else { return }
            displayedScore = 0
            withAnimation(.interpolatingSpring(stiffness: 40, damping: 8)) {
                displayedScore = target
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { showReadinessInfo.toggle() } label: {
                Image(systemName: "info.circle")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About readiness score")
            .popover(isPresented: $showReadinessInfo) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("How Readiness Is Calculated")
                        .font(.headline)
                    Text("Readiness = 40% HRV + 30% Resting HR + 30% Sleep quality.\n\n80+ → Green light day\n60–79 → Steady, stay on plan\n40–59 → Trim load\nBelow 40 → Prioritize rest")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .padding(AppSpacing.small)
                .frame(minWidth: 260)
                .presentationCompactAdaptation(.popover)
            }
            .padding(.top, AppSpacing.xxSmall)
            .padding(.trailing, AppSpacing.small)
        }
    }

    private func contextLabel(for score: Int?) -> String {
        guard let s = score else { return "Building your baseline..." }
        switch s {
        case 80...: return "HRV looks great today 💪"
        case 60..<80: return "Good to go today"
        case 40..<60: return "Sleep was short — train lighter"
        default: return "Body needs rest today"
        }
    }

    private func biometricRow(icon: String, label: String, title: String) -> some View {
        VStack(spacing: AppSpacing.micro) {
            Image(systemName: icon)
                .font(AppText.captionStrong)
                .foregroundStyle(AppColor.Text.inverseSecondary)
            Text(label)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.inversePrimary)
                .lineLimit(1)
            Text(title)
                .font(AppText.monoLabel)
                .foregroundStyle(AppColor.Text.inverseTertiary)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 1: Weekly Training
    // ─────────────────────────────────────────────────────

    private var weeklyTrainingPage: some View {
        let cal = Calendar.current
        // Build Mon–Sun for the current week
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun..7=Sat
        // Days offset so Monday = index 0
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        let monday = cal.date(byAdding: .day, value: mondayOffset, to: cal.startOfDay(for: today)) ?? today

        let weekDays: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

        // Map logs to the week
        let logsMap: [Date: DailyLog] = Dictionary(
            uniqueKeysWithValues: dataStore.dailyLogs.compactMap { log in
                guard let day = weekDays.first(where: { cal.isDate(log.date, inSameDayAs: $0) }) else { return nil }
                return (day, log)
            }
        )

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("This Week")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)
                .padding(.horizontal, AppSpacing.small)

            HStack(alignment: .bottom, spacing: AppSpacing.xxSmall) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { idx, day in
                    let log = logsMap[day]
                    let pct = log?.completionPct ?? 0
                    let barColor: Color = {
                        guard log != nil else { return AppColor.Text.secondary.opacity(0.2) }
                        if pct >= 100 { return Color.status.success }
                        if pct > 0    { return Color.accent.cyan }
                        return AppColor.Text.secondary.opacity(0.2)
                    }()
                    let maxBarHeight: CGFloat = 60
                    let barHeight: CGFloat = log != nil ? max(4, CGFloat(pct / 100.0) * maxBarHeight) : 4

                    VStack(spacing: AppSpacing.micro) {
                        RoundedRectangle(cornerRadius: AppRadius.micro)
                            .fill(barColor)
                            .frame(height: barHeight)
                            .frame(maxWidth: .infinity)

                        Text(dayLabels[idx])
                            .font(AppText.monoLabel)
                            .foregroundStyle(AppColor.Text.inverseTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: maxBarHeight + 16, alignment: .bottom)
                }
            }
            .padding(.horizontal, AppSpacing.small)
            .frame(height: 76)

            // Next day label
            let tomorrowType = logsMap[weekDays.first(where: { cal.isDateInTomorrow($0) }) ?? today]?.dayType
            Text("Next: \(tomorrowType?.rawValue ?? "–")")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.inverseSecondary)
                .padding(.horizontal, AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.xxSmall)
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 2: Nutrition Snapshot
    // ─────────────────────────────────────────────────────

    private var nutritionPage: some View {
        let todayLog = dataStore.todayLog()
        let nutrition = todayLog?.nutritionLog
        let protein = nutrition?.resolvedProteinG ?? 0
        let lbm = todayLog?.biometrics.leanBodyMassKg
        let proteinTarget = lbm.map { $0 * 2.0 } ?? 135.0
        let waterML = nutrition?.waterML ?? 0

        let morningDone = todayLog?.supplementLog.morningStatus == .completed
        let eveningDone = todayLog?.supplementLog.eveningStatus == .completed

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("Nutrition")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)

            // Protein progress
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                HStack {
                    Text("Protein")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.inverseSecondary)
                    Spacer()
                    Text(String(format: "%.0fg / %.0fg", protein, proteinTarget))
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppRadius.micro)
                            .fill(AppColor.Surface.materialLight)
                        RoundedRectangle(cornerRadius: AppRadius.micro)
                            .fill(Color.accent.cyan)
                            .frame(width: geo.size.width * min(1, CGFloat(protein / max(proteinTarget, 1))))
                    }
                }
                .frame(height: 6)
            }

            // Supplements
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: "pill.fill")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                Text("Supplements")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseSecondary)
                supplementDot(label: "AM", done: morningDone)
                supplementDot(label: "PM", done: eveningDone)
            }

            // Water
            if waterML > 0 {
                HStack(spacing: AppSpacing.xxSmall) {
                    Image(systemName: "drop.fill")
                        .font(AppText.captionStrong)
                        .foregroundStyle(Color.accent.cyan.opacity(0.8))
                    Text(String(format: "%.0f mL water", waterML))
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.inverseSecondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xSmall)
    }

    private func supplementDot(label: String, done: Bool) -> some View {
        HStack(spacing: AppSpacing.micro) {
            Circle()
                .fill(done ? Color.status.success : AppColor.Surface.materialStrong)
                .frame(width: 8, height: 8)
            Text(label)
                .font(AppText.monoLabel)
                .foregroundStyle(AppColor.Text.inverseSecondary)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 3: 7-Day Trends
    // ─────────────────────────────────────────────────────

    private var trendsPage: some View {
        let logs = dataStore.dailyLogs
            .sorted { $0.date < $1.date }

        let latest = logs.last
        let sevenAgo = logs.count >= 2 ? logs[max(0, logs.count - 7)] : nil

        let weightDelta   = delta(latest: latest?.biometrics.weightKg,          ago: sevenAgo?.biometrics.weightKg)
        let bfDelta       = delta(latest: latest?.biometrics.bodyFatPercent,     ago: sevenAgo?.biometrics.bodyFatPercent)
        let hrvDelta      = delta(latest: latest?.biometrics.effectiveHRV,       ago: sevenAgo?.biometrics.effectiveHRV)
        let sleepDelta    = delta(latest: latest?.biometrics.effectiveSleep,     ago: sevenAgo?.biometrics.effectiveSleep)

        // Training volume: total across last 7 logs vs previous 7
        let last7  = Array(logs.suffix(7))
        let prev7  = logs.count >= 14 ? Array(logs.dropLast(7).suffix(7)) : []
        let volNow  = last7.reduce(0.0) { $0 + $1.exerciseLogs.values.reduce(0.0) { $0 + $1.totalVolume } }
        let volPrev = prev7.reduce(0.0) { $0 + $1.exerciseLogs.values.reduce(0.0) { $0 + $1.totalVolume } }
        let volDelta = volPrev > 0 ? volNow - volPrev : nil

        // Steps: use biometrics.stepCount
        let stepsNow  = last7.compactMap { $0.biometrics.stepCount }.last
        let stepsPrev = prev7.compactMap { $0.biometrics.stepCount }.last
        let stepsDelta: Double? = if let now = stepsNow, let prev = stepsPrev { Double(now - prev) } else { nil }

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("7-Day Trends")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: AppSpacing.xxSmall) {
                trendCell(label: "Weight",  delta: weightDelta,  positiveIsGood: false)
                trendCell(label: "Body Fat",delta: bfDelta,      positiveIsGood: false)
                trendCell(label: "HRV",     delta: hrvDelta,     positiveIsGood: true)
                trendCell(label: "Sleep",   delta: sleepDelta,   positiveIsGood: true)
                trendCell(label: "Volume",  delta: volDelta,     positiveIsGood: true)
                trendCell(label: "Steps",   delta: stepsDelta,   positiveIsGood: true)
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xxSmall)
    }

    private func delta(latest: Double?, ago: Double?) -> Double? {
        guard let a = latest, let b = ago else { return nil }
        return a - b
    }

    private func trendCell(label: String, delta: Double?, positiveIsGood: Bool) -> some View {
        VStack(spacing: AppSpacing.micro) {
            if let d = delta {
                TrendIndicator(delta: d, positiveIsGood: positiveIsGood, isPercent: false)
            } else {
                Text("–")
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.inverseTertiary)
            }
            Text(label)
                .font(AppText.monoLabel)
                .foregroundStyle(AppColor.Text.inverseTertiary)
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: – Page 4: Achievements
    // ─────────────────────────────────────────────────────

    private var achievementsPage: some View {
        let streak     = dataStore.supplementStreak
        let dayOnProgram = dataStore.userProfile.daysSinceStart
        let prsThisWeek = countPRsThisWeek()

        return VStack(spacing: AppSpacing.xxSmall) {
            Text("Achievements")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)

            HStack(spacing: 0) {
                achievementCell(emoji: "🔥", value: streak,       label: "Supp Streak")
                Divider().background(AppColor.Surface.materialLight).frame(height: 50)
                achievementCell(emoji: "🏆", value: prsThisWeek,  label: "PRs This Week")
                Divider().background(AppColor.Surface.materialLight).frame(height: 50)
                achievementCell(emoji: "📅", value: dayOnProgram, label: "Program Day")
            }
            .padding(.horizontal, AppSpacing.xxSmall)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }

    private func achievementCell(emoji: String, value: Int, label: String) -> some View {
        VStack(spacing: AppSpacing.xxxSmall) {
            Text(emoji)
                .font(AppText.titleStrong)
            Text("\(value)")
                .font(AppText.metric)
                .foregroundStyle(AppColor.Text.inversePrimary)
            Text(label)
                .font(AppText.monoLabel)
                .foregroundStyle(AppColor.Text.inverseTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func countPRsThisWeek() -> Int {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = (weekday == 1) ? -6 : -(weekday - 2)
        guard let weekStart = cal.date(byAdding: .day, value: mondayOffset, to: cal.startOfDay(for: today)) else { return 0 }

        let thisWeekLogs = dataStore.dailyLogs.filter { $0.date >= weekStart }
        let priorLogs    = dataStore.dailyLogs.filter { $0.date < weekStart }

        // Build all-time best per exercise from prior logs
        var allTimeBest: [String: Double] = [:]
        for log in priorLogs {
            for (exerciseID, exLog) in log.exerciseLogs {
                let best = exLog.bestSet?.weightKg ?? 0
                allTimeBest[exerciseID] = max(allTimeBest[exerciseID] ?? 0, best)
            }
        }

        // Count exercises this week that beat all-time prior best
        var prExercises = Set<String>()
        for log in thisWeekLogs {
            for (exerciseID, exLog) in log.exerciseLogs {
                guard let best = exLog.bestSet?.weightKg else { continue }
                let prior = allTimeBest[exerciseID] ?? 0
                if best > prior {
                    prExercises.insert(exerciseID)
                }
            }
        }
        return prExercises.count
    }

    private var recoveryPage: some View {
        let todayLog = dataStore.todayLog()
        let recommendation = RecoveryRoutineLibrary.recommend(
            dayType: todayLog?.dayType ?? .restDay,
            readinessScore: dataStore.readinessScore(for: Date(), fallbackMetrics: healthKit.latest),
            liveMetrics: healthKit.latest,
            log: todayLog,
            preferences: dataStore.userPreferences
        )

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("Recovery Studio")
                .font(AppText.subheading)
                .foregroundStyle(AppColor.Text.inverseSecondary)

            HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text(recommendation.routine.title)
                        .font(.headline)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                    Text(recommendation.routine.focus)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.inverseSecondary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.xxxSmall) {
                    Text("\(recommendation.routine.durationMinutes)m")
                        .font(AppText.monoMetric)
                        .foregroundStyle(AppColor.Text.inversePrimary)
                    Text(recommendation.routine.intensityLabel)
                        .font(AppText.monoLabel)
                        .foregroundStyle(AppColor.Text.inverseTertiary)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                ForEach(Array(recommendation.reasons.prefix(2)), id: \.self) { reason in
                    HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
                        Image(systemName: "sparkles")
                            .font(AppText.caption)
                            .foregroundStyle(Color.accent.cyan.opacity(0.9))
                            .padding(.top, 1)
                        Text(reason)
                            .font(AppText.caption)
                            .foregroundStyle(AppColor.Text.inverseSecondary)
                            .lineLimit(2)
                    }
                }
            }

            HStack(spacing: AppSpacing.xxSmall) {
                ForEach(recommendation.routine.steps.prefix(2)) { step in
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        Text(step.title)
                            .font(AppText.captionStrong)
                            .foregroundStyle(AppColor.Text.inversePrimary)
                            .lineLimit(2)
                        Text("\(step.minutes) min")
                            .font(AppText.monoLabel)
                            .foregroundStyle(AppColor.Text.inverseTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.xxSmall)
                    .background(AppColor.Surface.primary.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                }
            }
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xSmall)
    }
}
