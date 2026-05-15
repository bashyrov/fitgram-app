import SwiftUI

/// A single friend-activity card. Reactions are only positive — heart /
/// clap / flame / sparkles — and there are no comments. The master prompt
/// is explicit: never expose a path that could surface negativity.
struct FeedEventCard: View {
    let event: FeedEvent
    let onReact: (ReactionKind) -> Void

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: Tokens.Space.sm) {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(initial)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.primary)
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(event.actorDisplayName)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(Self.relative.localizedString(for: event.createdAt, relativeTo: Date()))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: symbol)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Text(event.payload)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                reactionsRow
            }
        }
    }

    private var reactionsRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach(ReactionKind.allCases) { kind in
                let count = event.reactions[kind] ?? 0
                let selected = event.myReaction == kind
                Button {
                    onReact(kind)
                } label: {
                    HStack(spacing: 4) {
                        Text(kind.emoji)
                        if count > 0 {
                            Text("\(count)")
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.sm)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(selected ? Tokens.Palette.primarySoft : Tokens.Palette.surfaceMuted)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                selected ? Tokens.Palette.primary : .clear,
                                lineWidth: selected ? 1 : 0
                            )
                    )
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
