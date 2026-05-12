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

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        recordedAt: Date = Date(),
        weightKg: Double,
        note: String? = nil
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        self.note = note
    }
}
