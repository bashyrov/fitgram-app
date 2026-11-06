import SwiftData
import XCTest

@testable import Fitgram

@MainActor
final class SharedProfileBuilderTests: XCTestCase {
    private let owner = "owner-1"

    private func makeStore() throws -> ModelContainer {
        let container = try PersistenceController.makeInMemory().container
        let context = ModelContext(container)
        let user = User(remoteID: owner, goalKind: .lose)
        user.heightCm = 170
        user.goalTargetWeightKg = 60
        user.goalStartWeightKg = 65
        context.insert(user)
        context.insert(Streak(userRemoteID: owner, currentLength: 12))
        context.insert(Achievement(userRemoteID: owner, kind: "meal.first", title: "", details: ""))
        context.insert(WeightEntry(userRemoteID: owner, weightKg: 64.2))
        context.insert(Streak(userRemoteID: "someone-else", currentLength: 99))
        try context.save()
        return container
    }

    func testPrivateProfileSharesNothing() throws {
        var privacy = PrivacySettings()
        privacy.showStreak = true
        XCTAssertNil(SharedProfileBuilder.build(owner: owner, privacy: privacy, container: try makeStore()))
    }

    func testOnlySwitchedOnFieldsLeaveTheDevice() throws {
        var privacy = PrivacySettings()
        privacy.visibility = .friendsOnly
        privacy.showStreak = true
        privacy.showLevel = true

        let shared = try XCTUnwrap(
            SharedProfileBuilder.build(owner: owner, privacy: privacy, container: try makeStore()))

        XCTAssertEqual(shared.streak, 12)
        XCTAssertEqual(shared.level, 1)
        XCTAssertNil(shared.achievementKinds)
        XCTAssertNil(shared.goal)
        XCTAssertNil(shared.weekly)
        XCTAssertNil(shared.recipes)
        XCTAssertNil(shared.weightKg)
        XCTAssertNil(shared.heightCm)
    }

    func testEverythingSwitchedOn() throws {
        var privacy = PrivacySettings()
        privacy.visibility = .publicLink
        privacy.showAchievements = true
        privacy.showGoal = true
        privacy.showWeeklyStats = true
        privacy.showRecipes = true
        privacy.showWeightAndHeight = true

        let shared = try XCTUnwrap(
            SharedProfileBuilder.build(owner: owner, privacy: privacy, container: try makeStore()))

        XCTAssertEqual(shared.achievementKinds, ["meal.first"])
        XCTAssertEqual(shared.goal?.kind, GoalKind.lose.rawValue)
        XCTAssertNotNil(shared.weekly)
        XCTAssertEqual(shared.recipes, [])
        XCTAssertEqual(shared.weightKg, 64.2)
        XCTAssertEqual(shared.heightCm, 170)
        let data = try SharedProfile.coder.encoder.encode(shared)
        XCTAssertEqual(try SharedProfile.coder.decoder.decode(SharedProfile.self, from: data), shared)
    }
}
