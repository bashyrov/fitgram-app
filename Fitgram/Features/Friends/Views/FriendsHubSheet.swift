import SwiftUI

/// The "+" window on Znajomi: incoming requests (accept / decline), sent
/// requests, the friends list and people search.
struct FriendsHubSheet: View {
    @Bindable var state: FriendsState
    let onDismiss: () -> Void

    @State private var isMyCodePresented = false
    @State private var busyIDs: Set<String> = []
    @State private var openedProfile: ProfileSheetID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: TL(
                            pl: "Znajomi", en: "Friends", uk: "Друзі", ru: "Друзья", es: "Amigos"),
                        sub: TL(
                            pl: "Zaproszenia, Twoi znajomi i wyszukiwanie po username.",
                            en: "Requests, your friends and search by username.",
                            uk: "Запити, твої друзі й пошук за username.",
                            ru: "Заявки, твои друзья и поиск по username.",
                            es: "Solicitudes, tus amigos y búsqueda por usuario.")
                    )
                    Color.clear.frame(height: 14)
                    searchField
                    if !state.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                        searchResults
                    } else {
                        requestsSection
                        if !state.outgoing.isEmpty { sentSection }
                        friendsSection
                        codeSection
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(TL(pl: "Znajomi", en: "Friends", uk: "Друзі", ru: "Друзья", es: "Amigos"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Zamknij"), action: onDismiss)
                }
            }
            .refreshable { await state.refresh() }
            .sheet(item: $openedProfile) { route in
                FriendProfileView(userID: route.id, state: state) {
                    openedProfile = nil
                }
            }
            .sheet(isPresented: $isMyCodePresented) {
                MyCodeSheet(
                    userID: state.userRemoteID,
                    displayName: state.myUsername.map { "@\($0)" },
                    onDismiss: { isMyCodePresented = false }
                )
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.muted)
            TextField(
                TL(
                    pl: "@username, imię albo kod QR", en: "@username, name or QR code",
                    uk: "@username, ім'я або QR-код",
                    ru: "@username, имя или QR-код", es: "@usuario, nombre o código QR"),
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
            .autocorrectionDisabled()
            .submitLabel(.search)
            .accessibilityIdentifier("friends.hub.search")
            if !state.searchQuery.isEmpty {
                Button {
                    state.searchQuery = ""
                    Task { await state.runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Tokens.Mono.muted)
                }
                .accessibilityLabel(Text(L("Wyczyść")))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Tokens.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Tokens.Mono.line2, lineWidth: 1))
    }

    @ViewBuilder
    private var searchResults: some View {
        header(title: TL(pl: "Wyniki", en: "Results", uk: "Результати", ru: "Результаты", es: "Resultados"))
        if state.searchResults.isEmpty {
            MonoHint(
                text: TL(
                    pl: "Nikogo nie znaleziono. Sprawdź pisownię username.",
                    en: "No one found. Check the username spelling.",
                    uk: "Нікого не знайдено. Перевір написання username.",
                    ru: "Никого не найдено. Проверь написание username.",
                    es: "No se encontró a nadie. Revisa el nombre de usuario."))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(state.searchResults.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { MonoRowDivider(inset: 16) }
                    personRow(profile) { connectionButton(for: profile) }
                }
            }
            .monoRowsCard()
        }
    }

    // MARK: - Requests

    @ViewBuilder
    private var requestsSection: some View {
        header(
            number: "01",
            title: TL(pl: "Zaproszenia", en: "Requests", uk: "Запити", ru: "Заявки", es: "Solicitudes"),
            trailing: state.incoming.isEmpty ? nil : "\(state.incoming.count)")
        if state.incoming.isEmpty {
            MonoHint(
                text: TL(
                    pl: "Brak nowych zaproszeń.", en: "No new requests.", uk: "Нових запитів немає.",
                    ru: "Новых заявок нет.", es: "No hay solicitudes nuevas."))
        } else {
            VStack(spacing: 8) {
                ForEach(state.incoming) { request in
                    incomingRow(request)
                }
            }
        }
    }

    private func incomingRow(_ request: FriendRequest) -> some View {
        let profile = request.counterpart
        let name = profile?.publicName ?? L("Znajomy")
        let isBusy = busyIDs.contains(request.fromUserID)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                openProfile(request.fromUserID)
            } label: {
                HStack(spacing: 12) {
                    FriendInitialAvatar(name: name, size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        SocialNameLabel(name: name, isPremium: profile?.isPremium ?? false)
                        Text(
                            request.createdAt.formatted(.relative(presentation: .named))
                        )
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
            HStack(spacing: 8) {
                MonoButton(title: L("Odrzuć"), kind: .outline, height: 44) {
                    run(request.fromUserID) { await state.reject(request) }
                }
                MonoButton(title: L("Akceptuj"), kind: .dark, icon: "checkmark", height: 44) {
                    run(request.fromUserID) {
                        await state.accept(request)
                        Haptics.success()
                    }
                }
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.5 : 1)
        }
        .monoCard(padding: 16)
    }

    @ViewBuilder
    private var sentSection: some View {
        header(
            title: TL(pl: "Wysłane", en: "Sent", uk: "Надіслані", ru: "Отправленные", es: "Enviadas"),
            trailing: "\(state.outgoing.count)")
        VStack(spacing: 0) {
            ForEach(Array(state.outgoing.enumerated()), id: \.element.id) { index, request in
                if index > 0 { MonoRowDivider(inset: 16) }
                let profile = request.counterpart
                personRow(
                    profile ?? Self.placeholder(id: request.toUserID)
                ) {
                    Button {
                        run(request.toUserID) { await state.cancelRequest(to: request.toUserID) }
                    } label: {
                        Text(TL(pl: "Cofnij", en: "Cancel", uk: "Скасувати", ru: "Отменить", es: "Cancelar"))
                            .font(Tokens.Font.manrope(13, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .monoRowsCard()
    }

    // MARK: - Friends

    @ViewBuilder
    private var friendsSection: some View {
        header(
            number: "02",
            title: TL(pl: "Twoi znajomi", en: "Your friends", uk: "Твої друзі", ru: "Твои друзья", es: "Tus amigos"),
            trailing: "\(state.friends.count)")
        if state.friends.isEmpty {
            MonoHint(
                text: TL(
                    pl: "Jeszcze nikogo. Wyszukaj znajomego po username albo pokaż swój kod.",
                    en: "No one yet. Search a friend by username or show your code.",
                    uk: "Поки нікого. Знайди друга за username або покажи свій код.",
                    ru: "Пока никого. Найди друга по username или покажи свой код.",
                    es: "Aún nadie. Busca a un amigo por usuario o muestra tu código."))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(state.friends.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { MonoRowDivider(inset: 16) }
                    personRow(profile) { MonoChevron() }
                }
            }
            .monoRowsCard()
        }
    }

    @ViewBuilder
    private var codeSection: some View {
        header(number: "03", title: TL(pl: "Mój kod", en: "My code", uk: "Мій код", ru: "Мой код", es: "Mi código"))
        Button {
            isMyCodePresented = true
        } label: {
            MonoRow(
                icon: "qrcode",
                iconStyle: .dark,
                title: L("Pokaż mój kod"),
                sub: state.myUsername.map { "@\($0)" } ?? L("Udostępnij identyfikator w kilka sekund.")
            ) {
                MonoChevron()
            }
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    // MARK: - Rows

    private func personRow<Trailing: View>(
        _ profile: PublicProfile,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                openProfile(profile.id)
            } label: {
                HStack(spacing: 12) {
                    FriendInitialAvatar(name: profile.publicName, size: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        SocialNameLabel(name: profile.publicName, isPremium: profile.isPremium)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            trailing()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func connectionButton(for profile: PublicProfile) -> some View {
        let isBusy = busyIDs.contains(profile.id)
        switch state.connectionStatus(for: profile) {
        case .friend:
            pill(TL(pl: "Znajomy", en: "Friend", uk: "Друг", ru: "Друг", es: "Amigo"), icon: "checkmark", filled: false)
        case .outgoing:
            pill(
                TL(pl: "Wysłano", en: "Sent", uk: "Надіслано", ru: "Отправлено", es: "Enviada"),
                icon: "paperplane.fill", filled: false)
        case .incoming:
            Button {
                run(profile.id) { await state.respondToRequest(from: profile.id, accept: true) }
            } label: {
                pill(L("Akceptuj"), icon: "checkmark", filled: true)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        case .none:
            Button {
                run(profile.id) {
                    if await state.sendRequest(to: profile) { Haptics.success() }
                }
            } label: {
                pill(TL(pl: "Dodaj", en: "Add", uk: "Додати", ru: "Добавить", es: "Añadir"), icon: "plus", filled: true)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .opacity(isBusy ? 0.5 : 1)
            .accessibilityIdentifier("friends.hub.add.\(profile.id)")
        }
    }

    private func pill(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .heavy))
            Text(title).lineLimit(1)
        }
        .font(Tokens.Font.manrope(13, weight: 800))
        .foregroundStyle(filled ? Tokens.Mono.hi : Tokens.Mono.muted)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(filled ? Tokens.Mono.hero : Tokens.Mono.track))
        .fixedSize()
    }

    private func header(number: String? = nil, title: String, trailing: String? = nil) -> some View {
        MonoSectionHeader(number: number, title: title) {
            if let trailing { MonoLabel(text: trailing) }
        }
        .padding(.horizontal, 6)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func openProfile(_ id: String) {
        openedProfile = ProfileSheetID(id: id)
    }

    private func run(_ id: String, _ work: @escaping () async -> Void) {
        guard !busyIDs.contains(id) else { return }
        busyIDs.insert(id)
        Task {
            await work()
            busyIDs.remove(id)
        }
    }

    private static func placeholder(id: String) -> PublicProfile {
        PublicProfile(
            id: id, displayName: L("Znajomy"), avatarURL: nil, sharesStreak: false, sharesAchievements: false,
            currentStreak: nil, achievementCount: nil)
    }
}

/// Sheet route for a profile opened by user id.
struct ProfileSheetID: Identifiable, Hashable {
    let id: String
}
