import SwiftUI

struct FriendHighlight: Identifiable {
    let id: String
    let profileID: String
    let title: String
    let value: String
    let caption: String
    let symbol: String
    let tint: Color
}

struct FriendHighlightCard: View {
    let highlight: FriendHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonoIconBox(systemName: highlight.symbol, style: .track, size: 34)
                Spacer(minLength: 0)
                MonoChevron()
            }
            Text(highlight.title)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(highlight.value)
                    .font(Tokens.Font.monoNumber(24))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                MonoLabel(text: highlight.caption)
            }
        }
        .frame(width: 140, alignment: .topLeading)
        .monoTile()
        .fixedSize(horizontal: true, vertical: false)
    }
}

extension FeedEventKind {
    var highlightValue: String {
        switch self {
        case .streakMilestone: return L("Seria")
        case .achievementEarned: return L("Odznaka")
        case .recipeCooked: return L("Przepis")
        case .challengeWon: return L("Challenge")
        case .joined: return L("Nowy")
        }
    }

    var highlightSymbol: String {
        switch self {
        case .streakMilestone: return "flame.fill"
        case .achievementEarned: return "trophy.fill"
        case .recipeCooked: return "fork.knife"
        case .challengeWon: return "rosette"
        case .joined: return "person.crop.circle.badge.plus"
        }
    }

    var highlightTint: Color {
        switch self {
        case .streakMilestone: return Tokens.Palette.primary
        case .achievementEarned: return Tokens.Palette.accent
        case .recipeCooked: return Tokens.Palette.primary
        case .challengeWon: return Tokens.Palette.success
        case .joined: return Tokens.Palette.primary
        }
    }
}
