import SwiftUI

/// Large, soft shutter button — concentric circles with the inner one
/// shrinking on press for a tactile feel.
struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Tokens.Mono.hi)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 5))
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Mono.onHi)
                        .scaleEffect(1.3)
                }
            }
            .frame(width: 88, height: 88)
        }
        .buttonStyle(ShutterPressStyle())
        .disabled(isBusy)
        .accessibilityLabel(Text("Take a photo"))
    }
}

private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Tokens.Motion.quick, value: configuration.isPressed)
    }
}
