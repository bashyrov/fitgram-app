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
                VStack(spacing: 8) {
                    reminderCard(
                        title: "8:00 — Hi there!",
                        subtitle: "Ready for breakfast? Tap to add it."
                    )
                    reminderCard(
                        title: "21:00 — Podsumowanie",
                        subtitle: "Look back at your day."
                    )
                }
                .padding(.top, 4)
            }
        )
        .disabled(isRequesting)
        .opacity(isRequesting ? 0.6 : 1)
    }

    private func reminderCard(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "bell", style: .dark, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
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
