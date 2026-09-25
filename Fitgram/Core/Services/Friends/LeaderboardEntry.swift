import Foundation

/// One row in the streak leaderboard. Built by `Leaderboard.from(...)`
/// — pure value type so the view doesn't compute rank itself.
struct LeaderboardEntry: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let avatarURL: URL?
    let streak: Int
    let rank: Int
    let isYou: Bool
}

enum Leaderboard {
    /// Lightweight intermediate type so the merging helper stays a single
    /// function. Promotes `currentStreak ?? 0` once and carries the
    /// "is this me" flag through ranking.
    struct Candidate: Sendable {
        let id: String
        let name: String
        let streak: Int
        let avatar: URL?
        let isYou: Bool
    }

    struct You: Sendable {
        let id: String
        let displayName: String
        let streak: Int
    }

    /// Returns entries sorted by streak desc, then displayName asc as the
    /// tiebreaker. Ties share the same rank ("standard competition"
    /// ranking — friends with equal streak get the same medal).
    static func from(friends: [PublicProfile], you: You?) -> [LeaderboardEntry] {
        var rows: [Candidate] = friends.map {
            Candidate(
                id: $0.id, name: $0.displayName,
                streak: $0.currentStreak ?? 0,
                avatar: $0.avatarURL, isYou: false
            )
        }
        if let you {
            rows.append(
                Candidate(
                    id: you.id, name: you.displayName,
                    streak: you.streak, avatar: nil, isYou: true
                )
            )
        }
        rows.sort {
            if $0.streak != $1.streak { return $0.streak > $1.streak }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        var entries: [LeaderboardEntry] = []
        var previousStreak = -1
        var previousRank = 0
        for (index, row) in rows.enumerated() {
            let rank = (row.streak == previousStreak) ? previousRank : index + 1
            entries.append(
                LeaderboardEntry(
                    id: row.id,
                    displayName: row.name,
                    avatarURL: row.avatar,
                    streak: row.streak,
                    rank: rank,
                    isYou: row.isYou
                )
            )
            previousStreak = row.streak
            previousRank = rank
        }
        return entries
    }
}
