import SwiftUI

/// Znajomi tab — feed at the top (most actionable), pending requests
/// section, friend list at the bottom. Add button in the toolbar raises
/// the search/QR sheet.
struct FriendsRootView: View {
    @Bindable var state: FriendsState
    @Environment(ToastCenter.self) private var toastCenter

    @State var isAddPresented = false
    @State var isLeaderboardPresented = false
    @State var openedProfileID: String?
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    /// Trivial Identifiable wrapper so the sheet binding can present
    /// FriendProfileView when openedProfileID flips non-nil.
    private struct IdentifiedID: Identifiable {
        let value: String
        var id: String { value }
    }
    var yourStreak: Int = 0
    var yourDisplayName: String = ""
    var yourID: String = ""
    var friendService: (any FriendService)?

    var body: some View {
        NavigationStack {
            ZStack {
                friendsBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        friendsHeader
                        Color.clear.frame(height: 14)
                        friendsHero
                        if !state.incoming.isEmpty {
                            incomingCard
                        }
                        feedSection
                        friendsSection
                        friendHighlights
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 20)
                    .id(accentRaw)
                }
                .refreshable { await state.refresh() }
            }
            .navigationTitle(Text(L("Friends")))
            .toolbar(.hidden, for: .navigationBar)
            .task { await state.refresh() }
            .sheet(isPresented: $isAddPresented) {
                AddFriendSheet(
                    state: state,
                    onOpenProfile: { profile in
                        isAddPresented = false
                        openedProfileID = profile.id
                    },
                    onDismiss: { isAddPresented = false }
                )
            }
            .sheet(
                item: Binding(
                    get: { openedProfileID.map(IdentifiedID.init) },
                    set: { openedProfileID = $0?.value }
                )
            ) { wrapped in
                if let friendService {
                    FriendProfileView(
                        userID: wrapped.value,
                        viewerID: yourID,
                        service: friendService,
                        onDismiss: {
                            openedProfileID = nil
                            Task { await state.refresh() }
                        }
                    )
                }
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
        }
    }

    // MARK: - Sections

    private var friendsBackground: some View {
        Tokens.Palette.background.ignoresSafeArea()
    }

    /// Page header: big title + subtitle with leaderboard / add buttons (mockup "Znajomi").
    private var friendsHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Znajomi"))
                    .font(Tokens.Font.monoDisplay(30))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L("Streaki, reakcje i małe zwycięstwa ludzi, którzy trzymają rytm razem z Tobą."))
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
                    isAddPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Tokens.Mono.hi)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Tokens.Mono.hero))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Dodaj znajomego")))
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    private var friendsHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                MonoStat(label: L("dni serii"), value: "\(yourStreak)", dark: true)
                MonoStat(label: L("Friends"), value: "\(state.friends.count)", dark: true)
                MonoStat(label: L("nowa aktywność"), value: "\(state.feed.count)", dark: true)
            }
            HStack(spacing: 8) {
                MonoButton(title: L("Znajdź profil"), kind: .hi, icon: "magnifyingglass", height: 44) {
                    isAddPresented = true
                }
                Button {
                    isAddPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 14, weight: .bold))
                        Text(L("Pokaż kod"))
                            .lineLimit(1)
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

    private var incomingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(number: "01", title: L("Zaproszenia"), trailing: "\(state.incoming.count)")
            VStack(spacing: 8) {
                ForEach(state.incoming) { request in
                    requestRow(request)
                }
            }
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FriendInitialAvatar(name: request.fromUserID, size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    MonoLabel(text: L("Nowe zaproszenie"))
                    Text(String.localizedStringWithFormat(L("od %@"), request.fromUserID))
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                MonoButton(title: L("Odrzuć"), kind: .outline, height: 44) {
                    Task { await state.reject(request) }
                }
                MonoButton(title: L("Akceptuj"), kind: .dark, icon: "checkmark", height: 44) {
                    Task { await state.accept(request) }
                }
            }
        }
        .monoCard(padding: 16)
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(number: "02", title: L("Co u znajomych"))
            if state.feed.isEmpty {
                emptyStateCard(
                    symbol: "sparkles",
                    title: L("Cicho dzisiaj"),
                    message: L("Znajomi jeszcze nic dziś nie dodali. Wróć później albo wyślij zaproszenie.")
                ) {
                    isAddPresented = true
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(state.feed) { event in
                        FeedEventCard(event: event) { kind in
                            Task {
                                await state.toggleReaction(on: event, kind: kind)
                                toastCenter.success(
                                    L("Reakcja wysłana"),
                                    message: "\(kind.emoji) \(kind.label)"
                                )
                            }
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            openedProfileID = event.actorID
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                number: "03",
                title: String.localizedStringWithFormat(L("Twoi znajomi (%lld)"), state.friends.count)
            )
            if state.friends.isEmpty {
                emptyStateCard(
                    symbol: "person.2.fill",
                    title: L("Jeszcze bez znajomych"),
                    message: L("Dodaj pierwszą osobę, żeby widzieć jej streak, odznaki i reakcje.")
                ) {
                    isAddPresented = true
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(state.friends.enumerated()), id: \.element.id) { index, profile in
                        if index > 0 {
                            MonoRowDivider(inset: 16)
                        }
                        Button {
                            openedProfileID = profile.id
                        } label: {
                            FriendRow(profile: profile)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                openedProfileID = profile.id
                            } label: {
                                Label(L("Otwórz profil"), systemImage: "person.crop.circle")
                            }
                            Button(role: .destructive) {
                                Task { await state.unfriend(profile) }
                            } label: {
                                Label(L("Unfriend"), systemImage: "person.fill.xmark")
                            }
                        }
                    }
                }
                .monoRowsCard()
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

    private func emptyStateCard(
        symbol: String,
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: symbol, style: .track, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(message)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            MonoButton(title: L("Dodaj znajomego"), kind: .dark, icon: "plus", height: 46, action: action)
        }
        .monoCard(padding: 16)
    }
}
