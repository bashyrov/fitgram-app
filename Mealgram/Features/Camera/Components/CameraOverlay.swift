import SwiftUI

/// Translucent framing overlay — soft rounded rectangle suggesting where to
/// frame the plate, plus a hint line. Kept low-contrast so it doesn't fight
/// for attention with the food itself.
struct CameraOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.18)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 32, style: .continuous
                                )
                                .frame(width: proxy.size.width * 0.82, height: proxy.size.width * 0.82)
                                .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: proxy.size.width * 0.82, height: proxy.size.width * 0.82)

                VStack {
                    Spacer()
                    Text("Aim the whole plate into the center of the frame")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, proxy.size.height * 0.18)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
