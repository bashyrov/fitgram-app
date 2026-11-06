import SwiftData
import XCTest

@testable import Fitgram

/// In-memory stand-in for `public.user_records`.
private actor FakeSyncServer: CloudSyncTransport {
    private var rows: [String: RemoteRecord] = [:]
    private var clock = 0
    private(set) var upsertedCount = 0

    func fetchChanges(owner: String, after cursor: String?, limit: Int) async throws -> [RemoteRecord] {
        let changed = rows.values
            .filter { cursor == nil || $0.updatedAt > (cursor ?? "") }
            .sorted { $0.updatedAt < $1.updatedAt }
        return Array(changed.prefix(limit))
    }

    func upsert(_ records: [UploadRecord]) async throws {
        for record in records {
            clock += 1
            rows["\(record.kind)/\(record.id)"] = RemoteRecord(
                kind: record.kind, id: record.id, payload: record.payload, deleted: record.deleted,
                updatedAt: String(format: "%08d", clock))
        }
        upsertedCount += records.count
    }

    func resetCount() { upsertedCount = 0 }
}

@MainActor
final class CloudSyncServiceTests: XCTestCase {
    private let owner = "user-1"
    private var directories: [URL] = []

    override func setUp() {
        super.setUp()
        AccountScope.activate(owner)
    }

    override func tearDown() {
        AccountScope.activate(nil)
        directories.forEach { try? FileManager.default.removeItem(at: $0) }
        super.tearDown()
    }

    private func makeDevice(server: FakeSyncServer) throws -> (CloudSyncService, ModelContainer) {
        let container = try PersistenceController.makeInMemory().container
        let directory = FileManager.default.temporaryDirectory.appending(path: "sync-\(UUID().uuidString)")
        directories.append(directory)
        let service = CloudSyncService(
            container: container, stateStore: CloudSyncStateStore(directory: directory), makeTransport: { server })
        return (service, container)
    }

    func testNewDeviceGetsHistoryAndEditsAndDeletesFlowBack() async throws {
        let server = FakeSyncServer()
        let (phoneA, storeA) = try makeDevice(server: server)
        let contextA = ModelContext(storeA)
        let user = User(remoteID: owner, displayName: "Ola")
        user.onboardingCompletedAt = Date(timeIntervalSince1970: 1_700_000_000)
        contextA.insert(user)
        let meal = MealEntry(
            mealType: .lunch, source: .manual,
            items: [FoodItem(name: "Pierogi", quantityGrams: 200, caloriesKcal: 400, proteinGrams: 12)])
        contextA.insert(meal)
        contextA.insert(WeightEntry(userRemoteID: owner, weightKg: 72.5))
        contextA.insert(Recipe(title: "Bigos", ingredients: [RecipeIngredient(name: "Kapusta")]))
        contextA.insert(Achievement(userRemoteID: owner, kind: "meal.first", title: "Pierwszy", details: ""))
        try contextA.save()
        await phoneA.sync(owner: owner)

        // A fresh install of the same account.
        let (phoneB, storeB) = try makeDevice(server: server)
        await phoneB.sync(owner: owner)
        let contextB = ModelContext(storeB)
        let users = try contextB.fetch(FetchDescriptor<User>())
        XCTAssertEqual(users.map(\.displayName), ["Ola"])
        XCTAssertNotNil(users.first?.onboardingCompletedAt)
        let meals = try contextB.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(meals.map(\.id), [meal.id])
        XCTAssertEqual(meals.first?.userRemoteID, owner)
        XCTAssertEqual(meals.first?.items.map(\.name), ["Pierogi"])
        XCTAssertEqual(try contextB.fetch(FetchDescriptor<WeightEntry>()).map(\.weightKg), [72.5])
        XCTAssertEqual(try contextB.fetch(FetchDescriptor<Recipe>()).first?.ingredients.map(\.name), ["Kapusta"])
        XCTAssertEqual(try contextB.fetch(FetchDescriptor<Achievement>()).map(\.kind), ["meal.first"])

        // Nothing changed: a second pass uploads nothing.
        await server.resetCount()
        await phoneB.sync(owner: owner)
        let reuploaded = await server.upsertedCount
        XCTAssertEqual(reuploaded, 0)

        // Edit a meal and delete the weight on B; A follows.
        meals.first?.notes = "z cebulką"
        try contextB.fetch(FetchDescriptor<WeightEntry>()).forEach(contextB.delete)
        try contextB.save()
        await phoneB.sync(owner: owner)
        await phoneA.sync(owner: owner)

        let check = ModelContext(storeA)
        XCTAssertEqual(try check.fetch(FetchDescriptor<MealEntry>()).first?.notes, "z cebulką")
        XCTAssertTrue(try check.fetch(FetchDescriptor<WeightEntry>()).isEmpty)
        XCTAssertEqual(try check.fetch(FetchDescriptor<MealEntry>()).first?.items.count, 1)
    }

    func testOtherAccountsRowsAreNotUploaded() async throws {
        let server = FakeSyncServer()
        let (phone, store) = try makeDevice(server: server)
        let context = ModelContext(store)
        context.insert(WaterEntry(userRemoteID: "someone-else", milliliters: 300))
        context.insert(WaterEntry(userRemoteID: owner, milliliters: 250))
        try context.save()

        await phone.sync(owner: owner)

        let rows = try await server.fetchChanges(owner: owner, after: nil, limit: 100)
        XCTAssertEqual(rows.filter { $0.kind == WaterRecord.kind }.count, 1)
        XCTAssertTrue(rows.allSatisfy { $0.payload.contains("300") == false })
    }
}
