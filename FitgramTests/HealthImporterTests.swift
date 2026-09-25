import SwiftData
import XCTest

@testable import Fitgram

@MainActor
final class HealthImporterTests: XCTestCase {
    private var controller: PersistenceController!
    private var weightService: WeightService!
    private var workoutService: WorkoutService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        weightService = WeightService(container: controller.container)
        workoutService = WorkoutService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        weightService = nil
        workoutService = nil
    }

    func testUnavailableHealthReturnsUnavailable() async {
        let stub = StubHealth(isAvailable: false)
        let importer = HealthImporter(health: stub, weightService: weightService)
        let result = await importer.runImport(for: "u")
        XCTAssertEqual(result, .unavailable)
    }

    func testDeniedAuthorizationReturnsDenied() async {
        let stub = StubHealth(isAvailable: true, authorize: { false })
        let importer = HealthImporter(health: stub, weightService: weightService)
        let result = await importer.runImport(for: "u")
        XCTAssertEqual(result, .denied)
    }

    func testImportSkipsExistingSamplesByMinute() async throws {
        let sample = HealthKitService.WeightSample(
            kilograms: 72.0,
            recordedAt: Date(timeIntervalSince1970: 1_700_000_030)
        )
        let stub = StubHealth(isAvailable: true, authorize: { true }, samples: { _ in [sample] })
        let importer = HealthImporter(health: stub, weightService: weightService)

        // First run inserts the sample.
        let first = await importer.runImport(for: "u")
        XCTAssertEqual(first, .imported(count: 1))

        // Second run with the same data deduplicates by minute.
        let second = await importer.runImport(for: "u")
        XCTAssertEqual(second, .noNewSamples)
    }

    func testMinuteAlignmentNormalisesTimestamps() {
        // 1_700_000_010 and 1_700_000_030 fall in the same minute bucket
        // ([1_699_999_980, 1_700_000_040)). 1_700_000_058 jumps to the next.
        let lhs = HealthImporter.minuteAligned(Date(timeIntervalSince1970: 1_700_000_010))
        let rhs = HealthImporter.minuteAligned(Date(timeIntervalSince1970: 1_700_000_030))
        let next = HealthImporter.minuteAligned(Date(timeIntervalSince1970: 1_700_000_058))
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, next)
    }

    func testImportFailureSurfacesReason() async {
        struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }
        let stub = StubHealth(
            isAvailable: true,
            authorize: { true },
            samples: { _ in throw Boom() }
        )
        let importer = HealthImporter(health: stub, weightService: weightService)
        let result = await importer.runImport(for: "u")
        if case .failed(let reason) = result {
            XCTAssertTrue(reason.contains("boom"))
        } else {
            XCTFail("Expected .failed, got \(result)")
        }
    }

    func testWorkoutImportDeduplicatesHealthSamples() async throws {
        let id = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let sample = HealthKitService.WorkoutSample(
            id: id,
            activityType: 37,
            activityName: "Running",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_001_800),
            durationMinutes: 30,
            caloriesBurnedKcal: 310,
            distanceMeters: 5_000,
            sourceName: "Apple Watch"
        )
        let stub = StubHealth(isAvailable: true, authorize: { true }, workoutSamples: { _, _ in [sample] })
        let importer = HealthWorkoutImporter(health: stub, workoutService: workoutService)

        let first = await importer.importRecentDays(for: "u", days: 1, now: sample.startedAt)
        XCTAssertEqual(first, .imported(count: 1))

        let second = await importer.importRecentDays(for: "u", days: 1, now: sample.startedAt)
        XCTAssertEqual(second, .noNewSamples)

        let workouts = try workoutService.workouts(for: "u", on: sample.startedAt)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.source, .appleHealth)
        XCTAssertEqual(workouts.first?.caloriesBurnedKcal, 310)
    }

    func testWorkoutImportAddsActiveEnergyRemainder() async throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let stub = StubHealth(
            isAvailable: true,
            authorize: { true },
            activeEnergy: { _, _ in 180 }
        )
        let importer = HealthWorkoutImporter(health: stub, workoutService: workoutService)

        let result = await importer.importRecentDays(for: "u", days: 1, now: day)
        XCTAssertEqual(result, .imported(count: 1))

        let workouts = try workoutService.workouts(for: "u", on: day)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.activityID, WorkoutService.appleHealthActiveEnergyActivityID(for: day))
        XCTAssertEqual(workouts.first?.caloriesBurnedKcal, 180)
    }

    func testWorkoutImportEstimatesMovementFromStepsWhenActiveEnergyIsEmpty() async throws {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let user = User(remoteID: "u", email: "u@test.com")
        user.weightKg = 80
        controller.container.mainContext.insert(user)
        try controller.container.mainContext.save()

        let stub = StubHealth(
            isAvailable: true,
            authorize: { true },
            movement: { _, _ in
                HealthKitService.MovementSummary(
                    activeEnergyKcal: 0,
                    steps: 8_000,
                    walkingRunningDistanceMeters: 6_000
                )
            }
        )
        let importer = HealthWorkoutImporter(health: stub, workoutService: workoutService)

        let result = await importer.importRecentDays(for: "u", days: 1, now: day)
        XCTAssertEqual(result, .imported(count: 1))

        let workouts = try workoutService.workouts(for: "u", on: day)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.activityID, WorkoutService.appleHealthActiveEnergyActivityID(for: day))
        XCTAssertEqual(workouts.first?.caloriesBurnedKcal ?? 0, 264, accuracy: 0.5)
    }

    func testDeleteWorkoutRemovesManualActivity() async throws {
        let item = WorkoutCatalogItem(
            id: "walk.easy",
            met: 3.0,
            symbol: "figure.walk",
            names: [:]
        )
        let workout = try workoutService.log(
            item: item,
            durationMinutes: 30,
            weightKg: 80,
            manualCalories: nil,
            userRemoteID: "u"
        )

        try workoutService.deleteWorkout(id: workout.id, userRemoteID: "u")

        let workouts = try workoutService.workouts(for: "u", on: workout.recordedAt)
        XCTAssertTrue(workouts.isEmpty)
    }
}

@MainActor
private final class StubHealth: HealthKitWeightImporter {
    let isHealthDataAvailable: Bool
    let authorize: () -> Bool
    let samples: (Int) throws -> [HealthKitService.WeightSample]
    let activeEnergy: (Date, Date) throws -> Double
    let movement: (Date, Date) throws -> HealthKitService.MovementSummary
    let workoutSamples: (Date, Date) throws -> [HealthKitService.WorkoutSample]

    init(
        isAvailable: Bool,
        authorize: @escaping () -> Bool = { true },
        samples: @escaping (Int) throws -> [HealthKitService.WeightSample] = { _ in [] },
        activeEnergy: @escaping (Date, Date) throws -> Double = { _, _ in 0 },
        movement: ((Date, Date) throws -> HealthKitService.MovementSummary)? = nil,
        workoutSamples: @escaping (Date, Date) throws -> [HealthKitService.WorkoutSample] = { _, _ in [] }
    ) {
        self.isHealthDataAvailable = isAvailable
        self.authorize = authorize
        self.samples = samples
        self.activeEnergy = activeEnergy
        self.movement =
            movement
            ?? { startDate, endDate in
                HealthKitService.MovementSummary(
                    activeEnergyKcal: try activeEnergy(startDate, endDate),
                    steps: 0,
                    walkingRunningDistanceMeters: 0
                )
            }
        self.workoutSamples = workoutSamples
    }

    func requestAuthorization() async throws -> Bool { authorize() }
    func recentWeightSamples(limit: Int) async throws -> [HealthKitService.WeightSample] {
        try samples(limit)
    }
    func activeEnergyBurned(from startDate: Date, to endDate: Date) async throws -> Double {
        try activeEnergy(startDate, endDate)
    }
    func movementSummary(from startDate: Date, to endDate: Date) async throws -> HealthKitService.MovementSummary {
        try movement(startDate, endDate)
    }
    func workoutSamples(from startDate: Date, to endDate: Date) async throws -> [HealthKitService.WorkoutSample] {
        try workoutSamples(startDate, endDate)
    }
}
