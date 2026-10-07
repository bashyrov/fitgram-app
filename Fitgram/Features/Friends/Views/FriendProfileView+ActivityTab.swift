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
                    if idx > 0 {
                        MonoRowDivider()
                    }
                    timelineRow(event, isFirst: idx == 0, isLast: idx == events.count - 1)
                }
            }
            .monoRowsCard()
        } else {
            placeholder(
                symbol: "bolt.fill",
                title: L("Spokojnie tutaj"),
                subtitle: L("Brak ostatniej aktywności do pokazania.")
            )
        }
    }

    func timelineRow(_ event: FeedEvent, isFirst: Bool, isLast: Bool) -> some View {
        MonoRow(
            icon: eventSymbol(event.kind),
            iconStyle: .dark,
            title: event.payload,
            sub: "\(eventTitle(event.kind)) · \(event.createdAt.formatted(.relative(presentation: .named)))"
        ) {
            EmptyView()
        }
        .accessibilityElement(children: .combine)
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

    func eventTitle(_ kind: FeedEventKind) -> String {
        switch kind {
        case .streakMilestone: return L("Seria")
        case .achievementEarned: return L("Odznaka")
        case .recipeCooked: return L("Przepis")
        case .challengeWon: return L("Wyzwanie")
        case .joined: return L("Dołączenie")
        }
    }
}
