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
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.60),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // Mockup preview card ×4: 24 pt padding, brand label top, big count bottom-left.
            VStack(alignment: .leading, spacing: 0) {
                Text("Fitgram")
                    .font(Tokens.Font.monoDisplay(64))
                    .textCase(.uppercase)
                    .foregroundStyle(textColor)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 24) {
                    Text("\(streakLength)")
                        .font(Tokens.Font.monoNumber(440))
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .foregroundStyle(textColor)
                    Text(streakLength == 1 ? L("day in a row") : L("days in a row"))
                        .font(Tokens.Font.manrope(72, weight: 800))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if longestLength > streakLength {
                        Text(String.localizedStringWithFormat(L("personal record: %lld days"), longestLength))
                            .font(Tokens.Font.manrope(52, weight: 700))
                            .foregroundStyle(Tokens.Mono.hi)
                    } else if longestLength > 0 {
                        Text(L("new personal record!"))
                            .font(Tokens.Font.manrope(52, weight: 700))
                            .foregroundStyle(Tokens.Mono.hi)
                    }
                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(Tokens.Font.manrope(40, weight: 700))
                            .foregroundStyle(textColor.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(96)
        }
        .frame(width: 1080, height: 1920)
    }

    /// Hero text on the brand backdrop; plain white over photos / transparent stories.
    private var textColor: Color {
        if case .gradient = background { return Tokens.Mono.onHero }
        return .white
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .gradient:
            Tokens.Mono.hero
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
