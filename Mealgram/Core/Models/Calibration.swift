import Foundation
import SwiftData

/// Per-user "personal AI calibration" tuning. Tracks how much we should
/// nudge portion estimates because plate size and hand size vary.
/// Filled out by Milestone 2.1 — for now this is a near-empty scaffold so
/// the schema is stable.
@Model
final class Calibration {
    @Attribute(.unique) var id: UUID
    var userRemoteID: String

    var referenceObjectRaw: String
    /// >1 means the model tends to *over*-estimate and the value scales results down.
    var portionAdjustmentFactor: Double
    var sampleCount: Int
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        referenceObject: ReferenceObjectKind = .generic,
        portionAdjustmentFactor: Double = 1.0,
        sampleCount: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.referenceObjectRaw = referenceObject.rawValue
        self.portionAdjustmentFactor = portionAdjustmentFactor
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }
}

extension Calibration {
    var referenceObject: ReferenceObjectKind {
        get { ReferenceObjectKind(rawValue: referenceObjectRaw) ?? .generic }
        set { referenceObjectRaw = newValue.rawValue }
    }
}
