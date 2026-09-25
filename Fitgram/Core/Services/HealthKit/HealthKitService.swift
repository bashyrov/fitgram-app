import Foundation
import HealthKit
import OSLog

/// Reads weight samples from Apple Health and pipes them into our local
/// `WeightEntry` store. Wraps `HKHealthStore` behind a protocol so the
/// importer can be unit-tested without touching the real HealthKit
/// runtime.
///
/// The Health entitlement (`com.apple.developer.healthkit`) lands when the
/// Apple Developer Team ID is configured; until then the read flow will
/// return `.notAuthorised` at runtime but the surrounding code already
/// compiles and ships.
@MainActor
protocol HealthKitWeightImporter: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws -> Bool
    func recentWeightSamples(limit: Int) async throws -> [HealthKitService.WeightSample]
    func activeEnergyBurned(from startDate: Date, to endDate: Date) async throws -> Double
    func movementSummary(from startDate: Date, to endDate: Date) async throws -> HealthKitService.MovementSummary
    func workoutSamples(from startDate: Date, to endDate: Date) async throws -> [HealthKitService.WorkoutSample]
}

@MainActor
final class HealthKitService: HealthKitWeightImporter {
    enum ImportError: Error, Equatable {
        case unavailable
        case notAuthorised
        case query(String)
    }

    struct WeightSample: Equatable, Sendable {
        let kilograms: Double
        let recordedAt: Date
    }

    struct WorkoutSample: Equatable, Sendable {
        let id: UUID
        let activityType: UInt
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

    struct MovementSummary: Equatable, Sendable {
        let activeEnergyKcal: Double
        let steps: Double
        let walkingRunningDistanceMeters: Double
    }

    private struct HeartRateStats: Sendable {
        let average: Double?
        let min: Double?
        let max: Double?
    }

    private let store: HKHealthStore?
    private var workoutObserverQuery: HKObserverQuery?

    init() {
        self.store = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    var isHealthDataAvailable: Bool { store != nil }

    func requestAuthorization() async throws -> Bool {
        guard let store else { throw ImportError.unavailable }
        let weightType = HKQuantityType(.bodyMass)
        let workoutType = HKObjectType.workoutType()
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let distanceWalkingRunningType = HKQuantityType(.distanceWalkingRunning)
        let distanceCyclingType = HKQuantityType(.distanceCycling)
        let distanceSwimmingType = HKQuantityType(.distanceSwimming)
        let stepType = HKQuantityType(.stepCount)
        let heartRateType = HKQuantityType(.heartRate)
        let flightsType = HKQuantityType(.flightsClimbed)
        let readTypes: Set<HKObjectType> = [
            weightType,
            workoutType,
            activeEnergyType,
            distanceWalkingRunningType,
            distanceCyclingType,
            distanceSwimmingType,
            stepType,
            heartRateType,
            flightsType,
        ]
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            Logger.persistence.error("HealthKit auth failed: \(String(describing: error))")
            throw ImportError.query(error.localizedDescription)
        }
    }

    /// Returns the most recent body-mass samples (Newton-first), already
    /// converted to kilograms.
    func recentWeightSamples(limit: Int = 20) async throws -> [WeightSample] {
        guard let store else { throw ImportError.unavailable }
        let weightType = HKQuantityType(.bodyMass)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ImportError.query(error.localizedDescription))
                    return
                }
                let mapped: [WeightSample] = (samples ?? []).compactMap { raw in
                    guard let sample = raw as? HKQuantitySample else { return nil }
                    let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                    return WeightSample(kilograms: kg, recordedAt: sample.endDate)
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    func activeEnergyBurned(from startDate: Date, to endDate: Date) async throws -> Double {
        try await quantitySum(
            type: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            from: startDate,
            to: endDate
        )
    }

    func movementSummary(from startDate: Date, to endDate: Date) async throws -> MovementSummary {
        let activeEnergy = try await activeEnergyBurned(from: startDate, to: endDate)
        let steps = try await quantitySum(
            type: HKQuantityType(.stepCount),
            unit: .count(),
            from: startDate,
            to: endDate
        )
        let distance = try await quantitySum(
            type: HKQuantityType(.distanceWalkingRunning),
            unit: .meter(),
            from: startDate,
            to: endDate
        )
        return MovementSummary(
            activeEnergyKcal: activeEnergy,
            steps: steps,
            walkingRunningDistanceMeters: distance
        )
    }

    private func quantitySum(
        type: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        guard let store else { throw ImportError.unavailable }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: ImportError.query(error.localizedDescription))
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: max(0, value))
            }
            store.execute(query)
        }
    }

    /// Returns workouts in the requested local window with active calories
    /// and useful context normalized for Fitgram's activity timeline.
    func workoutSamples(from startDate: Date, to endDate: Date) async throws -> [WorkoutSample] {
        let workouts = try await workoutObjects(from: startDate, to: endDate)
        var mapped: [WorkoutSample] = []
        for workout in workouts {
            let storedCalories = Self.activeCaloriesKcal(for: workout)
            let intervalCalories =
                storedCalories > 0
                ? storedCalories
                : ((try? await activeEnergyBurned(from: workout.startDate, to: workout.endDate)) ?? 0)
            let calories = max(0, intervalCalories)
            let distance = Self.distanceMeters(for: workout)
            let steps = Int(
                ((try? await quantitySum(
                    type: HKQuantityType(.stepCount),
                    unit: .count(),
                    from: workout.startDate,
                    to: workout.endDate
                )) ?? 0).rounded()
            )
            let flights = Int(
                ((try? await quantitySum(
                    type: HKQuantityType(.flightsClimbed),
                    unit: .count(),
                    from: workout.startDate,
                    to: workout.endDate
                )) ?? 0).rounded()
            )
            let heartRate = await heartRateStats(from: workout.startDate, to: workout.endDate)
            guard calories >= 5 else { continue }
            mapped.append(
                WorkoutSample(
                    id: workout.uuid,
                    activityType: workout.workoutActivityType.rawValue,
                    activityName: Self.localizedWorkoutName(for: workout.workoutActivityType),
                    startedAt: workout.startDate,
                    endedAt: workout.endDate,
                    durationMinutes: max(1, Int((workout.duration / 60).rounded())),
                    caloriesBurnedKcal: calories,
                    distanceMeters: distance,
                    steps: steps,
                    flightsClimbed: flights,
                    averageHeartRateBpm: heartRate.average,
                    maxHeartRateBpm: heartRate.max,
                    minHeartRateBpm: heartRate.min,
                    sourceName: workout.sourceRevision.source.name
                )
            )
        }
        return mapped
    }

    private func workoutObjects(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        guard let store else { throw ImportError.unavailable }
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: ImportError.query(error.localizedDescription))
                    return
                }
                continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKWorkout })
            }
            store.execute(query)
        }
    }

    private func heartRateStats(from startDate: Date, to endDate: Date) async -> HeartRateStats {
        let type = HKQuantityType(.heartRate)
        async let average = try? quantityStatistic(
            type: type,
            unit: Self.heartRateUnit,
            option: .discreteAverage,
            from: startDate,
            to: endDate
        )
        async let minimum = try? quantityStatistic(
            type: type,
            unit: Self.heartRateUnit,
            option: .discreteMin,
            from: startDate,
            to: endDate
        )
        async let maximum = try? quantityStatistic(
            type: type,
            unit: Self.heartRateUnit,
            option: .discreteMax,
            from: startDate,
            to: endDate
        )
        return await HeartRateStats(average: average, min: minimum, max: maximum)
    }

    private func quantityStatistic(
        type: HKQuantityType,
        unit: HKUnit,
        option: HKStatisticsOptions,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double? {
        guard let store else { throw ImportError.unavailable }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: option
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: ImportError.query(error.localizedDescription))
                    return
                }
                let quantity: HKQuantity?
                if option.contains(.discreteAverage) {
                    quantity = statistics?.averageQuantity()
                } else if option.contains(.discreteMin) {
                    quantity = statistics?.minimumQuantity()
                } else if option.contains(.discreteMax) {
                    quantity = statistics?.maximumQuantity()
                } else {
                    quantity = nil
                }
                guard let value = quantity?.doubleValue(for: unit), value > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func startWorkoutObserver(onChange: @escaping @MainActor @Sendable () -> Void) async throws {
        guard let store else { throw ImportError.unavailable }
        if workoutObserverQuery != nil { return }

        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            if let error {
                Logger.persistence.error("Health workout observer failed: \(String(describing: error))")
                completionHandler()
                return
            }
            completionHandler()
            Task { @MainActor in
                onChange()
            }
        }
        workoutObserverQuery = query
        store.execute(query)

        do {
            try await store.enableBackgroundDelivery(for: workoutType, frequency: .immediate)
        } catch {
            Logger.persistence.error("Health workout background delivery failed: \(String(describing: error))")
            throw ImportError.query(error.localizedDescription)
        }
    }

    private static func activeCaloriesKcal(for workout: HKWorkout) -> Double {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        if let sum = workout.statistics(for: activeEnergyType)?.sumQuantity() {
            return sum.doubleValue(for: .kilocalorie())
        }
        if let total = workout.totalEnergyBurned {
            return total.doubleValue(for: .kilocalorie())
        }
        return 0
    }

    private static func distanceMeters(for workout: HKWorkout) -> Double? {
        let distanceTypes = [
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ]
        for type in distanceTypes {
            if let sum = workout.statistics(for: type)?.sumQuantity() {
                let meters = sum.doubleValue(for: .meter())
                if meters > 0 { return meters }
            }
        }
        return workout.totalDistance?.doubleValue(for: .meter())
    }

    private static var heartRateUnit: HKUnit {
        HKUnit.count().unitDivided(by: .minute())
    }

    private static func localizedWorkoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking:
            return TL(pl: "Spacer", en: "Walking", uk: "Ходьба", ru: "Ходьба", es: "Caminar")
        case .running:
            return TL(pl: "Bieganie", en: "Running", uk: "Біг", ru: "Бег", es: "Correr")
        case .cycling:
            return TL(pl: "Rower", en: "Cycling", uk: "Велосипед", ru: "Велосипед", es: "Ciclismo")
        case .swimming:
            return TL(pl: "Pływanie", en: "Swimming", uk: "Плавання", ru: "Плавание", es: "Natación")
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return TL(
                pl: "Trening siłowy", en: "Strength training", uk: "Силове тренування",
                ru: "Силовая тренировка", es: "Fuerza")
        case .yoga:
            return TL(pl: "Joga", en: "Yoga", uk: "Йога", ru: "Йога", es: "Yoga")
        case .pilates:
            return TL(pl: "Pilates", en: "Pilates", uk: "Пілатес", ru: "Пилатес", es: "Pilates")
        case .soccer:
            return TL(pl: "Piłka nożna", en: "Football", uk: "Футбол", ru: "Футбол", es: "Fútbol")
        case .basketball:
            return TL(pl: "Koszykówka", en: "Basketball", uk: "Баскетбол", ru: "Баскетбол", es: "Baloncesto")
        case .tennis:
            return TL(pl: "Tenis", en: "Tennis", uk: "Теніс", ru: "Теннис", es: "Tenis")
        default:
            return TL(pl: "Trening", en: "Workout", uk: "Тренування", ru: "Тренировка", es: "Entrenamiento")
        }
    }
}
