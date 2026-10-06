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
                    LazyVStack(spacing: Tokens.Space.lg) {
                        hero
                        addModes
                        searchField
                        if state.searchResults.isEmpty {
                            emptyHint
                            myCodeButton
                        } else {
                            VStack(spacing: Tokens.Space.sm) {
                                ForEach(state.searchResults) { profile in
                                    searchRow(profile)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("Dodaj znajomego")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Zamknij"), action: onDismiss)
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
        ScreenBackground(mood: .social)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                Image(systemName: "person.2.badge.plus.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Palette.onPrimary)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            Tokens.Palette.primary
                        )
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Dodaj znajomego"))
                        .font(Tokens.Font.archivo(size: 28, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Znajdź osobę po username, wklej kod QR albo otwórz profil i wyślij zaproszenie."))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.lg)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55)
        )
    }

    private var addModes: some View {
        HStack(spacing: Tokens.Space.sm) {
            AddFriendModeCard(
                symbol: "at",
                title: L("Username"),
                subtitle: L("Wpisz nazwę, sprawdź profil, wyślij zaproszenie."),
                tint: Tokens.Palette.primary
            )
            Button {
                isMyCodePresented = true
            } label: {
                AddFriendModeCard(
                    symbol: "qrcode",
                    title: L("QR"),
                    subtitle: L("Pokaż swój kod albo wklej kod znajomego w wyszukiwarkę."),
                    tint: Tokens.Palette.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var myCodeButton: some View {
        Button {
            isMyCodePresented = true
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "qrcode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Pokaż mój kod"))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Udostępnij identyfikator w kilka sekund."))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Tokens.Palette.separator, lineWidth: 0.35)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
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
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !state.searchQuery.isEmpty {
                Button {
                    state.searchQuery = ""
                    Task { await state.runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.86)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 0.35)
        )
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Tokens.Palette.accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Tokens.Palette.accentSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Szukaj po imieniu albo username"))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Najpierw zobacz profil osoby, potem wyślij zaproszenie. To chroni przed pomyłką."))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.80)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55))
    }

    private func searchRow(_ profile: PublicProfile) -> some View {
        let status = state.connectionStatus(for: profile)
        let isAdding = addingProfileID == profile.id
        return HStack(spacing: Tokens.Space.sm) {
            Button {
                onOpenProfile(profile)
            } label: {
                FriendRow(profile: profile)
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    addingProfileID = profile.id
                    let didAdd = await state.sendRequest(to: profile)
                    addingProfileID = nil
                    if didAdd {
                        onOpenProfile(profile)
                    }
                }
            } label: {
                addButtonLabel(status: status, isAdding: isAdding)
            }
            .accessibilityLabel(Text(L("Wyślij zaproszenie")))
            .disabled(status != .none || isAdding)
        }
    }

    @ViewBuilder
    private func addButtonLabel(status: FriendsState.ConnectionStatus, isAdding: Bool) -> some View {
        let symbol: String = {
            if isAdding { return "hourglass" }
            switch status {
            case .none: return "person.crop.circle.badge.plus"
            case .outgoing: return "paperplane.fill"
            case .friend: return "checkmark"
            }
        }()
        let tint: Color = {
            switch status {
            case .none: return Tokens.Palette.primary
            case .outgoing: return Tokens.Palette.accent
            case .friend: return Tokens.Palette.success
            }
        }()
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(Circle().fill(tint.opacity(0.14)))
    }
}

private struct AddFriendModeCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(title)
                .font(Tokens.Font.manrope(16, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(subtitle)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .padding(Tokens.Space.md)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(
                Tokens.Palette.separator.opacity(0.55), lineWidth: 0.55)
        )
    }
}
