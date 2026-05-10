import SwiftUI

/// Subtle "press" interaction shared by `PrimaryButton`, `SecondaryButton`, and
/// any other custom button. Gently scales down on tap with the design-system
/// quick-spring motion.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Tokens.Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// `.buttonStyle(.pressable)` — Mealgram press feedback.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
