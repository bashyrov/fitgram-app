import SwiftUI

/// Znajomi tab — feed at the top (most actionable), pending requests
/// section, friend list at the bottom. Add button in the toolbar raises
/// the search/QR sheet.
struct FriendsRootView: View {
    @Bindable var state: FriendsState

    @State private var isAddPresented = false
    @State private var isLeaderboardPresented = false
    @State private var openedProfileID: String?

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
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        if !state.incoming.isEmpty {
                            incomingCard
                        }
                        feedSection
                        friendsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .refreshable { await state.refresh() }
            }
            .navigationTitle(Text("Znajomi"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isLeaderboardPresented = true
                    } label: {
                        Image(systemName: "trophy.fill")
                    }
                    .accessibilityLabel(Text("Tablica wyników"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel(Text("Dodaj znajomego"))
                }
            }
            .task { await state.refresh() }
            .sheet(isPresented: $isAddPresented) {
                AddFriendSheet(state: state) { isAddPresented = false }
            }
            .sheet(item: Binding(
                get: { openedProfileID.map(IdentifiedID.init) },
                set: { openedProfileID = $0?.value }
            )) { wrapped in
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

    private var incomingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Zaproszenia (\(state.incoming.count))")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(state.incoming) { request in
                    requestRow(request)
                }
            }
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
                Text("Nowe zaproszenie")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("od \(request.fromUserID)")
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
            .accessibilityLabel(Text("Odrzuć"))
            Button {
                Task { await state.accept(request) }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .accessibilityLabel(Text("Akceptuj"))
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Co u znajomych")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            if state.feed.isEmpty {
                Card {
                    VStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Cicho — Twoi znajomi jeszcze nie dodawali nic dziś.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(state.feed) { event in
                    FeedEventCard(event: event) { kind in
                        Task { await state.toggleReaction(on: event, kind: kind) }
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        openedProfileID = event.actorID
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Twoi znajomi (\(state.friends.count))")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            if state.friends.isEmpty {
                Card {
                    VStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Brak znajomych. Dodaj kogoś, żeby zobaczyć jego streak i odznaki.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .multilineTextAlignment(.center)
                        PrimaryButton(title: "Dodaj znajomego", systemImage: "plus") {
                            isAddPresented = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
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
                            Label("Otwórz profil", systemImage: "person.crop.circle")
                        }
                        Button(role: .destructive) {
                            Task { await state.unfriend(profile) }
                        } label: {
                            Label("Usuń znajomość", systemImage: "person.fill.xmark")
                        }
                    }
                }
            }
        }
    }
}
