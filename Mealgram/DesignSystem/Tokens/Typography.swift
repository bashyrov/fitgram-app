import SwiftUI

extension Tokens {
    /// Editorial typography stack. Display headlines use the system serif
    /// (New York) for that magazine feel; body + UI uses default SF Pro
    /// for crisp legibility. Counter stays monospaced so calorie tickers
    /// don't reflow.
    enum Font {
        static let display = SwiftUI.Font.system(size: 40, weight: .heavy, design: .serif)
        static let title = SwiftUI.Font.system(size: 32, weight: .bold, design: .serif)
        static let title2 = SwiftUI.Font.system(size: 26, weight: .bold, design: .serif)
        static let title3 = SwiftUI.Font.system(size: 22, weight: .semibold, design: .default)
        static let headline = SwiftUI.Font.system(.headline, design: .default, weight: .semibold)
        static let body = SwiftUI.Font.system(.body, design: .default, weight: .regular)
        static let bodyEmphasized = SwiftUI.Font.system(.body, design: .default, weight: .semibold)
        static let callout = SwiftUI.Font.system(.callout, design: .default, weight: .regular)
        static let subheadline = SwiftUI.Font.system(.subheadline, design: .default, weight: .regular)
        static let footnote = SwiftUI.Font.system(.footnote, design: .default, weight: .regular)
        static let caption = SwiftUI.Font.system(.caption, design: .default, weight: .medium)
        static let caption2 = SwiftUI.Font.system(.caption2, design: .default, weight: .medium)

        /// Editorial number tray — wide, heavy, monospaced.
        static let counter = SwiftUI.Font.system(size: 64, weight: .black, design: .serif)
            .monospacedDigit()

        /// Eyebrow caption — caps + tracking for hero section labels
        /// ("DZIEŃ 3", "TWOJE CELE" style).
        static let eyebrow = SwiftUI.Font.system(size: 11, weight: .heavy, design: .default)
    }
}

extension View {
    /// Apply a Mealgram typography preset with sensible defaults.
    func mealgramFont(_ font: SwiftUI.Font) -> some View {
        self.font(font)
    }

    /// Eyebrow label — uppercase with letter spacing for editorial section
    /// labels. Used in hero strips ("LIVE", "DZIŚ 1 240 KCAL", "OBSERWUJ").
    func eyebrowStyle() -> some View {
        self.font(Tokens.Font.eyebrow)
            .textCase(.uppercase)
            .tracking(1.6)
    }
}
