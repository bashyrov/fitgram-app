import OSLog
import SwiftUI

// Rich friend-profile sheet — avatar header, identity tiles, segmented tabs, and
// four content tabs (Statystyki / Cele / Aktywność / Reakcje). The
// service is responsible for honouring the owner's privacy settings; the
// UI just renders whatever fields survive the snapshot. Per-tab content
// lives in `FriendProfileView+*Tab.swift` extension files.
// swiftlint:disable:next type_body_length
struct FriendProfileView: View {
    let userID: String
    let viewerID: String
    let service: any FriendService
    let onDismiss: () -> Void
    /// Optional — when present, lets the user save a top-recipe to
    /// their own library.
    var onCopyRecipe: ((PublicRecipeReference) -> Void)?
    /// Optional — when present, the bottom action bar exposes a
    /// destructive "Unfriend" CTA.
    var onUnfriend: (() -> Void)?

    @Environment(ToastCenter.self) var toasts

    @State var snapshot: FriendProfileSnapshot?
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var activeTab: Tab = .stats
    @State private var isReportPresented: Bool = false
    @State private var reportReason: String = ""
    @State private var isBlockConfirmed: Bool = false
    @State private var isUnfriendConfirmed: Bool = false

    enum Tab: Hashable, CaseIterable {
        case stats, goals, activity, reactions

        var label: String {
            switch self {
            case .stats: return L("Stats")
            case .goals: return L("Goals")
            case .activity: return L("Activity")
            case .reactions: return L("Reactions")
            }
        }

        var symbol: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .goals: return "target"
            case .activity: return "bolt.fill"
            case .reactions: return "hand.thumbsup.fill"
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
                    onUnfriend?()
                    onDismiss()
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
            MonoNavText(title: L("Zamknij"), action: onDismiss)
                .accessibilityLabel(Text(L("Close")))
        }
        ToolbarItem(placement: .topBarTrailing) {
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
    }

    @ViewBuilder
    private func content(_ snapshot: FriendProfileSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(snapshot)
                Color.clear.frame(height: 16)
                identityTiles(snapshot)
                Color.clear.frame(height: 14)
                tabBar
                Color.clear.frame(height: 12)
                Group {
                    switch activeTab {
                    case .stats: statsTab(snapshot)
                    case .goals: goalsTab(snapshot)
                    case .activity: activityTab(snapshot)
                    case .reactions: reactionsTab(snapshot)
                    }
                }
                .transition(.opacity)
                .animation(Tokens.Motion.gentle, value: activeTab)
                if !snapshot.hasAnyShared {
                    Color.clear.frame(height: 10)
                    privacyHint
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
    }

    // MARK: - Hero (avatar + name row)

    @ViewBuilder
    private func hero(_ snapshot: FriendProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                avatarHero(snapshot)
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.displayName)
                        .font(Tokens.Font.monoDisplay(26))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
        Text(initial(for: snapshot.displayName))
            .font(Tokens.Font.monoNumber(30))
            .foregroundStyle(Tokens.Mono.hi)
            .frame(width: 72, height: 72)
            .background(Circle().fill(Tokens.Mono.hero))
    }

    /// "@user · W Fitgram od … · Znajomi od …" line under the name.
    private func heroSubtitle(_ snapshot: FriendProfileSnapshot) -> String? {
        var parts: [String] = []
        if let username = snapshot.username {
            parts.append(usernameDisplay(username))
        }
        if let since = snapshot.memberSinceDate {
            let formatted = since.formatted(.dateTime.month(.wide).year())
            parts.append(String.localizedStringWithFormat(L("Fitgram-er since %@"), formatted))
            parts.append(String.localizedStringWithFormat(L("Friends since %@"), formatted))
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

    private func usernameDisplay(_ username: String) -> String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    private func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    private var privacyHint: some View {
        HStack(spacing: 10) {
            MonoIconBox(systemName: "lock", style: .track, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Ten profil nie udostępnia szczegółów"))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Zależy od ustawień prywatności znajomego.",
                        en: "Depends on your friend's privacy settings.",
                        uk: "Залежить від налаштувань приватності друга.",
                        ru: "Зависит от настроек приватности друга.",
                        es: "Depende de la configuración de privacidad de tu amigo."
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    // MARK: - Segmented tabs

    private var tabBar: some View {
        MonoSegmented(
            selection: $activeTab,
            options: Tab.allCases.map { (value: $0, title: $0.label) }
        )
    }

    // MARK: - Bottom action bar

    private var actionBar: some View {
        MonoBottomBar {
            HStack(spacing: 8) {
                MonoButton(title: L("Support"), kind: .dark, icon: "heart", height: 46) {
                    Task { await send(intent: .encourage) }
                }
                if onUnfriend != nil {
                    MonoButton(title: L("Unfriend"), kind: .outline, height: 46) {
                        isUnfriendConfirmed = true
                    }
                }
                MonoButton(title: L("Report"), kind: .danger, icon: "flag", height: 46) {
                    isReportPresented = true
                }
            }
        }
    }

    // MARK: - Empty + feedback

    func placeholder(
        symbol: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: symbol, style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
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
        isLoading = true
        do {
            snapshot = try await service.snapshot(forUserID: userID, viewer: viewerID)
        } catch {
            loadError = L("Nie udało się załadować profilu.")
            Logger.persistence.error("Snapshot load failed: \(String(describing: error))")
        }
        isLoading = false
    }

    func send(intent: PositiveReactionIntent) async {
        do {
            try await service.sendPositiveReaction(to: userID, from: viewerID, intent: intent)
            toasts.success(intent.toastTitle, message: intent.toastSubtitle(name: snapshot?.displayName))
            Haptics.success()
        } catch {
            toasts.error(
                L("Nie udało się wysłać"),
                message: L("Spróbuj jeszcze raz za chwilę.")
            )
        }
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
