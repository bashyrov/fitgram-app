import XCTest

@testable import Mealgram

final class LeaderboardTests: XCTestCase {
    private func profile(id: String, name: String, streak: Int?) -> PublicProfile {
        PublicProfile(
            id: id,
            displayName: name,
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: streak,
            achievementCount: nil
        )
    }

    func testEntriesSortedByStreakDesc() {
        let entries = Leaderboard.from(
            friends: [
                profile(id: "a", name: "Anna", streak: 3),
                profile(id: "b", name: "Bartek", streak: 10),
                profile(id: "c", name: "Cyryl", streak: 1),
            ],
            you: nil
        )
        XCTAssertEqual(entries.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(entries.map(\.rank), [1, 2, 3])
    }

    func testTiesShareTheSameRank() {
        let entries = Leaderboard.from(
            friends: [
                profile(id: "a", name: "Anna", streak: 10),
                profile(id: "b", name: "Bartek", streak: 10),
                profile(id: "c", name: "Cyryl", streak: 5),
            ],
            you: nil
        )
        XCTAssertEqual(entries.map(\.rank), [1, 1, 3])
    }

    func testYouRowMixedIntoRanking() {
        let entries = Leaderboard.from(
            friends: [
                profile(id: "a", name: "Anna", streak: 12),
                profile(id: "b", name: "Bartek", streak: 4),
            ],
            you: .init(id: "me", displayName: "Ola", streak: 7)
        )
        XCTAssertEqual(entries.map(\.id), ["a", "me", "b"])
        let yourEntry = entries.first { $0.isYou }
        XCTAssertEqual(yourEntry?.rank, 2)
    }

    func testFriendsWithoutStreakDataDefaultToZero() {
        let entries = Leaderboard.from(
            friends: [
                profile(id: "a", name: "Anna", streak: nil),
                profile(id: "b", name: "Bartek", streak: 1),
            ],
            you: nil
        )
        XCTAssertEqual(entries.first?.id, "b")
    }

    func testEmptyListIsEmpty() {
        let entries = Leaderboard.from(friends: [], you: nil)
        XCTAssertTrue(entries.isEmpty)
    }

    func testNameTiebreakerForEqualStreaks() {
        let entries = Leaderboard.from(
            friends: [
                profile(id: "z", name: "Zofia", streak: 5),
                profile(id: "a", name: "Anna", streak: 5),
            ],
            you: nil
        )
        XCTAssertEqual(entries.map(\.id), ["a", "z"])
    }
}
