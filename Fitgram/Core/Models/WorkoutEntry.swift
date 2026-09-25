import Foundation
import SwiftData

@Model
final class WorkoutEntry {
    var id: UUID = UUID()
    var userRemoteID: String = ""
    var recordedAt: Date = Date()
    var activityID: String = ""
    var activityName: String = ""
    var durationMinutes: Int = 0
    var met: Double = 0
    var caloriesBurnedKcal: Double = 0
    var sourceRaw: String = WorkoutSource.manualMET.rawValue
    var endedAt: Date?
    var distanceMeters: Double?
    var steps: Int = 0
    var flightsClimbed: Int = 0
    var averageHeartRateBpm: Double?
    var maxHeartRateBpm: Double?
    var minHeartRateBpm: Double?
    var sourceName: String?
    var activityTypeRawValue: Int = 0
    var countsTowardDailyGoal: Bool = true
    var note: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        userRemoteID: String,
        recordedAt: Date = Date(),
        activityID: String,
        activityName: String,
        durationMinutes: Int,
        met: Double,
        caloriesBurnedKcal: Double,
        source: WorkoutSource = .manualMET,
        endedAt: Date? = nil,
        distanceMeters: Double? = nil,
        steps: Int = 0,
        flightsClimbed: Int = 0,
        averageHeartRateBpm: Double? = nil,
        maxHeartRateBpm: Double? = nil,
        minHeartRateBpm: Double? = nil,
        sourceName: String? = nil,
        activityTypeRawValue: Int = 0,
        countsTowardDailyGoal: Bool = true,
        note: String? = nil
    ) {
        let now = Date()
        self.id = id
        self.userRemoteID = userRemoteID
        self.recordedAt = recordedAt
        self.activityID = activityID
        self.activityName = activityName
        self.durationMinutes = durationMinutes
        self.met = met
        self.caloriesBurnedKcal = caloriesBurnedKcal
        self.sourceRaw = source.rawValue
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.steps = steps
        self.flightsClimbed = flightsClimbed
        self.averageHeartRateBpm = averageHeartRateBpm
        self.maxHeartRateBpm = maxHeartRateBpm
        self.minHeartRateBpm = minHeartRateBpm
        self.sourceName = sourceName
        self.activityTypeRawValue = activityTypeRawValue
        self.countsTowardDailyGoal = countsTowardDailyGoal
        self.note = note
        self.createdAt = now
        self.updatedAt = now
    }
}

extension WorkoutEntry {
    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .manualMET }
        set { sourceRaw = newValue.rawValue }
    }
}

enum WorkoutSource: String, Codable, CaseIterable, Sendable {
    case manualMET = "manual_met"
    case manualCalories = "manual_calories"
    case appleHealth = "apple_health"
    case strava
    case oura
    case garmin
    case whoop
}
