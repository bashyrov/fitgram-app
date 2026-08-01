import SwiftUI

extension FriendsRootView {
    var socialActionHub: some View {
        HStack(spacing: Tokens.Space.sm) {
            socialAction(
                title: "Username",
                subtitle: "Znajdź profil",
                symbol: "at",
                tint: Tokens.Palette.primary
            ) {
                isAddPresented = true
            }
            socialAction(
                title: "QR",
                subtitle: "Pokaż kod",
                symbol: "qrcode.viewfinder",
                tint: Tokens.Palette.accent
            ) {
                isAddPresented = true
            }
            socialAction(
                title: "Ranking",
                subtitle: "Streaki",
                symbol: "trophy.fill",
                tint: Tokens.Palette.warning
            ) {
                isLeaderboardPresented = true
            }
        }
    }

    @ViewBuilder
    var friendHighlights: some View {
        let highlights = socialHighlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionHeader(title: L("Ostatnie zwycięstwa"), symbol: "rosette")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Space.sm) {
                        ForEach(highlights) { highlight in
                            Button {
                                openedProfileID = highlight.profileID
                            } label: {
                                FriendHighlightCard(highlight: highlight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
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

    func socialAction(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.14)))
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(Tokens.Font.caption2)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .padding(Tokens.Space.sm)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }
}
