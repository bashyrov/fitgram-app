import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class CoachMemoryStoreTests: XCTestCase {
    private var controller: PersistenceController!
    private var store: CoachMemoryStore!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        store = CoachMemoryStore(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        store = nil
    }

    func testRecordPersistsNote() throws {
        try store.record(
            forUser: "u",
            summary: "Lubi twaróg",
            kind: .preference,
            confidence: 0.7
        )
        let notes = store.notes(forUser: "u")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].summary, "Lubi twaróg")
        XCTAssertEqual(notes[0].kind, .preference)
    }

    func testRecordIsCaseInsensitiveUpsert() throws {
        try store.record(forUser: "u", summary: "Trenuje siłowo", kind: .observation, confidence: 0.4)
        try store.record(forUser: "u", summary: "trenuje siłowo", kind: .observation, confidence: 0.8)
        let notes = store.notes(forUser: "u")
        XCTAssertEqual(notes.count, 1, "Case-only duplicate should upsert")
        // Confidence averages 0.4 + 0.8 → 0.6
        XCTAssertEqual(notes[0].confidence, 0.6, accuracy: 0.001)
    }

    func testNotesFilteredByKind() throws {
        try store.record(forUser: "u", summary: "Cel: 70 kg", kind: .goal)
        try store.record(forUser: "u", summary: "Nie lubi ryb", kind: .preference)
        try store.record(forUser: "u", summary: "Schudł 5 kg", kind: .milestone)
        XCTAssertEqual(store.notes(forUser: "u", kind: .goal).count, 1)
        XCTAssertEqual(store.notes(forUser: "u", kind: .preference).count, 1)
        XCTAssertEqual(store.notes(forUser: "u", kind: .milestone).count, 1)
    }

    func testEmptySummaryThrows() {
        XCTAssertThrowsError(
            try store.record(forUser: "u", summary: "   ", kind: .observation)
        )
    }

    func testNotesSegregatedPerUser() throws {
        try store.record(forUser: "a", summary: "user a only", kind: .observation)
        try store.record(forUser: "b", summary: "user b only", kind: .observation)
        XCTAssertEqual(store.notes(forUser: "a").count, 1)
        XCTAssertEqual(store.notes(forUser: "b").count, 1)
    }
}
