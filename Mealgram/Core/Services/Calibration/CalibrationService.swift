import Foundation
import OSLog
import SwiftData

/// Manages the per-user portion-estimate calibration. The full vision-based
/// "look at a card on the plate" UI ships later; for now we expose a
/// manual ±factor the user can tune from Profile when they feel the AI's
/// estimates skew high or low.
@MainActor
final class CalibrationService {
    static let factorBounds: ClosedRange<Double> = 0.6...1.4

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Reads (or creates) the calibration row for the user. Always returns
    /// a value — the default factor is 1.0.
    @discardableResult
    func current(forUser userRemoteID: String) throws -> Calibration {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Calibration>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let fresh = Calibration(userRemoteID: userRemoteID)
        context.insert(fresh)
        try context.save()
        return fresh
    }

    /// Updates the manual portion-adjustment factor. Clamped to a sane
    /// range so a fat-fingered slider drag can't 10× the user's calories.
    func updateFactor(_ factor: Double, referenceObject: ReferenceObjectKind, forUser userRemoteID: String) throws {
        let clamped = max(Self.factorBounds.lowerBound, min(Self.factorBounds.upperBound, factor))
        let calibration = try current(forUser: userRemoteID)
        let context = ModelContext(container)
        let remoteID = calibration.userRemoteID
        let descriptor = FetchDescriptor<Calibration>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard let stored = try context.fetch(descriptor).first else {
            throw CalibrationError.notFound
        }
        stored.portionAdjustmentFactor = clamped
        stored.referenceObject = referenceObject
        stored.lastUpdated = Date()
        try context.save()
        Logger.persistence.notice(
            "Calibration factor=\(clamped, format: .fixed(precision: 2)) ref=\(referenceObject.rawValue, privacy: .public)"
        )
    }

    /// Restores the calibration row to defaults (factor 1.0, reference
    /// .creditCard, sample count 0). Used by the "Resetuj" button on the
    /// Profile → Kalibracja screen when the user wants to start fresh.
    func reset(forUser userRemoteID: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Calibration>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        guard let stored = try context.fetch(descriptor).first else { return }
        stored.portionAdjustmentFactor = 1.0
        stored.referenceObject = .creditCard
        stored.sampleCount = 0
        stored.lastUpdated = Date()
        try context.save()
    }

    /// Bumps the observed sample count — called after each photo scan so
    /// the user sees "from N posiłków" on the screen.
    func recordSample(forUser userRemoteID: String) throws {
        let calibration = try current(forUser: userRemoteID)
        let context = ModelContext(container)
        let remoteID = calibration.userRemoteID
        let descriptor = FetchDescriptor<Calibration>(
            predicate: #Predicate { $0.userRemoteID == remoteID }
        )
        guard let stored = try context.fetch(descriptor).first else { return }
        stored.sampleCount += 1
        stored.lastUpdated = Date()
        try context.save()
    }

    /// Applies the saved adjustment to a scan result so totals match what
    /// the user actually expects.
    func apply(_ factor: Double, to result: ScanResult) -> ScanResult {
        guard factor != 1 else { return result }
        var adjusted = result
        adjusted.items = result.items.map { item in
            var copy = item
            copy.quantityGrams *= factor
            copy.caloriesKcal *= factor
            copy.proteinGrams *= factor
            copy.carbsGrams *= factor
            copy.fatGrams *= factor
            return copy
        }
        return adjusted
    }

    enum CalibrationError: Error, Equatable {
        case notFound
    }
}
