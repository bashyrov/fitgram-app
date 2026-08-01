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
                    VStack(spacing: Tokens.Space.lg) {
                        boardHero
                        if entries.isEmpty {
                            empty
                        } else {
                            LazyVStack(spacing: Tokens.Space.sm) {
                                ForEach(entries) { entry in
                                    row(entry)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Tablica wyników"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    private var boardBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 105)
                .offset(x: -150, y: -210)
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.34))
                .frame(width: 330, height: 330)
                .blur(radius: 112)
                .offset(x: 150, y: -10)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 105)
                .offset(x: -80, y: 360)
        }
        .ignoresSafeArea()
    }

    private var boardHero: some View {
        VStack(spacing: Tokens.Space.sm) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.Palette.warning)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Tokens.Palette.warning.opacity(0.16)))
            Text("Tablica wyników")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
            Text("Ranking serii pokazuje, kto dziś trzyma rytm najdłużej.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        .shadow(color: Tokens.Palette.warning.opacity(0.12), radius: 24, y: 14)
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(medalColor(for: entry.rank).opacity(0.2))
                    .frame(width: 36, height: 36)
                if let medal = medalSymbol(for: entry.rank) {
                    Image(systemName: medal)
                        .foregroundStyle(medalColor(for: entry.rank))
                } else {
                    Text("\(entry.rank)")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(medalColor(for: entry.rank))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                if entry.isYou {
                    Text("To Ty")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Tokens.Palette.warning)
                Text("\(entry.streak)")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(entry.isYou ? Tokens.Palette.primarySoft.opacity(0.92) : Tokens.Palette.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    entry.isYou ? Tokens.Palette.primary.opacity(0.5) : .white.opacity(0.34),
                    lineWidth: entry.isYou ? 1.5 : 1
                )
        )
        .shadow(color: Tokens.Palette.primary.opacity(entry.isYou ? 0.12 : 0.05), radius: 14, y: 8)
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "trophy")
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text("Pusta tablica")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Text("Dodaj znajomego, żeby porównać serie.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Tokens.Space.xxxl)
    }

    private func medalSymbol(for rank: Int) -> String? {
        switch rank {
        case 1: return "1.circle.fill"
        case 2: return "2.circle.fill"
        case 3: return "3.circle.fill"
        default: return nil
        }
    }

    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return Tokens.Palette.inkMuted
        }
    }
}
