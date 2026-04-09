import Foundation
import HealthKit
import Combine

/// Streams live biometric data from HealthKit: heart rate, HRV, and blood oxygen.
@MainActor
final class HealthMonitor: ObservableObject {

    // MARK: - Published state

    @Published var heartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var spo2: Double = 0
    @Published var authorizationStatus: String = "Not authorized"

    // MARK: - Private

    private let store = HKHealthStore()
    private var hrQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var spo2Query: HKAnchoredObjectQuery?

    private let hrType   = HKQuantityType(.heartRate)
    private let hrvType  = HKQuantityType(.heartRateVariabilitySDNN)
    private let spo2Type = HKQuantityType(.oxygenSaturation)

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = "Health data unavailable"
            return
        }
        let types: Set<HKObjectType> = [hrType, hrvType, spo2Type]
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            authorizationStatus = "Authorized"
            startStreaming()
        } catch {
            authorizationStatus = "Authorization failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Streaming

    func startStreaming() {
        startHRStream()
        startHRVStream()
        startSpO2Stream()
    }

    func stopStreaming() {
        [hrQuery, hrvQuery, spo2Query].compactMap { $0 }.forEach { store.stop($0) }
    }

    // MARK: - Private queries

    private func startHRStream() {
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil)
        hrQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        hrQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHRSamples(samples)
        }
        if let q = hrQuery { store.execute(q) }
    }

    private func startHRVStream() {
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: nil)
        hrvQuery = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleHRVSamples(samples)
        }
        hrvQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleHRVSamples(samples)
        }
        if let q = hrvQuery { store.execute(q) }
    }

    private func startSpO2Stream() {
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: nil)
        spo2Query = HKAnchoredObjectQuery(
            type: spo2Type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.handleSpO2Samples(samples)
        }
        spo2Query?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.handleSpO2Samples(samples)
        }
        if let q = spo2Query { store.execute(q) }
    }

    // MARK: - Sample handlers

    private func handleHRSamples(_ samples: [HKSample]?) {
        guard let latest = (samples as? [HKQuantitySample])?.last else { return }
        let bpm = latest.quantity.doubleValue(for: .init(from: "count/min"))
        Task { @MainActor in self.heartRate = bpm }
    }

    private func handleHRVSamples(_ samples: [HKSample]?) {
        guard let latest = (samples as? [HKQuantitySample])?.last else { return }
        let ms = latest.quantity.doubleValue(for: .millisecondUnit(with: .milli))
        Task { @MainActor in self.hrv = ms }
    }

    private func handleSpO2Samples(_ samples: [HKSample]?) {
        guard let latest = (samples as? [HKQuantitySample])?.last else { return }
        let pct = latest.quantity.doubleValue(for: .percent()) * 100
        Task { @MainActor in self.spo2 = pct }
    }
}
