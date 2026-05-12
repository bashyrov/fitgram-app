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
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.sm) {
                        if entries.isEmpty {
                            empty
                        } else {
                            ForEach(entries) { entry in
                                row(entry)
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
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(entry.isYou ? Tokens.Palette.primarySoft : Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .stroke(
                    entry.isYou ? Tokens.Palette.primary.opacity(0.5) : Tokens.Palette.separator,
                    lineWidth: entry.isYou ? 1.5 : 1
                )
        )
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
