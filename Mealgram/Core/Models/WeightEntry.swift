import Foundation
import SwiftData

/// A single weigh-in. Lightweight (one number + an optional note); the body
/// photo timeline (M3.10) lives separately so the encryption story doesn't
/// drag this simple flow into its weight class.
@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var userRemoteID: String
    var recordedAt: Date
    var weightKg: Double
    var note: String?

    /// Provenance of the weigh-in. Defaults to `.manual` so SwiftData
    /// lightweight migration fills existing rows without bumping schema.
    /// The Goal Tracker feature sets `.goalTracker`; Apple Health import
    /// sets `.appleHealth`.
    var sourceRaw: String = WeightEntrySource.manual.rawValue

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        recordedAt: Date = Date(),
        weightKg: Double,
        note: String? = nil,
        source: WeightEntrySource = .manual
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        self.note = note
        self.sourceRaw = source.rawValue
    }
}

extension WeightEntry {
    var source: WeightEntrySource {
        get { WeightEntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

/// Where a `WeightEntry` came from. Stable raw values — migrations don't
/// renumber.
enum WeightEntrySource: String, Codable, CaseIterable, Sendable {
    case manual
    case goalTracker = "goal_tracker"
    case appleHealth = "apple_health"
}
