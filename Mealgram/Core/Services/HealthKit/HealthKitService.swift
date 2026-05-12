import Foundation
import HealthKit
import OSLog

/// Reads weight samples from Apple Health and pipes them into our local
/// `WeightEntry` store. Wraps `HKHealthStore` behind a protocol so the
/// importer can be unit-tested without touching the real HealthKit
/// runtime.
///
/// The Health entitlement (`com.apple.developer.healthkit`) lands when the
/// Apple Developer Team ID is configured; until then the read flow will
/// return `.notAuthorised` at runtime but the surrounding code already
/// compiles and ships.
@MainActor
protocol HealthKitWeightImporter: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws -> Bool
    func recentWeightSamples(limit: Int) async throws -> [HealthKitService.WeightSample]
}

@MainActor
final class HealthKitService: HealthKitWeightImporter {
    enum ImportError: Error, Equatable {
        case unavailable
        case notAuthorised
        case query(String)
    }

    struct WeightSample: Equatable, Sendable {
        let kilograms: Double
        let recordedAt: Date
    }

    private let store: HKHealthStore?

    init() {
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    var isHealthDataAvailable: Bool { store != nil }

    func requestAuthorization() async throws -> Bool {
        guard let store else { throw ImportError.unavailable }
        let weightType = HKQuantityType(.bodyMass)
        do {
            try await store.requestAuthorization(toShare: [], read: [weightType])
            let status = store.authorizationStatus(for: weightType)
            return status != .sharingDenied
        } catch {
            Logger.persistence.error("HealthKit auth failed: \(String(describing: error))")
            throw ImportError.query(error.localizedDescription)
        }
    }

    /// Returns the most recent body-mass samples (Newton-first), already
    /// converted to kilograms.
    func recentWeightSamples(limit: Int = 20) async throws -> [WeightSample] {
        guard let store else { throw ImportError.unavailable }
        let weightType = HKQuantityType(.bodyMass)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ImportError.query(error.localizedDescription))
                    return
                }
                let mapped: [WeightSample] = (samples ?? []).compactMap { raw in
                    guard let sample = raw as? HKQuantitySample else { return nil }
                    let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return WeightSample(kilograms: kg, recordedAt: sample.endDate)
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }
}
