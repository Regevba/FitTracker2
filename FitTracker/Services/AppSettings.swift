// Services/AppSettings.swift
// App-wide preferences: unit system + appearance mode
// Persisted to UserDefaults — no encryption needed (not health data)

import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────
// MARK: – Unit System
// ─────────────────────────────────────────────────────────

enum UnitSystem: String, CaseIterable, Sendable {
    case metric   = "Metric"
    case imperial = "Imperial"

    // Weight
    func weightLabel() -> String  { self == .metric ? "kg" : "lbs" }
    func heightLabel() -> String  { self == .metric ? "cm" : "in" }
    func distanceLabel() -> String { self == .metric ? "km" : "mi" }

    func displayWeight(_ kg: Double) -> String {
        if self == .metric {
            return String(format: "%.1f kg", kg)
        } else {
            return String(format: "%.1f lbs", kg * 2.20462)
        }
    }

    func displayWeightValue(_ kg: Double) -> String {
        self == .metric
            ? String(format: "%.1f", kg)
            : String(format: "%.1f", kg * 2.20462)
    }

    func displayDistance(_ km: Double) -> String {
        self == .metric
            ? String(format: "%.2f km", km)
            : String(format: "%.2f mi", km * 0.621371)
    }

    func displayHeight(_ cm: Double) -> String {
        if self == .metric {
            return String(format: "%.0f cm", cm)
        } else {
            let totalInches = cm / 2.54
            let feet   = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        }
    }

    // Convert user input back to metric for storage
    func toMetricWeight(_ value: Double) -> Double {
        self == .metric ? value : value / 2.20462
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Appearance Mode
// ─────────────────────────────────────────────────────────

enum AppAppearance: String, CaseIterable, Sendable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – AppSettings Observable
// ─────────────────────────────────────────────────────────

@MainActor
final class AppSettings: ObservableObject {

    // Instance owned by FitTrackerApp via @StateObject

    // ── Unit system ──────────────────────────────────────
    @Published var unitSystem: UnitSystem = .metric {
        didSet { UserDefaults.standard.set(unitSystem.rawValue, forKey: "ft.unitSystem") }
    }

    // ── Appearance ───────────────────────────────────────
    @Published var appearance: AppAppearance = .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "ft.appearance") }
    }

    // ── Onboarding ───────────────────────────────────────
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "ft.onboardingComplete") }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "ft.unitSystem"),
           let v = UnitSystem(rawValue: raw) { unitSystem = v }
        if let raw = UserDefaults.standard.string(forKey: "ft.appearance"),
           let v = AppAppearance(rawValue: raw) { appearance = v }
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "ft.onboardingComplete")
    }
}
