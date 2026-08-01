import SwiftUI
import UIKit

/// 1080x1920 (9:16) story-shaped card the user can render to PNG and
/// share via ShareLink. Three background variants:
///   - `.gradient` — the default sage/lime brand backdrop
///   - `.transparent` — alpha background so the PNG drops nicely on
///     Stories without a visible box
///   - `.photo(UIImage)` — the user's own photo with the streak overlay
///     on top, with a soft dark scrim so the text stays readable
///
/// Rendering happens via `StreakShareCard.render(...)` which materialises
/// the SwiftUI tree through `ImageRenderer` (iOS 16+).
struct StreakShareCard: View {
    enum Background: Equatable {
        case gradient
        case transparent
        case photo(UIImage)
    }

    let streakLength: Int
    let longestLength: Int
    let displayName: String?
    var background: Background = .gradient

    var body: some View {
        ZStack {
            backgroundLayer
            // When we sit on top of a photo we add a soft scrim so the
            // white text stays legible across busy images.
            if case .photo = background {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
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
                        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 6)
                    Text("\(streakLength)")
                        .font(.system(size: 220, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 22, x: 0, y: 6)
                    Text(streakLength == 1 ? L("day in a row") : L("days in a row"))
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 3)
                }

                VStack(spacing: 6) {
                    if longestLength > streakLength {
                        Text(String.localizedStringWithFormat(L("personal record: %lld days"), longestLength))
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    } else if longestLength > 0 {
                        Text(L("new personal record!"))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.top, 12)
                    }
                }
                .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 3)
                Spacer()
            }
            .padding(80)
        }
        .frame(width: 1080, height: 1920)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .gradient:
            LinearGradient(
                colors: [
                    Tokens.Palette.primarySoft,
                    Tokens.Palette.primary.opacity(0.85),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .transparent:
            Color.clear
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .clipped()
        }
    }
}

extension StreakShareCard {
    /// Renders the share card to a UIImage at native size. Returns nil if
    /// `ImageRenderer` can't produce a CGImage (extremely rare; logs and
    /// the caller should fall back to a plain text share).
    ///
    /// For `.transparent`, the renderer's `isOpaque` is forced off so the
    /// generated PNG carries an alpha channel (otherwise iOS fills the
    /// alpha with the current colour scheme's window background).
    @MainActor
    static func render(
        streakLength: Int,
        longestLength: Int,
        displayName: String?,
        background: Background = .gradient
    ) -> UIImage? {
        let view = StreakShareCard(
            streakLength: streakLength,
            longestLength: longestLength,
            displayName: displayName,
            background: background
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        if case .transparent = background {
            renderer.isOpaque = false
        }
        return renderer.uiImage
    }
}
