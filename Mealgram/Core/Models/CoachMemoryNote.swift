import Foundation
import SwiftData

/// Long-lived note the AI coach keeps about the user — preferences,
/// observations, milestones worth remembering across sessions. The
/// rule-based generator doesn't write these yet; the Claude-backed
/// generator (M3.2) will. Modelled now so the store is ready and the
/// schema migrates cleanly when the LLM lands.
@Model
final class CoachMemoryNote {
    var id: UUID = UUID()
    var userRemoteID: String = ""
    /// Short summary, e.g. "Trenuje siłowo 3× w tygodniu" or
    /// "Pomija obiad w środy". Free-form text the coach will reference
    /// in future prompts.
    var summary: String = ""
    /// One of `CoachMemoryKind.rawValue` — keeps the schema flat while
    /// letting the engine reason about which slot a note belongs to.
    var kindRaw: String = ""
    /// 0…1 confidence in the observation; coach can downgrade with new
    /// signals (or upgrade with reinforcement).
    var confidence: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(
        id: UUID = UUID(),
        userRemoteID: String,
        summary: String,
        kind: CoachMemoryKind,
        confidence: Double = 0.5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.summary = summary
        self.kindRaw = kind.rawValue
        self.confidence = max(0, min(1, confidence))
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

extension CoachMemoryNote {
    var kind: CoachMemoryKind {
        get { CoachMemoryKind(rawValue: kindRaw) ?? .observation }
        set { kindRaw = newValue.rawValue }
    }
}

/// What slot a `CoachMemoryNote` fills. New cases are safe additions —
/// existing rows just fall back to `.observation` if the raw value
/// doesn't decode.
enum CoachMemoryKind: String, Codable, Sendable, CaseIterable {
    /// A factual observation the user implicitly confirmed
    /// ("preferuje mięso", "alergia na orzechy").
    case observation
    /// An explicit user-stated preference ("nie lubi twarogu").
    case preference
    /// A milestone worth referencing ("zrzucił 5 kg w pierwszym miesiącu").
    case milestone
    /// A goal the user articulated ("chce zbudować masę przed wakacjami").
    case goal
}
