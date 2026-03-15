import Foundation

struct RecoveryStep: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let minutes: Int
}

struct RecoveryRoutine: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let focus: String
    let icon: String
    let durationMinutes: Int
    let intensityLabel: String
    let coachingNote: String
    let steps: [RecoveryStep]
}

struct RecoveryRecommendation: Sendable {
    let routine: RecoveryRoutine
    let reasons: [String]
    let shouldReplaceTraining: Bool
}

enum RecoveryRoutineLibrary {
    static let nervousSystemReset = RecoveryRoutine(
        id: "nervous_system_reset",
        title: "Nervous System Reset",
        subtitle: "Breathing, downshifting, and low-demand movement.",
        focus: "Lower stress load and get the body back to baseline.",
        icon: "lungs.fill",
        durationMinutes: 12,
        intensityLabel: "Low",
        coachingNote: "Keep effort light. The goal is to leave this feeling calmer than when you started.",
        steps: [
            RecoveryStep(id: "reset_1", title: "Box breathing", detail: "Inhale 4, hold 4, exhale 4, hold 4.", minutes: 3),
            RecoveryStep(id: "reset_2", title: "Supine twist + reach", detail: "Slow alternating trunk rotation and long exhales.", minutes: 3),
            RecoveryStep(id: "reset_3", title: "Easy walk", detail: "Quiet nasal breathing and relaxed shoulders.", minutes: 6)
        ]
    )

    static let mobilityFlush = RecoveryRoutine(
        id: "mobility_flush",
        title: "Mobility Flush",
        subtitle: "Joint prep and tissue-friendly movement for stiff days.",
        focus: "Open hips, thoracic spine, shoulders, and ankles without fatigue.",
        icon: "figure.cooldown",
        durationMinutes: 18,
        intensityLabel: "Low-Moderate",
        coachingNote: "Move smoothly, not deeply. This should feel like circulation and range, not stretching pain.",
        steps: [
            RecoveryStep(id: "flush_1", title: "Cat-cow + thoracic rotation", detail: "Restore spinal motion and upper-back rotation.", minutes: 4),
            RecoveryStep(id: "flush_2", title: "90/90 hip flow", detail: "Controlled hip internal and external rotation.", minutes: 5),
            RecoveryStep(id: "flush_3", title: "Ankle rocks + calf opener", detail: "Drive knee over toe with heel down.", minutes: 4),
            RecoveryStep(id: "flush_4", title: "Band or wall shoulder opener", detail: "Gentle overhead reach and scap movement.", minutes: 5)
        ]
    )

    static let yogaFlow = RecoveryRoutine(
        id: "yoga_flow",
        title: "Recovery Yoga Flow",
        subtitle: "Slow full-body sequence for tired or mentally heavy days.",
        focus: "Blend breathing, mobility, and light tissue loading.",
        icon: "figure.yoga",
        durationMinutes: 24,
        intensityLabel: "Moderate",
        coachingNote: "Stay with the breath. If one position feels sticky, shorten the range and keep moving.",
        steps: [
            RecoveryStep(id: "yoga_1", title: "Sun-breath warm-up", detail: "Gentle overhead reach, fold, and half-lift rhythm.", minutes: 4),
            RecoveryStep(id: "yoga_2", title: "World's greatest stretch", detail: "Lunge, rotate, and open the hip flexors.", minutes: 6),
            RecoveryStep(id: "yoga_3", title: "Down dog to plank wave", detail: "Light shoulder and hamstring loading.", minutes: 6),
            RecoveryStep(id: "yoga_4", title: "Pigeon or figure-four", detail: "Long exhale hip opener to finish.", minutes: 8)
        ]
    )

    static let all: [RecoveryRoutine] = [nervousSystemReset, mobilityFlush, yogaFlow]

    static func recommend(dayType: DayType, readinessScore: Int?, liveMetrics: LiveMetrics, log: DailyLog?, preferences: UserPreferences = UserPreferences()) -> RecoveryRecommendation {
        let sleep = liveMetrics.sleepHours ?? log?.biometrics.effectiveSleep ?? 0
        let hrv = liveMetrics.hrv ?? log?.biometrics.effectiveHRV ?? 0
        let restingHR = liveMetrics.restingHR ?? log?.biometrics.effectiveRestingHR ?? 0
        let protein = log?.nutritionLog.resolvedProteinG ?? 0
        let water = log?.nutritionLog.waterML ?? 0
        let completedMeals = log?.nutritionLog.meals.filter { $0.status == .completed }.count ?? 0
        let score = readinessScore ?? 65

        var reasons: [String] = []
        if score < 45 { reasons.append("Readiness is low enough to bias recovery over intensity.") }
        else if score < 60 { reasons.append("Readiness is moderate, so lighter movement will likely give better return today.") }

        if sleep > 0, sleep < 6.5 { reasons.append(String(format: "Sleep came in at %.1f hrs, so downshifting will help more than pushing load.", sleep)) }
        if hrv > 0, hrv < preferences.hrvReadyThreshold { reasons.append(String(format: "HRV is %.0f ms, which points toward a lighter nervous-system day.", hrv)) }
        if restingHR > 0, restingHR >= Double(preferences.hrReadyThreshold) { reasons.append(String(format: "Resting HR is %.0f bpm, so recovery work is the safer call.", restingHR)) }
        if protein > 0, protein < 120 { reasons.append("Protein is still behind target, so keep training stress modest until nutrition catches up.") }
        if water > 0, water < 1800 { reasons.append("Hydration is still low, so use recovery work while you bring fluids up.") }
        if completedMeals == 0 { reasons.append("No meals logged yet, which is another sign to keep the day restorative.") }

        let routine: RecoveryRoutine
        let shouldReplaceTraining = !dayType.isTrainingDay || score < 45

        if (sleep > 0 && sleep < 6.5) || restingHR >= 78 || score < 40 {
            routine = nervousSystemReset
        } else if dayType == .lowerBody || dayType == .fullBody || score < 60 {
            routine = mobilityFlush
        } else {
            routine = yogaFlow
        }

        if reasons.isEmpty {
            reasons = [
                shouldReplaceTraining
                    ? "Use the lighter session to build momentum without adding stress."
                    : "A short guided recovery block will make the main session feel better."
            ]
        }

        return RecoveryRecommendation(routine: routine, reasons: Array(reasons.prefix(3)), shouldReplaceTraining: shouldReplaceTraining)
    }
}
