import XCTest
@testable import FitTracker

final class HomeRecommendationProviderTests: XCTestCase {

    // MARK: - Nil / missing score

    func testNilScore_returnsEncouraging() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: nil,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .encouraging)
    }

    // MARK: - Score-based tiers

    func testHighScore_returnsCelebratory() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 85,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .celebratory)
    }

    func testMediumScore_returnsEncouraging() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 65,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .encouraging)
    }

    func testLowScore_returnsCautious() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 30,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .cautious)
    }

    // MARK: - Rest day

    func testRestDay_returnsEncouraging() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: nil,
            isRestDay: true,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .encouraging)
        XCTAssertTrue(
            result.subtitle.contains("Recovery"),
            "Rest day subtitle should mention recovery"
        )
    }

    func testRestDayOverridesScore() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 95,
            isRestDay: true,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .encouraging)
        XCTAssertEqual(result.title, "Rest day")
    }

    // MARK: - Streak

    func testStreakAppendsToSubtitle() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 85,
            isRestDay: false,
            streakDays: 5
        )

        XCTAssertTrue(
            result.subtitle.contains("5-day streak"),
            "Subtitle should contain streak info when streakDays >= 3"
        )
    }

    func testNoStreak_noStreakInSubtitle() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 85,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertFalse(
            result.subtitle.contains("streak"),
            "Subtitle should not mention streak when streakDays is 0"
        )
    }

    // MARK: - Boundary scores

    func testBoundaryScore80_isCelebratory() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 80,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .celebratory)
    }

    func testBoundaryScore50_isEncouraging() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 50,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .encouraging)
    }

    func testBoundaryScore49_isCautious() {
        let result = HomeRecommendationProvider.recommendation(
            readinessScore: 49,
            isRestDay: false,
            streakDays: 0
        )

        XCTAssertEqual(result.tone, .cautious)
    }
}
