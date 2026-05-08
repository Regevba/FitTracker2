// FitTracker/Models/Stats/MetricSeriesPoint.swift
import Foundation

struct MetricSeriesPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}
