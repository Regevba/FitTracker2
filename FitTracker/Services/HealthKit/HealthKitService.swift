// Services/HealthKit/HealthKitService.swift
// Full HealthKit + Apple Watch integration
// Apple-platform only: iOS 17+, iPadOS 17+, macOS 14+

import Foundation
import HealthKit
import SwiftUI
import Combine

// ─────────────────────────────────────────────────────────
// MARK: – Live metrics snapshot
// ─────────────────────────────────────────────────────────

struct LiveMetrics: Sendable {
    var heartRate:       Double?
    var restingHR:       Double?
    var hrv:             Double?
    var vo2Max:          Double?
    var weightKg:        Double?
    var bodyFatPct:      Double?   // 0.0–1.0 from HealthKit
    var leanMassKg:      Double?
    var stepCount:       Int?
    var activeCalories:  Double?
    var sleepHours:      Double?
    var deepSleepMin:    Double?
    var remSleepMin:     Double?
    var lastUpdated:     Date = Date()

    var restingHRStatus: MetricStatus {
        guard let r = restingHR else { return .unknown }
        if r < 60 { return .excellent } else if r < 75 { return .good }
        else if r < 85 { return .caution } else { return .alert }
    }
    var hrvStatus: MetricStatus {
        guard let h = hrv else { return .unknown }
        if h >= 45 { return .excellent } else if h >= 35 { return .good }
        else if h >= 28 { return .caution } else { return .alert }
    }
    var isReadyForTraining: Bool {
        (restingHR ?? 999) < 75 && (hrv ?? 0) >= 28
    }
}

enum MetricStatus: String, Sendable {
    case excellent, good, caution, alert, unknown
    var color: Color {
        switch self {
        case .excellent: .green; case .good: .teal
        case .caution:  .orange; case .alert: .red; case .unknown: .secondary
        }
    }
}

struct HistoricalPoint: Sendable {
    let date: Date; let value: Double
}

struct HistoricalData: Sendable {
    var weights:    [HistoricalPoint] = []
    var bodyFat:    [HistoricalPoint] = []
    var hrv:        [HistoricalPoint] = []
    var restingHR:  [HistoricalPoint] = []
    var sleep:      [HistoricalPoint] = []
}

// ─────────────────────────────────────────────────────────
// MARK: – HealthKit Service
// ─────────────────────────────────────────────────────────

@MainActor
final class HealthKitService: ObservableObject {

    @Published var isAuthorized   = false
    @Published var latest         = LiveMetrics()
    @Published var errorMessage:  String?

    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var hasStartedBackgroundDelivery = false
    // Coalesces rapid multi-type deliveries (e.g. post-workout) into a single fetchAll().
    private var fetchTask: Task<Void, Never>?

    // Types to read
    static var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        let qtids: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .vo2Max, .bodyMass, .bodyFatPercentage, .leanBodyMass,
            .stepCount, .activeEnergyBurned, .basalEnergyBurned
        ]
        qtids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }.forEach { s.insert($0) }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { s.insert(sleep) }
        s.insert(HKObjectType.electrocardiogramType())
        s.insert(HKObjectType.workoutType())
        return s
    }

    static var writeTypes: Set<HKSampleType> {
        var s = Set<HKSampleType>()
        s.insert(HKObjectType.workoutType())
        if let ae = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(ae) }
        return s
    }

    // ── Authorization ─────────────────────────────────────
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        // requestAuthorization completes without throwing even if the user denies permission
        // (Apple privacy model). Check actual authorization status for a critical type to
        // determine whether we should proceed with fetching.
        let heartRateType = HKQuantityType(.heartRate)
        let authStatus = store.authorizationStatus(for: heartRateType)
        isAuthorized = authStatus != .notDetermined
        if isAuthorized {
            await fetchAll()
            startBackgroundDelivery()
        }
    }

    // ── Background delivery from Apple Watch ─────────────
    func startBackgroundDelivery() {
        guard isAuthorized, !hasStartedBackgroundDelivery else { return }
        let ids: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .bodyMass, .bodyFatPercentage, .stepCount
        ]
        for id in ids {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { continue }
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, done, _ in
                // Call done() immediately to unblock HealthKit background delivery.
                // Future deliveries stop if done() is called from a detached Task instead.
                done()
                // Debounce: cancel any pending fetch before scheduling a new one.
                // A completed workout can fire 4–6 observer callbacks simultaneously;
                // this coalesces them into a single fetchAll() 500 ms after the last one.
                Task { @MainActor [weak self] in
                    self?.fetchTask?.cancel()
                    self?.fetchTask = Task { [weak self] in
                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled else { return }
                        await self?.fetchAll()
                    }
                }
            }
            store.execute(q)
            observers.append(q)
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
        hasStartedBackgroundDelivery = true
    }

    // ── Fetch all latest metrics ──────────────────────────
    func fetchAll() async {
        async let hr     = latestQ(.heartRate,            unit: HKUnit.count().unitDivided(by: .minute()))
        async let rhr    = latestQ(.restingHeartRate,     unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv    = latestQ(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let vo2    = latestQ(.vo2Max,               unit: HKUnit(from: "ml/kg*min"))
        async let mass   = latestQ(.bodyMass,             unit: .gramUnit(with: .kilo))
        async let bf     = latestQ(.bodyFatPercentage,    unit: .percent())
        async let lbm    = latestQ(.leanBodyMass,         unit: .gramUnit(with: .kilo))
        async let steps  = latestQ(.stepCount,            unit: .count())
        async let actE   = latestQ(.activeEnergyBurned,   unit: .kilocalorie())
        async let sleep  = fetchSleep()

        let (hrV,rhrV,hrvV,vo2V,massV,bfV,lbmV,stepsV,actEV,sleepV) =
            await (hr,rhr,hrv,vo2,mass,bf,lbm,steps,actE,sleep)

        latest = LiveMetrics(
            heartRate: hrV, restingHR: rhrV, hrv: hrvV, vo2Max: vo2V,
            weightKg: massV, bodyFatPct: bfV, leanMassKg: lbmV,
            stepCount: stepsV.map { Int($0) }, activeCalories: actEV,
            sleepHours: sleepV.total, deepSleepMin: sleepV.deep,
            remSleepMin: sleepV.rem
        )
    }

    // ── Historical data for charts ────────────────────────
    func fetchHistorical(days: Int) async -> HistoricalData {
        let end   = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        async let w  = samples(.bodyMass,           unit: .gramUnit(with: .kilo), from: start, to: end)
        async let bf = samples(.bodyFatPercentage,   unit: .percent(),             from: start, to: end)
        async let h  = samples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: start, to: end)
        async let r  = samples(.restingHeartRate,    unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end)
        async let s  = sleepSamples(from: start, to: end)
        let (wV,bfV,hV,rV,sV) = await (w,bf,h,r,s)
        return HistoricalData(weights: wV, bodyFat: bfV, hrv: hV, restingHR: rV, sleep: sV)
    }

    // ── Private: single latest sample ────────────────────
    private func latestQ(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: (s?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    // ── Private: range samples ────────────────────────────
    private func samples(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async -> [HistoricalPoint] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: from, end: to)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: (s as? [HKQuantitySample] ?? []).map {
                    HistoricalPoint(date: $0.endDate, value: $0.quantity.doubleValue(for: unit))
                })
            }
            store.execute(q)
        }
    }

    // ── Sleep ─────────────────────────────────────────────
    private func fetchSleep() async -> (total: Double?, deep: Double?, rem: Double?) {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return (nil,nil,nil) }
        let yesterday = Calendar.current.startOfDay(for: Date().addingTimeInterval(-86400))
        let pred = HKQuery.predicateForSamples(withStart: yesterday, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 200,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, s, _ in
                var deep = 0.0, rem = 0.0, core = 0.0
                for s in (s as? [HKCategorySample] ?? []) {
                    let h = s.endDate.timeIntervalSince(s.startDate) / 3600
                    switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                    case .asleepDeep: deep += h
                    case .asleepREM:  rem  += h
                    default:          core += h
                    }
                }
                let total = deep + rem + core
                cont.resume(returning: (total > 0 ? total : nil, deep > 0 ? deep*60 : nil, rem > 0 ? rem*60 : nil))
            }
            store.execute(q)
        }
    }

    private func sleepSamples(from: Date, to: Date) async -> [HistoricalPoint] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: from, end: to)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: pred,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                let grouped = Dictionary(grouping: samples as? [HKCategorySample] ?? []) {
                    Calendar.current.startOfDay(for: $0.startDate)
                }
                let points = grouped.keys.sorted().compactMap { day -> HistoricalPoint? in
                    let hours = grouped[day, default: []]
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600 }
                    guard hours > 0 else { return nil }
                    return HistoricalPoint(date: day, value: hours)
                }
                cont.resume(returning: points)
            }
            store.execute(q)
        }
    }
}
