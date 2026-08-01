import XCTest

@testable import Mealgram

@MainActor
final class InMemoryFriendServiceTests: XCTestCase {
    private let me = "debug-user-001"

    func testSeedHasThreeFriendsAndOnePending() async throws {
        let service = InMemoryFriendService()

        let friends = try await service.friends(of: me)
        XCTAssertEqual(friends.count, 3)
        XCTAssertEqual(friends.map(\.displayName).sorted(), ["Kasia", "Michał", "Ola"])

        let incoming = try await service.pendingIncoming(for: me)
        XCTAssertEqual(incoming.count, 1)
        XCTAssertEqual(incoming.first?.fromUserID, "friend-nina")
    }

    func testAcceptMovesPendingIntoFriendsList() async throws {
        let service = InMemoryFriendService()
        let pending = try await service.pendingIncoming(for: me).first.unwrap()

        try await service.accept(request: pending, as: me)

        let friends = try await service.friends(of: me)
        XCTAssertTrue(friends.contains(where: { $0.id == "friend-nina" }))
        let remaining = try await service.pendingIncoming(for: me)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRejectRemovesFromPendingWithoutAddingFriendship() async throws {
        let service = InMemoryFriendService()
        let pending = try await service.pendingIncoming(for: me).first.unwrap()

        try await service.reject(request: pending, as: me)

        let friends = try await service.friends(of: me)
        XCTAssertFalse(friends.contains(where: { $0.id == "friend-nina" }))
        let remaining = try await service.pendingIncoming(for: me)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testSearchByNameIsCaseInsensitive() async throws {
        let service = InMemoryFriendService()

        let lower = try await service.search(query: "kas", excluding: me)
        XCTAssertEqual(lower.map(\.id), ["friend-kasia"])

        let upper = try await service.search(query: "OLA", excluding: me)
        XCTAssertEqual(upper.map(\.id), ["friend-ola"])

        let empty = try await service.search(query: "   ", excluding: me)
        XCTAssertTrue(empty.isEmpty)
    }

    func testSendRequestRejectsIfAlreadyFriends() async throws {
        let service = InMemoryFriendService()

        do {
            _ = try await service.sendRequest(from: me, to: "friend-kasia")
            XCTFail("expected alreadyFriends")
        } catch let error as FriendError {
            XCTAssertEqual(error, .alreadyFriends)
        }
    }

    func testSendRequestIsIdempotentOnAlreadyPending() async throws {
        let service = InMemoryFriendService()

        _ = try await service.sendRequest(from: me, to: "friend-nina")
        do {
            _ = try await service.sendRequest(from: me, to: "friend-nina")
            XCTFail("expected alreadyRequested")
        } catch let error as FriendError {
            XCTAssertEqual(error, .alreadyRequested)
        }
    }

    func testReactToggleAddsRemovesAndSwapsKind() async throws {
        let service = InMemoryFriendService()
        let feed = try await service.recentFeed(for: me, limit: 30)
        let target = try feed.first(where: { $0.actorID == "friend-ola" }).unwrap()
        XCTAssertNil(target.myReaction)
        XCTAssertEqual(target.reactions[.heart], 2)

        let liked = try await service.react(to: target, as: me, kind: .heart)
        XCTAssertEqual(liked.myReaction, .heart)
        XCTAssertEqual(liked.reactions[.heart], 3)

        let swapped = try await service.react(to: liked, as: me, kind: .flame)
        XCTAssertEqual(swapped.myReaction, .flame)
        XCTAssertEqual(swapped.reactions[.heart], 2)
        XCTAssertEqual(swapped.reactions[.flame], 1)

        let cleared = try await service.react(to: swapped, as: me, kind: nil)
        XCTAssertNil(cleared.myReaction)
        XCTAssertNil(cleared.reactions[.flame])
    }

    func testUnfriendIsSymmetric() async throws {
        let service = InMemoryFriendService()

        try await service.unfriend("friend-kasia", as: me)

        let mine = try await service.friends(of: me)
        XCTAssertFalse(mine.contains(where: { $0.id == "friend-kasia" }))
        let theirs = try await service.friends(of: "friend-kasia")
        XCTAssertFalse(theirs.contains(where: { $0.id == me }))
    }

    func testFeedOnlyContainsEventsFromCurrentFriends() async throws {
        let service = InMemoryFriendService()
        try await service.unfriend("friend-ola", as: me)

        let feed = try await service.recentFeed(for: me, limit: 30)
        XCTAssertFalse(feed.contains(where: { $0.actorID == "friend-ola" }))
        XCTAssertTrue(feed.contains(where: { $0.actorID == "friend-kasia" }))
    }

    // MARK: - Snapshot + blocks + positive reactions

    func testSnapshotReturnsRichFields() async throws {
        let service = InMemoryFriendService()
        let snap = try await service.snapshot(forUserID: "friend-ola", viewer: me)
        XCTAssertEqual(snap.displayName, "Ola")
        XCTAssertNotNil(snap.currentStreak)
        XCTAssertNotNil(snap.level)
        XCTAssertNotNil(snap.weeklyStats)
        XCTAssertTrue(snap.hasAnyShared)
    }

    func testSnapshotIncludesActivityForOwner() async throws {
        let service = InMemoryFriendService()
        let snap = try await service.snapshot(forUserID: "friend-ola", viewer: me)
        XCTAssertNotNil(snap.recentEvents)
        let events = try XCTUnwrap(snap.recentEvents)
        XCTAssertFalse(events.isEmpty)
    }

    func testBlockHidesSnapshotAndDropsFriendship() async throws {
        let service = InMemoryFriendService()
        try await service.block("friend-ola", as: me)
        do {
            _ = try await service.snapshot(forUserID: "friend-ola", viewer: me)
            XCTFail("Snapshot should fail for blocked user")
        } catch FriendError.notFound { /* expected */  }
        let friends = try await service.friends(of: me)
        XCTAssertFalse(friends.contains { $0.id == "friend-ola" })
    }

    func testBlockedUserIDsRoundtrip() async throws {
        let service = InMemoryFriendService()
        try await service.block("friend-michal", as: me)
        var blocked = try await service.blockedUserIDs(for: me)
        XCTAssertTrue(blocked.contains("friend-michal"))
        try await service.unblock("friend-michal", as: me)
        blocked = try await service.blockedUserIDs(for: me)
        XCTAssertFalse(blocked.contains("friend-michal"))
    }

    func testPositiveReactionDoesNotThrow() async throws {
        let service = InMemoryFriendService()
        try await service.sendPositiveReaction(to: "friend-ola", from: me, intent: .celebrate)
    }

    func testReportDoesNotThrow() async throws {
        let service = InMemoryFriendService()
        try await service.report("friend-ola", reason: "test reason", as: me)
    }
}

@MainActor
final class PrivacyStoreTests: XCTestCase {
    private func makeStore(suffix: String = #function) -> PrivacyStore {
        let suiteName = "PrivacyStoreTests.\(suffix).\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return PrivacyStore(defaults: defaults, storageKey: "privacy.test")
    }

    func testDefaultIsFullyPrivate() {
        let store = makeStore()
        XCTAssertEqual(store.current.visibility, .privateOnly)
        XCTAssertFalse(store.current.showStreak)
        XCTAssertFalse(store.current.showAchievements)
        XCTAssertFalse(store.current.showWeightAndHeight)
        XCTAssertFalse(store.current.showMealDetails)
    }

    func testUpdateMutatesAndPersists() {
        let suiteName = "PrivacyStoreTests.persist.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let first = PrivacyStore(defaults: defaults, storageKey: "privacy.test")
        first.update {
            $0.visibility = .friendsOnly
            $0.showStreak = true
            $0.showAchievements = true
        }
        XCTAssertEqual(first.current.visibility, .friendsOnly)
        XCTAssertTrue(first.current.showStreak)
        let second = PrivacyStore(defaults: defaults, storageKey: "privacy.test")
        XCTAssertEqual(second.current.visibility, .friendsOnly)
        XCTAssertTrue(second.current.showStreak)
        XCTAssertTrue(second.current.showAchievements)
        XCTAssertFalse(second.current.showWeightAndHeight)
    }
}

extension Optional {
    fileprivate func unwrap(file: StaticString = #filePath, line: UInt = #line) throws -> Wrapped {
        try XCTUnwrap(self, file: file, line: line)
    }
}
