import SwiftUI

/// Tap-the-flame explainer. Surfaces what counts as a streak day, how
/// freezes work, and where to find the full history.
struct StreakExplanationSheet: View {
    let streakLength: Int
    let onDismiss: () -> Void

    private struct Bullet: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let bullets: [Bullet] = [
        Bullet(
            symbol: "fork.knife.circle.fill",
            title: "What counts as a day",
            body: "Any meal logged today keeps your streak going."
        ),
        Bullet(
            symbol: "snowflake",
            title: "Freeze saves a missed day",
            body:
                "In the afternoon, if you haven't entered anything, a freeze button appears. It uses up one of your two weekly saves."
        ),
        Bullet(
            symbol: "moon.zzz",
            title: "Reset po cichu",
            body:
                "Skipping a full 24-hour period without a freeze resets the counter to zero. No big deal — you can start a new streak right away."
        ),
        Bullet(
            symbol: "calendar",
            title: "Pełna historia w Profilu",
            body: "Profil → Historia serii pokazuje miesięczną kratę z każdym zalogowanym dniem."
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        VStack(spacing: Tokens.Space.md) {
                            ForEach(bullets) { item in
                                bulletCard(item)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("How the streak works"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
    }

    private var header: some View {
        Card(background: Tokens.Palette.warning.opacity(0.15)) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: streakLength > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        streakLength > 0
                            ? LocalizedStringKey("\(streakLength) dni z rzędu")
                            : LocalizedStringKey("Jeszcze nie ma serii")
                    )
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        streakLength > 0
                            ? LocalizedStringKey("Brawo — utrzymuj rytm, freezy pojawiają się gdy ich potrzebujesz.")
                            : LocalizedStringKey("Zaloguj posiłek, żeby zacząć liczyć dni.")
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func bulletCard(_ item: Bullet) -> some View {
        Card {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                Image(systemName: item.symbol)
                    .font(.title3)
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(item.body)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
