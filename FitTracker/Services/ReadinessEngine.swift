import Foundation

// ─────────────────────────────────────────────────────────
// MARK: – ReadinessEngine (v2 — evidence-based, goal-aware)
// ─────────────────────────────────────────────────────────
//
// Computes a 0–100 training readiness score from 5 weighted components:
//   1. HRV — ln(SDNN) deviation from 7-day EWMA baseline
//   2. Sleep Quality — composite of duration, deep %, REM %
//   3. Training Load — ACWR via EWMA (acute 7d / chronic 28d)
//   4. Resting HR — deviation from 7-day rolling average
//   5. Body Comp — binary suppressors (hydration, visceral fat trend)
//
// Weights shift based on the user's fitness goal (fat loss, muscle gain,
// maintain, general). The formula becomes progressively personalized
// as more data accumulates (Layer 0 → 3).
//
// Scientific basis cited per component. All formulas designed for graceful
// degradation — any component can be nil, remaining are re-weighted.
//
// References:
//   Plews et al. 2013 — ln(rMSSD) monitoring approach
//   Shaffer & Ginsberg 2017 — HRV metrics overview (PMC5624990)
//   Buysse et al. 1989 — PSQI sleep quality index
//   Williams et al. 2017 — EWMA ACWR (PubMed 28003238)
//   Foster 1998 — session RPE for training load
//   PMC11235883 — RHR as overreaching early warning
//   PMC8507742 — HRV-guided training meta-analysis

enum ReadinessEngine {

    // MARK: – Public API

    /// Computes a full readiness assessment.
    /// Returns nil only if absolutely no usable data is available.
    static func compute(
        todayMetrics: LiveMetrics,
        dailyLogs: [DailyLog],
        goalMode: NutritionGoalMode,
        date: Date = Date()
    ) -> ReadinessResult? {
        let layer = personalizationLayer(logCount: dailyLogs.count)
        let weights = componentWeights(for: goalMode)

        // Compute each component (nil = data unavailable)
        let hrv = hrvComponent(
            todayHRV: todayMetrics.hrv,
            logs: dailyLogs,
            date: date,
            layer: layer
        )
        let sleep = sleepComponent(
            totalHours: todayMetrics.sleepHours,
            deepMin: todayMetrics.deepSleepMin,
            remMin: todayMetrics.remSleepMin,
            goalHours: 8.0
        )
        let training = trainingLoadComponent(logs: dailyLogs, date: date)
        let rhr = rhrComponent(
            todayRHR: todayMetrics.restingHR,
            logs: dailyLogs,
            date: date
        )
        let flags = bodyCompFlags(
            todayWeight: todayMetrics.weightKg,
            logs: dailyLogs,
            date: date
        )

        // Need at least one scored component
        let components: [(String, Double?, Double)] = [
            ("hrv", hrv, weights.hrv),
            ("sleep", sleep, weights.sleep),
            ("training", training, weights.training),
            ("rhr", rhr, weights.rhr),
            ("bodyComp", flags.score, weights.bodyComp),
        ]

        let available = components.filter { $0.1 != nil }
        guard !available.isEmpty else { return nil }

        // Re-weight available components to sum to 1.0
        let totalWeight = available.reduce(0.0) { $0 + $2 }
        guard totalWeight > 0 else { return nil }

        let weightedSum = available.reduce(0.0) { acc, c in
            acc + (c.1! * (c.2 / totalWeight))
        }

        // Apply body comp flag suppression (up to -10 points)
        let suppression = Double(flags.flags.count) * 5.0
        let rawScore = max(0, min(100, weightedSum - suppression))
        let finalScore = Int(rawScore.rounded())

        // Build applied weights map (for UI transparency)
        var appliedWeights: [String: Double] = [:]
        for c in available {
            appliedWeights[c.0] = c.2 / totalWeight
        }

        // Warnings
        var warnings: [String] = []
        if flags.flags.contains(.hydrationWarning) {
            warnings.append("Overnight weight change >1% — possible dehydration")
        }
        if flags.flags.contains(.visceralTrend) {
            warnings.append("Visceral fat trending up over past 7 days")
        }
        if let h = hrv, h < 30 {
            warnings.append("HRV significantly below baseline — consider rest")
        }
        if let r = rhr, r < 30 {
            warnings.append("Resting HR elevated >5 BPM above baseline")
        }

        // Confidence
        let confidence: ReadinessConfidence
        switch layer {
        case 0: confidence = .low
        case 1, 2: confidence = .medium
        default: confidence = .high
        }

        return ReadinessResult(
            overallScore: finalScore,
            hrvScore: hrv ?? 0,
            sleepScore: sleep ?? 0,
            trainingLoadScore: training ?? 0,
            rhrScore: rhr ?? 0,
            bodyCompFlags: flags.flags,
            confidence: confidence,
            personalizationLayer: layer,
            goalMode: goalMode,
            appliedWeights: appliedWeights,
            warnings: warnings,
            recommendation: recommendation(for: finalScore, flags: flags.flags)
        )
    }

    // MARK: – Component 1: HRV (35% base)
    // Scientific basis: Plews et al. 2013 — ln(rMSSD) weekly mean + CV
    // as dual monitoring approach. Deviation from personal baseline is
    // more meaningful than absolute value. PMC8507742 meta-analysis.

    static func hrvComponent(
        todayHRV: Double?,
        logs: [DailyLog],
        date: Date,
        layer: Int
    ) -> Double? {
        guard let todayHRV, todayHRV > 0 else { return nil }

        // ln(SDNN) — HealthKit provides SDNN in ms
        let lnToday = log(todayHRV)

        if layer == 0 {
            // Layer 0: no baseline yet, use absolute thresholds
            // Population reference: ln(ms) of 3.0-4.5 is typical range
            return min(100, max(0, (lnToday / 4.0) * 100))
        }

        // Layer 1+: compare to 7-day EWMA baseline
        let baselineValues = recentBiometricValues(
            from: logs, date: date, days: 7
        ) { $0.effectiveHRV }

        guard !baselineValues.isEmpty else {
            return min(100, max(0, (lnToday / 4.0) * 100))
        }

        // EWMA with lambda = 2/(N+1) where N=7
        let ewma = exponentialWeightedAverage(baselineValues, lambda: 2.0 / 8.0)
        let lnBaseline = log(max(1, ewma))

        // Score: 50 at baseline, scales linearly
        // +50% above baseline → 100, -50% below → 0
        let ratio = lnToday / lnBaseline
        let score = min(100, max(0, ratio * 50))

        return score
    }

    // MARK: – Component 2: Sleep Quality (25% base)
    // Scientific basis: Pittsburgh Sleep Quality Index (Buysse et al. 1989)
    // adapted for wearable data. Apple Watch sleep staging validated against
    // polysomnography. Target: deep ~15-20%, REM ~20-25% of total.

    static func sleepComponent(
        totalHours: Double?,
        deepMin: Double?,
        remMin: Double?,
        goalHours: Double
    ) -> Double? {
        guard let totalHours, totalHours > 0 else { return nil }

        let totalMin = totalHours * 60.0

        // Sub-component 1: Duration ratio (40% of sleep score)
        let durationScore = min(100, (totalHours / goalHours) * 100)

        // Sub-component 2: Deep sleep % (30% of sleep score)
        // Target: 15-20% of total sleep. Midpoint 17.5%.
        let deepScore: Double
        if let deep = deepMin, totalMin > 0 {
            let deepPct = deep / totalMin
            deepScore = min(100, (deepPct / 0.175) * 100)
        } else {
            // No stage data — use duration only (re-weighted)
            deepScore = durationScore
        }

        // Sub-component 3: REM sleep % (30% of sleep score)
        // Target: 20-25% of total sleep. Midpoint 22.5%.
        let remScore: Double
        if let rem = remMin, totalMin > 0 {
            let remPct = rem / totalMin
            remScore = min(100, (remPct / 0.225) * 100)
        } else {
            remScore = durationScore
        }

        return durationScore * 0.40 + deepScore * 0.30 + remScore * 0.30
    }

    // MARK: – Component 3: Training Load / ACWR (20% base)
    // Scientific basis: Williams et al. 2017 — EWMA ACWR (PubMed 28003238).
    // Session load = RPE × duration (Foster 1998 sRPE).
    // Sweet spot ACWR: 0.8-1.3. Injury risk spikes above 1.5.

    static func trainingLoadComponent(
        logs: [DailyLog],
        date: Date
    ) -> Double? {
        let cal = Calendar.current

        // Compute daily training loads for past 28 days
        var dailyLoads: [Double] = []
        for dayOffset in (1...28).reversed() {
            guard let targetDate = cal.date(byAdding: .day, value: -dayOffset, to: date) else {
                dailyLoads.append(0)
                continue
            }
            let dayLog = logs.first { cal.isDate($0.date, inSameDayAs: targetDate) }
            dailyLoads.append(sessionLoad(for: dayLog))
        }

        // Need at least 7 days for acute load
        let nonZeroDays = dailyLoads.suffix(7).filter { $0 > 0 }.count
        guard nonZeroDays >= 2 else { return nil }

        // EWMA calculation
        let acuteLambda = 2.0 / 8.0   // N=7
        let chronicLambda = 2.0 / 29.0 // N=28

        let acuteEWMA = exponentialWeightedAverage(
            Array(dailyLoads.suffix(7)), lambda: acuteLambda
        )
        let chronicEWMA = exponentialWeightedAverage(
            dailyLoads, lambda: chronicLambda
        )

        guard chronicEWMA > 0 else {
            // No chronic load — user just started, score neutral
            return 50.0
        }

        let acwr = acuteEWMA / chronicEWMA

        // Score mapping:
        // ACWR 0.8-1.3 → 80-100 (sweet spot)
        // ACWR < 0.5 → ~40 (undertrained / deloading)
        // ACWR > 1.5 → ~30 (overreaching risk)
        // ACWR > 2.0 → ~10 (high injury risk)
        let score: Double
        if acwr >= 0.8 && acwr <= 1.3 {
            // Sweet spot — score 80-100
            let normalized = (acwr - 0.8) / 0.5 // 0-1 within sweet spot
            score = 80 + normalized * 20
        } else if acwr < 0.8 {
            // Below sweet spot — linear decline to 40 at ACWR=0
            score = max(40, 80 * (acwr / 0.8))
        } else if acwr <= 1.5 {
            // Above sweet spot but not danger — 80 → 50
            let overreach = (acwr - 1.3) / 0.2
            score = max(50, 80 - overreach * 30)
        } else {
            // Danger zone — 50 → 10
            let danger = min(1, (acwr - 1.5) / 0.5)
            score = max(10, 50 - danger * 40)
        }

        return score
    }

    // MARK: – Component 4: Resting HR (15% base)
    // Scientific basis: PMC11235883 — RHR elevation >5 BPM above baseline
    // appears ~6 days into overreaching, earlier than HRV changes (~10 days).

    static func rhrComponent(
        todayRHR: Double?,
        logs: [DailyLog],
        date: Date
    ) -> Double? {
        guard let todayRHR else { return nil }

        let baselineValues = recentBiometricValues(
            from: logs, date: date, days: 7
        ) { $0.effectiveRestingHR }

        guard !baselineValues.isEmpty else {
            // No baseline — use absolute thresholds
            if todayRHR < 60 { return 100 }
            if todayRHR < 75 { return 70 }
            if todayRHR < 85 { return 40 }
            return 20
        }

        let avgBaseline = baselineValues.reduce(0, +) / Double(baselineValues.count)
        let deviation = todayRHR - avgBaseline

        // Score: 80 at baseline, +10 per BPM below, -10 per BPM above
        // Capped 0-100
        let score = min(100, max(0, 80 - (deviation * 10)))
        return score
    }

    // MARK: – Component 5: Body Composition Flags (5% base)
    // Binary suppressors, not linearly scored.
    // Overnight weight change >1% signals dehydration (impacts performance).
    // Rising visceral fat over 7 days is a metabolic warning.

    static func bodyCompFlags(
        todayWeight: Double?,
        logs: [DailyLog],
        date: Date
    ) -> (score: Double?, flags: [BodyCompFlag]) {
        var flags: [BodyCompFlag] = []

        // Check overnight weight change
        if let todayW = todayWeight {
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: date),
               let yesterdayLog = logs.first(where: { cal.isDate($0.date, inSameDayAs: yesterday) }),
               let yesterdayW = yesterdayLog.biometrics.weightKg,
               yesterdayW > 0 {
                let changePct = abs(todayW - yesterdayW) / yesterdayW
                if changePct > 0.01 {
                    flags.append(.hydrationWarning)
                }
            }
        }

        // Check visceral fat trend (7-day window)
        let visceralValues = recentValues(from: logs, date: date, days: 7) {
            $0.biometrics.visceralFatRating.map(Double.init)
        }
        if visceralValues.count >= 3 {
            let first = visceralValues.prefix(visceralValues.count / 2)
            let second = visceralValues.suffix(visceralValues.count / 2)
            let firstAvg = first.reduce(0, +) / Double(first.count)
            let secondAvg = second.reduce(0, +) / Double(second.count)
            if secondAvg > firstAvg + 0.5 {
                flags.append(.visceralTrend)
            }
        }

        // Score: 100 if no flags, 50 per flag
        let baseScore: Double = flags.isEmpty ? 100 : max(0, 100 - Double(flags.count) * 50)
        return (baseScore, flags)
    }

    // MARK: – Weight Selection

    struct ComponentWeights {
        let hrv: Double
        let sleep: Double
        let training: Double
        let rhr: Double
        let bodyComp: Double
    }

    static func componentWeights(for goal: NutritionGoalMode) -> ComponentWeights {
        switch goal {
        case .fatLoss:
            return ComponentWeights(hrv: 0.30, sleep: 0.30, training: 0.15, rhr: 0.15, bodyComp: 0.10)
        case .gain:
            return ComponentWeights(hrv: 0.30, sleep: 0.20, training: 0.25, rhr: 0.20, bodyComp: 0.05)
        case .maintain:
            return ComponentWeights(hrv: 0.35, sleep: 0.25, training: 0.20, rhr: 0.15, bodyComp: 0.05)
        }
    }

    // MARK: – Personalization Layer

    static func personalizationLayer(logCount: Int) -> Int {
        if logCount >= 90 { return 3 }
        if logCount >= 28 { return 2 }
        if logCount >= 7  { return 1 }
        return 0
    }

    // MARK: – Training Recommendation

    static func recommendation(
        for score: Int,
        flags: [BodyCompFlag]
    ) -> TrainingRecommendation {
        if score < 30 || flags.count >= 2 { return .restDay }
        if score < 50 { return .lightOnly }
        if score < 70 { return .moderate }
        if score < 85 { return .fullIntensity }
        return .pushHard
    }

    // MARK: – Helpers

    /// Computes session training load from a DailyLog.
    /// Uses session RPE × duration (Foster 1998 sRPE method).
    private static func sessionLoad(for log: DailyLog?) -> Double {
        guard let log else { return 0 }

        var totalLoad = 0.0

        // Resistance: sum of (RPE × estimated duration per set)
        for (_, exerciseLog) in log.exerciseLogs {
            for set in exerciseLog.sets where !set.isWarmup {
                let rpe = set.rpe ?? 5.0  // default moderate if not logged
                // Estimate ~2 min per working set (including rest)
                totalLoad += rpe * 2.0
            }
        }

        // Cardio: RPE × duration, or HR-based estimate
        for (_, cardioLog) in log.cardioLogs {
            let duration = cardioLog.durationMinutes ?? 0
            // Estimate RPE from HR if available, otherwise default 5
            let rpe: Double
            if let avgHR = cardioLog.avgHeartRate {
                // Rough RPE estimation: HR% of max (220-age, default 177 for 43yo)
                let hrPct = avgHR / 177.0
                rpe = min(10, max(1, hrPct * 10))
            } else {
                rpe = 5.0
            }
            totalLoad += rpe * duration
        }

        return totalLoad
    }

    /// Extracts recent biometric values from daily logs, excluding the target date.
    private static func recentBiometricValues(
        from logs: [DailyLog],
        date: Date,
        days: Int,
        extractor: (DailyBiometrics) -> Double?
    ) -> [Double] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: date) else { return [] }
        return logs
            .filter { $0.date >= start && !cal.isDate($0.date, inSameDayAs: date) }
            .compactMap { extractor($0.biometrics) }
    }

    /// Extracts recent values from daily logs using a custom extractor.
    private static func recentValues(
        from logs: [DailyLog],
        date: Date,
        days: Int,
        extractor: (DailyLog) -> Double?
    ) -> [Double] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: date) else { return [] }
        return logs
            .filter { $0.date >= start && !cal.isDate($0.date, inSameDayAs: date) }
            .compactMap { extractor($0) }
    }

    /// Exponentially Weighted Moving Average.
    /// lambda = 2 / (N + 1) where N is the window size.
    /// Williams et al. 2017 — more sensitive than simple rolling average.
    private static func exponentialWeightedAverage(
        _ values: [Double],
        lambda: Double
    ) -> Double {
        guard let first = values.first else { return 0 }
        var ewma = first
        for value in values.dropFirst() {
            ewma = value * lambda + ewma * (1 - lambda)
        }
        return ewma
    }
}
