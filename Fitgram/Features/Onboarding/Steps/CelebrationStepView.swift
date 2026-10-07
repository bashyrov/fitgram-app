import SwiftUI

/// Final onboarding screen — confetti animation + "Witaj w Fitgram!"
/// + a primary CTA. Triggered after paywall regardless of trial choice.
/// The confetti is pure SwiftUI (no library) using a TimelineView so it
/// only animates while the screen is visible.
struct CelebrationStepView: View {
    let displayName: String?
    /// Daily kcal target shown in the plan card (mockup "1800 kcal").
    var dailyKcal: Int?
    let onContinue: () -> Void

    @State private var animateBadge = false
    @State private var animateCheckmarks = false

    var body: some View {
        ZStack {
            backdrop
            ConfettiCanvas()
                .allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        heroBadge
                        headline
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                    planCard
                        .padding(.top, 24)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MonoBottomBar {
                    MonoButton(title: L("Zaczynamy"), kind: .dark) {
                        onContinue()
                    }
                }
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
        Tokens.Palette.background.ignoresSafeArea()
    }

    /// 120 pt dark disc with the accent checkmark.
    private var heroBadge: some View {
        Circle()
            .fill(Tokens.Mono.hero)
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .heavy))
                    .foregroundStyle(Tokens.Mono.hi)
                    .scaleEffect(animateBadge ? 1.0 : 0.5)
                    .opacity(animateBadge ? 1 : 0)
            )
            .scaleEffect(animateBadge ? 1.0 : 0.85)
            .accessibilityHidden(true)
    }

    private var headline: some View {
        VStack(spacing: 16) {
            Text(welcomeHeadline)
                .font(Tokens.Font.monoDisplay(30))
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Zebraliśmy Twoje dane i przygotowaliśmy spokojny start: cel, makro, wodę i rytm dnia.")
                .font(Tokens.Font.manrope(15, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MonoLabel(text: L("Twój plan jest gotowy"))
                    Spacer(minLength: 8)
                    if let dailyKcal, dailyKcal > 0 {
                        Text(verbatim: "\(dailyKcal) kcal")
                            .font(Tokens.Font.monoNumber(20))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                    }
                }
                Text("Możesz zacząć od pierwszego posiłku.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            checkRow("Cel kalorii i makro zapisane", delay: 0)
            checkRow("Ola przygotowała pierwsze wskazówki", delay: 0.1)
            checkRow("Przypomnienia i streak są gotowe", delay: 0.2)
        }
        .monoCard(padding: 16)
    }

    private func checkRow(_ text: LocalizedStringKey, delay: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Tokens.Mono.hi)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Tokens.Mono.hero))
                .scaleEffect(animateCheckmarks ? 1 : 0)
                .opacity(animateCheckmarks ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay), value: animateCheckmarks)

            Text(text)
                .font(Tokens.Font.manrope(14, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
            Spacer(minLength: 0)
        }
    }

    private var welcomeHeadline: String {
        if let displayName, !displayName.isEmpty {
            return String.localizedStringWithFormat(L("Plan gotowy, %@"), displayName)
        }
        return L("Twój plan jest gotowy")
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
            Tokens.Mono.accent,
            Tokens.Mono.fat,
            Tokens.Mono.hi,
            Tokens.Mono.strong,
        ]
        return ConfettiPiece(
            x: Double.random(in: 0.0...1.0, using: &generator),
            delay: Double.random(in: 0.0...4.0, using: &generator),
            wobbleFrequency: Double.random(in: 1.5...3.5, using: &generator),
            wobbleAmplitude: Double.random(in: 12...28, using: &generator),
            rotationSpeed: Double.random(in: 60...180, using: &generator),
            rotationOffset: Double.random(in: 0...360, using: &generator),
            color: palette.randomElement(using: &generator) ?? Tokens.Mono.accent,
            isCircle: Bool.random(using: &generator)
        )
    }
}

private struct ConfettiShape: View {
    let piece: ConfettiPiece

    var body: some View {
        // Design D confetti: small 10×16 slanted slips (no circles).
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(piece.color)
            .frame(width: piece.isCircle ? 8 : 10, height: piece.isCircle ? 12 : 16)
            .opacity(0.9)
    }
}
