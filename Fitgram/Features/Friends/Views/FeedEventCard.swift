import SwiftUI

/// A single friend-activity card. Reactions are only positive — heart /
/// clap / flame / sparkles — and there are no comments. The master prompt
/// is explicit: never expose a path that could surface negativity.
struct FeedEventCard: View {
    let event: FeedEvent
    let onReact: (ReactionKind) -> Void

    private var relative: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.unitsStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                FriendInitialAvatar(name: event.actorDisplayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.actorDisplayName)
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(event.payload)
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(relative.localizedString(for: event.createdAt, relativeTo: Date()))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            reactionsRow
        }
        .monoCard(padding: 16)
    }

    private var reactionsRow: some View {
        HStack(spacing: 6) {
            ForEach(ReactionKind.allCases) { kind in
                let count = event.reactions[kind] ?? 0
                let selected = event.myReaction == kind
                Button {
                    onReact(kind)
                } label: {
                    HStack(spacing: 4) {
                        Text(kind.emoji)
                            .font(.system(size: 14))
                        if count > 0 {
                            Text("\(count)")
                                .font(Tokens.Font.manrope(12, weight: 800))
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule().fill(selected ? Tokens.Mono.track : Color.clear))
                    .overlay(
                        Capsule().stroke(selected ? Tokens.Mono.hero : Tokens.Mono.line2, lineWidth: 1)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text(kind.label))
                .accessibilityValue(Text(count == 0 ? "0" : "\(count)"))
            }
            Spacer(minLength: 0)
        }
    }

    private var initial: String {
        event.actorDisplayName.first.map { String($0).uppercased() } ?? "?"
    }

    private var iconTint: Color {
        switch event.kind {
        case .streakMilestone: return Tokens.Palette.warning
        case .achievementEarned: return Tokens.Palette.accent
        case .recipeCooked: return Tokens.Palette.primary
        case .challengeWon: return Tokens.Palette.success
        case .joined: return Tokens.Palette.primary
        }
    }

    private var symbol: String {
        switch event.kind {
        case .streakMilestone: return "flame.fill"
        case .achievementEarned: return "trophy.fill"
        case .recipeCooked: return "fork.knife"
        case .challengeWon: return "rosette"
        case .joined: return "person.crop.circle.badge.plus"
        }
    }
}
