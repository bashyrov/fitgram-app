import SwiftUI

/// Mockup `VoiceListening`: dark hero (label · waveform · live transcript), muted example hint and
/// the round accent mic button with its caption at the bottom. Tapping the mic toggles capture.
struct VoiceCaptureView: View {
    let isListening: Bool
    let transcript: String
    let onToggle: () -> Void

    /// Bar heights of the mockup waveform (17 bars, 6 pt wide, 5 pt apart).
    private static let waveHeights: [CGFloat] = [18, 34, 56, 40, 72, 48, 90, 64, 38, 70, 52, 30, 60, 42, 24, 46, 20]

    var body: some View {
        VStack(spacing: 0) {
            listeningHero
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 30)
            Text("Powiedz na przykład: „zjadłam zupę pomidorową i kanapkę z serem”.")
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 18)
            Spacer(minLength: 20)
            micBlock
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 20)
                .padding(.bottom, 34)
        }
    }

    /// `hero(LBLH 'Słucham…' + wave + transcript, pad 24, gap 18)`.
    private var listeningHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoLabel(
                text: isListening
                    ? TL(pl: "Słucham…", en: "Listening…", uk: "Слухаю…", ru: "Слушаю…", es: "Escuchando…")
                    : TL(pl: "Gotowy", en: "Ready", uk: "Готовий", ru: "Готов", es: "Listo"),
                onHero: true
            )
            waveform
                .frame(maxWidth: .infinity)
                .frame(height: 110)
            transcriptText
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    @ViewBuilder
    private var transcriptText: some View {
        if transcript.isEmpty {
            Text(verbatim: "„…”")
                .font(Tokens.Font.manrope(20, weight: 700))
                .foregroundStyle(Tokens.Mono.heroMuted)
        } else {
            Text(verbatim: "„\(transcript)”")
                .font(Tokens.Font.manrope(20, weight: 700))
                .foregroundStyle(Tokens.Mono.onHero)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Static mockup bars; they gently breathe while the microphone is live.
    private var waveform: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isListening)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(Self.waveHeights.indices, id: \.self) { index in
                    Capsule()
                        .fill(isListening ? Tokens.Mono.hi : Tokens.Mono.heroLine)
                        .frame(width: 6, height: barHeight(index: index, time: time))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let base = Self.waveHeights[index]
        guard isListening else { return base }
        let wave = sin(time * 6 + Double(index) * 0.8)
        let scale = 0.75 + 0.25 * CGFloat(wave)
        return max(8, base * scale)
    }

    /// `bottom(84 pt accent mic + 'Stuknij, aby zakończyć')`.
    private var micBlock: some View {
        VStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Tokens.Mono.onAccent)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Tokens.Mono.accent))
                    .scaleEffect(isListening ? 1.05 : 1)
                    .animation(Tokens.Motion.bouncy, value: isListening)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isListening ? "Zatrzymaj nagrywanie" : "Zacznij nagrywać"))
            Text(isListening ? "Stuknij, żeby zakończyć" : "Stuknij, żeby zacząć mówić")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
