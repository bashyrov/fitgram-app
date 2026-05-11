import SwiftUI

/// Minimal profile / settings screen. Milestone 1.8 in the master prompt
/// covers full data export + privacy URLs — this is enough to surface the
/// sign-out path and basic info while we keep building.
struct ProfileView: View {
    let user: User?
    let streak: Streak?
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        identityCard
                        statsRow
                        goalsCard
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Konto")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                signOutButton
                                Divider().background(Tokens.Palette.separator)
                                deleteButton
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Profil"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var identityCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            HStack(spacing: Tokens.Space.lg) {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(initial)
                            .font(Tokens.Font.title2)
                            .foregroundStyle(Tokens.Palette.primary)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(emailLine)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: Tokens.Space.md) {
            statCard(icon: "flame.fill", value: "\(streak?.currentLength ?? 0)", label: "Streak")
            statCard(icon: "calendar", value: "\(streak?.longestLength ?? 0)", label: "Rekord")
            statCard(icon: "snowflake", value: "\(streak?.freezesAvailable ?? 0)", label: "Freeze")
        }
    }

    private func statCard(icon: String, value: String, label: LocalizedStringKey) -> some View {
        Card {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(value)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(label)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var goalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Dzienne cele")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                goalRow(label: "Kalorie", value: "\(user?.dailyCalorieGoalKcal ?? 2100) kcal")
                goalRow(label: "Białko", value: "\(user?.proteinGoalGrams ?? 120) g")
                goalRow(label: "Węgle", value: "\(user?.carbsGoalGrams ?? 240) g")
                goalRow(label: "Tłuszcz", value: "\(user?.fatGoalGrams ?? 70) g")
            }
        }
    }

    private func goalRow(label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text(value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive, action: onSignOut) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Wyloguj")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .foregroundStyle(Tokens.Palette.ink)
            .font(Tokens.Font.body)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDeleteAccount) {
            HStack {
                Image(systemName: "trash")
                Text("Usuń konto")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .foregroundStyle(Tokens.Palette.error)
            .font(Tokens.Font.body)
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        if let email = user?.email, !email.isEmpty { return email }
        return String(localized: "Konto Mealgram")
    }

    private var emailLine: String {
        if let email = user?.email, !email.isEmpty { return email }
        return String(localized: "Brak adresu e-mail")
    }

    private var initial: String {
        if let first = displayName.first { return String(first).uppercased() }
        return "M"
    }
}
