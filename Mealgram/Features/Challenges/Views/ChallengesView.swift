import SwiftUI

/// "Wyzwania tygodnia" sheet — auto-rolling challenges for the current
/// ISO week. Read-only; the user doesn't pick — every challenge runs
/// in parallel and progress comes from the meal log.
struct ChallengesView: View {
    let progress: [ChallengeProgress]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        intro
                        ForEach(progress) { item in
                            ChallengeCard(item: item)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Wyzwania tygodnia"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private var intro: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Twój tydzień")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "All challenges run in parallel. You don't have to choose anything — every meal counts on its own."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ChallengeCard: View {
    let item: ChallengeProgress

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: Tokens.Space.md) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Image(systemName: item.challenge.systemImage)
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.challenge.title)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(item.challenge.body)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if item.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Tokens.Palette.accent)
                    }
                }
                progressBar
                Text("\(item.current) / \(item.challenge.rule.target)")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Tokens.Palette.surfaceMuted)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accent)
                    .frame(width: geometry.size.width * item.ratio)
            }
        }
        .frame(height: 8)
    }

    private var accent: Color {
        item.isCompleted ? Tokens.Palette.accent : Tokens.Palette.primary
    }
}
