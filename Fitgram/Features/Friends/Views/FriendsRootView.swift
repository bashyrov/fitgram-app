import SwiftUI

/// Znajomi tab: friends' posts with likes. The "+" opens the friends &
/// requests window (with a dot while requests wait); Premium users write
/// posts from the hero card.
struct FriendsRootView: View {
    @Bindable var state: FriendsState
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    @Environment(ToastCenter.self) private var toastCenter

    @State var isHubPresented = false
    @State var isLeaderboardPresented = false
    @State private var isComposerPresented = false
    @State var isUsernamePickerPresented = false
    @State var openedProfile: ProfileSheetID?
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    var user: User?
    var yourStreak: Int = 0
    var yourDisplayName: String = ""
    var yourID: String = ""

    var isPremium: Bool { entitlementsStore.current.isPremium }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        friendsHeader
                        Color.clear.frame(height: 14)
                        friendsHero
                        if state.needsUsername {
                            usernameCard.padding(.top, 10)
                        }
                        postsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 20)
                    .id(accentRaw)
                }
                .refreshable { await state.refresh() }
            }
            .navigationTitle(Text(L("Friends")))
            .toolbar(.hidden, for: .navigationBar)
            .task {
                state.myDisplayName = yourDisplayName
                await state.setPremium(isPremium)
                await state.refresh()
                if let chosen = await state.loadIdentity(localUsername: user?.username) {
                    persistUsername(chosen)
                }
            }
            .onChange(of: isPremium) { _, value in
                Task {
                    await state.setPremium(value)
                    await state.refreshPosts()
                }
            }
            .sheet(isPresented: $isHubPresented) {
                FriendsHubSheet(state: state, onDismiss: { isHubPresented = false })
            }
            .sheet(item: $openedProfile) { route in
                FriendProfileView(
                    userID: route.id,
                    state: state,
                    onDismiss: {
                        openedProfile = nil
                        Task { await state.refresh() }
                    }
                )
            }
            .sheet(isPresented: $isLeaderboardPresented) {
                LeaderboardView(
                    entries: Leaderboard.from(
                        friends: state.friends,
                        you: yourID.isEmpty
                            ? nil
                            : .init(id: yourID, displayName: yourDisplayName, streak: yourStreak)
                    ),
                    onDismiss: { isLeaderboardPresented = false }
                )
            }
            .sheet(isPresented: $isComposerPresented) {
                PostComposerSheet(
                    state: state,
                    calorieGoalKcal: user?.dailyCalorieGoalKcal,
                    onDismiss: { isComposerPresented = false }
                )
            }
            .sheet(isPresented: $isUsernamePickerPresented) {
                UsernamePickerSheet(
                    state: state,
                    suggestion: UsernamePolicy.suggestion(from: yourDisplayName),
                    onDone: { chosen in
                        persistUsername(chosen)
                        isUsernamePickerPresented = false
                        toastCenter.success(
                            TL(
                                pl: "Username zapisany", en: "Username saved", uk: "Username збережено",
                                ru: "Username сохранён", es: "Usuario guardado"),
                            message: "@\(chosen)")
                    },
                    onDismiss: { isUsernamePickerPresented = false }
                )
            }
        }
    }

    // MARK: - Header + hero

    /// Page header: big title + subtitle with leaderboard / friends buttons.
    private var friendsHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Znajomi"))
                    .font(Tokens.Font.monoDisplay(30))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Posty, makro i małe zwycięstwa ludzi, którzy trzymają rytm razem z Tobą.",
                        en: "Posts, macros and small wins from people keeping the rhythm with you.",
                        uk: "Пости, макро й маленькі перемоги людей, які тримають ритм разом з тобою.",
                        ru: "Посты, макро и маленькие победы людей, которые держат ритм вместе с тобой.",
                        es: "Publicaciones, macros y pequeñas victorias de quienes mantienen el ritmo contigo.")
                )
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .frame(maxWidth: 250, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button {
                    isLeaderboardPresented = true
                } label: {
                    Image(systemName: "trophy")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Tablica wyników")))
                Button {
                    isHubPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Tokens.Mono.hi)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Tokens.Mono.hero))
                        .overlay(alignment: .topTrailing) { requestsBadge }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(
                        TL(
                            pl: "Znajomi i zaproszenia", en: "Friends and requests", uk: "Друзі й запити",
                            ru: "Друзья и заявки", es: "Amigos y solicitudes"))
                )
                .accessibilityValue(Text(state.incoming.isEmpty ? "" : "\(state.incoming.count)"))
                .accessibilityIdentifier("friends.hub.open")
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    /// Accent dot with the number of waiting requests.
    @ViewBuilder
    private var requestsBadge: some View {
        let count = state.incoming.count
        if count > 0 {
            Text(verbatim: count > 9 ? "9+" : "\(count)")
                .font(Tokens.Font.manrope(10, weight: 800))
                .foregroundStyle(Tokens.Mono.onAccent)
                .padding(.horizontal, 4)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Tokens.Mono.accent))
                .overlay(Capsule().stroke(Tokens.Palette.background, lineWidth: 2))
                .offset(x: 4, y: -3)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private var friendsHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                MonoStat(label: L("dni serii"), value: "\(yourStreak)", dark: true)
                MonoStat(label: L("Friends"), value: "\(state.friends.count)", dark: true)
                MonoStat(
                    label: TL(
                        pl: "posty dziś", en: "posts today", uk: "пости сьогодні", ru: "посты сегодня",
                        es: "publicaciones hoy"),
                    value: "\(state.postsPublishedToday)/\(PostLimits.dailyMax)", dark: true)
            }
            HStack(spacing: 8) {
                MonoButton(
                    title: TL(
                        pl: "Napisz post", en: "Write a post", uk: "Написати пост", ru: "Написать пост",
                        es: "Publicar"),
                    kind: .hi,
                    icon: isPremium ? "square.and.pencil" : "lock.fill",
                    height: 44
                ) {
                    openComposer()
                }
                .accessibilityIdentifier("friends.post.compose")
                Button {
                    isHubPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .bold))
                        Text(TL(pl: "Znajdź", en: "Find", uk: "Знайти", ru: "Найти", es: "Buscar")).lineLimit(1)
                    }
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(Tokens.Mono.heroLine, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    // MARK: - Posts

    @ViewBuilder
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                number: "01",
                title: TL(
                    pl: "Posty znajomych", en: "Friends' posts", uk: "Пости друзів", ru: "Посты друзей",
                    es: "Publicaciones de amigos"))
            if !isPremium {
                premiumCard.padding(.bottom, 10)
            }
            if !state.postsLoaded {
                VStack(spacing: 10) {
                    LoadingShimmer(cornerRadius: 24).frame(height: 160)
                    LoadingShimmer(cornerRadius: 24).frame(height: 220)
                }
            } else if state.posts.isEmpty {
                emptyStateCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(state.posts) { post in
                        PostCard(
                            post: post,
                            isMine: post.authorID == state.userRemoteID,
                            onLike: { Task { await state.toggleLike(post) } },
                            onOpenAuthor: post.authorID == state.userRemoteID
                                ? nil : { openedProfile = ProfileSheetID(id: post.authorID) },
                            onDelete: { Task { await state.deletePost(post) } }
                        )
                    }
                }
            }
        }
    }

    /// Mockup `sec(n, title, trailing)`: numbered display title with hairline, 28 pt above, 12 pt below.
    func sectionHeader(number: String?, title: String, trailing: String? = nil) -> some View {
        MonoSectionHeader(number: number, title: title) {
            if let trailing {
                MonoLabel(text: trailing)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Actions

    private func openComposer() {
        guard isPremium else {
            paywallCoordinator.present(.socialPosts)
            return
        }
        guard state.postsLeftToday > 0 else {
            toastCenter.info(
                TL(
                    pl: "Limit na dziś", en: "Today's limit", uk: "Ліміт на сьогодні", ru: "Лимит на сегодня",
                    es: "Límite de hoy"),
                message: PostComposerSheet.message(for: .dailyLimitReached))
            return
        }
        isComposerPresented = true
    }

    private func persistUsername(_ username: String) {
        guard let user, user.username != username else { return }
        user.username = username
        user.updatedAt = Date()
        try? user.modelContext?.save()
    }
}
