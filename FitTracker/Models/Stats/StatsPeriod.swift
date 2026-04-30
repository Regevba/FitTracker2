// FitTracker/Models/Stats/StatsPeriod.swift
import Foundation

enum StatsPeriod: String, CaseIterable {
    case daily = "D"
    case weekly = "W"
    case monthly = "M"
    case threeMonths = "3M"
    case sixMonths = "6M"

    var periodLabel: String {
        switch self {
        case .daily:
            return "Today"
        case .weekly:
            return "Last 7 days"
        case .monthly:
            return "This month"
        case .threeMonths:
            return "Last 3 months"
        case .sixMonths:
            return "Last 6 months"
        }
    }

    var dateRange: (from: Date, to: Date) {
        let calendar = Calendar.current
        let now = Date()
        let todayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        switch self {
        case .daily:
            return (calendar.startOfDay(for: now), todayEnd)
        case .weekly:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return (start, todayEnd)
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            return (monthStart, todayEnd)
        case .threeMonths:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .month, value: -2, to: monthStart) ?? monthStart
            return (start, todayEnd)
        case .sixMonths:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .month, value: -5, to: monthStart) ?? monthStart
            return (start, todayEnd)
        }
    }
}
