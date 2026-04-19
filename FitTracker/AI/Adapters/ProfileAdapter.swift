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
        // Audit AI-004: gender stays nil until UserProfile gains a `gender` field.
        // Better to surface insufficientData than fabricate "prefer_not_to_say".
        snapshot.genderIdentity = nil
        snapshot.activeWeeks = max(0, Int(ceil(Double(profile.daysSinceStart) / 7.0)))
        snapshot.programPhase = todayDayType.aiProgramPhase
        // Audit AI-005: pass the real user value (Int? — nil if not configured).
        // No compile-time constant fallback; the snapshot honestly reports "not set".
        snapshot.trainingDaysPerWeek = profile.trainingDaysPerWeek
        snapshot.primaryGoal = Self.primaryGoal(for: preferences)
        // Audit AI-006: dietPattern stays nil until UserPreferences gains a
        // `dietPattern` field. Same reasoning as AI-004.
        snapshot.dietPattern = nil
    }

    private static func primaryGoal(for preferences: UserPreferences) -> String {
        switch preferences.nutritionGoalMode {
        case .fatLoss: return "weight_loss"
        case .maintain: return "maintenance"
        case .gain: return "muscle_gain"
        }
    }
}
