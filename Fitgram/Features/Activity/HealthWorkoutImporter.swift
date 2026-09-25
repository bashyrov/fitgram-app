import Foundation
import OSLog

@MainActor
final class HealthWorkoutImporter {
    enum ImportResult: Equatable {
        case unavailable
        case denied
        case imported(count: Int)
        case noNewSamples
        case failed(reason: String)
    }

    private let health: any HealthKitWeightImporter
    private let workoutService: WorkoutService
    private let calendar: Calendar

    init(
        health: any HealthKitWeightImporter,
        workoutService: WorkoutService,
        calendar: Calendar = .current
    ) {
        self.health = health
        self.workoutService = workoutService
        self.calendar = calendar
    }

    func importToday(for userRemoteID: String, now: Date = Date()) async -> ImportResult {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return .failed(reason: "Invalid date window")
        }
        return await importWorkouts(for: userRemoteID, from: start, to: end)
    }

    func importRecentDays(for userRemoteID: String, days: Int = 14, now: Date = Date()) async -> ImportResult {
        let todayStart = calendar.startOfDay(for: now)
        let safeDays = max(1, min(days, 60))
        guard
            let start = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart),
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart)
        else {
            return .failed(reason: "Invalid date window")
        }
        return await importWorkouts(for: userRemoteID, from: start, to: end)
    }

    private func importWorkouts(for userRemoteID: String, from startDate: Date, to endDate: Date) async -> ImportResult {
        guard health.isHealthDataAvailable else { return .unavailable }
        do {
            let granted = try await health.requestAuthorization()
            guard granted else { return .denied }
        } catch {
            Logger.persistence.error("Health workout auth failed: \(String(describing: error))")
            return .failed(reason: error.localizedDescription)
        }

        let samples: [HealthKitService.WorkoutSample]
        do {
            samples = try await health.workoutSamples(from: startDate, to: endDate)
        } catch {
            Logger.persistence.error("Health workout query failed: \(String(describing: error))")
            return .failed(reason: error.localizedDescription)
        }

        var inserted = 0
        for sample in samples {
            do {
                let entry = try workoutService.importAppleHealthWorkout(
                    AppleHealthWorkoutImport(
                        externalID: sample.id,
                        activityTypeRawValue: sample.activityType,
                        activityName: sample.activityName,
                        startedAt: sample.startedAt,
                        endedAt: sample.endedAt,
                        durationMinutes: sample.durationMinutes,
                        caloriesBurnedKcal: sample.caloriesBurnedKcal,
                        distanceMeters: sample.distanceMeters,
                        steps: sample.steps,
                        flightsClimbed: sample.flightsClimbed,
                        averageHeartRateBpm: sample.averageHeartRateBpm,
                        maxHeartRateBpm: sample.maxHeartRateBpm,
                        minHeartRateBpm: sample.minHeartRateBpm,
                        sourceName: sample.sourceName
                    ),
                    userRemoteID: userRemoteID
                )
                if entry != nil { inserted += 1 }
            } catch {
                Logger.persistence.error("Health workout save failed: \(String(describing: error))")
            }
        }
        inserted += await importActiveEnergyRemainders(
            for: userRemoteID,
            from: startDate,
            to: endDate
        )

        return inserted == 0 ? .noNewSamples : .imported(count: inserted)
    }

    private func importActiveEnergyRemainders(
        for userRemoteID: String,
        from startDate: Date,
        to endDate: Date
    ) async -> Int {
        var changed = 0
        var dayStart = calendar.startOfDay(for: startDate)
        while dayStart < endDate {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            do {
                let summary = try await health.movementSummary(from: dayStart, to: min(dayEnd, endDate))
                let workoutCalories = try workoutService.appleHealthWorkoutCalories(for: userRemoteID, on: dayStart)
                let activeRemainder = max(0, summary.activeEnergyKcal - workoutCalories)
                let estimatedMovement = try estimatedMovementCalories(
                    for: userRemoteID,
                    summary: summary
                )
                let shouldUseEstimate = activeRemainder < 1 && estimatedMovement >= 10
                let calories = shouldUseEstimate ? estimatedMovement : activeRemainder
                let entry = try workoutService.importAppleHealthActiveEnergy(
                    day: dayStart,
                    caloriesBurnedKcal: calories,
                    userRemoteID: userRemoteID,
                    steps: summary.steps,
                    distanceMeters: summary.walkingRunningDistanceMeters,
                    isEstimatedFromMovement: shouldUseEstimate
                )
                if entry != nil { changed += 1 }
            } catch {
                Logger.persistence.error("Health active energy import failed: \(String(describing: error))")
            }
            dayStart = dayEnd
        }
        return changed
    }

    private func estimatedMovementCalories(
        for userRemoteID: String,
        summary: HealthKitService.MovementSummary
    ) throws -> Double {
        guard summary.steps >= 500 || summary.walkingRunningDistanceMeters >= 350 else { return 0 }
        let weightKg = try workoutService.currentUserWeightKg(for: userRemoteID) ?? 70
        let distanceMeters =
            summary.walkingRunningDistanceMeters > 0
            ? summary.walkingRunningDistanceMeters
            : summary.steps * 0.75
        let distanceKm = distanceMeters / 1000
        return max(0, distanceKm * weightKg * 0.55)
    }
}

enum HealthWorkoutConnectionStore {
    private static let enabledKey = "fitgram.health.workouts.enabled"
    private static let lastAutoSyncKey = "fitgram.health.workouts.lastAutoSync"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static func shouldAutoSync(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return false }
        guard let lastSync = UserDefaults.standard.object(forKey: lastAutoSyncKey) as? Date else { return true }
        return !calendar.isDate(lastSync, equalTo: now, toGranularity: .minute)
    }

    static func markAutoSynced(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastAutoSyncKey)
    }
}
