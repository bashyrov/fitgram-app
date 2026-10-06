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
                    Text("Fitgram")
                        .font(Tokens.Font.manrope(42, weight: 700))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 24) {
                    AchievementMedallion(definition: definition, isEarned: true, size: 330, showsLock: false)
                    Text(definition.title)
                        .font(Tokens.Font.archivo(size: 56, weight: 800, width: 115))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Text(definition.summary)
                        .font(Tokens.Font.manrope(30, weight: 600))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 6) {
                    if let earnedAt {
                        Text(
                            String.localizedStringWithFormat(L("zdobyte %@"), Self.dateFormatter.string(from: earnedAt))
                        )
                        .font(Tokens.Font.manrope(26, weight: 600))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(Tokens.Font.manrope(30, weight: 600))
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

    private static var dateFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM yyyy"
        return formatter

    }
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
