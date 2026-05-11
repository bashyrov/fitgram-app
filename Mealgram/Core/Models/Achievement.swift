import Foundation
import SwiftData

/// Earned badge — one per (userRemoteID, kind) pair. Full catalog of
/// possible achievements lives in `Resources/Mock/achievements.json` once
/// Milestone 2.8 lands.
@Model
final class Achievement {
    @Attribute(.unique) var id: UUID
    var userRemoteID: String

    /// Stable identifier ("streak.7", "scan.first", "protein.30days").
    var kind: String
    var earnedAt: Date
    var title: String
    var details: String

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        kind: String,
        title: String,
        details: String,
        earnedAt: Date = Date()
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.kind = kind
        self.title = title
        self.details = details
        self.earnedAt = earnedAt
    }
}
