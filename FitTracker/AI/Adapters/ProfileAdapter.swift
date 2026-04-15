// AI/Adapters/ProfileAdapter.swift
// Contributes demographic and goal fields from UserProfile + UserPreferences.

import Foundation

struct ProfileAdapter: AIInputAdapter {
    let sourceID = "profile"

    private let profile: UserProfile
    private let preferences: UserPreferences
    private let todayDayType: DayType

    var lastUpdated: Date? { nil } // profile is always current

    init(profile: UserProfile, preferences: UserPreferences, todayDayType: DayType) {
        self.profile = profile
        self.preferences = preferences
        self.todayDayType = todayDayType
    }

    func contribute(to snapshot: inout LocalUserSnapshot) {
        snapshot.ageYears = profile.age
        snapshot.genderIdentity = "prefer_not_to_say"
        snapshot.activeWeeks = max(0, Int(ceil(Double(profile.daysSinceStart) / 7.0)))
        snapshot.programPhase = todayDayType.aiProgramPhase
        snapshot.trainingDaysPerWeek = DayType.allCases.filter(\.isTrainingDay).count
        snapshot.primaryGoal = Self.primaryGoal(for: preferences)
        snapshot.dietPattern = "standard"
    }

    private static func primaryGoal(for preferences: UserPreferences) -> String {
        switch preferences.nutritionGoalMode {
        case .fatLoss: return "weight_loss"
        case .maintain: return "maintenance"
        case .gain: return "muscle_gain"
        }
    }
}
