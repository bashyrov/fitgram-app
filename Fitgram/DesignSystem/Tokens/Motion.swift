import SwiftUI

extension Tokens {
    /// Animation presets. Gentle springs by default — nothing snappy or harsh.
    enum Motion {
        /// 250 ms responsive spring — buttons, taps, small state changes.
        static let quick: Animation = .spring(response: 0.25, dampingFraction: 0.85)

        /// 500 ms relaxed spring — sheet transitions, large layout shifts.
        static let gentle: Animation = .spring(response: 0.5, dampingFraction: 0.85)

        /// Slightly playful spring — celebrations, streak milestone reveals.
        static let bouncy: Animation = .spring(response: 0.4, dampingFraction: 0.7)

        /// Linear-ish ease for skeleton shimmer and other continuous loops.
        static let ease: Animation = .easeInOut(duration: 0.25)
    }
}
