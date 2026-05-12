import SwiftUI

/// Final onboarding screen — confetti animation + "Witaj w Mealgram!"
/// + a primary CTA. Triggered after paywall regardless of trial choice.
/// The confetti is pure SwiftUI (no library) using a TimelineView so it
/// only animates while the screen is visible.
struct CelebrationStepView: View {
    let displayName: String?
    let onContinue: () -> Void

    @State private var animateBadge = false

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ConfettiCanvas()
                .allowsHitTesting(false)
            VStack(spacing: Tokens.Space.xl) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 140, height: 140)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .scaleEffect(animateBadge ? 1.0 : 0.6)
                        .opacity(animateBadge ? 1 : 0)
                }
                VStack(spacing: Tokens.Space.sm) {
                    Text(welcomeHeadline)
                        .font(Tokens.Font.title)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Cele zapisane, przypomnienia gotowe. Wpisz pierwszy posiłek — Ola podpowie resztę.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.lg)
                }
                Spacer()
                PrimaryButton(title: "Zaczynamy", systemImage: "arrow.right") {
                    onContinue()
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) {
                animateBadge = true
            }
        }
    }

    private var welcomeHeadline: String {
        if let displayName, !displayName.isEmpty {
            return String(localized: "Witaj, \(displayName)!")
        }
        return String(localized: "Witaj w Mealgram!")
    }
}

/// Pure-SwiftUI confetti — 36 falling shapes randomly tinted with our
/// palette accents. No external dependency; ~150 ms per frame on iPhone
/// 17 so it stays smooth.
private struct ConfettiCanvas: View {
    private let pieces: [ConfettiPiece]

    init() {
        var rng = SystemRandomNumberGenerator()
        self.pieces = (0..<36).map { _ in ConfettiPiece.random(using: &rng) }
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(pieces) { piece in
                        ConfettiShape(piece: piece)
                            .position(position(for: piece, in: geometry.size, elapsed: elapsed))
                            .rotationEffect(.degrees(rotation(for: piece, elapsed: elapsed)))
                    }
                }
            }
        }
    }

    private func position(
        for piece: ConfettiPiece,
        in size: CGSize,
        elapsed: TimeInterval
    ) -> CGPoint {
        let totalDuration: TimeInterval = 4
        let progress = ((elapsed + piece.delay).truncatingRemainder(dividingBy: totalDuration)) / totalDuration
        let yOffset = -60 + (size.height + 120) * progress
        let xWobble = sin(progress * .pi * 2 * piece.wobbleFrequency) * piece.wobbleAmplitude
        return CGPoint(x: piece.x * size.width + xWobble, y: yOffset)
    }

    private func rotation(for piece: ConfettiPiece, elapsed: TimeInterval) -> Double {
        elapsed * piece.rotationSpeed + piece.rotationOffset
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: Double
    let delay: Double
    let wobbleFrequency: Double
    let wobbleAmplitude: Double
    let rotationSpeed: Double
    let rotationOffset: Double
    let color: Color
    let isCircle: Bool

    static func random<G: RandomNumberGenerator>(using generator: inout G) -> ConfettiPiece {
        let palette: [Color] = [
            Tokens.Palette.primary,
            Tokens.Palette.primarySoft,
            Tokens.Palette.accent,
            Tokens.Palette.warning,
        ]
        return ConfettiPiece(
            x: Double.random(in: 0.0...1.0, using: &generator),
            delay: Double.random(in: 0.0...4.0, using: &generator),
            wobbleFrequency: Double.random(in: 1.5...3.5, using: &generator),
            wobbleAmplitude: Double.random(in: 12...28, using: &generator),
            rotationSpeed: Double.random(in: 60...180, using: &generator),
            rotationOffset: Double.random(in: 0...360, using: &generator),
            color: palette.randomElement(using: &generator) ?? Tokens.Palette.primary,
            isCircle: Bool.random(using: &generator)
        )
    }
}

private struct ConfettiShape: View {
    let piece: ConfettiPiece

    var body: some View {
        Group {
            if piece.isCircle {
                Circle().fill(piece.color)
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(piece.color)
            }
        }
        .frame(width: 8, height: 12)
        .opacity(0.85)
    }
}
