import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class HealthImporterTests: XCTestCase {
    private var controller: PersistenceController!
    private var weightService: WeightService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        weightService = WeightService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        weightService = nil
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
}

@MainActor
private final class StubHealth: HealthKitWeightImporter {
    let isHealthDataAvailable: Bool
    let authorize: () -> Bool
    let samples: (Int) throws -> [HealthKitService.WeightSample]

    init(
        isAvailable: Bool,
        authorize: @escaping () -> Bool = { true },
        samples: @escaping (Int) throws -> [HealthKitService.WeightSample] = { _ in [] }
    ) {
        self.isHealthDataAvailable = isAvailable
        self.authorize = authorize
        self.samples = samples
    }

    func requestAuthorization() async throws -> Bool { authorize() }
    func recentWeightSamples(limit: Int) async throws -> [HealthKitService.WeightSample] {
        try samples(limit)
    }
}
