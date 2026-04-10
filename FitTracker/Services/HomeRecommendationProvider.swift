import SwiftUI

// MARK: - HomeRecommendation

struct HomeRecommendation {
    let tone: RecommendationTone
    let title: String
    let subtitle: String
    let accentColor: Color
}

// MARK: - RecommendationTone

enum RecommendationTone {
    case encouraging
    case cautious
    case celebratory
}

// MARK: - HomeRecommendationProvider

struct HomeRecommendationProvider {

    /// Pure function that produces a recommendation based on readiness data.
    /// Copy follows the "Celebration Not Guilt" principle — encouraging, never judgmental.
    static func recommendation(
        readinessScore: Int?,
        isRestDay: Bool,
        streakDays: Int
    ) -> HomeRecommendation {

        // Rest day takes priority — recovery is always celebrated.
        if isRestDay {
            let subtitle = streakSubtitle(
                base: "Recovery is training too — enjoy the break",
                streakDays: streakDays
            )
            return HomeRecommendation(
                tone: .encouraging,
                title: "Rest day",
                subtitle: subtitle,
                accentColor: AppColor.Accent.sleep
            )
        }

        // No score yet — onboarding-style nudge.
        guard let score = readinessScore else {
            return HomeRecommendation(
                tone: .encouraging,
                title: "Ready to start?",
                subtitle: "Log your first metrics to get personalized insights",
                accentColor: AppColor.Accent.primary
            )
        }

        // Score-based tiers (high → low).
        let base: HomeRecommendation
        switch score {
        case 80...:
            base = HomeRecommendation(
                tone: .celebratory,
                title: "You're in great shape!",
                subtitle: "Your recovery looks excellent — perfect day to push it",
                accentColor: AppColor.Status.success
            )
        case 50..<80:
            base = HomeRecommendation(
                tone: .encouraging,
                title: "Looking good",
                subtitle: "You're recovering well — steady effort today",
                accentColor: AppColor.Accent.primary
            )
        default:
            base = HomeRecommendation(
                tone: .cautious,
                title: "Take it easy today",
                subtitle: "Your body could use more recovery — consider a lighter session",
                accentColor: AppColor.Status.warning
            )
        }

        // Append streak callout when the user has built momentum.
        if streakDays >= 3 {
            return HomeRecommendation(
                tone: base.tone,
                title: base.title,
                subtitle: streakSubtitle(base: base.subtitle, streakDays: streakDays),
                accentColor: base.accentColor
            )
        }

        return base
    }

    // MARK: - ReadinessResult overload

    /// Richer recommendation using the full `ReadinessResult` from ReadinessEngine v2.
    /// When `readinessResult` is nil, falls back to `defaultRecommendation(streakDays:)`.
    /// The existing `recommendation(readinessScore:isRestDay:streakDays:)` continues to
    /// work unchanged for callers that only have the Int score.
    static func recommendation(
        readinessResult: ReadinessResult?,
        isRestDay: Bool,
        streakDays: Int
    ) -> HomeRecommendation {

        // Rest day takes priority — recovery is always celebrated.
        if isRestDay {
            let subtitle = streakSubtitle(
                base: "Recovery is training too — enjoy the break",
                streakDays: streakDays
            )
            return HomeRecommendation(
                tone: .encouraging,
                title: "Rest day",
                subtitle: subtitle,
                accentColor: AppColor.Accent.sleep
            )
        }

        guard let result = readinessResult else {
            return defaultRecommendation(streakDays: streakDays)
        }

        let (title, subtitle, tone, accent): (String, String, RecommendationTone, Color) = switch result.recommendation {
        case .pushHard:
            ("You're in great shape!", "Push it today — all systems go.", RecommendationTone.celebratory, AppColor.Status.success)
        case .fullIntensity:
            ("Good to go today", "Full session, normal intensity.", RecommendationTone.encouraging, AppColor.Accent.primary)
        case .moderate:
            ("Dial it back slightly", "Reduce intensity ~20% — your body is recovering.", RecommendationTone.encouraging, AppColor.Status.warning)
        case .lightOnly:
            ("Light session today", "Active recovery or Zone 2 only.", RecommendationTone.cautious, AppColor.Status.warning)
        case .restDay:
            ("Your body needs rest", "Skip training — recovery is the priority.", RecommendationTone.cautious, AppColor.Accent.sleep)
        }

        let base = HomeRecommendation(
            tone: tone,
            title: title,
            subtitle: subtitle,
            accentColor: accent
        )

        if streakDays >= 3 {
            return HomeRecommendation(
                tone: base.tone,
                title: base.title,
                subtitle: streakSubtitle(base: base.subtitle, streakDays: streakDays),
                accentColor: base.accentColor
            )
        }

        return base
    }

    // MARK: - Private helpers

    private static func defaultRecommendation(streakDays: Int) -> HomeRecommendation {
        let base = HomeRecommendation(
            tone: .encouraging,
            title: "Ready to start?",
            subtitle: "Log your first metrics to get personalized insights",
            accentColor: AppColor.Accent.primary
        )
        if streakDays >= 3 {
            return HomeRecommendation(
                tone: base.tone,
                title: base.title,
                subtitle: streakSubtitle(base: base.subtitle, streakDays: streakDays),
                accentColor: base.accentColor
            )
        }
        return base
    }

    private static func streakSubtitle(base: String, streakDays: Int) -> String {
        "\(base). \(streakDays)-day streak — keep it going!"
    }
}
