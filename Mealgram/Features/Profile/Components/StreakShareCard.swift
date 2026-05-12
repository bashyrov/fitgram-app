import SwiftUI
import UIKit

/// 1080x1920 (9:16) story-shaped card the user can render to PNG and
/// share via ShareLink. Designed to look good both at full size on a
/// social feed and as a small preview thumbnail in the share sheet.
///
/// Rendering happens via `StreakShareCard.render(streak:displayName:)`
/// which materialises the SwiftUI tree through `ImageRenderer` (iOS 16+).
struct StreakShareCard: View {
    let streakLength: Int
    let longestLength: Int
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

                VStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
                    Text("\(streakLength)")
                        .font(.system(size: 220, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 6)
                    Text(streakLength == 1 ? "dzień z rzędu" : "dni z rzędu")
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(spacing: 6) {
                    if longestLength > streakLength {
                        Text("rekord życiowy: \(longestLength) dni")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    } else if longestLength > 0 {
                        Text("nowy rekord życiowy!")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
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
}

extension StreakShareCard {
    /// Renders the share card to a UIImage at native size. Returns nil if
    /// `ImageRenderer` can't produce a CGImage (extremely rare; logs and
    /// the caller should fall back to a plain text share).
    @MainActor
    static func render(streakLength: Int, longestLength: Int, displayName: String?) -> UIImage? {
        let view = StreakShareCard(
            streakLength: streakLength,
            longestLength: longestLength,
            displayName: displayName
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }
}
