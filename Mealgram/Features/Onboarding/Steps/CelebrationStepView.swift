import SwiftUI

/// Final onboarding screen — confetti animation + "Witaj w Mealgram!"
/// + a primary CTA. Triggered after paywall regardless of trial choice.
/// The confetti is pure SwiftUI (no library) using a TimelineView so it
/// only animates while the screen is visible.
struct CelebrationStepView: View {
    let displayName: String?
    let onContinue: () -> Void

    @State private var animateBadge = false
    @State private var animateCheckmarks = false

    var body: some View {
        ZStack {
            backdrop
            ConfettiCanvas()
                .allowsHitTesting(false)
            VStack(spacing: Tokens.Space.lg) {
                Spacer()
                heroBadge
                headline
                checklist
                    .padding(.top, Tokens.Space.md)
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
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateCheckmarks = true
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -160, y: -300)
                .allowsHitTesting(false)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 170, y: 300)
                .allowsHitTesting(false)
        }
    }

    private var heroBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Palette.primary.opacity(0.85),
                            Tokens.Palette.primary,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 28, y: 14)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(animateBadge ? 1.0 : 0.5)
                .opacity(animateBadge ? 1 : 0)
        }
    }

    private var headline: some View {
        VStack(spacing: Tokens.Space.sm) {
            Text(welcomeHeadline)
                .font(Tokens.Font.title)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Palette.ink)
            Text("Cele zapisane, przypomnienia gotowe. Wpisz pierwszy posiłek — Ola podpowie resztę.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
        }
    }

    private var checklist: some View {
        VStack(spacing: Tokens.Space.sm) {
            checkRow("Profil i cele zapisane", delay: 0)
            checkRow("Ola dostosowała Twój plan", delay: 0.1)
            checkRow("Bezpieczna prywatność domyślnie", delay: 0.2)
        }
        .padding(.horizontal, Tokens.Space.xl)
    }

    private func checkRow(_ text: LocalizedStringKey, delay: Double) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(animateCheckmarks ? 1 : 0)
            .opacity(animateCheckmarks ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay), value: animateCheckmarks)

            Text(text)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
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
