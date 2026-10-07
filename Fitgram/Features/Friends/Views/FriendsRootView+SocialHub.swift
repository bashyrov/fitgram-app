import SwiftUI

extension FriendsRootView {
    @ViewBuilder
    var friendHighlights: some View {
        let highlights = socialHighlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(number: "04", title: L("Ostatnie zwycięstwa"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(highlights) { highlight in
                            Button {
                                openedProfileID = highlight.profileID
                            } label: {
                                FriendHighlightCard(highlight: highlight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    var socialHighlights: [FriendHighlight] {
        var highlights: [FriendHighlight] = []
        let streakCandidates = state.friends.filter { ($0.currentStreak ?? 0) > 0 && $0.sharesStreak }
        if let streakLeader = streakCandidates.max(by: { ($0.currentStreak ?? 0) < ($1.currentStreak ?? 0) }) {
            highlights.append(
                FriendHighlight(
                    id: "streak-\(streakLeader.id)",
                    profileID: streakLeader.id,
                    title: streakLeader.displayName,
                    value: "\(streakLeader.currentStreak ?? 0)",
                    caption: L("dni serii"),
                    symbol: "flame.fill",
                    tint: Tokens.Palette.primary
                ))
        }
        let badgeCandidates = state.friends.filter { ($0.achievementCount ?? 0) > 0 && $0.sharesAchievements }
        if let badgeLeader = badgeCandidates.max(by: { ($0.achievementCount ?? 0) < ($1.achievementCount ?? 0) }) {
            highlights.append(
                FriendHighlight(
                    id: "badges-\(badgeLeader.id)",
                    profileID: badgeLeader.id,
                    title: badgeLeader.displayName,
                    value: "\(badgeLeader.achievementCount ?? 0)",
                    caption: L("odznak"),
                    symbol: "seal.fill",
                    tint: Tokens.Palette.accent
                ))
        }
        if let newestEvent = state.feed.first {
            highlights.append(
                FriendHighlight(
                    id: "event-\(newestEvent.id.uuidString)",
                    profileID: newestEvent.actorID,
                    title: newestEvent.actorDisplayName,
                    value: newestEvent.kind.highlightValue,
                    caption: L("nowa aktywność"),
                    symbol: newestEvent.kind.highlightSymbol,
                    tint: newestEvent.kind.highlightTint
                ))
        }
        return Array(highlights.prefix(3))
    }
}
