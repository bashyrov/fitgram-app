import SwiftUI

/// Brand splash shown on cold start. The Fitgram mark draws itself as a
/// clean outline, then softly fills with the current theme accent.
struct SplashScreen: View {
    let onComplete: () -> Void

    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    @State private var outlineProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.985
    @State private var logoOpacity: Double = 1
    @State private var logoBlur: CGFloat = 0
    @State private var logoOffsetY: CGFloat = 0

    private var palette: AppAccentPalette {
        let palette = AppAccentPalette(rawValue: accentRaw) ?? .rose
        return palette.isSelectable ? palette : .rose
    }

    var body: some View {
        ZStack {
            Tokens.Mono.hero.ignoresSafeArea()

            VStack(spacing: 18) {
                FitgramAnimatedLogo(
                    outlineProgress: outlineProgress,
                    fillOpacity: fillOpacity,
                    color: Tokens.Mono.hi
                )
                .frame(width: 180, height: 84)

                Text(verbatim: "FITGRAM")
                    .font(Tokens.Font.manrope(13, weight: 800))
                    .tracking(3.9)
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .opacity(fillOpacity)
                    .accessibilityHidden(true)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .blur(radius: logoBlur)
            .offset(y: logoOffsetY)
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        withAnimation(.easeInOut(duration: 0.95)) {
            outlineProgress = 1
            logoScale = 1
        }
        withAnimation(.easeOut(duration: 0.55).delay(0.78)) {
            fillOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.42).delay(1.55)) {
            logoScale = 1.025
            logoOpacity = 0
            logoBlur = 5
            logoOffsetY = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.92) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreen(onComplete: {})
}

/// Static, filled Fitgram mark (design D heroes on Auth / Onboarding).
struct FitgramLogoMark: View {
    var color: Color = Tokens.Mono.hi

    var body: some View {
        ZStack {
            ForEach(FitgramLogoPart.Part.allCases) { part in
                FitgramLogoPart(part: part).fill(color)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FitgramAnimatedLogo: View {
    let outlineProgress: CGFloat
    let fillOpacity: Double
    let color: Color

    var body: some View {
        ZStack {
            ForEach(FitgramLogoPart.Part.allCases) { part in
                FitgramLogoPart(part: part)
                    .fill(color)
                    .opacity(fillOpacity)
            }

            ForEach(FitgramLogoPart.Part.allCases) { part in
                FitgramLogoPart(part: part)
                    .trim(from: 0, to: outlineProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .opacity(fillOpacity > 0.88 ? 0.24 : 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One of the three Fitgram mark strokes (shared with Auth / Onboarding heroes).
struct FitgramLogoPart: Shape {
    enum Part: CaseIterable, Identifiable {
        case left
        case middle
        case right

        var id: Self { self }
    }

    let part: Part

    func path(in rect: CGRect) -> Path {
        switch part {
        case .left: return leftPath(in: rect)
        case .middle: return middlePath(in: rect)
        case .right: return rightPath(in: rect)
        }
    }

    private func leftPath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(422.213, 588.013, in: rect))
        path.addLine(to: point(475.433, 474.793, in: rect))
        path.addCurve(
            to: point(471.813, 469.091, in: rect),
            control1: point(476.680, 472.140, in: rect),
            control2: point(474.744, 469.091, in: rect)
        )
        path.addLine(to: point(338.705, 469.091, in: rect))
        path.addLine(to: point(264.034, 469.091, in: rect))
        path.addCurve(
            to: point(174.134, 525.296, in: rect),
            control1: point(225.784, 469.091, in: rect),
            control2: point(190.886, 490.910, in: rect)
        )
        path.addLine(to: point(96.005, 685.675, in: rect))
        path.addCurve(
            to: point(104.995, 700.055, in: rect),
            control1: point(92.769, 692.318, in: rect),
            control2: point(97.606, 700.055, in: rect)
        )
        path.addLine(to: point(202.290, 700.055, in: rect))
        path.addCurve(
            to: point(211.283, 694.428, in: rect),
            control1: point(206.118, 700.055, in: rect),
            control2: point(209.609, 697.870, in: rect)
        )
        path.addLine(to: point(249.297, 616.265, in: rect))
        path.addCurve(
            to: point(285.269, 593.759, in: rect),
            control1: point(255.993, 602.498, in: rect),
            control2: point(269.959, 593.759, in: rect)
        )
        path.addLine(to: point(413.163, 593.759, in: rect))
        path.addCurve(
            to: point(422.213, 588.013, in: rect),
            control1: point(417.038, 593.759, in: rect),
            control2: point(420.564, 591.521, in: rect)
        )
        path.closeSubpath()
        return path
    }

    private func middlePath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(600.173, 469.091, in: rect))
        path.addLine(to: point(510.626, 469.091, in: rect))
        path.addCurve(
            to: point(501.570, 474.849, in: rect),
            control1: point(506.746, 469.091, in: rect),
            control2: point(503.216, 471.336, in: rect)
        )
        path.addLine(to: point(406.079, 678.691, in: rect))
        path.addCurve(
            to: point(419.662, 700.055, in: rect),
            control1: point(401.419, 688.638, in: rect),
            control2: point(408.678, 700.055, in: rect)
        )
        path.addLine(to: point(508.732, 700.055, in: rect))
        path.addCurve(
            to: point(517.779, 694.314, in: rect),
            control1: point(512.605, 700.055, in: rect),
            control2: point(516.129, 697.818, in: rect)
        )
        path.addLine(to: point(613.744, 490.481, in: rect))
        path.addCurve(
            to: point(600.173, 469.091, in: rect),
            control1: point(618.428, 480.532, in: rect),
            control2: point(611.169, 469.091, in: rect)
        )
        path.closeSubpath()
        return path
    }

    private func rightPath(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(926.404, 323.412, in: rect))
        path.addLine(to: point(276.679, 323.412, in: rect))
        path.addCurve(
            to: point(267.589, 329.245, in: rect),
            control1: point(272.769, 323.412, in: rect),
            control2: point(269.218, 325.691, in: rect)
        )
        path.addLine(to: point(226.816, 418.201, in: rect))
        path.addCurve(
            to: point(244.997, 446.535, in: rect),
            control1: point(220.744, 431.449, in: rect),
            control2: point(230.424, 446.535, in: rect)
        )
        path.addLine(to: point(632.709, 446.534, in: rect))
        path.addCurve(
            to: point(646.259, 467.970, in: rect),
            control1: point(643.728, 446.534, in: rect),
            control2: point(650.986, 458.017, in: rect)
        )
        path.addLine(to: point(546.591, 677.815, in: rect))
        path.addCurve(
            to: point(560.140, 699.250, in: rect),
            control1: point(541.864, 687.768, in: rect),
            control2: point(549.122, 699.250, in: rect)
        )
        path.addLine(to: point(645.119, 699.250, in: rect))
        path.addCurve(
            to: point(654.092, 693.665, in: rect),
            control1: point(648.930, 699.250, in: rect),
            control2: point(652.410, 697.084, in: rect)
        )
        path.addLine(to: point(767.425, 463.290, in: rect))
        path.addCurve(
            to: point(794.341, 446.532, in: rect),
            control1: point(772.472, 453.032, in: rect),
            control2: point(782.909, 446.534, in: rect)
        )
        path.addLine(to: point(873.314, 446.524, in: rect))
        path.addCurve(
            to: point(886.811, 438.065, in: rect),
            control1: point(879.062, 446.524, in: rect),
            control2: point(884.305, 443.238, in: rect)
        )
        path.addLine(to: point(935.403, 337.772, in: rect))
        path.addCurve(
            to: point(926.404, 323.412, in: rect),
            control1: point(938.620, 331.131, in: rect),
            control2: point(933.783, 323.412, in: rect)
        )
        path.closeSubpath()
        return path
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        let sourceMinX: CGFloat = 96
        let sourceMinY: CGFloat = 323
        let sourceWidth: CGFloat = 840
        let sourceHeight: CGFloat = 378
        let scale = min(rect.width / sourceWidth, rect.height / sourceHeight)
        let width = sourceWidth * scale
        let height = sourceHeight * scale
        let xOffset = rect.midX - width / 2
        let yOffset = rect.midY - height / 2
        return CGPoint(x: xOffset + (x - sourceMinX) * scale, y: yOffset + (y - sourceMinY) * scale)
    }
}
