import SwiftUI
import UIKit

/// 1080×1920 story card for an unlocked achievement, in the same look as
/// `StreakShareCard`: graphite backdrop with a warm glow, glowing medallion,
/// no user name. Card chrome is English; the badge title stays in the
/// user's language because it names their badge.
struct AchievementShareCard: View {
    let definition: AchievementDefinition
    let earnedAt: Date?

    private enum Palette {
        static let graphite = Color(red: 0.09, green: 0.10, blue: 0.11)
        static let graphiteTop = Color(red: 0.14, green: 0.15, blue: 0.17)
        static let flame = Color(red: 0.94, green: 0.54, blue: 0.27)
        static let gold = Color(red: 1.0, green: 0.78, blue: 0.38)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.graphiteTop, Palette.graphite], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Palette.flame.opacity(0.5), Palette.flame.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: 820
            )
            VStack(spacing: 0) {
                HStack {
                    Text(verbatim: "FITGRAM")
                        .font(Tokens.Font.archivo(size: 64, weight: 900, width: 122, italic: true))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .heavy))
                        Text(verbatim: "UNLOCKED")
                            .font(Tokens.Font.manrope(34, weight: 800))
                            .tracking(3)
                    }
                    .foregroundStyle(Palette.graphite)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(Palette.gold))
                }
                Spacer(minLength: 0)
                AchievementMedallion(definition: definition, isEarned: true, size: 420, showsLock: false)
                    .shadow(color: Palette.flame.opacity(0.6), radius: 70)
                Text(verbatim: "ACHIEVEMENT")
                    .font(Tokens.Font.manrope(38, weight: 800))
                    .tracking(8)
                    .foregroundStyle(Palette.flame)
                    .padding(.top, 90)
                Text(definition.title)
                    .font(Tokens.Font.archivo(size: 104, weight: 900, width: 122, italic: true))
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 20)
                Text(definition.summary)
                    .font(Tokens.Font.manrope(40, weight: 600))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.top, 28)
                    .padding(.horizontal, 40)
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline) {
                    if let earnedAt {
                        Text(verbatim: "EARNED \(Self.dateFormatter.string(from: earnedAt).uppercased())")
                            .font(Tokens.Font.manrope(34, weight: 800))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(verbatim: "fitgram.space")
                        .font(Tokens.Font.manrope(36, weight: 800))
                        .foregroundStyle(Palette.flame)
                }
            }
            .padding(.horizontal, 96)
            .padding(.vertical, 120)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
}

extension AchievementShareCard {
    @MainActor
    static func render(definition: AchievementDefinition, earnedAt: Date?) -> UIImage? {
        let renderer = ImageRenderer(content: AchievementShareCard(definition: definition, earnedAt: earnedAt))
        renderer.scale = 1
        return renderer.uiImage
    }
}
