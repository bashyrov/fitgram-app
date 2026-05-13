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
            title: "Co liczy się jako dzień",
            body: "Każdy zalogowany posiłek z dzisiejszego dnia podtrzymuje serię."
        ),
        Bullet(
            symbol: "snowflake",
            title: "Freeze ratuje przerwę",
            body:
                "Po południu, gdy nic nie wpisałeś, pojawia się przycisk freeze. Zużywa jeden z dwóch tygodniowych zapasów."
        ),
        Bullet(
            symbol: "moon.zzz",
            title: "Reset po cichu",
            body:
                "Pominięcie pełnej doby bez freeze cofa licznik do zera. Nic strasznego — od razu możesz zacząć nową serię."
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
            .navigationTitle(Text("Jak działa streak"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
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
                    Text(streakLength > 0 ? "\(streakLength) dni z rzędu" : "Jeszcze nie ma serii")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        streakLength > 0
                            ? "Brawo — utrzymuj rytm, freezy pojawiają się gdy ich potrzebujesz."
                            : "Zaloguj posiłek, żeby zacząć liczyć dni."
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
