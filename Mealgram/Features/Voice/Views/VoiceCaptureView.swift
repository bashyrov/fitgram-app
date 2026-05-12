import SwiftUI

/// Mic button + live transcript bubble. Tapping the mic toggles capture.
struct VoiceCaptureView: View {
    let isListening: Bool
    let transcript: String
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.xxl) {
            Spacer()
            transcriptBubble
            Spacer()
            micButton
            Text(isListening ? "Stuknij, żeby zakończyć" : "Stuknij, żeby zacząć mówić")
                .font(Tokens.Font.callout)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .padding(.bottom, Tokens.Space.xxl)
        }
    }

    private var transcriptBubble: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                if transcript.isEmpty {
                    Text("Powiedz na przykład: „zjadłam zupę pomidorową i kanapkę z serem”.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                } else {
                    Text(transcript)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    private var micButton: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .fill(isListening ? Tokens.Palette.accent : Tokens.Palette.primary)
                    .frame(width: 96, height: 96)
                    .mealgramShadow(Tokens.Shadow.float)
                Image(systemName: isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isListening ? 1.05 : 1)
            .animation(Tokens.Motion.bouncy, value: isListening)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isListening ? "Zatrzymaj nagrywanie" : "Zacznij nagrywać"))
    }
}
