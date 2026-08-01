import Foundation
import SwiftData

/// Logging streak — one row per user. Milestone 1.9 fleshes out the
/// transitions; this carries enough state to render the header counter and
/// hold "streak freezes" (a premium item).
@Model
final class Streak {
    var id: UUID = UUID()
    var userRemoteID: String = ""
    var currentLength: Int = 0
    var longestLength: Int = 0
    var lastLoggedDate: Date?
    var freezesAvailable: Int = 0
    var lastFreezeDate: Date?
    var lastFreezeAwardedLength: Int = 0
    init(
        id: UUID = UUID(),
        userRemoteID: String,
        currentLength: Int = 0,
        longestLength: Int = 0,
        lastLoggedDate: Date? = nil,
        freezesAvailable: Int = 0,
        lastFreezeDate: Date? = nil,
        lastFreezeAwardedLength: Int = 0
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.currentLength = currentLength
        self.longestLength = longestLength
        self.lastLoggedDate = lastLoggedDate
        self.freezesAvailable = freezesAvailable
        self.lastFreezeDate = lastFreezeDate
        self.lastFreezeAwardedLength = lastFreezeAwardedLength
    }
}
