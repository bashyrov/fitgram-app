import OSLog
import SwiftUI

// swiftlint:disable file_length

// Rich friend-profile sheet — gradient hero, animated pill tab bar, and
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
    /// destructive "Usuń znajomość" CTA.
    var onUnfriend: (() -> Void)?

    @Environment(ToastCenter.self) var toasts
    @Namespace private var tabIndicator

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

        var label: LocalizedStringKey {
            switch self {
            case .stats: return "Statystyki"
            case .goals: return "Cele"
            case .activity: return "Aktywność"
            case .reactions: return "Reakcje"
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
                Tokens.Palette.background.ignoresSafeArea()
                if isLoading {
                    ProgressView()
                } else if let snapshot {
                    content(snapshot)
                } else {
                    fallback
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await load() }
            .confirmationDialog(
                "Zablokować tego użytkownika?",
                isPresented: $isBlockConfirmed,
                titleVisibility: .visible
            ) {
                Button("Zablokuj", role: .destructive) { Task { await block() } }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Stracisz znajomość, a osoba ta przestanie widzieć Twój profil.")
            }
            .confirmationDialog(
                "Usunąć znajomość?",
                isPresented: $isUnfriendConfirmed,
                titleVisibility: .visible
            ) {
                Button("Usuń znajomość", role: .destructive) {
                    onUnfriend?()
                    onDismiss()
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Możesz w każdej chwili wysłać nowe zaproszenie.")
            }
            .sheet(isPresented: $isReportPresented) { reportSheet }
        }
        .toastSurface()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Tokens.Palette.surfaceMuted))
            }
            .accessibilityLabel(Text("Zamknij"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    isBlockConfirmed = true
                } label: {
                    Label("Zablokuj", systemImage: "hand.raised.fill")
                }
                Button(role: .destructive) {
                    isReportPresented = true
                } label: {
                    Label("Zgłoś", systemImage: "exclamationmark.bubble.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Tokens.Palette.surfaceMuted))
            }
            .accessibilityLabel(Text("Więcej"))
        }
    }

    @ViewBuilder
    private func content(_ snapshot: FriendProfileSnapshot) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    hero(snapshot)
                    tabBar
                    Group {
                        switch activeTab {
                        case .stats: statsTab(snapshot)
                        case .goals: goalsTab(snapshot)
                        case .activity: activityTab(snapshot)
                        case .reactions: reactionsTab(snapshot)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(Tokens.Motion.gentle, value: activeTab)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.sm)
                .padding(.bottom, Tokens.Space.xxxl + Tokens.Space.huge)
            }
            actionBar
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ snapshot: FriendProfileSnapshot) -> some View {
        ZStack {
            heroBackdrop
            VStack(spacing: Tokens.Space.md) {
                avatarHero(snapshot)
                VStack(spacing: 2) {
                    Text(snapshot.displayName)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let username = snapshot.username {
                        Text(usernameDisplay(username))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                if let bio = snapshot.bio {
                    Text(bio)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.top, 2)
                }
                heroChips(snapshot)
                if !snapshot.hasAnyShared {
                    privacyHint
                        .padding(.top, Tokens.Space.xs)
                }
            }
            .padding(.vertical, Tokens.Space.xl)
            .padding(.horizontal, Tokens.Space.lg)
            .frame(maxWidth: .infinity)
        }
    }

    private var heroBackdrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(Tokens.Palette.surface)
                .mealgramShadow(Tokens.Shadow.card)
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.22))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: -120, y: -60)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 70)
                .offset(x: 130, y: 70)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
        .allowsHitTesting(false)
    }

    private func avatarHero(_ snapshot: FriendProfileSnapshot) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 112, height: 112)
                .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 22, y: 10)
            Circle()
                .fill(Tokens.Palette.surface)
                .frame(width: 102, height: 102)
            Text(initial(for: snapshot.displayName))
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func usernameDisplay(_ username: String) -> String {
        username.hasPrefix("@") ? username : "@\(username)"
    }

    private func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    @ViewBuilder
    private func heroChips(_ snapshot: FriendProfileSnapshot) -> some View {
        let chips = heroChipItems(snapshot)
        if !chips.isEmpty {
            FlowLayout(spacing: Tokens.Space.xs) {
                ForEach(chips, id: \.id) { chip in
                    heroChip(chip)
                }
            }
            .padding(.top, Tokens.Space.xs)
        }
    }

    private struct HeroChip: Identifiable {
        let id: String
        let symbol: String
        let text: String
        let tint: Color
        let isProminent: Bool
    }

    private func heroChipItems(_ snapshot: FriendProfileSnapshot) -> [HeroChip] {
        var items: [HeroChip] = []
        if let streak = snapshot.currentStreak, streak > 0 {
            items.append(
                HeroChip(
                    id: "streak",
                    symbol: "flame.fill",
                    text: String(localized: "\(streak) dni z rzędu"),
                    tint: Tokens.Palette.warning,
                    isProminent: true
                )
            )
        }
        if let since = snapshot.memberSinceDate {
            let formatted = since.formatted(.dateTime.month(.wide).year())
            items.append(
                HeroChip(
                    id: "member",
                    symbol: "leaf.fill",
                    text: String(localized: "Mealgram-er od \(formatted)"),
                    tint: Tokens.Palette.success,
                    isProminent: false
                )
            )
            items.append(
                HeroChip(
                    id: "friend",
                    symbol: "person.2.fill",
                    text: String(localized: "Znajomi od \(formatted)"),
                    tint: Tokens.Palette.primary,
                    isProminent: false
                )
            )
        }
        if let level = snapshot.level {
            items.append(
                HeroChip(
                    id: "level",
                    symbol: "star.fill",
                    text: "Lvl \(level.number) · \(level.label)",
                    tint: Tokens.Palette.accent,
                    isProminent: false
                )
            )
        }
        return items
    }

    private func heroChip(_ chip: HeroChip) -> some View {
        HStack(spacing: 5) {
            Image(systemName: chip.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(chip.text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(chip.isProminent ? Color.white : chip.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    chip.isProminent
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [chip.tint, chip.tint.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(chip.tint.opacity(0.16))
                )
        )
        .shadow(
            color: chip.isProminent ? chip.tint.opacity(0.35) : .clear,
            radius: chip.isProminent ? 6 : 0,
            y: 2
        )
    }

    private var privacyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text("Ten profil nie udostępnia szczegółów")
        }
        .font(Tokens.Font.caption)
        .foregroundStyle(Tokens.Palette.inkMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Tokens.Palette.background.opacity(0.6)))
    }

    // MARK: - Custom segmented pill tab bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabPill(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted)
        )
    }

    private func tabPill(_ tab: Tab) -> some View {
        let isActive = activeTab == tab
        return Button {
            withAnimation(Tokens.Motion.gentle) { activeTab = tab }
            Haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12, weight: .bold))
                Text(tab.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color.white : Tokens.Palette.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .matchedGeometryEffect(id: "indicator", in: tabIndicator)
                            .shadow(color: Tokens.Palette.primary.opacity(0.35), radius: 10, y: 4)
                    }
                }
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(tab.label))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Bottom action bar

    private var actionBar: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button {
                Task { await send(intent: .encourage) }
            } label: {
                HStack(spacing: 6) {
                    Text("Zachęć")
                        .font(Tokens.Font.bodyEmphasized)
                    Text(verbatim: "👋")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 14, y: 6)
                )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text("Zachęć"))

            if onUnfriend != nil {
                Button {
                    isUnfriendConfirmed = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.error)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(Tokens.Palette.surface)
                                .overlay(Circle().stroke(Tokens.Palette.error.opacity(0.4), lineWidth: 1))
                        )
                        .mealgramShadow(Tokens.Shadow.card)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text("Usuń znajomość"))
            }
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, Tokens.Space.md)
        .padding(.top, Tokens.Space.sm)
        .background(
            LinearGradient(
                colors: [
                    Tokens.Palette.background.opacity(0),
                    Tokens.Palette.background.opacity(0.92),
                    Tokens.Palette.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Empty + feedback

    func placeholder(
        symbol: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) -> some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Palette.primary.opacity(0.18), Tokens.Palette.accent.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.xxl)
    }

    private var fallback: some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.surfaceMuted)
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Text(loadError ?? String(localized: "Profil niedostępny."))
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                                Text("Powód zgłoszenia")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                                TextEditor(text: $reportReason)
                                    .frame(minHeight: 120)
                            }
                        }
                        Text("Zgłoszenie trafia do naszego zespołu moderacji. Nie informujemy o decyzjach.")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Zgłoś"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") { isReportPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Wyślij") {
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
            loadError = String(localized: "Nie udało się załadować profilu.")
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
            toasts.error("Nie udało się wysłać", message: "Spróbuj jeszcze raz za chwilę.")
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
        toasts.info("Zgłoszenie wysłane", message: "Dzięki, nasz zespół moderacji się tym zajmie.")
        reportReason = ""
    }
}
