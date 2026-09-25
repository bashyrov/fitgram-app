import Foundation
import OSLog
import SwiftData

struct AppleHealthWorkoutImport: Sendable {
    let externalID: UUID
    let activityTypeRawValue: UInt
    let activityName: String
    let startedAt: Date
    let endedAt: Date
    let durationMinutes: Int
    let caloriesBurnedKcal: Double
    let distanceMeters: Double?
    let steps: Int
    let flightsClimbed: Int
    let averageHeartRateBpm: Double?
    let maxHeartRateBpm: Double?
    let minHeartRateBpm: Double?
    let sourceName: String
}

@MainActor
final class WorkoutService {
    private let container: ModelContainer
    private let calendar: Calendar

    init(container: ModelContainer, calendar: Calendar = .current) {
        self.container = container
        self.calendar = calendar
    }

    func workouts(for userRemoteID: String, on day: Date) throws -> [WorkoutEntry] {
        let context = ModelContext(container)
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.userRemoteID == userRemoteID
                    && entry.recordedAt >= dayStart
                    && entry.recordedAt < dayEnd
            },
            sortBy: [SortDescriptor(\WorkoutEntry.recordedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func caloriesBurned(for userRemoteID: String, on day: Date) throws -> Double {
        try workouts(for: userRemoteID, on: day).reduce(0) { $0 + $1.caloriesBurnedKcal }
    }

    func caloriesCountedTowardGoal(for userRemoteID: String, on day: Date) throws -> Double {
        try workouts(for: userRemoteID, on: day)
            .filter(\.countsTowardDailyGoal)
            .reduce(0) { $0 + $1.caloriesBurnedKcal }
    }

    func deleteWorkout(id: UUID, userRemoteID: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.id == id && entry.userRemoteID == userRemoteID
            }
        )
        guard let entry = try context.fetch(descriptor).first else { return }
        context.delete(entry)
        try context.save()
        Logger.persistence.notice("Deleted workout \(id.uuidString, privacy: .public)")
        NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
    }

    func setCountsTowardDailyGoal(id: UUID, userRemoteID: String, isEnabled: Bool) throws -> WorkoutEntry? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.id == id && entry.userRemoteID == userRemoteID
            }
        )
        guard let entry = try context.fetch(descriptor).first else { return nil }
        entry.countsTowardDailyGoal = isEnabled
        entry.updatedAt = Date()
        try context.save()
        NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
        return entry
    }

    func appleHealthWorkoutCalories(for userRemoteID: String, on day: Date) throws -> Double {
        try workouts(for: userRemoteID, on: day)
            .filter { $0.source == .appleHealth && $0.activityID.hasPrefix("apple_health:") }
            .reduce(0) { $0 + $1.caloriesBurnedKcal }
    }

    func currentUserWeightKg(for userRemoteID: String) throws -> Double? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        return try context.fetch(descriptor).first?.weightKg
    }

    func existingActivityIDs(for userRemoteID: String, from startDate: Date, to endDate: Date) throws -> Set<String> {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.userRemoteID == userRemoteID
                    && entry.recordedAt >= startDate
                    && entry.recordedAt < endDate
            }
        )
        return Set(try context.fetch(descriptor).map(\.activityID))
    }

    @discardableResult
    func log(
        item: WorkoutCatalogItem,
        durationMinutes: Int,
        weightKg: Double,
        manualCalories: Double?,
        userRemoteID: String,
        at date: Date = Date(),
        countsTowardDailyGoal: Bool = true,
        note: String? = nil
    ) throws -> WorkoutEntry {
        let context = ModelContext(container)
        let calories =
            manualCalories
            ?? WorkoutCatalog.calories(
                met: item.met,
                weightKg: weightKg,
                durationMinutes: durationMinutes
            )
        let entry = WorkoutEntry(
            userRemoteID: userRemoteID,
            recordedAt: date,
            activityID: item.id,
            activityName: item.localizedName,
            durationMinutes: max(1, durationMinutes),
            met: item.met,
            caloriesBurnedKcal: max(0, calories),
            source: manualCalories == nil ? .manualMET : .manualCalories,
            endedAt: calendar.date(byAdding: .minute, value: max(1, durationMinutes), to: date),
            countsTowardDailyGoal: countsTowardDailyGoal,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        if entry.note?.isEmpty == true { entry.note = nil }
        context.insert(entry)
        try context.save()
        Logger.persistence.notice("Logged workout \(entry.activityID, privacy: .public)")
        NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
        return entry
    }

    @discardableResult
    func importAppleHealthWorkout(
        _ sample: AppleHealthWorkoutImport,
        userRemoteID: String
    ) throws -> WorkoutEntry? {
        let context = ModelContext(container)
        let activityID = Self.appleHealthActivityID(for: sample.externalID)
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.userRemoteID == userRemoteID && entry.activityID == activityID
            }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.activityName = sample.activityName
            existing.endedAt = sample.endedAt
            existing.durationMinutes = max(1, sample.durationMinutes)
            existing.caloriesBurnedKcal = max(0, sample.caloriesBurnedKcal)
            existing.distanceMeters = sample.distanceMeters
            existing.steps = max(0, sample.steps)
            existing.flightsClimbed = max(0, sample.flightsClimbed)
            existing.averageHeartRateBpm = sample.averageHeartRateBpm
            existing.maxHeartRateBpm = sample.maxHeartRateBpm
            existing.minHeartRateBpm = sample.minHeartRateBpm
            existing.sourceName = sample.sourceName.isEmpty ? nil : sample.sourceName
            existing.activityTypeRawValue = Int(sample.activityTypeRawValue)
            existing.updatedAt = Date()
            try context.save()
            return nil
        }

        let noteParts = [
            "Apple Health",
            sample.sourceName.isEmpty ? nil : sample.sourceName,
            sample.distanceMeters.map { String(format: "%.2f km", $0 / 1000) },
        ].compactMap { $0 }
        let entry = WorkoutEntry(
            userRemoteID: userRemoteID,
            recordedAt: sample.startedAt,
            activityID: activityID,
            activityName: sample.activityName,
            durationMinutes: max(1, sample.durationMinutes),
            met: 0,
            caloriesBurnedKcal: max(0, sample.caloriesBurnedKcal),
            source: .appleHealth,
            endedAt: sample.endedAt,
            distanceMeters: sample.distanceMeters,
            steps: max(0, sample.steps),
            flightsClimbed: max(0, sample.flightsClimbed),
            averageHeartRateBpm: sample.averageHeartRateBpm,
            maxHeartRateBpm: sample.maxHeartRateBpm,
            minHeartRateBpm: sample.minHeartRateBpm,
            sourceName: sample.sourceName.isEmpty ? nil : sample.sourceName,
            activityTypeRawValue: Int(sample.activityTypeRawValue),
            note: noteParts.joined(separator: " · ")
        )
        context.insert(entry)
        try context.save()
        Logger.persistence.notice("Imported Apple Health workout \(sample.activityTypeRawValue, privacy: .public)")
        NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
        return entry
    }

    @discardableResult
    func importAppleHealthActiveEnergy(
        day: Date,
        caloriesBurnedKcal: Double,
        userRemoteID: String,
        steps: Double = 0,
        distanceMeters: Double = 0,
        isEstimatedFromMovement: Bool = false
    ) throws -> WorkoutEntry? {
        let context = ModelContext(container)
        let dayStart = calendar.startOfDay(for: day)
        let activityID = Self.appleHealthActiveEnergyActivityID(for: dayStart, calendar: calendar)
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.userRemoteID == userRemoteID && entry.activityID == activityID
            }
        )
        let existing = try context.fetch(descriptor).first
        let calories = max(0, caloriesBurnedKcal)

        if calories < 1 {
            if let existing {
                context.delete(existing)
                try context.save()
                NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
            }
            return nil
        }

        let recordedAt =
            calendar.date(byAdding: .hour, value: 12, to: dayStart)
            ?? dayStart
        let note = Self.appleHealthDailyMovementNote(
            steps: steps,
            distanceMeters: distanceMeters,
            isEstimated: isEstimatedFromMovement
        )

        if let existing {
            guard abs(existing.caloriesBurnedKcal - calories) >= 0.5 else { return nil }
            existing.recordedAt = recordedAt
            existing.activityName = Self.appleHealthDailyMovementName
            existing.durationMinutes = 1
            existing.caloriesBurnedKcal = calories
            existing.steps = Int(max(0, steps).rounded())
            existing.distanceMeters = distanceMeters > 0 ? distanceMeters : nil
            existing.sourceName = "Apple Health"
            existing.note = note
            existing.updatedAt = Date()
            try context.save()
            NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
            return existing
        }

        let entry = WorkoutEntry(
            userRemoteID: userRemoteID,
            recordedAt: recordedAt,
            activityID: activityID,
            activityName: Self.appleHealthDailyMovementName,
            durationMinutes: 1,
            met: 0,
            caloriesBurnedKcal: calories,
            source: .appleHealth,
            distanceMeters: distanceMeters > 0 ? distanceMeters : nil,
            steps: Int(max(0, steps).rounded()),
            sourceName: "Apple Health",
            note: note
        )
        context.insert(entry)
        try context.save()
        Logger.persistence.notice("Imported Apple Health active energy")
        NotificationCenter.default.post(name: Notification.Name("FitgramWorkoutSaved"), object: nil)
        return entry
    }

    static func appleHealthActivityID(for id: UUID) -> String {
        "apple_health:\(id.uuidString.lowercased())"
    }

    static func appleHealthActiveEnergyActivityID(for day: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "apple_health_active:%04d-%02d-%02d", year, month, day)
    }

    private static var appleHealthDailyMovementName: String {
        TL(
            pl: "Aktywność z Apple Health",
            en: "Apple Health activity",
            uk: "Активність з Apple Health",
            ru: "Активность из Apple Health",
            es: "Actividad de Apple Health"
        )
    }

    private static func appleHealthDailyMovementNote(
        steps: Double,
        distanceMeters: Double,
        isEstimated: Bool
    ) -> String {
        let source: String
        if isEstimated {
            source = TL(
                pl: "szacunek ze kroków/dystansu",
                en: "estimated from steps/distance",
                uk: "оцінка за кроками/дистанцією",
                ru: "оценка по шагам/дистанции",
                es: "estimado por pasos/distancia"
            )
        } else {
            source = TL(
                pl: "aktywna energia poza treningami",
                en: "active energy outside workouts",
                uk: "активна енергія поза тренуваннями",
                ru: "активная энергия вне тренировок",
                es: "energía activa fuera de entrenos"
            )
        }
        var parts = ["Apple Health", source]
        if steps >= 1 {
            parts.append(String.localizedStringWithFormat("%.0f steps", steps))
        }
        if distanceMeters >= 1 {
            parts.append(String(format: "%.2f km", distanceMeters / 1000))
        }
        return parts.joined(separator: " · ")
    }
}
