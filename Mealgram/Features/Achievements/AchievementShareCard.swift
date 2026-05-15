import SwiftUI
import UIKit

/// 1080×1920 portrait share card for an unlocked achievement. Mirrors
/// the visual language of StreakShareCard so the user's social feed
/// stays on-brand across both kinds of share.
struct AchievementShareCard: View {
    let definition: AchievementDefinition
    let earnedAt: Date?
    let displayName: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Tokens.Palette.primarySoft,
                    Tokens.Palette.primary.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 48) {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64, weight: .regular))
                        .foregroundStyle(.white)
                    Text("Mealgram")
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 320, height: 320)
                        Image(systemName: definition.symbol)
                            .font(.system(size: 152, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
                    }
                    Text(definition.title)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text(definition.summary)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 6) {
                    if let earnedAt {
                        Text("zdobyte \(Self.dateFormatter.string(from: earnedAt))")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 12)
                    }
                }
                Spacer()
            }
            .padding(80)
        }
        .frame(width: 1080, height: 1920)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
}

extension AchievementShareCard {
    @MainActor
    static func render(
        definition: AchievementDefinition,
        earnedAt: Date?,
        displayName: String?
    ) -> UIImage? {
        let view = AchievementShareCard(
            definition: definition,
            earnedAt: earnedAt,
            displayName: displayName
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }
}
