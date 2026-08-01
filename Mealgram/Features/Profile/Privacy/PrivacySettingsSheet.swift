import SwiftUI

/// "What my friends see" — granular privacy controls in Profile.
/// Two-level: top picks the overall visibility (Tylko ja / Tylko znajomi
/// / Wszyscy z linkiem); below, per-field toggles. Saving an empty
/// state is fine — that's the privacy-first default.
struct PrivacySettingsSheet: View {
    @Bindable var store: PrivacyStore
    let onDismiss: () -> Void

    @State private var draft: PrivacySettings

    init(store: PrivacyStore, onDismiss: @escaping () -> Void) {
        self.store = store
        self.onDismiss = onDismiss
        self._draft = State(initialValue: store.current)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        explainer
                        visibilityCard
                        if draft.visibility != .privateOnly {
                            toggleCard
                            sensitiveCard
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Privacy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.replace(draft)
                        Haptics.success()
                        onDismiss()
                    }
                }
            }
        }
    }

    private var explainer: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Prywatność najpierw", systemImage: "lock.shield.fill")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(
                    "By default, we don't share anything. Enable only what you actually want to show your friends."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
            }
        }
    }

    private var visibilityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Kto może zobaczyć Twój profil")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                visibilityRow(.privateOnly, label: "Tylko ja", subtitle: "Profil ukryty dla wszystkich")
                visibilityRow(.friendsOnly, label: "Tylko znajomi", subtitle: "Widoczne dla osób, które dodały Cię")
                visibilityRow(
                    .publicLink, label: "Wszyscy z linkiem", subtitle: "Anyone with your code can see your profile")
            }
        }
    }

    private func visibilityRow(
        _ option: PrivacySettings.Visibility,
        label: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        Button {
            draft.visibility = option
        } label: {
            HStack(alignment: .top, spacing: Tokens.Space.sm) {
                Image(systemName: draft.visibility == option ? "circle.inset.filled" : "circle")
                    .foregroundStyle(Tokens.Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var toggleCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("What to share")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                toggle(
                    title: "Mój streak",
                    detail: "np. 🔥 30 dni",
                    bind: $draft.showStreak
                )
                toggle(
                    title: "Mój poziom",
                    detail: "np. Lvl 12 — Pro",
                    bind: $draft.showLevel
                )
                toggle(
                    title: "Moje achievements",
                    detail: "Odznaki, które zdobyłeś/aś",
                    bind: $draft.showAchievements
                )
                toggle(
                    title: "Mój widoczny cel",
                    detail: "np. Schudnięcie 5 kg",
                    bind: $draft.showGoal
                )
                toggle(
                    title: "Moje statystyki tygodniowe",
                    detail: "Średnie kcal, najczęstsze produkty",
                    bind: $draft.showWeeklyStats
                )
                toggle(
                    title: "Moje top przepisy",
                    detail: "Z Twojej książki kucharskiej",
                    bind: $draft.showRecipes
                )
            }
        }
    }

    private var sensitiveCard: some View {
        Card(background: Tokens.Palette.surface) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Image(systemName: "exclamationmark.lock.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("Wrażliwe dane")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text("This data is disabled by default. You only enable it if you consciously want to show it.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                toggle(
                    title: "Moja waga / wzrost",
                    detail: "Pokazuje aktualne wartości",
                    bind: $draft.showWeightAndHeight
                )
                toggle(
                    title: "Szczegóły posiłków",
                    detail: "What exactly you ate",
                    bind: $draft.showMealDetails
                )
            }
        }
    }

    private func toggle(title: LocalizedStringKey, detail: LocalizedStringKey, bind: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: bind) {
                Text(title)
                    .font(Tokens.Font.body)
            }
            .tint(Tokens.Palette.primary)
            Text(detail)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }
}
