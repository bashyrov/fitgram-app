import SwiftUI

/// Mockup `VoiceListening`: dark hero (label · waveform · live transcript), muted example hint and
/// the round accent mic button with its caption at the bottom. Tapping the mic toggles capture.
struct VoiceCaptureView: View {
    let isListening: Bool
    let meter: VoiceLevelMeter
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
            VoiceWaveform(meter: meter, isListening: isListening, idleHeights: Self.waveHeights)
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

/// Bars that follow the microphone: each one is a recent loudness sample,
/// newest on the right, so the wave scrolls exactly with the voice. Idle, it
/// shows the mockup's static silhouette. Lives in its own view so the ~45 Hz
/// level updates only re-render the bars.
private struct VoiceWaveform: View {
    let meter: VoiceLevelMeter
    let isListening: Bool
    let idleHeights: [CGFloat]

    private let minHeight: CGFloat = 6
    private let maxHeight: CGFloat = 104

    var body: some View {
        HStack(spacing: 5) {
            ForEach(idleHeights.indices, id: \.self) { index in
                Capsule()
                    .fill(isListening ? Tokens.Mono.hi : Tokens.Mono.heroLine)
                    .frame(width: 6, height: height(at: index))
            }
        }
        .animation(.linear(duration: 0.08), value: meter.levels)
        .animation(Tokens.Motion.gentle, value: isListening)
        .accessibilityHidden(true)
    }

    private func height(at index: Int) -> CGFloat {
        guard isListening else { return idleHeights[index] }
        let levels = meter.levels
        let level = index < levels.count ? levels[index] : 0
        return minHeight + (maxHeight - minHeight) * CGFloat(level)
    }
}
