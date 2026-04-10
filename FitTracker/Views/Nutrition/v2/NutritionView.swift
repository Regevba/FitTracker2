// FitTracker/Views/Nutrition/v2/NutritionView.swift
// Nutrition v2 — UX Foundations alignment pass (2026-04-10)
// Built bottom-up from design system tokens. See:
//   .claude/features/nutrition-v2/v2-audit-report.md (23 findings)
//   .claude/features/nutrition-v2/ux-spec.md (token mapping)

import SwiftUI

// MARK: - Load State

enum NutritionLoadState: Equatable {
    case loading
    case success
    case error(String)
}

// MARK: - NutritionView

struct NutritionView: View {

    @EnvironmentObject var dataStore: EncryptedDataStore
    @State private var activeDate: Date = Date()
    @State private var log: DailyLog?
    @State private var supplementsExpanded = false
    @State private var editingMealEntry: MealEntry?
    @State private var showSupplementInfo = false
    @State private var loadState: NutritionLoadState = .loading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var morning: [SupplementDefinition] { TrainingProgramData.morningSupplements }
    private var evening: [SupplementDefinition] { TrainingProgramData.eveningSupplements }

    var body: some View {
        ZStack {
            AppGradient.screenBackground
                .ignoresSafeArea()

            switch loadState {
            case .loading:
                loadingState
            case .error(let message):
                errorState(message: message)
            case .success:
                successContent
            }
        }
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

    // MARK: - State Views

    private var loadingState: some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading nutrition data...")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading nutrition data")
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(AppText.metric)
                .foregroundStyle(AppColor.Status.warning)
            Text("Couldn't load nutrition data")
                .font(AppText.sectionTitle)
                .foregroundStyle(AppColor.Text.primary)
            Text(message)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)
            Button {
                loadLog(for: activeDate)
            } label: {
                Text("Retry")
                    .font(AppText.captionStrong)
                    .foregroundStyle(AppColor.Brand.primary)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(AppColor.Brand.primary.opacity(AppOpacity.disabled), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry loading")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var successContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.large) {
                dateHeader
                macroBar
                nutritionCommandDeck
                loggedItemsFeed
                quickLogSection
                supplementRow
                hydrationCard
                adherenceRow
                disclaimerNote
            }
            .padding(.horizontal, AppSpacing.small)
            .padding(.bottom, AppSpacing.xxLarge)
        }
    }

    // MARK: - Derived State

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

    private var targetCalories: Double { goalPlan.calories }
    private var targetProteinG: Double { goalPlan.proteinG }
    private var targetCarbsG: Double { goalPlan.carbsG }
    private var targetFatG: Double { goalPlan.fatG }

    private var consumedCalories: Double { nutritionLog.resolvedCalories ?? 0 }
    private var consumedProteinG: Double { nutritionLog.resolvedProteinG ?? 0 }
    private var consumedCarbsG: Double { nutritionLog.resolvedCarbsG ?? 0 }
    private var consumedFatG: Double { nutritionLog.resolvedFatG ?? 0 }

    private var remainingCalories: Double { max(targetCalories - consumedCalories, 0) }
    private var remainingProteinG: Double { max(targetProteinG - consumedProteinG, 0) }
    private var remainingFatG: Double { max(targetFatG - consumedFatG, 0) }

    private var nextMealNumber: Int {
        max((nutritionLog.meals.map(\.mealNumber).max() ?? 0) + 1, 1)
    }

    private var completionText: String {
        let completedMeals = nutritionLog.meals.filter { $0.status == .completed }.count
        let templateCount = dataStore.mealTemplates.count
        if completedMeals == 0 {
            return templateCount > 0 ? "Use your saved meals or scan a label to start the cut cleanly." : "Log your first meal to start the deficit with structure."
        }
        if remainingProteinG > 25 { return "Protein is the main gap right now. A quick repeat meal can close it fast." }
        if remainingFatG > 18 { return "You still need some healthy fats. Add them without overshooting calories." }
        if remainingCalories > 400 { return "You still have room in the plan. Finish the day with one more measured meal." }
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

    // MARK: - Date Header (F3 fix: 48pt touch targets)

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
                        .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)
                        .background(AppColor.Surface.elevated, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous day")
                .accessibilityHint("Navigate to the previous day's nutrition log")

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
                .accessibilityLabel(isViewingToday ? "Today selected" : "Jump to today")

                Button {
                    shiftDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.primary)
                        .frame(width: AppSize.touchTargetLarge, height: AppSize.touchTargetLarge)
                        .background(AppColor.Surface.elevated, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next day")
                .accessibilityHint("Navigate to the next day's nutrition log")

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

    // F7 fix: AppColor.Status.success instead of Color.status.success
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Supplement adherence \(pct) percent")
    }

    // MARK: - Macro Bar

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily nutrition")
            .accessibilityValue("\(Int(consumedCalories)) of \(Int(targetCalories)) calories")

            Text(completionText)
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
    }

    // MARK: - Command Deck (F7, F8 fixes)

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
                nutritionMetric(title: "Protein left", value: "\(Int(remainingProteinG))g", color: AppColor.Accent.nutrition)
                nutritionMetric(title: "Fat floor", value: "\(Int(max(targetFatG, 0)))g", color: AppColor.Chart.nutritionFat)
                nutritionMetric(title: "Meals logged", value: "\(nutritionLog.meals.filter { $0.status == .completed }.count)", color: AppColor.Brand.warm)
            }
        }
        .padding(.bottom, AppSpacing.xxxSmall)
    }

    // MARK: - Logged Items Feed (F14, F23 fixes)

    private var loggedItemsFeed: some View {
        let completedMeals = nutritionLog.meals
            .filter { $0.status == .completed }
            .sorted { ($0.eatenAt ?? .distantPast) < ($1.eatenAt ?? .distantPast) }

        return VStack(spacing: AppSpacing.xxSmall) {
            if completedMeals.isEmpty {
                VStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "fork.knife.circle")
                        .font(AppText.metric)
                        .foregroundStyle(AppColor.Text.tertiary)
                        .accessibilityLabel("No meals logged")
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Meal: \(meal.name.isEmpty ? "Meal \(meal.mealNumber)" : meal.name)")
                    .accessibilityValue("\(Int(meal.calories ?? 0)) calories, \(Int(meal.proteinG ?? 0)) grams protein")
                    .accessibilityHint("Double tap to edit this meal")
                }
            }
        }
    }

    // MARK: - Quick Log Section

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

    // MARK: - Supplement Row (F1, F7, F9, F10, F12, F13 fixes)

    private var supplementRow: some View {
        Group {
            if supplementsExpanded {
                VStack(spacing: AppSpacing.xSmall) {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(reduceMotion ? .none : AppMotion.quickInteraction) {
                                supplementsExpanded = false
                            }
                        } label: {
                            HStack(spacing: AppSpacing.xxxSmall) {
                                Text("Hide").font(AppText.captionStrong)
                                Image(systemName: "chevron.up").font(AppText.captionStrong)
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
                // Collapsed: compact row with pill buttons
                HStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: "pills.fill")
                        .font(AppText.titleMedium)
                        .foregroundStyle(AppColor.Accent.achievement)

                    HStack(spacing: AppSpacing.xxSmall) {
                        supplementPillButton(title: "Morning", isComplete: morningStatus == .completed) {
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
                        }

                        supplementPillButton(title: "Evening", isComplete: eveningStatus == .completed) {
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
                        }
                    }

                    Spacer()

                    // Streak badge (F9, F7 fix)
                    Text("🔥 \(dataStore.supplementStreak)")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Chart.achievement)
                        .padding(.horizontal, AppSpacing.xxSmall)
                        .padding(.vertical, AppSpacing.xxxSmall)
                        .background(AppColor.Chart.achievement.opacity(AppOpacity.subtle), in: Capsule())

                    Button {
                        withAnimation(reduceMotion ? .none : AppMotion.quickInteraction) {
                            supplementsExpanded = true
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(AppText.captionStrong)
                            .foregroundStyle(AppColor.Text.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Expand supplements")
                    .accessibilityHint("Show supplement tracking section")
                }
                .padding(.horizontal, AppSpacing.xSmall)
                .padding(.vertical, AppSpacing.xSmall)
                .background(AppColor.Surface.elevated, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            }
        }
        .motionSafe(AppEasing.short, value: supplementsExpanded)
    }

    // MARK: - Supplement Pill Button (F9, F10, F12, F13 — extracted pattern)

    private func supplementPillButton(title: String, isComplete: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxxSmall) {
                Text(title).font(AppText.captionStrong)
                if isComplete {
                    Image(systemName: "checkmark").font(AppText.captionStrong)
                }
            }
            .foregroundStyle(isComplete ? AppColor.Status.success : AppColor.Text.secondary)
            .padding(.horizontal, AppSpacing.xxSmall)
            .padding(.vertical, AppSpacing.xxxSmall)
            .background(
                isComplete
                    ? AppColor.Status.success.opacity(AppOpacity.disabled)
                    : AppColor.Surface.elevated.opacity(0.8)
            )
            .overlay(
                Capsule().stroke(isComplete ? AppColor.Status.success : AppColor.Border.subtle, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isComplete ? "\(title) supplements taken" : "\(title) supplements pending")
        .accessibilityHint("Toggle to mark \(title.lowercased()) supplements")
    }

    // MARK: - Hydration Card (F1, F6, F7 fixes — uses ProgressBar)

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

            ProgressBar(
                progress: waterProgress,
                color: AppColor.Accent.secondary,
                height: 8,
                backgroundColor: AppColor.Text.secondary.opacity(AppOpacity.disabled)
            )
            .accessibilityProgress(
                label: "Hydration progress",
                value: "\(Int(waterML)) of \(Int(waterTarget)) milliliters"
            )

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
                            .background(AppColor.Accent.recovery.opacity(AppOpacity.subtle), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(Int(amount)) milliliters")
                }

                Spacer()

                Button {
                    let current = log?.nutritionLog.alluloseTaken ?? false
                    log?.nutritionLog.alluloseTaken = !current
                    saveLog()
                } label: {
                    Label(
                        log?.nutritionLog.alluloseTaken == true ? "Allulose done" : "Allulose",
                        systemImage: log?.nutritionLog.alluloseTaken == true ? "checkmark.circle.fill" : "circle"
                    )
                    .font(AppText.captionStrong)
                    .foregroundStyle(log?.nutritionLog.alluloseTaken == true ? AppColor.Status.success : AppColor.Text.secondary)
                    .padding(.horizontal, AppSpacing.xSmall)
                    .padding(.vertical, AppSpacing.xxSmall)
                    .background(AppColor.Surface.elevated, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(log?.nutritionLog.alluloseTaken == true ? "Allulose taken" : "Allulose not taken")
                .accessibilityHint("Toggle allulose supplement")
            }
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }

    // MARK: - Adherence Row (F1, F2, F6, F7, F15, F17 fixes — uses ProgressBar)

    private var adherenceRow: some View {
        let all   = morning + evening
        let taken = individualStatus.filter { $0.value }.count
        let total = all.count
        let frac  = total > 0 ? Double(taken) / Double(total) : 0.0

        return VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack {
                Text("DAILY PROGRESS")
                    .font(AppText.monoLabel)
                    .foregroundStyle(AppColor.Text.secondary)
                    .tracking(1)
                Spacer()
                Text("\(taken)/\(total) taken")
                    .font(AppText.monoLabel)
                    .foregroundStyle(AppColor.Text.secondary)
                Button { showSupplementInfo.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(AppText.captionStrong)
                        .foregroundStyle(AppColor.Text.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Supplement adherence info")
                .accessibilityHint("Show details about supplement adherence tracking")
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

            ProgressBar(
                progress: frac,
                color: AppColor.Status.success,
                height: 6,
                backgroundColor: AppColor.Text.secondary.opacity(AppOpacity.disabled)
            )
            .accessibilityProgress(
                label: "Supplement adherence",
                value: "\(Int(frac * 100)) percent, \(taken) of \(total) taken"
            )
        }
        .padding(.vertical, AppSpacing.xxxSmall)
    }

    // MARK: - Disclaimer

    private var disclaimerNote: some View {
        HStack(alignment: .top, spacing: AppSpacing.xxSmall) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColor.Text.secondary)
                .font(AppText.caption)
            Text("Supplement timing matters. Take morning stack with food. Evening stack 30 min before bed — especially glycine + magnesium for deep sleep. Always separate creatine from NAC by 2+ hours.")
                .font(AppText.caption)
                .foregroundStyle(AppColor.Text.tertiary)
        }
        .padding(.vertical, AppSpacing.xxSmall)
    }

    // MARK: - Helpers

    private static let todayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private var formattedActiveDate: String {
        Calendar.current.isDateInToday(activeDate) ? "Today" : Self.todayDateFormatter.string(from: activeDate)
    }

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
        loadState = .loading
        let normalizedDate = Calendar.current.startOfDay(for: date)
        activeDate = normalizedDate
        log = dataStore.log(for: normalizedDate) ?? DailyLog.scheduled(
            for: normalizedDate,
            profile: dataStore.userProfile,
            dayType: suggestedDay(for: normalizedDate)
        )
        loadState = .success
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
                .background(tint.opacity(AppOpacity.subtle), in: RoundedRectangle(cornerRadius: AppRadius.small))
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
                                            .foregroundStyle(AppColor.Accent.nutrition)
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(meal.name), \(Int(meal.calories ?? 0)) calories")
                        .accessibilityHint("Double tap to prefill this meal")
                    }
                }
                .padding(.vertical, AppSpacing.micro)
            }
        }
    }
}
