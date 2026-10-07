import SwiftUI

/// Username + QR/deep-link lookup. Camera scanning can land on top of this
/// by piping the scanned `fitgram://friend/...` payload into `searchQuery`.
struct AddFriendSheet: View {
    @Bindable var state: FriendsState
    let onOpenProfile: (PublicProfile) -> Void
    let onDismiss: () -> Void

    @State private var isMyCodePresented = false
    @State private var addingProfileID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                addBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoH1(
                            text: L("Dodaj znajomego"),
                            sub: L("Znajdź osobę po username, wklej kod QR albo otwórz profil i wyślij zaproszenie.")
                        )
                        Color.clear.frame(height: 16)
                        searchField
                        Color.clear.frame(height: 12)
                        addModes
                        if state.searchResults.isEmpty {
                            Color.clear.frame(height: 12)
                            emptyHint
                        } else {
                            resultHeader
                            VStack(spacing: 8) {
                                ForEach(state.searchResults) { profile in
                                    searchRow(profile)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .monoNavigationTitle(L("Dodaj znajomego"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
            .sheet(isPresented: $isMyCodePresented) {
                MyCodeSheet(
                    userID: state.userRemoteID,
                    displayName: nil,
                    onDismiss: { isMyCodePresented = false }
                )
            }
        }
    }

    private var addBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    /// Mockup rows: Username / QR / Pokaż mój kod.
    private var addModes: some View {
        VStack(spacing: 0) {
            MonoRow(
                icon: "person",
                iconStyle: .track,
                title: L("Username"),
                sub: L("Wpisz nazwę, sprawdź profil, wyślij zaproszenie.")
            ) {
                EmptyView()
            }
            MonoRowDivider()
            Button {
                isMyCodePresented = true
            } label: {
                MonoRow(
                    icon: "qrcode",
                    iconStyle: .track,
                    title: L("QR"),
                    sub: L("Pokaż swój kod albo wklej kod znajomego w wyszukiwarkę.")
                ) {
                    EmptyView()
                }
            }
            .buttonStyle(.plain)
            MonoRowDivider()
            myCodeButton
        }
        .monoRowsCard()
    }

    private var myCodeButton: some View {
        Button {
            isMyCodePresented = true
        } label: {
            MonoRow(
                icon: "square.and.arrow.up",
                iconStyle: .dark,
                title: L("Pokaż mój kod"),
                sub: L("Udostępnij identyfikator w kilka sekund.")
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.muted)
            TextField(
                L("Imię, username lub kod QR"),
                text: Binding(
                    get: { state.searchQuery },
                    set: { value in
                        state.searchQuery = value
                        Task { await state.runSearch() }
                    }
                )
            )
            .font(Tokens.Font.manrope(15, weight: 600))
            .foregroundStyle(Tokens.Palette.ink)
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !state.searchQuery.isEmpty {
                Button {
                    state.searchQuery = ""
                    Task { await state.runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .accessibilityLabel(Text(L("Wyczyść")))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Tokens.Palette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Tokens.Mono.line2, lineWidth: 1)
        )
    }

    private var resultHeader: some View {
        MonoSectionHeader(title: TL(pl: "Wynik", en: "Result", uk: "Результат", ru: "Результат", es: "Resultado"))
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 12)
    }

    private var emptyHint: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "sparkles", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Szukaj po imieniu albo username"))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L("Najpierw zobacz profil osoby, potem wyślij zaproszenie. To chroni przed pomyłką."))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    private func searchRow(_ profile: PublicProfile) -> some View {
        let status = state.connectionStatus(for: profile)
        let isAdding = addingProfileID == profile.id
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                onOpenProfile(profile)
            } label: {
                HStack(spacing: 12) {
                    FriendInitialAvatar(name: profile.displayName, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(Tokens.Font.manrope(16, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                        Text(resultSubtitle(profile))
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    MonoChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L("Otwórz profil")))
            .accessibilityValue(Text(profile.displayName))

            Text(L("Najpierw zobacz profil osoby, potem wyślij zaproszenie. To chroni przed pomyłką."))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)

            MonoButton(
                title: L("Wyślij zaproszenie"),
                kind: status == .none ? .dark : .outline,
                icon: addSymbol(status: status, isAdding: isAdding),
                height: 46
            ) {
                Task {
                    addingProfileID = profile.id
                    let didAdd = await state.sendRequest(to: profile)
                    addingProfileID = nil
                    if didAdd {
                        onOpenProfile(profile)
                    }
                }
            }
            .accessibilityLabel(Text(L("Wyślij zaproszenie")))
            .disabled(status != .none || isAdding)
        }
        .monoCard(padding: 16)
    }

    private func resultSubtitle(_ profile: PublicProfile) -> String {
        if let streak = profile.currentStreak, streak > 0, profile.sharesStreak {
            return "\(L("Seria")) · \(streak)"
        }
        if let count = profile.achievementCount, profile.sharesAchievements {
            return String.localizedStringWithFormat(L("%lld badges"), count)
        }
        return "Fitgram"
    }

    private func addSymbol(status: FriendsState.ConnectionStatus, isAdding: Bool) -> String {
        if isAdding { return "hourglass" }
        switch status {
        case .none: return "plus"
        case .outgoing: return "paperplane.fill"
        case .friend: return "checkmark"
        }
    }
}
