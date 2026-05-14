import CoreGraphics

extension Tokens {
    /// 4-point spacing grid. Generous scale to keep the UI feeling airy.
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        static let huge: CGFloat = 64

        /// Horizontal screen edge padding used by most screens.
        static let screenPadding: CGFloat = 20
        /// Vertical breathing room between unrelated stacks.
        static let sectionSpacing: CGFloat = 32
    }

    /// Editorial radius scale — tighter, more architectural. Big
    /// surfaces use `xl`; cards use `md`; chips/pills use `pill`.
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Used for chips / pill buttons — capsule-shaped.
        static let pill: CGFloat = 999
    }
}
