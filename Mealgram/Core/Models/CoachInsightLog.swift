import Foundation
import SwiftData

/// Persisted snapshot of one weekly Ola debrief. The week itself is the
/// natural primary key — at most one record per ISO week per user. We
/// store the rendered headline + JSON-encoded insights so the history
/// view stays cheap (no rerun of the rule engine) and the historical
/// copy survives even if the rules later change wording.
@Model
final class CoachInsightLog {
    @Attribute(.unique) var id: UUID
    var userRemoteID: String

    /// Monday 00:00 of the ISO week the debrief covers.
    var weekStartAt: Date
    /// When the snapshot was created (within `weekStartAt + 7 days`).
    var generatedAt: Date

    var headline: String
    /// JSON-encoded `[StoredInsight]` (see `CoachInsightLogStore`).
    var insightsJSON: String
    /// JSON-encoded `[StoredStat]`.
    var statsJSON: String
    /// User feedback on the week — nil = not asked, true = thumbs up,
    /// false = thumbs down. Added in a lightweight migration (optional
    /// column = no schema version bump needed).
    var helpful: Bool?

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        weekStartAt: Date,
        generatedAt: Date,
        headline: String,
        insightsJSON: String,
        statsJSON: String
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.weekStartAt = weekStartAt
        self.generatedAt = generatedAt
        self.headline = headline
        self.insightsJSON = insightsJSON
        self.statsJSON = statsJSON
    }
}
