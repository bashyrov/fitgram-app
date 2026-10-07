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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: L("Prywatność najpierw"),
                        sub: L(
                            "By default, we don't share anything. Enable only what you actually want to show your friends."
                        ),
                        kicker: L("Privacy")
                    )
                    sectionHeader(number: "01", title: L("Kto może zobaczyć Twój profil"), top: 4)
                    visibilityCard
                    if draft.visibility != .privateOnly {
                        sectionHeader(number: "02", title: L("What to share"), top: 12)
                        toggleCard
                        sectionHeader(number: "03", title: L("Wrażliwe dane"), top: 12, bottom: 8)
                        MonoHint(
                            text: L(
                                "This data is disabled by default. You only enable it if you consciously want to show it."
                            )
                        )
                        .padding(.bottom, 10)
                        sensitiveCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Privacy"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save")) {
                        store.replace(draft)
                        Haptics.success()
                        onDismiss()
                    }
                }
            }
        }
    }

    /// `sec(n, title, '', mt)` — 16 pt built into the header plus `top`.
    private func sectionHeader(number: String, title: String, top: CGFloat, bottom: CGFloat = 12) -> some View {
        MonoSectionHeader(number: number, title: title)
            .padding(.horizontal, 6)
            .padding(.top, top)
            .padding(.bottom, bottom)
    }

    /// rows(inset 16): three visibility options, a check marks the selected one.
    private var visibilityCard: some View {
        VStack(spacing: 0) {
            visibilityRow(.privateOnly, label: L("Tylko ja"), subtitle: L("Profil ukryty dla wszystkich"))
            MonoRowDivider(inset: 16)
            visibilityRow(.friendsOnly, label: L("Tylko znajomi"), subtitle: L("Widoczne dla osób, które dodały Cię"))
            MonoRowDivider(inset: 16)
            visibilityRow(
                .publicLink, label: L("Wszyscy z linkiem"), subtitle: L("Anyone with your code can see your profile"))
        }
        .monoRowsCard()
    }

    private func visibilityRow(
        _ option: PrivacySettings.Visibility,
        label: String,
        subtitle: String
    ) -> some View {
        let isSelected = draft.visibility == option
        return Button {
            Haptics.selection()
            withAnimation(Tokens.Motion.quick) {
                draft.visibility = option
            }
        } label: {
            MonoRow(title: label, sub: subtitle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Tokens.Palette.ink)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var toggleCard: some View {
        VStack(spacing: 0) {
            toggle(title: L("Mój streak"), detail: L("np. 🔥 30 dni"), bind: $draft.showStreak)
            MonoRowDivider(inset: 16)
            toggle(title: L("Mój poziom"), detail: L("np. Lvl 12 — Pro"), bind: $draft.showLevel)
            MonoRowDivider(inset: 16)
            toggle(
                title: L("Moje achievements"), detail: L("Odznaki, które zdobyłeś/aś"), bind: $draft.showAchievements)
            MonoRowDivider(inset: 16)
            toggle(title: L("Mój widoczny cel"), detail: L("np. Schudnięcie 5 kg"), bind: $draft.showGoal)
            MonoRowDivider(inset: 16)
            toggle(
                title: L("Moje statystyki tygodniowe"),
                detail: L("Średnie kcal, najczęstsze produkty"),
                bind: $draft.showWeeklyStats
            )
            MonoRowDivider(inset: 16)
            toggle(title: L("Moje top przepisy"), detail: L("Z Twojej książki kucharskiej"), bind: $draft.showRecipes)
        }
        .monoRowsCard()
    }

    private var sensitiveCard: some View {
        VStack(spacing: 0) {
            toggle(
                title: L("Moja waga / wzrost"),
                detail: L("Pokazuje aktualne wartości"),
                bind: $draft.showWeightAndHeight
            )
            MonoRowDivider(inset: 16)
            toggle(title: L("Szczegóły posiłków"), detail: L("What exactly you ate"), bind: $draft.showMealDetails)
        }
        .monoRowsCard()
    }

    /// `toggle_row(title)` — Mono switch as trailing view.
    private func toggle(title: String, detail: String, bind: Binding<Bool>) -> some View {
        MonoRow(title: title, sub: detail) {
            Toggle(title, isOn: bind)
                .labelsHidden()
                .toggleStyle(MonoToggleStyle())
                .fixedSize()
        }
    }
}
