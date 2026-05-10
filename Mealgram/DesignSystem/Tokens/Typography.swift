import SwiftUI

extension Tokens {
    /// Typography scale. SF Pro Rounded everywhere; Dynamic Type respected by
    /// pairing each preset with its closest `Font.TextStyle`.
    enum Font {
        static let display = SwiftUI.Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = SwiftUI.Font.system(.title, design: .rounded, weight: .semibold)
        static let title2 = SwiftUI.Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = SwiftUI.Font.system(.title3, design: .rounded, weight: .medium)
        static let headline = SwiftUI.Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = SwiftUI.Font.system(.body, design: .rounded, weight: .regular)
        static let bodyEmphasized = SwiftUI.Font.system(.body, design: .rounded, weight: .medium)
        static let callout = SwiftUI.Font.system(.callout, design: .rounded, weight: .regular)
        static let subheadline = SwiftUI.Font.system(.subheadline, design: .rounded, weight: .regular)
        static let footnote = SwiftUI.Font.system(.footnote, design: .rounded, weight: .regular)
        static let caption = SwiftUI.Font.system(.caption, design: .rounded, weight: .regular)
        static let caption2 = SwiftUI.Font.system(.caption2, design: .rounded, weight: .regular)

        /// Monospaced digits, for calorie counters and timers, keeping width stable.
        static let counter = SwiftUI.Font.system(size: 44, weight: .semibold, design: .rounded)
            .monospacedDigit()
    }
}

extension View {
    /// Apply a Mealgram typography preset with sensible defaults (rounded, dynamic).
    func mealgramFont(_ font: SwiftUI.Font) -> some View {
        self.font(font)
    }
}
