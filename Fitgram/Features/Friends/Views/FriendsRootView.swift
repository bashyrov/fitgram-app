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
                    LazyVStack(spacing: Tokens.Space.lg) {
                        friendsHero
                        socialActionHub
                        friendHighlights
                        if !state.incoming.isEmpty {
                            incomingCard
                        }
                        feedSection
                        friendsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                    .id(accentRaw)
                }
                .refreshable { await state.refresh() }
            }
            .navigationTitle(Text(L("Friends")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isLeaderboardPresented = true
                    } label: {
                        Image(systemName: "trophy.fill")
                    }
                    .accessibilityLabel(Text(L("Tablica wyników")))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel(Text(L("Dodaj znajomego")))
                }
            }
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
        ScreenBackground(mood: .social)
    }

    private var friendsHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Znajomi"))
                        .font(Tokens.Font.monoDisplay(32))
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text(L("Streaki, reakcje i małe zwycięstwa ludzi, którzy trzymają rytm razem z Tobą."))
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.md)
                Button {
                    isAddPresented = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Tokens.Mono.onHi)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Tokens.Mono.hi))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(L("Dodaj znajomego")))
            }

            HStack(spacing: Tokens.Space.sm) {
                heroMetric(
                    value: "\(state.friends.count)",
                    label: L("Friends"),
                    symbol: "person.2.fill",
                    tint: Tokens.Mono.hi
                )
                heroMetric(
                    value: "\(yourStreak)",
                    label: L("Streak"),
                    symbol: "flame.fill",
                    tint: Tokens.Mono.fat
                )
                heroMetric(
                    value: "\(state.feed.count)",
                    label: L("Today"),
                    symbol: "bolt.fill",
                    tint: Tokens.Mono.heroMuted
                )
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private var incomingCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            sectionHeader(title: L("Zaproszenia"), symbol: "envelope.badge.fill")
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                ForEach(state.incoming) { request in
                    requestRow(request)
                }
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.78)))
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Nowe zaproszenie"))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(String.localizedStringWithFormat(L("od %@"), request.fromUserID))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Button {
                Task { await state.reject(request) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .accessibilityLabel(Text(L("Odrzuć")))
            Button {
                Task { await state.accept(request) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .accessibilityLabel(Text(L("Akceptuj")))
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionHeader(title: L("Co u znajomych"), symbol: "sparkles")
            if state.feed.isEmpty {
                emptyStateCard(
                    symbol: "sparkles",
                    title: L("Cicho dzisiaj"),
                    message: L("Znajomi jeszcze nic dziś nie dodali. Wróć później albo wyślij zaproszenie.")
                ) {
                    isAddPresented = true
                }
            } else {
                VStack(spacing: Tokens.Space.sm) {
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
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionHeader(
                title: String.localizedStringWithFormat(L("Twoi znajomi (%lld)"), state.friends.count),
                symbol: "person.2.fill"
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
                LazyVStack(spacing: Tokens.Space.sm) {
                    ForEach(state.friends) { profile in
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
            }
        }
    }

    func sectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.Palette.primarySoft))
            Text(title)
                .font(Tokens.Font.manrope(18, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
    }

    private func emptyStateCard(
        symbol: String,
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Tokens.Palette.primarySoft))
            VStack(spacing: 4) {
                Text(title)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(message)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            PrimaryButton(title: "Dodaj znajomego", systemImage: "plus", action: action)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Space.lg)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.78)))
    }
}
