import SwiftUI

/// Translucent framing overlay — soft rounded rectangle suggesting where to
/// frame the plate, plus a hint line. Kept low-contrast so it doesn't fight
/// for attention with the food itself.
struct CameraOverlay: View {
    /// Distance from the top of the safe area to the frame (close button row + 80 pt).
    var frameTop: CGFloat = 132

    var body: some View {
        GeometryReader { proxy in
            let side = min(290, proxy.size.width - 64)
            ZStack(alignment: .top) {
                CameraFrameDim(side: side, top: frameTop)
                    .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))

                VStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .strokeBorder(Tokens.Mono.hi, lineWidth: 3)
                        .frame(width: side, height: side)
                    Text("Aim the whole plate into the center of the frame")
                        .font(Tokens.Font.manrope(14, weight: 700))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, frameTop)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Dimmed backdrop with a rounded "window" cut out for the plate. The outer rectangle is drawn
/// well past the bounds so the dim also covers the safe-area edges.
private struct CameraFrameDim: Shape {
    let side: CGFloat
    let top: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect.insetBy(dx: -400, dy: -400))
        let hole = CGRect(x: rect.midX - side / 2, y: rect.minY + top, width: side, height: side)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 40, height: 40), style: .continuous)
        return path
    }
}
