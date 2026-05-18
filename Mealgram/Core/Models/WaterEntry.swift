import Foundation
import SwiftData

/// One drink event. Granularity = 1 ml (we treat the value as integer ml
/// so the UI math stays simple); reuse the same `userRemoteID` scoping
/// pattern as WeightEntry + Streak.
@Model
final class WaterEntry {
    var id: UUID
    var userRemoteID: String
    var recordedAt: Date
    var milliliters: Int

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        recordedAt: Date = Date(),
        milliliters: Int
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.recordedAt = recordedAt
        self.milliliters = max(0, milliliters)
    }
}
