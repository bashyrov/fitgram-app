import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class CalibrationServiceTests: XCTestCase {
    private var controller: PersistenceController!
    private var service: CalibrationService!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        service = CalibrationService(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        service = nil
    }

    func testCurrentCreatesRowOnFirstAccess() throws {
        let first = try service.current(forUser: "u-1")
        XCTAssertEqual(first.userRemoteID, "u-1")
        XCTAssertEqual(first.portionAdjustmentFactor, 1.0, accuracy: 0.001)
        XCTAssertEqual(first.sampleCount, 0)
        // Second call should resolve to the same row.
        let second = try service.current(forUser: "u-1")
        XCTAssertEqual(first.id, second.id)
    }

    func testUpdateFactorClampsToBounds() throws {
        try service.updateFactor(10, referenceObject: .creditCard, forUser: "u-2")
        let stored = try service.current(forUser: "u-2")
        XCTAssertEqual(stored.portionAdjustmentFactor, CalibrationService.factorBounds.upperBound, accuracy: 0.001)

        try service.updateFactor(-1, referenceObject: .creditCard, forUser: "u-2")
        let lowered = try service.current(forUser: "u-2")
        XCTAssertEqual(lowered.portionAdjustmentFactor, CalibrationService.factorBounds.lowerBound, accuracy: 0.001)
    }

    func testUpdateFactorPersistsReferenceObject() throws {
        try service.updateFactor(1.15, referenceObject: .eatingHand, forUser: "u-3")
        let stored = try service.current(forUser: "u-3")
        XCTAssertEqual(stored.referenceObject, .eatingHand)
        XCTAssertEqual(stored.portionAdjustmentFactor, 1.15, accuracy: 0.001)
    }

    func testRecordSampleIncrements() throws {
        try service.recordSample(forUser: "u-4")
        try service.recordSample(forUser: "u-4")
        XCTAssertEqual(try service.current(forUser: "u-4").sampleCount, 2)
    }

    func testApplyScalesScanResultProportionally() {
        let result = ScanResult(
            items: [
                ScanResult.DetectedItem(
                    name: "X", quantityGrams: 100, caloriesKcal: 200,
                    proteinGrams: 10, carbsGrams: 30, fatGrams: 5, confidence: 0.9
                )
            ],
            suggestedMealType: .snack,
            confidence: 0.9,
            rawAINotes: nil
        )
        let adjusted = service.apply(0.8, to: result)
        XCTAssertEqual(adjusted.items[0].caloriesKcal, 160, accuracy: 0.001)
        XCTAssertEqual(adjusted.items[0].quantityGrams, 80, accuracy: 0.001)
        XCTAssertEqual(adjusted.items[0].proteinGrams, 8, accuracy: 0.001)
    }

    func testApplyWithFactorOneIsIdentity() {
        let result = ScanResult.defaultFixture
        let same = service.apply(1.0, to: result)
        XCTAssertEqual(same, result)
    }
}
