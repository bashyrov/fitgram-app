import OSLog
import SwiftUI

// Profile sheet for a friend or anyone found in search — avatar header,
// identity tiles and tabs (Posty / Statystyki / Cele / Aktywność). The
// service honours the owner's privacy settings; the UI renders whatever
// survives the snapshot. Per-tab content lives in
// `FriendProfileView+*Tab.swift` extension files.
// swiftlint:disable:next type_body_length
struct FriendProfileView: View {
    let userID: String
    @Bindable var state: FriendsState
    let onDismiss: () -> Void
    /// Optional — when present, lets the user save a top-recipe to
    /// their own library.
    var onCopyRecipe: ((PublicRecipeReference) -> Void)?

    @Environment(ToastCenter.self) var toasts

    @State var snapshot: FriendProfileSnapshot?
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var activeTab: Tab = .posts
    @State private var isReportPresented: Bool = false
    @State private var reportReason: String = ""
    @State private var isBlockConfirmed: Bool = false
    @State private var isUnfriendConfirmed: Bool = false
    @State private var isWorking = false
    @State var authorPosts: AuthorPosts?

    private var viewerID: String { state.userRemoteID }
    private var service: any FriendService { state.service }
    var connection: FriendsState.ConnectionStatus { state.connectionStatus(for: userID) }

    enum Tab: Hashable, CaseIterable {
        case posts, stats, goals, activity

        var label: String {
            switch self {
            case .posts: return TL(pl: "Posty", en: "Posts", uk: "Пости", ru: "Посты", es: "Posts")
            case .stats: return L("Stats")
            case .goals: return L("Goals")
            case .activity: return L("Activity")
            }
        }

        var symbol: String {
            switch self {
            case .posts: return "text.bubble.fill"
            case .stats: return "chart.bar.fill"
            case .goals: return "target"
            case .activity: return "bolt.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                profileBackground
                if isLoading {
                    ScrollView {
                        VStack(spacing: 12) {
                            LoadingShimmer(cornerRadius: 26).frame(height: 96)
                            LoadingShimmer(cornerRadius: 20).frame(height: 80)
                            LoadingShimmer(cornerRadius: 16).frame(height: 46)
                            LoadingShimmer(cornerRadius: 24).frame(height: 180)
                        }
                        .padding(Tokens.Space.screenPadding)
                    }
                } else if let snapshot {
                    content(snapshot)
                } else {
                    fallback
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Tokens.Palette.background, for: .navigationBar)
            .toolbar { toolbarContent }
            .task { await load() }
            .confirmationDialog(
                L("Block this user?"),
                isPresented: $isBlockConfirmed,
                titleVisibility: .visible
            ) {
                Button(L("Block"), role: .destructive) { Task { await block() } }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("You'll lose the connection and they won't see your profile."))
            }
            .confirmationDialog(
                L("Unfriend?"),
                isPresented: $isUnfriendConfirmed,
                titleVisibility: .visible
            ) {
                Button(L("Unfriend"), role: .destructive) {
                    Task {
                        await state.unfriend(userID)
                        Haptics.warning()
                        onDismiss()
                    }
                }
                Button(L("Cancel"), role: .cancel) {}
            } message: {
                Text(L("You can send a new invitation any time."))
            }
            .sheet(isPresented: $isReportPresented) { reportSheet }
        }
        .toastSurface()
    }

    private var profileBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            MonoNavIcon(systemName: "xmark", accessibilityLabel: L("Close"), action: onDismiss)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 6) {
                if connection == .friend {
                    Button {
                        isUnfriendConfirmed = true
                    } label: {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L("Unfriend")))
                    .accessibilityIdentifier("friend.profile.unfriend")
                }
                moreMenu
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            Button(role: .destructive) {
                isBlockConfirmed = true
            } label: {
                Label(L("Block"), systemImage: "hand.raised.fill")
            }
            Button(role: .destructive) {
                isReportPresented = true
            } label: {
                Label(L("Report"), systemImage: "exclamationmark.bubble.fill")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .accessibilityLabel(Text(L("More")))
    }

    @ViewBuilder
    private func content(_ snapshot: FriendProfileSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(snapshot)
                Color.clear.frame(height: 16)
                if snapshot.isRestricted {
                    restrictedCard
                    Color.clear.frame(height: 14)
                    postsTab()
                } else {
                    identityTiles(snapshot)
                    Color.clear.frame(height: 14)
                    tabBar
                    Color.clear.frame(height: 12)
                    Group {
                        switch activeTab {
                        case .posts: postsTab()
                        case .stats: statsTab(snapshot)
                        case .goals: goalsTab(snapshot)
                        case .activity: activityTab(snapshot)
                        }
                    }
                    .transition(.opacity)
                    .animation(Tokens.Motion.gentle, value: activeTab)
                    if !snapshot.hasAnyShared && activeTab != .posts {
                        Color.clear.frame(height: 10)
                        privacyHint
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, 24)
        }
        .refreshable { await load() }
        .safeAreaInset(edge: .bottom) {
            if userID != viewerID, connection != .friend {
                actionBar
            }
        }
    }

    // MARK: - Hero (avatar + name row)

    @ViewBuilder
    private func hero(_ snapshot: FriendProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                avatarHero(snapshot)
                VStack(alignment: .leading, spacing: 3) {
                    SocialNameLabel(
                        name: snapshot.publicName,
                        isPremium: snapshot.isPremium,
                        font: Tokens.Font.monoDisplay(26),
                        markHeight: 20
                    )
                    if let subtitle = heroSubtitle(snapshot) {
                        Text(subtitle)
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if let bio = snapshot.bio {
                Text(bio)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    private func avatarHero(_ snapshot: FriendProfileSnapshot) -> some View {
        Text(initial(for: snapshot.publicName))
            .font(Tokens.Font.monoNumber(30))
            .foregroundStyle(Tokens.Mono.hi)
            .frame(width: 72, height: 72)
            .background(Circle().fill(Tokens.Mono.hero))
    }

    /// "@user · W Fitgram od …" line under the name.
    private func heroSubtitle(_ snapshot: FriendProfileSnapshot) -> String? {
        var parts: [String] = []
        if let since = snapshot.memberSinceDate {
            let formatted = since.formatted(.dateTime.month(.wide).year())
            parts.append(String.localizedStringWithFormat(L("Fitgram-er since %@"), formatted))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Mockup tiles: Seria · Odznaki · Poziom.
    private func identityTiles(_ snapshot: FriendProfileSnapshot) -> some View {
        HStack(spacing: 8) {
            identityTile(label: L("Seria"), value: snapshot.currentStreak.map { "\($0)" } ?? "—")
            identityTile(label: L("Odznaki"), value: snapshot.achievements.map { "\($0.count)" } ?? "—")
            identityTile(label: L("Poziom"), value: snapshot.level.map { "\($0.number)" } ?? "—")
        }
    }

    private func identityTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: label)
            Text(value)
                .font(Tokens.Font.monoNumber(26))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .monoTile()
        .accessibilityElement(children: .combine)
    }

    private func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Segmented tabs

    private var tabBar: some View {
        MonoSegmented(
            selection: $activeTab,
            options: Tab.allCases.map { (value: $0, title: $0.label) }
        )
    }

    // MARK: - Bottom action bar

    /// Shown only for people who aren't friends yet.
    private var actionBar: some View {
        MonoBottomBar {
            switch connection {
            case .none, .friend:
                MonoButton(
                    title: TL(
                        pl: "Dodaj do znajomych", en: "Add friend", uk: "Додати в друзі", ru: "Добавить в друзья",
                        es: "Añadir a amigos"),
                    kind: .dark, icon: "person.badge.plus", height: 50
                ) {
                    work {
                        if await state.sendRequest(to: userID) {
                            Haptics.success()
                            toasts.success(
                                TL(
                                    pl: "Zaproszenie wysłane", en: "Request sent", uk: "Запит надіслано",
                                    ru: "Заявка отправлена", es: "Solicitud enviada"),
                                message: snapshot?.publicName)
                        }
                    }
                }
                .accessibilityIdentifier("friend.profile.add")
            case .outgoing:
                MonoButton(
                    title: TL(
                        pl: "Zaproszenie wysłane · cofnij", en: "Request sent · cancel",
                        uk: "Запит надіслано · скасувати", ru: "Заявка отправлена · отменить",
                        es: "Solicitud enviada · cancelar"),
                    kind: .outline, icon: "paperplane.fill", height: 50
                ) {
                    work { await state.cancelRequest(to: userID) }
                }
            case .incoming:
                HStack(spacing: 8) {
                    MonoButton(title: L("Odrzuć"), kind: .outline, height: 50) {
                        work { await state.respondToRequest(from: userID, accept: false) }
                    }
                    MonoButton(title: L("Akceptuj"), kind: .dark, icon: "checkmark", height: 50) {
                        work {
                            await state.respondToRequest(from: userID, accept: true)
                            Haptics.success()
                            await load()
                        }
                    }
                }
            }
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.6 : 1)
    }

    private func work(_ action: @escaping () async -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await action()
            isWorking = false
        }
    }

    private var fallback: some View {
        VStack(spacing: 12) {
            MonoIconBox(systemName: "lock", style: .track, size: 56)
            Text(loadError ?? L("Profil niedostępny."))
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private var reportSheet: some View {
        NavigationStack {
            ZStack {
                profileBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        MonoField(label: L("Powód zgłoszenia"), multiline: true) {
                            TextEditor(text: $reportReason)
                                .scrollContentBackground(.hidden)
                                .font(Tokens.Font.manrope(15, weight: 600))
                                .frame(minHeight: 120)
                        }
                        MonoHint(
                            text: L("Zgłoszenie trafia do naszego zespołu moderacji. Nie informujemy o decyzjach."))
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, 16)
                }
            }
            .monoNavigationTitle(L("Report"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel")) { isReportPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Wyślij")) {
                        Task { await report() }
                    }
                    .disabled(reportReason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        if snapshot == nil { isLoading = true }
        do {
            snapshot = try await service.snapshot(forUserID: userID, viewer: viewerID)
        } catch {
            loadError = L("Nie udało się załadować profilu.")
            Logger.persistence.error("Snapshot load failed: \(String(describing: error))")
        }
        isLoading = false
        authorPosts = await state.posts(by: userID)
    }

    private func block() async {
        try? await service.block(userID, as: viewerID)
        Haptics.warning()
        onDismiss()
    }

    private func report() async {
        try? await service.report(userID, reason: reportReason, as: viewerID)
        Haptics.success()
        isReportPresented = false
        toasts.info(
            L("Zgłoszenie wysłane"),
            message: L("Thanks — our moderation team will look into it.")
        )
        reportReason = ""
    }
}
