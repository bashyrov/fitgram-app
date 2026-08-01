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
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.actorDisplayName)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(Self.relative.localizedString(for: event.createdAt, relativeTo: Date()))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
                Spacer(minLength: 0)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconTint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(iconTint.opacity(0.13)))
            }
            Text(LocalizedStringKey(event.payload))
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            reactionsRow
        }
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.80)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 16, y: 10)
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
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(selected ? Tokens.Palette.primarySoft : Tokens.Palette.surface.opacity(0.82))
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

    private var avatar: some View {
        Text(initial)
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .shadow(color: Tokens.Palette.primary.opacity(0.18), radius: 10, y: 5)
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
