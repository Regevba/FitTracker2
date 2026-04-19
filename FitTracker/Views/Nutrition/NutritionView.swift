// HISTORICAL — superseded by v2/NutritionView.swift on 2026-04-10 per
// UX Foundations alignment pass. See
// .claude/features/nutrition-v2/v2-audit-report.md for the gap analysis.
// This file is no longer in the build target; it stays in the repo
// as a reviewable reference for the v1 → v2 diff.
//
// Audit UI-003 closure (2026-04-19): file is correctly excluded from the
// Sources build phase in FitTracker.xcodeproj. The Sources entry references
// v2/NutritionView.swift; the v1 file has only a PBXFileReference (visible
// in git history + navigator) without a PBXBuildFile entry. No code change
// required — the audit's "1112-line file" concern is moot because the file
// is dead weight in the repo, not in the binary.

import SwiftUI

struct NutritionView_V1_Historical: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @State private var activeDate: Date = Date()
    @State private var log: DailyLog?
    @State private var supplementsExpanded = false
    @State private var editingMealEntry: MealEntry?
    @State private var showSupplementInfo = false

    private var morning: [SupplementDefinition] { TrainingProgramData.morningSupplements }
    private var evening: [SupplementDefinition] { TrainingProgramData.eveningSupplements }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.large) {
                dateHeader
                macroBar             // 1. Macro targets always pinned at top
                nutritionCommandDeck // 2. Log First Meal + Quick Protein buttons
                loggedItemsFeed      // 3. Chronological feed (replaces meal slot sections)
                quickLogSection      // 4. Favorites + Remembered meals
                supplementRow        // 5. Supplements
                hydrationCard        // 6. Hydration
                adherenceRow         // 7. Adherence summary

                disclaimerNote
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.xxLarge)
        }
        } // ZStack
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            activeDate = Calendar.current.startOfDay(for: Date())
            loadLog(for: activeDate)
        }
        .onDisappear { saveLog() }
        .sheet(item: $editingMealEntry) { entry in
            let entryBinding = Binding<MealEntry>(
                get: { log?.nutritionLog.meals.first(where: { $0.mealNumber == entry.mealNumber }) ?? entry },
                set: { newEntry in
                    if let i = log?.nutritionLog.meals.firstIndex(where: { $0.mealNumber == entry.mealNumber }) {
                        log?.nutritionLog.meals[i] = newEntry
                    } else {
                        log?.nutritionLog.meals.append(newEntry)
                    }
                }
            )
            MealEntrySheet(entry: entryBinding) { saved in
                if let i = log?.nutritionLog.meals.firstIndex(where: { $0.mealNumber == saved.mealNumber }) {
                    log?.nutritionLog.meals[i] = saved
                } else {
                    log?.nutritionLog.meals.append(saved)
                }
                saveLog()
                editingMealEntry = nil
            }
            .environmentObject(dataStore)
            .analyticsScreen(AnalyticsScreen.mealEntry)
            .presentationDetents([.large])
            .presentationCornerRadius(AppSheet.standardCornerRadius)
        }
    }

    // ─────────────────────────────────────────────────────
    // Derived state
    // ─────────────────────────────────────────────────────

    private var morningStatus: TaskStatus { log?.supplementLog.morningStatus ?? .pending }
    private var eveningStatus: TaskStatus { log?.supplementLog.eveningStatus ?? .pending }

    private var individualStatus: [String: Bool] {
        log?.supplementLog.individualOverrides ?? [:]
    }

    private var nutritionLog: NutritionLog {
        log?.nutritionLog ?? NutritionLog()
    }

    private var isTrainingDay: Bool {
        (log?.dayType ?? suggestedDay(for: activeDate)).isTrainingDay
    }

    private var latestWeightKg: Double? {
        if let current = log?.biometrics.weightKg { return current }
        return dataStore.dailyLogs
            .sorted { $0.date > $1.date }
            .compactMap { $0.biometrics.weightKg }
            .first
    }

    private var latestBodyFatPercent: Double? {
        if let current = log?.biometrics.bodyFatPercent { return current }
        return dataStore.dailyLogs
            .sorted { $0.date > $1.date }
            .compactMap { $0.biometrics.bodyFatPercent }
            .first
    }

    private var goalPlan: NutritionGoalPlan {
        dataStore.userProfile.nutritionPlan(
            currentWeightKg: latestWeightKg,
            currentBodyFatPercent: latestBodyFatPercent,
            isTrainingDay: isTrainingDay,
            preferences: dataStore.userPreferences
        )
    }

    private var targetCalories: Double {
        goalPlan.calories
    }

    private var targetProteinG: Double {
        goalPlan.proteinG
    }

    private var targetCarbsG: Double {
        goalPlan.carbsG
    }

    private var targetFatG: Double {
        goalPlan.fatG
    }

    private var consumedCalories: Double {
        nutritionLog.resolvedCalories ?? 0
    }

    private var consumedProteinG: Double {
        nutritionLog.resolvedProteinG ?? 0
    }

    private var consumedCarbsG: Double {
        nutritionLog.resolvedCarbsG ?? 0
    }

    private var consumedFatG: Double {
        nutritionLog.resolvedFatG ?? 0
    }

    private var remainingCalories: Double {
        max(targetCalories - consumedCalories, 0)
    }

    private var remainingProteinG: Double {
        max(targetProteinG - consumedProteinG, 0)
    }

    private var remainingFatG: Double {
        max(targetFatG - consumedFatG, 0)
    }

    private var nextMealNumber: Int {
        max((nutritionLog.meals.map(\.mealNumber).max() ?? 0) + 1, 1)
    }

    private var completionText: String {
        let completedMeals = nutritionLog.meals.filter { $0.status == .completed }.count
        let templateCount = dataStore.mealTemplates.count
        if completedMeals == 0 {
            return templateCount > 0 ? "Use your saved meals or scan a label to start the cut cleanly." : "Log your first meal to start the deficit with structure."
        }
        if remainingProteinG > 25 {
            return "Protein is the main gap right now. A quick repeat meal can close it fast."
        }
        if remainingFatG > 18 {
            return "You still need some healthy fats. Add them without overshooting calories."
        }
        if remainingCalories > 400 {
            return "You still have room in the plan. Finish the day with one more measured meal."
        }
        return "Nutrition is on track. Keep hydration tight and protect the deficit."
    }

    private var recentMeals: [MealEntry] {
        var seen = Set<String>()
        return dataStore.dailyLogs
            .sorted { $0.date > $1.date }
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: activeDate) }
            .flatMap { $0.nutritionLog.meals }
            .filter { $0.status == .completed && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { meal in
                let key = meal.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return seen.insert(key).inserted
            }
            .prefix(6)
            .map { $0 }
    }

    // ─────────────────────────────────────────────────────
    // Sub-views
    // ─────────────────────────────────────────────────────

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text("Nutrition")
                        .font(AppText.pageTitle)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(formattedActiveDate)
                        .font(AppText.body)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                overallBadge
            }

            HStack(spacing: AppSpacing.xxSmall) {
                Button {
                    shiftDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                        .accessibilityLabel("Previous day")
                        .accessibilityHint("Navigate to the previous day's nutrition log")
                        .frame(width: 44, height: 44)
                        .background(AppColor.Surface.elevated, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    activeDate = Calendar.current.startOfDay(for: Date())
                    loadLog(for: activeDate)
                } label: {
                    Text(isViewingToday ? "Today" : "Jump to Today")
                        .font(AppText.captionStrong)
                        .foregroundStyle(isViewingToday ? AppColor.Text.secondary : AppColor.Text.primary)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .background(AppColor.Surface.elevated, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    shiftDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                        .accessibilityLabel("Next day")
                        .accessibilityHint("Navigate to the next day's nutrition log")
                        .frame(width: 44, height: 44)
                        .background(AppColor.Surface.elevated, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(log?.dayType.rawValue ?? suggestedDay(for: activeDate).rawValue)
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.secondary)
                    .padding(.horizontal, AppSpacing.xSmall)
                    .padding(.vertical, AppSpacing.xxSmall)
                    .background(AppColor.Surface.elevated, in: Capsule())
            }
        }
        .padding(.top, AppSpacing.xxxSmall)
    }

    private var overallBadge: some View {
        let total  = morning.count + evening.count
        let taken  = individualStatus.filter { $0.value }.count
        let pct    = total > 0 ? Int(Double(taken) / Double(total) * 100) : 0
        return VStack(spacing: AppSpacing.micro) {
            Text("\(pct)%")
                .font(AppText.monoMetric)
                .foregroundStyle(AppColor.Status.success)
            Text("supps")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }

    private var nutritionCommandDeck: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text("NUTRITION STRATEGY")
                        .font(AppText.monoLabel)
                        .foregroundStyle(AppColor.Text.secondary)
                        .tracking(1.4)
                    Text(goalPlan.title)
                        .font(AppText.sectionTitle)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(goalPlan.summary)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: AppSpacing.xxSmall) {
                    Text("\(Int(remainingCalories))")
                        .font(AppText.monoMetric)
                        .foregroundStyle(AppColor.Accent.primary)
                    Text(goalPlan.emphasis)
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Quick shortcuts — meal logging itself happens through the meal slots below.
            if !recentMeals.isEmpty {
                quickActionButton(
                    title: "Repeat Last",
                    icon: "clock.arrow.circlepath",
                    tint: AppColor.Status.success
                ) {
                    if let recent = recentMeals.first {
                        openPrefilledMeal(recent)
                    }
                }
            }

            HStack(spacing: AppSpacing.medium) {
                nutritionMetric(title: "Protein left", value: "\(Int(remainingProteinG))g", color: AppColor.Accent.recovery)
                nutritionMetric(title: "Fat floor", value: "\(Int(max(targetFatG, 0)))g", color: AppColor.Chart.nutritionFat)
                nutritionMetric(title: "Meals logged", value: "\(nutritionLog.meals.filter { $0.status == .completed }.count)", color: AppColor.Brand.warm)
            }
        }
        .padding(.bottom, AppSpacing.xxxSmall)
    }

    private var adherenceRow: some View {
        let all   = morning + evening
        let taken = individualStatus.filter { $0.value }.count
        let total = all.count
        let frac  = total > 0 ? Double(taken) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack {
                Text("DAILY PROGRESS")
                    .font(AppText.monoLabel).foregroundStyle(AppColor.Text.secondary).tracking(1)
                Spacer()
                Text("\(taken)/\(total) taken")
                    .font(AppText.monoLabel).foregroundStyle(AppColor.Text.secondary)
                Button { showSupplementInfo.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Supplement information")
                .accessibilityHint("Show details about supplements")
                .accessibilityLabel("About supplement adherence")
                .popover(isPresented: $showSupplementInfo) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text("Supplement Adherence")
                            .font(AppText.sectionTitle)
                            .foregroundStyle(AppColor.Text.primary)
                        Text("Tracks whether you took all pills in your morning and evening stacks today. The 🔥 streak counts consecutive days with 100% adherence across both stacks.")
                            .font(AppText.body)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .padding(AppSpacing.small)
                    .frame(minWidth: 260)
                    .presentationCompactAdaptation(.popover)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(AppColor.Text.secondary.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(LinearGradient(colors: [AppColor.Status.success, AppColor.Status.success], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * frac, height: 6)
                        .animation(.spring(response: 0.6), value: frac)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }

    private var macroBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack {
                Text("MACRO TARGETS")
                    .font(AppText.monoLabel)
                    .foregroundStyle(AppColor.Text.secondary)
                    .tracking(1.4)
                Spacer()
                Text("\(Int(consumedCalories)) / \(Int(targetCalories)) kcal")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            MacroTargetBar(
                protein: nutritionLog.resolvedProteinG ?? 0,
                carbs: nutritionLog.resolvedCarbsG ?? 0,
                fat: nutritionLog.resolvedFatG ?? 0,
                targetCalories: Int(targetCalories),
                targetProteinG: targetProteinG,
                targetCarbsG: targetCarbsG,
                targetFatG: targetFatG
            )

            Text(completionText)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }

    // Chronological feed of all logged meals — replaces the old slot-based MealSectionView.
    // Each entry shows name + time + kcal + protein. Tappable to edit.
    private var loggedItemsFeed: some View {
        let completedMeals = nutritionLog.meals
            .filter { $0.status == .completed }
            .sorted { ($0.eatenAt ?? .distantPast) < ($1.eatenAt ?? .distantPast) }

        return VStack(spacing: AppSpacing.xxSmall) {
            if completedMeals.isEmpty {
                // Empty state — encourage first log
                VStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "fork.knife.circle")
                        .font(AppText.metric)
                        .foregroundStyle(AppColor.Text.tertiary)
                    Text("No meals logged yet today")
                        .font(AppText.subheading)
                        .foregroundStyle(AppColor.Text.secondary)
                    Text("Tap \"Log First Meal\" above to start tracking.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.large)
            } else {
                ForEach(completedMeals, id: \.mealNumber) { meal in
                    Button {
                        editingMealEntry = meal
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                                Text(meal.name.isEmpty ? "Meal \(meal.mealNumber)" : meal.name)
                                    .font(AppText.body)
                                    .foregroundStyle(AppColor.Text.primary)
                                if let time = meal.eatenAt {
                                    Text(time, style: .time)
                                        .font(AppText.caption)
                                        .foregroundStyle(AppColor.Text.tertiary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: AppSpacing.micro) {
                                Text("\(Int(meal.calories ?? 0)) kcal")
                                    .font(AppText.captionStrong)
                                    .foregroundStyle(AppColor.Text.primary)
                                Text("\(Int(meal.proteinG ?? 0))g protein")
                                    .font(AppText.caption)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                        }
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.xSmall)
                        .background(AppColor.Surface.materialLight, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColor.Border.subtle.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            if !dataStore.mealTemplates.isEmpty {
                quickMealLane(
                    title: "Favorites",
                    subtitle: "Saved templates for repeat meals",
                    meals: dataStore.mealTemplates.prefix(6).map {
                        MealEntry(
                            mealNumber: nextMealNumber,
                            name: $0.name,
                            calories: $0.calories,
                            proteinG: $0.proteinG,
                            carbsG: $0.carbsG,
                            fatG: $0.fatG
                        )
                    }
                )
            }

            if !recentMeals.isEmpty {
                quickMealLane(
                    title: "Remembered Meals",
                    subtitle: "Recently logged meals you can reuse",
                    meals: recentMeals
                )
            }
        }
    }

    private var hydrationCard: some View {
        let waterML = nutritionLog.waterML ?? 0
        let waterTarget = isTrainingDay ? 3500.0 : 2800.0
        let waterProgress = min(max(waterML / waterTarget, 0), 1)

        return VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text("Hydration")
                        .font(AppText.sectionTitle)
                    Text(isTrainingDay ? "Training days need a little more water." : "Keep the baseline high even on rest days.")
                        .font(AppText.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                Text("\(Int(waterML)) ml")
                    .font(AppText.monoMetric)
                    .foregroundStyle(AppColor.Accent.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(AppColor.Text.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: AppRadius.micro)
                        .fill(LinearGradient(colors: [AppColor.Accent.recovery.opacity(0.72), AppColor.Accent.secondary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * waterProgress, height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: AppSpacing.xxSmall) {
                ForEach([250.0, 500.0, 1000.0], id: \.self) { amount in
                    Button {
                        log?.nutritionLog.waterML = waterML + amount
                        saveLog()
                    } label: {
                        Text("+\(Int(amount)) ml")
                            .font(AppText.captionStrong)
                            .foregroundStyle(AppColor.Accent.secondary)
                            .padding(.horizontal, AppSpacing.xSmall)
                            .padding(.vertical, AppSpacing.xxSmall)
                            .background(AppColor.Accent.recovery.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    let current = log?.nutritionLog.alluloseTaken ?? false
                    log?.nutritionLog.alluloseTaken = !current
                    saveLog()
                } label: {
                    Label(log?.nutritionLog.alluloseTaken == true ? "Allulose done" : "Allulose", systemImage: log?.nutritionLog.alluloseTaken == true ? "checkmark.circle.fill" : "circle")
                        .font(AppText.captionStrong)
                        .foregroundStyle(log?.nutritionLog.alluloseTaken == true ? AppColor.Status.success : AppColor.Text.secondary)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, AppSpacing.xxSmall)
                        .background(AppColor.Surface.elevated, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }

    // ─────────────────────────────────────────────────────
    // Compact supplement row (collapsed) / full cards (expanded)
    // ─────────────────────────────────────────────────────

    private var supplementRow: some View {
        Group {
            if supplementsExpanded {
                // ── Expanded: show full stack cards with a collapse button ──
                VStack(spacing: AppSpacing.xSmall) {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                supplementsExpanded = false
                            }
                        } label: {
                            HStack(spacing: AppSpacing.xxxSmall) {
                                Text("Hide")
                                    .font(AppText.captionStrong)
                                Image(systemName: "chevron.up")
                                    .font(AppText.captionStrong)
                            }
                            .foregroundStyle(AppColor.Text.secondary)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(AppColor.Surface.elevated, in: Capsule())
                        }
                    }

                    SupplementStackCard(
                        stackTitle: "🌅  Morning Stack",
                        stackSubtitle: "Take with breakfast",
                        supplements: morning,
                        stackStatus: morningStatus,
                        individualStatus: individualStatus,
                        accentColor: AppColor.Accent.achievement
                    ) { newStatus in
                        log?.supplementLog.morningStatus = newStatus
                        if newStatus == .completed {
                            log?.supplementLog.morningTime = Date()
                            for s in morning { log?.supplementLog.individualOverrides[s.id] = true }
                        }
                        saveLog()
                    } onToggle: { suppID, taken in
                        log?.supplementLog.individualOverrides[suppID] = taken
                        recomputeStackStatus(isEvening: false)
                        saveLog()
                    }

                    SupplementStackCard(
                        stackTitle: "🌙  Evening Stack",
                        stackSubtitle: "30 min before bed",
                        supplements: evening,
                        stackStatus: eveningStatus,
                        individualStatus: individualStatus,
                        accentColor: AppColor.Accent.sleep
                    ) { newStatus in
                        log?.supplementLog.eveningStatus = newStatus
                        if newStatus == .completed {
                            log?.supplementLog.eveningTime = Date()
                            for s in evening { log?.supplementLog.individualOverrides[s.id] = true }
                        }
                        saveLog()
                    } onToggle: { suppID, taken in
                        log?.supplementLog.individualOverrides[suppID] = taken
                        recomputeStackStatus(isEvening: true)
                        saveLog()
                    }
                }
            } else {
                // ── Collapsed: single compact row ──
                HStack(spacing: AppSpacing.xSmall) {

                    // Pills icon
                    Image(systemName: "pills.fill")
                        .font(AppText.titleMedium)
                        .foregroundStyle(AppColor.Accent.achievement)

                    // Morning + Evening pill status buttons
                    HStack(spacing: AppSpacing.xxSmall) {
                        // Morning pill
                        Button {
                            HapticFeedback.impact()
                            let newStatus: TaskStatus = morningStatus == .completed ? .pending : .completed
                            log?.supplementLog.morningStatus = newStatus
                            if newStatus == .completed {
                                log?.supplementLog.morningTime = Date()
                                for s in morning { log?.supplementLog.individualOverrides[s.id] = true }
                            } else {
                                for s in morning { log?.supplementLog.individualOverrides[s.id] = false }
                            }
                            recomputeStackStatus(isEvening: false)
                            saveLog()
                        } label: {
                            HStack(spacing: AppSpacing.xxxSmall) {
                                Text("Morning")
                                    .font(AppText.captionStrong)
                                if morningStatus == .completed {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(morningStatus == .completed ? AppColor.Status.success : AppColor.Text.secondary)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(
                                morningStatus == .completed
                                    ? AppColor.Status.success.opacity(0.15)
                                    : AppColor.Surface.elevated.opacity(0.8)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        morningStatus == .completed
                                            ? AppColor.Status.success
                                            : AppColor.Border.subtle,
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Evening pill
                        Button {
                            HapticFeedback.impact()
                            let newStatus: TaskStatus = eveningStatus == .completed ? .pending : .completed
                            log?.supplementLog.eveningStatus = newStatus
                            if newStatus == .completed {
                                log?.supplementLog.eveningTime = Date()
                                for s in evening { log?.supplementLog.individualOverrides[s.id] = true }
                            } else {
                                for s in evening { log?.supplementLog.individualOverrides[s.id] = false }
                            }
                            recomputeStackStatus(isEvening: true)
                            saveLog()
                        } label: {
                            HStack(spacing: AppSpacing.xxxSmall) {
                                Text("Evening")
                                    .font(AppText.captionStrong)
                                if eveningStatus == .completed {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(eveningStatus == .completed ? AppColor.Status.success : AppColor.Text.secondary)
                            .padding(.horizontal, AppSpacing.xxSmall)
                            .padding(.vertical, AppSpacing.xxxSmall)
                            .background(
                                eveningStatus == .completed
                                    ? AppColor.Status.success.opacity(0.15)
                                    : AppColor.Surface.elevated.opacity(0.8)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        eveningStatus == .completed
                                            ? AppColor.Status.success
                                            : AppColor.Border.subtle,
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Streak badge
                    Text("🔥 \(dataStore.supplementStreak)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, AppSpacing.xxSmall)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(Color.orange.opacity(0.12), in: Capsule())

                    // Expand chevron
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            supplementsExpanded = true
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .accessibilityLabel("Expand supplements")
                            .accessibilityHint("Show supplement tracking section")
                            .font(AppText.captionStrong)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xSmall)
                .padding(.vertical, AppSpacing.xSmall)
                .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: supplementsExpanded)
    }

    private var disclaimerNote: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
            Image(systemName: "info.circle").foregroundStyle(AppColor.Text.secondary).font(AppText.caption)
            Text("Supplement timing matters. Take morning stack with food. Evening stack 30 min before bed — especially glycine + magnesium for deep sleep. Always separate creatine from NAC by 2+ hours.")
                .font(AppText.caption).foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.vertical, AppSpacing.xxSmall)
    }

    private static let todayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var formattedActiveDate: String {
        if Calendar.current.isDateInToday(activeDate) {
            return "Today"
        }
        return Self.todayDateFormatter.string(from: activeDate)
    }

    // ─────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(activeDate)
    }

    private func saveLog() {
        guard var current = log else { return }
        current.date = activeDate
        current.dayType = log?.dayType ?? suggestedDay(for: activeDate)
        current.recoveryDay = dataStore.userProfile.recoveryDay(for: activeDate)
        log = current
        dataStore.upsertLog(current)
    }

    private func loadLog(for date: Date) {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        activeDate = normalizedDate
        log = dataStore.log(for: normalizedDate) ?? DailyLog.scheduled(
            for: normalizedDate,
            profile: dataStore.userProfile,
            dayType: suggestedDay(for: normalizedDate)
        )
    }

    private func shiftDay(by days: Int) {
        guard let nextDate = Calendar.current.date(byAdding: .day, value: days, to: activeDate) else { return }
        saveLog()
        loadLog(for: nextDate)
    }

    private func suggestedDay(for date: Date) -> DayType {
        TrainingProgramStore.dayType(forWeekday: Calendar.current.component(.weekday, from: date))
    }

    private func recomputeStackStatus(isEvening: Bool) {
        let group = isEvening ? evening : morning
        let taken = group.filter { log?.supplementLog.individualOverrides[$0.id] == true }.count
        let status: TaskStatus = taken == 0 ? .pending
                               : taken == group.count ? .completed
                               : .partial
        if isEvening { log?.supplementLog.eveningStatus = status }
        else          { log?.supplementLog.morningStatus = status }
    }

    private func openPrefilledMeal(_ meal: MealEntry) {
        editingMealEntry = MealEntry(
            mealNumber: nextMealNumber,
            name: meal.name,
            calories: meal.calories,
            proteinG: meal.proteinG,
            carbsG: meal.carbsG,
            fatG: meal.fatG
        )
    }

    private func quickActionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(AppText.captionStrong)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xSmall)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.small))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func nutritionMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
            Text(title)
                .font(AppText.monoLabel)
                .foregroundStyle(AppColor.Text.secondary)
            Text(value)
                .font(AppText.captionStrong)
                .foregroundStyle(color)
        }
    }

    private func quickMealLane(title: String, subtitle: String, meals: [MealEntry]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                Text(title)
                    .font(AppText.sectionTitle)
                    .foregroundStyle(AppColor.Text.primary)
                Text(subtitle)
                    .font(AppText.caption)
                    .foregroundStyle(AppColor.Text.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xSmall) {
                    ForEach(meals) { meal in
                        Button {
                            openPrefilledMeal(meal)
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                                Text(meal.name)
                                    .font(AppText.callout)
                                    .foregroundStyle(AppColor.Text.primary)
                                    .lineLimit(2)
                                HStack(spacing: AppSpacing.xxSmall) {
                                    if let calories = meal.calories {
                                        Text("\(Int(calories)) kcal")
                                            .font(AppText.caption)
                                            .foregroundStyle(AppColor.Accent.primary)
                                    }
                                    if let protein = meal.proteinG {
                                        Text("\(Int(protein))g protein")
                                            .font(AppText.caption)
                                            .foregroundStyle(AppColor.Accent.recovery)
                                    }
                                }
                                Text("Tap to prefill")
                                    .font(AppText.monoLabel)
                                    .foregroundStyle(AppColor.Text.secondary)
                            }
                            .frame(minWidth: 160, idealWidth: 180, maxWidth: 220, alignment: .leading)
                            .padding(.vertical, AppSpacing.xxxSmall)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, AppSpacing.micro)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Supplement Stack Card
// ─────────────────────────────────────────────────────────

struct SupplementStackCard: View {

    let stackTitle:      String
    let stackSubtitle:   String
    let supplements:     [SupplementDefinition]
    let stackStatus:     TaskStatus
    let individualStatus: [String: Bool]
    let accentColor:     Color
    let onStackStatus:   (TaskStatus) -> Void
    let onToggle:        (String, Bool) -> Void

    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {

            // ── Stack header ─────────────────────────────
            HStack(spacing: AppSpacing.xSmall) {
                VStack(alignment: .leading, spacing: AppSpacing.micro) {
                    Text(stackTitle)
                        .font(AppText.sectionTitle)
                        .foregroundStyle(AppColor.Text.primary)
                    Text(stackSubtitle)
                        .font(AppText.caption).foregroundStyle(AppColor.Text.secondary)
                }
                Spacer()
                // Mark all button
                StatusDropdown(status: stackStatus, onSelect: onStackStatus)
                // Expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                        .accessibilityLabel(expanded ? "Collapse" : "Expand")
                        .accessibilityHint(expanded ? "Hide details" : "Show details")
                }
            }
            .padding(AppSpacing.xSmall)
            .background(accentColor.opacity(0.07))

            // ── Status indicator bar ─────────────────────
            GeometryReader { geo in
                let taken = supplements.filter { individualStatus[$0.id] == true }.count
                let frac  = supplements.count > 0 ? Double(taken) / Double(supplements.count) : 0
                Rectangle()
                    .fill(accentColor.opacity(0.15)).frame(height: 3)
                Rectangle()
                    .fill(accentColor)
                    .frame(width: geo.size.width * frac, height: 3)
                    .animation(.spring(response: 0.5), value: frac)
            }
            .frame(height: 3)

            // ── Supplement rows ──────────────────────────
            if expanded {
                ForEach(supplements) { supp in
                    SupplementItemRow(
                        supplement: supp,
                        isTaken: individualStatus[supp.id] ?? false,
                        accentColor: accentColor
                    ) { taken in
                        onToggle(supp.id, taken)
                    }
                    // 54pt indent aligns divider with text after supplement icon + spacing
                    if supp.id != supplements.last?.id { Divider().padding(.leading, 54) }
                }
            }
        }
        .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(stackStatus == .completed ? accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .clipped()
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Single supplement row
// ─────────────────────────────────────────────────────────

struct SupplementItemRow: View {

    let supplement:  SupplementDefinition
    let isTaken:     Bool
    let accentColor: Color
    let onToggle:    (Bool) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticFeedback.impact()
                onToggle(!isTaken)
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    // Checkbox
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.xSmall)
                            .stroke(isTaken ? accentColor : AppColor.Border.subtle, lineWidth: 1.5)
                            .frame(width: 26, height: 26)
                        if isTaken {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accentColor)
                        }
                    }

                    // Supplement info
                    VStack(alignment: .leading, spacing: AppSpacing.micro) {
                        HStack(spacing: AppSpacing.xxSmall) {
                            Text(supplement.name)
                                .font(AppText.callout)
                                .strikethrough(isTaken, color: accentColor)
                                .foregroundStyle(isTaken ? AppColor.Text.secondary : AppColor.Text.primary)
                            Text(supplement.dose)
                                .font(AppText.monoLabel)
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, AppSpacing.xxxSmall).padding(.vertical, AppSpacing.micro)
                                .background(accentColor.opacity(0.1), in: Capsule())
                        }
                        Text(supplement.timing.rawValue)
                            .font(AppText.caption).foregroundStyle(AppColor.Text.secondary)
                    }

                    Spacer()

                    // Info expand toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(AppText.caption).foregroundStyle(AppColor.Text.secondary)
                    }
                    .accessibilityLabel("Show details")
                    .accessibilityHint("Toggle supplement details")
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xSmall).padding(.vertical, AppSpacing.xSmall)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable benefit / notes
            if expanded {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text(supplement.benefit)
                        .font(AppText.caption).foregroundStyle(AppColor.Text.secondary)
                    HStack(spacing: AppSpacing.xxxSmall) {
                        Image(systemName: "clock").font(AppText.caption).foregroundStyle(AppColor.Text.tertiary)
                        Text(supplement.notes).font(AppText.caption).foregroundStyle(AppColor.Text.tertiary)
                    }
                }
                // 54pt horizontal indent matches supplement icon + label alignment
                .padding(.horizontal, 54).padding(.bottom, AppSpacing.xxSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.03))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Haptic helper (iOS only)
// ─────────────────────────────────────────────────────────

enum HapticFeedback {
    static func impact() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
        #endif
    }
}
