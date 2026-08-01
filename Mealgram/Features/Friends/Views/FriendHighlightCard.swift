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
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Image(systemName: highlight.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(highlight.tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(highlight.tint.opacity(0.14)))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            Text(highlight.title)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(highlight.value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(highlight.caption)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .frame(width: 156, alignment: .topLeading)
        .frame(minHeight: 138, alignment: .topLeading)
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 14, y: 8)
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
