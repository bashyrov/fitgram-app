import Foundation
import SwiftData

// Weight, water, workouts, favourites, custom goals and coach history: plain
// rows keyed by their UUID.

struct WeightRecord: SyncedRecord {
    static let kind = "weight"

    var recordedAt: Date
    var weightKg: Double
    var note: String?
    var source: String

    static func owned(by owner: String, in context: ModelContext) throws -> [WeightEntry] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: WeightEntry) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> WeightEntry? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> WeightEntry {
        let entry = WeightEntry(id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, weightKg: 0)
        context.insert(entry)
        return entry
    }

    init(_ model: WeightEntry) {
        recordedAt = model.recordedAt
        weightKg = model.weightKg
        note = model.note
        source = model.sourceRaw
    }

    func apply(to model: WeightEntry, in context: ModelContext) {
        model.recordedAt = recordedAt
        model.weightKg = weightKg
        model.note = note
        model.sourceRaw = source
    }
}

struct WaterRecord: SyncedRecord {
    static let kind = "water"

    var recordedAt: Date
    var milliliters: Int

    static func owned(by owner: String, in context: ModelContext) throws -> [WaterEntry] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: WaterEntry) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> WaterEntry? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> WaterEntry {
        let entry = WaterEntry(id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, milliliters: 0)
        context.insert(entry)
        return entry
    }

    init(_ model: WaterEntry) {
        recordedAt = model.recordedAt
        milliliters = model.milliliters
    }

    func apply(to model: WaterEntry, in context: ModelContext) {
        model.recordedAt = recordedAt
        model.milliliters = milliliters
    }
}

struct WorkoutRecord: SyncedRecord {
    static let kind = "workout"

    var recordedAt: Date
    var activityID: String
    var activityName: String
    var durationMinutes: Int
    var met: Double
    var caloriesBurnedKcal: Double
    var source: String
    var endedAt: Date?
    var distanceMeters: Double?
    var steps: Int
    var flightsClimbed: Int
    var averageHeartRateBpm: Double?
    var maxHeartRateBpm: Double?
    var minHeartRateBpm: Double?
    var sourceName: String?
    var activityTypeRawValue: Int
    var countsTowardDailyGoal: Bool
    var note: String?
    var createdAt: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [WorkoutEntry] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: WorkoutEntry) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> WorkoutEntry? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> WorkoutEntry {
        let entry = WorkoutEntry(
            id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, activityID: "", activityName: "",
            durationMinutes: 0, met: 0, caloriesBurnedKcal: 0)
        context.insert(entry)
        return entry
    }

    init(_ model: WorkoutEntry) {
        recordedAt = model.recordedAt
        activityID = model.activityID
        activityName = model.activityName
        durationMinutes = model.durationMinutes
        met = model.met
        caloriesBurnedKcal = model.caloriesBurnedKcal
        source = model.sourceRaw
        endedAt = model.endedAt
        distanceMeters = model.distanceMeters
        steps = model.steps
        flightsClimbed = model.flightsClimbed
        averageHeartRateBpm = model.averageHeartRateBpm
        maxHeartRateBpm = model.maxHeartRateBpm
        minHeartRateBpm = model.minHeartRateBpm
        sourceName = model.sourceName
        activityTypeRawValue = model.activityTypeRawValue
        countsTowardDailyGoal = model.countsTowardDailyGoal
        note = model.note
        createdAt = model.createdAt
    }

    func apply(to model: WorkoutEntry, in context: ModelContext) {
        model.recordedAt = recordedAt
        model.activityID = activityID
        model.activityName = activityName
        model.durationMinutes = durationMinutes
        model.met = met
        model.caloriesBurnedKcal = caloriesBurnedKcal
        model.sourceRaw = source
        model.endedAt = endedAt
        model.distanceMeters = distanceMeters
        model.steps = steps
        model.flightsClimbed = flightsClimbed
        model.averageHeartRateBpm = averageHeartRateBpm
        model.maxHeartRateBpm = maxHeartRateBpm
        model.minHeartRateBpm = minHeartRateBpm
        model.sourceName = sourceName
        model.activityTypeRawValue = activityTypeRawValue
        model.countsTowardDailyGoal = countsTowardDailyGoal
        model.note = note
        model.createdAt = createdAt
        model.updatedAt = Date()
    }
}

struct FavoriteMealRecord: SyncedRecord {
    static let kind = "favorite"

    var name: String
    var defaultQuantityGrams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var sourceHint: String
    var catalogFoodID: UUID?
    var useCount: Int
    var lastUsedAt: Date?
    var createdAt: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [FavoriteMeal] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: FavoriteMeal) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> FavoriteMeal? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> FavoriteMeal {
        let favorite = FavoriteMeal(
            id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, name: "", defaultQuantityGrams: 0,
            caloriesKcal: 0)
        context.insert(favorite)
        return favorite
    }

    init(_ model: FavoriteMeal) {
        name = model.name
        defaultQuantityGrams = model.defaultQuantityGrams
        caloriesKcal = model.caloriesKcal
        proteinGrams = model.proteinGrams
        carbsGrams = model.carbsGrams
        fatGrams = model.fatGrams
        fiberGrams = model.fiberGrams
        sourceHint = model.sourceHintRaw
        catalogFoodID = model.catalogFoodID
        useCount = model.useCount
        lastUsedAt = model.lastUsedAt
        createdAt = model.createdAt
    }

    func apply(to model: FavoriteMeal, in context: ModelContext) {
        model.name = name
        model.defaultQuantityGrams = defaultQuantityGrams
        model.caloriesKcal = caloriesKcal
        model.proteinGrams = proteinGrams
        model.carbsGrams = carbsGrams
        model.fatGrams = fatGrams
        model.fiberGrams = fiberGrams
        model.sourceHintRaw = sourceHint
        model.catalogFoodID = catalogFoodID
        model.useCount = useCount
        model.lastUsedAt = lastUsedAt
        model.createdAt = createdAt
    }
}

struct CustomGoalRecord: SyncedRecord {
    static let kind = "goal"

    var name: String
    var startDate: Date
    var endDate: Date
    var targetsJSON: Data
    var reminderType: String?
    var status: String
    var createdAt: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [CustomGoal] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: CustomGoal) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> CustomGoal? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> CustomGoal {
        let goal = CustomGoal(id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, name: "", endDate: Date())
        context.insert(goal)
        return goal
    }

    init(_ model: CustomGoal) {
        name = model.name
        startDate = model.startDate
        endDate = model.endDate
        targetsJSON = model.targetsJSON
        reminderType = model.reminderTypeRaw
        status = model.statusRaw
        createdAt = model.createdAt
    }

    func apply(to model: CustomGoal, in context: ModelContext) {
        model.name = name
        model.startDate = startDate
        model.endDate = endDate
        model.targetsJSON = targetsJSON
        model.reminderTypeRaw = reminderType
        model.statusRaw = status
        model.createdAt = createdAt
    }
}

struct CoachMemoryRecord: SyncedRecord {
    static let kind = "coachMemory"

    var summary: String
    var kindRaw: String
    var confidence: Double
    var createdAt: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [CoachMemoryNote] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: CoachMemoryNote) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> CoachMemoryNote? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> CoachMemoryNote {
        let note = CoachMemoryNote(
            id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, summary: "", kind: .observation)
        context.insert(note)
        return note
    }

    init(_ model: CoachMemoryNote) {
        summary = model.summary
        kindRaw = model.kindRaw
        confidence = model.confidence
        createdAt = model.createdAt
    }

    func apply(to model: CoachMemoryNote, in context: ModelContext) {
        model.summary = summary
        model.kindRaw = kindRaw
        model.confidence = confidence
        model.createdAt = createdAt
        model.updatedAt = Date()
    }
}

struct CoachInsightRecord: SyncedRecord {
    static let kind = "coachInsight"

    var weekStartAt: Date
    var generatedAt: Date
    var headline: String
    var insightsJSON: String
    var statsJSON: String
    var helpful: Bool?

    static func owned(by owner: String, in context: ModelContext) throws -> [CoachInsightLog] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: CoachInsightLog) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> CoachInsightLog? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> CoachInsightLog {
        let log = CoachInsightLog(
            id: UUID(uuidString: id) ?? UUID(), userRemoteID: owner, weekStartAt: Date(), generatedAt: Date(),
            headline: "", insightsJSON: "", statsJSON: "")
        context.insert(log)
        return log
    }

    init(_ model: CoachInsightLog) {
        weekStartAt = model.weekStartAt
        generatedAt = model.generatedAt
        headline = model.headline
        insightsJSON = model.insightsJSON
        statsJSON = model.statsJSON
        helpful = model.helpful
    }

    func apply(to model: CoachInsightLog, in context: ModelContext) {
        model.weekStartAt = weekStartAt
        model.generatedAt = generatedAt
        model.headline = headline
        model.insightsJSON = insightsJSON
        model.statsJSON = statsJSON
        model.helpful = helpful
    }
}
