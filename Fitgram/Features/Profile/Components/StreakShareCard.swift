import SwiftUI
import UIKit

/// 1080×1920 (9:16) story card for the current streak, rendered to PNG.
/// English only and anonymous on purpose: it is posted publicly, so it
/// carries no name and reads the same for every audience.
///
/// Backgrounds:
///   - `.gradient` — graphite card with a warm glow (the default)
///   - `.transparent` — no backdrop at all; the PNG keeps its alpha so it
///     drops onto a Story as a sticker
///   - `.photo(UIImage)` — the user's photo under a dark scrim
struct StreakShareCard: View {
    enum Background: Equatable {
        case gradient
        case transparent
        case photo(UIImage)
    }

    let streakLength: Int
    let longestLength: Int
    var background: Background = .gradient

    /// Fixed colours (not theme tokens) so the PNG looks identical in light
    /// and dark mode.
    private enum Palette {
        static let graphite = Color(red: 0.09, green: 0.10, blue: 0.11)
        static let graphiteTop = Color(red: 0.14, green: 0.15, blue: 0.17)
        static let flame = Color(red: 0.94, green: 0.54, blue: 0.27)
        static let ember = Color(red: 0.90, green: 0.36, blue: 0.16)
        static let gold = Color(red: 1.0, green: 0.78, blue: 0.38)
        static let track = Color.white.opacity(0.16)
    }

    private static let milestones = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365, 500, 730, 1000]

    var body: some View {
        ZStack {
            backgroundLayer
            content
                .padding(.horizontal, 96)
                .padding(.vertical, 120)
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            flame
            Text(verbatim: "\(streakLength)")
                .font(Tokens.Font.archivo(size: 520, weight: 900, width: 125, italic: true))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .shadow(color: shadowColor, radius: 24, y: 8)
                .padding(.top, -20)
            Text(verbatim: "DAY STREAK")
                .font(Tokens.Font.archivo(size: 92, weight: 900, width: 122, italic: true))
                .foregroundStyle(.white)
                .shadow(color: shadowColor, radius: 16, y: 4)
                .padding(.top, -24)
            milestoneMeter
                .padding(.top, 72)
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(verbatim: "FITGRAM")
                .font(Tokens.Font.archivo(size: 64, weight: 900, width: 122, italic: true))
                .foregroundStyle(.white)
            Spacer()
            recordBadge
        }
        .shadow(color: shadowColor, radius: 12, y: 4)
    }

    @ViewBuilder
    private var recordBadge: some View {
        if isPersonalBest {
            badge(text: "PERSONAL BEST", symbol: "crown.fill", fill: Palette.gold, ink: Palette.graphite)
        } else if longestLength > streakLength {
            badge(text: "BEST \(longestLength)", symbol: "trophy.fill", fill: .white.opacity(0.14), ink: .white)
        }
    }

    private func badge(text: String, symbol: String, fill: Color, ink: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .heavy))
            Text(verbatim: text)
                .font(Tokens.Font.manrope(34, weight: 800))
                .tracking(3)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        .background(Capsule().fill(fill))
    }

    private var flame: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 220, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Palette.gold, Palette.flame, Palette.ember],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Palette.flame.opacity(0.65), radius: 60)
    }

    /// Ticks toward the next milestone, with "4 to go" under them.
    private var milestoneMeter: some View {
        let target = nextMilestone
        let progress = target > 0 ? Double(streakLength) / Double(target) : 1
        return VStack(alignment: .leading, spacing: 22) {
            MonoTicks(progress: progress, count: 24, height: 64, fill: Palette.flame, empty: Palette.track)
            HStack {
                Text(verbatim: "NEXT GOAL · \(target) DAYS")
                Spacer()
                Text(verbatim: "\(max(0, target - streakLength)) TO GO")
                    .foregroundStyle(Palette.flame)
            }
            .font(Tokens.Font.manrope(36, weight: 800))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: shadowColor, radius: 10, y: 3)
    }

    private var footer: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(verbatim: "Logging every meal.\nOne day at a time.")
                .font(Tokens.Font.manrope(40, weight: 700))
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(6)
            Spacer()
            Text(verbatim: "fitgram.space")
                .font(Tokens.Font.manrope(36, weight: 800))
                .foregroundStyle(Palette.flame)
        }
        .shadow(color: shadowColor, radius: 10, y: 3)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .gradient:
            ZStack {
                LinearGradient(colors: [Palette.graphiteTop, Palette.graphite], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [Palette.flame.opacity(0.55), Palette.ember.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.25, y: 0.48),
                    startRadius: 0,
                    endRadius: 900
                )
                RadialGradient(
                    colors: [Palette.gold.opacity(0.18), .clear],
                    center: UnitPoint(x: 1.0, y: 1.0),
                    startRadius: 0,
                    endRadius: 700
                )
            }
        case .transparent:
            Color.clear
        case .photo(let image):
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 1080, height: 1920)
                    .clipped()
                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.15), .black.opacity(0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Helpers

    /// Soft shadow keeps white text readable on stickers and photos.
    private var shadowColor: Color {
        if case .gradient = background { return .clear }
        return .black.opacity(0.45)
    }

    private var isPersonalBest: Bool {
        streakLength > 0 && streakLength >= longestLength
    }

    private var nextMilestone: Int {
        Self.milestones.first { $0 > streakLength } ?? (streakLength / 1000 + 1) * 1000
    }
}

extension StreakShareCard {
    /// Renders the card at native size. For `.transparent` the renderer is
    /// non-opaque so the bitmap keeps its alpha channel.
    @MainActor
    static func render(streakLength: Int, longestLength: Int, background: Background = .gradient) -> UIImage? {
        let renderer = ImageRenderer(
            content: StreakShareCard(streakLength: streakLength, longestLength: longestLength, background: background)
        )
        renderer.scale = 1
        renderer.isOpaque = background != .transparent
        return renderer.uiImage
    }
}
