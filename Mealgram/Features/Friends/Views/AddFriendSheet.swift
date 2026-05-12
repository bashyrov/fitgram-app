import SwiftUI

/// Username search + QR code stub (we draw a QR icon for now — Vision-based
/// scanning lands when the social backend is wired and we know what payload
/// to encode).
struct AddFriendSheet: View {
    @Bindable var state: FriendsState
    let onDismiss: () -> Void

    @State private var isMyCodePresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
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
            .navigationTitle(Text("Dodaj znajomego"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
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

    private var myCodeButton: some View {
        Button {
            isMyCodePresented = true
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "qrcode")
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Pokaż mój kod")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(Tokens.Palette.primarySoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField(
                "Imię lub username",
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
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
    }

    private var emptyHint: some View {
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: "qrcode")
                    .foregroundStyle(Tokens.Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Szukaj po imieniu albo username")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Skanowanie kodu QR i deeplinki włączymy razem z backendem.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func searchRow(_ profile: PublicProfile) -> some View {
        HStack(spacing: Tokens.Space.md) {
            FriendRow(profile: profile)
            Button {
                Task { await state.sendRequest(to: profile) }
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22))
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
            }
            .accessibilityLabel(Text("Wyślij zaproszenie"))
        }
    }
}
