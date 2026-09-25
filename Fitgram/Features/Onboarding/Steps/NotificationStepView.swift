import SwiftUI
import UserNotifications

/// Soft permission ask. We never hard-fail — the user can always opt in
/// later from Settings.
struct NotificationStepView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false

    var body: some View {
        OnboardingStepScaffold(
            title: "Lekkie przypomnienia",
            subtitle: "A short note in the morning when your day begins, and one in the evening to wrap up.",
            primaryTitle: "Enable reminders",
            primarySystemImage: "bell.fill",
            secondaryTitle: "Maybe later",
            secondaryAction: onContinue,
            onPrimary: { Task { await request() } },
            content: {
                VStack(spacing: Tokens.Space.md) {
                    Card(elevation: Tokens.Shadow.card) {
                        HStack(spacing: Tokens.Space.md) {
                            Image(systemName: "sun.max.fill")
                                .font(.title2)
                                .foregroundStyle(Tokens.Palette.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("8:00 — Hi there!")
                                    .font(Tokens.Font.bodyEmphasized)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text("Ready for breakfast? Tap to add it.")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    Card(elevation: Tokens.Shadow.card) {
                        HStack(spacing: Tokens.Space.md) {
                            Image(systemName: "moon.fill")
                                .font(.title2)
                                .foregroundStyle(Tokens.Palette.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("21:00 — Podsumowanie")
                                    .font(Tokens.Font.bodyEmphasized)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text("Look back at your day.")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        )
        .disabled(isRequesting)
        .opacity(isRequesting ? 0.6 : 1)
    }

    private func request() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        onContinue()
    }
}
