import SwiftUI

/// "Aktywność" tab — vertical timeline of recent feed events. Each row
/// has a timestamp gutter, gradient icon chip, and an event card with
/// a tinted "kind" caption above the human-readable payload.
extension FriendProfileView {
    @ViewBuilder
    func activityTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let events = snapshot.recentEvents, !events.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                    timelineRow(event, isFirst: idx == 0, isLast: idx == events.count - 1)
                }
            }
            .padding(.horizontal, 2)
        } else {
            placeholder(
                symbol: "bolt.fill",
                title: "Spokojnie tutaj",
                subtitle: "Brak ostatniej aktywności do pokazania."
            )
        }
    }

    func timelineRow(_ event: FeedEvent, isFirst: Bool, isLast: Bool) -> some View {
        let tint = eventTint(event.kind)
        return HStack(alignment: .top, spacing: Tokens.Space.md) {
            Text(event.createdAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 64, alignment: .trailing)
                .padding(.top, 14)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Tokens.Palette.separator)
                    .frame(width: 2, height: 14)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: tint.opacity(0.35), radius: 6, y: 2)
                    Image(systemName: eventSymbol(event.kind))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Rectangle()
                    .fill(isLast ? Color.clear : Tokens.Palette.separator)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(eventTitle(event.kind))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(LocalizedStringKey(event.payload))
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82))
            )
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
            .shadow(color: tint.opacity(0.08), radius: 14, y: 8)
            .padding(.bottom, Tokens.Space.md)
            .padding(.top, Tokens.Space.xs)
        }
    }

    func eventTint(_ kind: FeedEventKind) -> Color {
        switch kind {
        case .streakMilestone: return Tokens.Palette.warning
        case .achievementEarned: return Tokens.Palette.accent
        case .recipeCooked: return Tokens.Palette.success
        case .challengeWon: return Tokens.Palette.primary
        case .joined: return Tokens.Palette.inkMuted
        }
    }

    func eventSymbol(_ kind: FeedEventKind) -> String {
        switch kind {
        case .streakMilestone: return "flame.fill"
        case .achievementEarned: return "rosette"
        case .recipeCooked: return "book.closed.fill"
        case .challengeWon: return "trophy.fill"
        case .joined: return "person.crop.circle.badge.checkmark"
        }
    }

    func eventTitle(_ kind: FeedEventKind) -> LocalizedStringKey {
        switch kind {
        case .streakMilestone: return "Seria"
        case .achievementEarned: return "Odznaka"
        case .recipeCooked: return "Przepis"
        case .challengeWon: return "Wyzwanie"
        case .joined: return "Dołączenie"
        }
    }
}
