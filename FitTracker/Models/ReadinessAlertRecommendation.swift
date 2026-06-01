// Models/ReadinessAlertRecommendation.swift
// All platform targets: iOS, iPadOS, macOS

import Foundation

enum ReadinessAlertRecommendation: String, Codable, Equatable, Sendable, CaseIterable {
    case continueAsPlanned
    case adaptEasierLoad
    case restDaySwap

    var headline: String {
        switch self {
        case .continueAsPlanned: return "You're ready — train as planned"
        case .adaptEasierLoad:   return "Lighten today's session"
        case .restDaySwap:       return "Swap to a rest day"
        }
    }

    var primaryCTA: String {
        switch self {
        case .continueAsPlanned: return "Train now"
        case .adaptEasierLoad:   return "Lighten"
        case .restDaySwap:       return "Swap to rest"
        }
    }
}

struct ReadinessAlertContext: Equatable, Codable, Sendable {
    let recommendation: ReadinessAlertRecommendation
    let readinessScore: Int
    let scheduledDayType: DayType
    let suggestedSwapDayType: DayType?
    let drivingComponent: DrivingComponent
    let componentBreakdown: ComponentBreakdown
    let scheduledTrainingTime: Date
    let generatedAt: Date

    enum DrivingComponent: String, Codable, Equatable, Sendable {
        case hrv, sleep, restingHR, trainingLoad, composite
    }

    struct ComponentBreakdown: Equatable, Codable, Sendable {
        let hrvScore: Double
        let sleepScore: Double
        let restingHRScore: Double
        let trainingLoadScore: Double
        let bodyCompFlagCount: Int
    }
}
