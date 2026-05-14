import Foundation
import OSLog

/// Glue between `HealthKitWeightImporter` and `WeightService` — fetches
/// recent samples from Apple Health and writes any that aren't already in
/// the local log (deduped by recordedAt to the minute).
@MainActor
final class HealthImporter {
    enum ImportResult: Equatable {
        case unavailable
        case denied
        case imported(count: Int)
        case noNewSamples
        case failed(reason: String)
    }

    private let health: any HealthKitWeightImporter
    private let weightService: WeightService

    init(health: any HealthKitWeightImporter, weightService: WeightService) {
        self.health = health
        self.weightService = weightService
    }

    func runImport(for userRemoteID: String) async -> ImportResult {
        guard health.isHealthDataAvailable else { return .unavailable }
        do {
            let granted = try await health.requestAuthorization()
            guard granted else { return .denied }
        } catch {
            Logger.persistence.error("Health auth failed: \(String(describing: error))")
            return .failed(reason: error.localizedDescription)
        }

        let samples: [HealthKitService.WeightSample]
        do {
            samples = try await health.recentWeightSamples(limit: 50)
        } catch {
            return .failed(reason: error.localizedDescription)
        }

        let existing: Set<Date>
        do {
            existing = Set(
                try weightService.entries(for: userRemoteID).map { entry in
                    Self.minuteAligned(entry.recordedAt)
                })
        } catch {
            return .failed(reason: error.localizedDescription)
        }

        var inserted = 0
        for sample in samples where !existing.contains(Self.minuteAligned(sample.recordedAt)) {
            try? weightService.log(
                sample.kilograms,
                for: userRemoteID,
                note: "Apple Health",
                at: sample.recordedAt,
                source: .appleHealth
            )
            inserted += 1
        }
        return inserted == 0 ? .noNewSamples : .imported(count: inserted)
    }

    /// Buckets timestamps to the minute so HealthKit samples saved on
    /// the user's behalf earlier in the day don't double-up. Uses the
    /// 1970 epoch to make assertions easy to read in tests.
    static func minuteAligned(_ date: Date) -> Date {
        let interval = floor(date.timeIntervalSince1970 / 60) * 60
        return Date(timeIntervalSince1970: interval)
    }
}
