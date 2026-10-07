import SwiftUI

/// "Tablica wyników" — ranked streak board for the current user + their
/// friends. Top three rows get medal styling; the user's own row is
/// highlighted regardless of rank so they can find themselves fast.
struct LeaderboardView: View {
    let entries: [LeaderboardEntry]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                boardBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoH1(
                            text: L("Tablica wyników"),
                            sub: L("Ranking serii pokazuje, kto dziś trzyma rytm najdłużej.")
                        )
                        Color.clear.frame(height: 16)
                        if entries.isEmpty {
                            empty
                        } else {
                            podium
                            Color.clear.frame(height: 12)
                            VStack(spacing: 0) {
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                    if index > 0 {
                                        MonoRowDivider(inset: 0)
                                    }
                                    row(entry)
                                }
                            }
                            .monoRowsCard()
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .monoNavigationTitle(L("Tablica wyników"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
        }
    }

    private var boardBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    /// Top-3 podium tiles in 2 · 1 · 3 order (heights 130 / 160 / 110 like the mockup).
    private var podium: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(podiumItems.enumerated()), id: \.offset) { _, item in
                podiumTile(item.entry, height: item.height)
            }
        }
    }

    private var podiumItems: [(entry: LeaderboardEntry, height: CGFloat)] {
        var items: [(entry: LeaderboardEntry, height: CGFloat)] = []
        if entries.count > 1 { items.append((entry: entries[1], height: 130)) }
        if let first = entries.first { items.append((entry: first, height: 160)) }
        if entries.count > 2 { items.append((entry: entries[2], height: 110)) }
        return items
    }

    private func podiumTile(_ entry: LeaderboardEntry, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "medal")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Tokens.Mono.fat)
            Text(entry.isYou ? L("To Ty") : entry.displayName)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(entry.streak)")
                .font(Tokens.Font.monoNumber(26))
                .foregroundStyle(Tokens.Palette.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .bottom)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                .stroke(Tokens.Mono.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(Tokens.Font.monoNumber(20))
                .foregroundStyle(rankColor(for: entry))
                .frame(width: 30, alignment: .leading)
            FriendInitialAvatar(name: entry.displayName, size: 40)
            Text(entry.isYou ? "\(entry.displayName) · \(L("To Ty"))" : entry.displayName)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(entry.isYou ? Tokens.Mono.onHero : Tokens.Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Mono.fat)
                Text("\(entry.streak)")
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(entry.isYou ? Tokens.Mono.onHero : Tokens.Palette.ink)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(entry.isYou ? Tokens.Mono.hero : Color.clear)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "trophy", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Pusta tablica"))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L("Dodaj znajomego, żeby porównać serie."))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    private func rankColor(for entry: LeaderboardEntry) -> Color {
        if entry.isYou { return Tokens.Mono.hi }
        return entry.rank <= 3 ? Tokens.Mono.fat : Tokens.Mono.muted
    }
}
