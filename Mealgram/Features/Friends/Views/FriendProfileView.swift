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
    /// destructive "Unfriend" CTA.
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
            case .stats: return "Stats"
            case .goals: return "Goals"
            case .activity: return "Activity"
            case .reactions: return "Reactions"
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
                        VStack(spacing: Tokens.Space.md) {
                            LoadingShimmer(cornerRadius: 28).frame(height: 260)
                            LoadingShimmer(cornerRadius: 22).frame(height: 58)
                            LoadingShimmer(cornerRadius: 22).frame(height: 110)
                            LoadingShimmer(cornerRadius: 22).frame(height: 180)
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
            .toolbar { toolbarContent }
            .task { await load() }
            .confirmationDialog(
                "Block this user?",
                isPresented: $isBlockConfirmed,
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) { Task { await block() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll lose the connection and they won't see your profile.")
            }
            .confirmationDialog(
                "Unfriend?",
                isPresented: $isUnfriendConfirmed,
                titleVisibility: .visible
            ) {
                Button("Unfriend", role: .destructive) {
                    onUnfriend?()
                    onDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can send a new invitation any time.")
            }
            .sheet(isPresented: $isReportPresented) { reportSheet }
        }
        .toastSurface()
    }

    private var profileBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.42))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: -160, y: -220)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 116)
                .offset(x: 160, y: -10)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.09))
                .frame(width: 260, height: 260)
                .blur(radius: 105)
                .offset(x: -90, y: 390)
        }
        .ignoresSafeArea()
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
            .accessibilityLabel(Text("Close"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    isBlockConfirmed = true
                } label: {
                    Label("Block", systemImage: "hand.raised.fill")
                }
                Button(role: .destructive) {
                    isReportPresented = true
                } label: {
                    Label("Report", systemImage: "exclamationmark.bubble.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Tokens.Palette.surfaceMuted))
            }
            .accessibilityLabel(Text("More"))
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
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Tokens.Palette.surface.opacity(0.92),
                        Tokens.Palette.primarySoft.opacity(0.54),
                        Tokens.Palette.accentSoft.opacity(0.36),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.44), lineWidth: 1)
            )
            .shadow(color: Tokens.Palette.primary.opacity(0.12), radius: 26, y: 16)
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
                    text: String.localizedStringWithFormat(L("%lld days in a row"), streak),
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
                    text: String.localizedStringWithFormat(L("Mealgram-er since %@"), formatted),
                    tint: Tokens.Palette.success,
                    isProminent: false
                )
            )
            items.append(
                HeroChip(
                    id: "friend",
                    symbol: "person.2.fill",
                    text: String.localizedStringWithFormat(L("Friends since %@"), formatted),
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
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.06), radius: 12, y: 7)
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
                .accessibilityLabel(Text("Unfriend"))
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
        .padding(.horizontal, Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.80)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
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
            Text(loadError ?? L("Profil niedostępny."))
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            ZStack {
                profileBackground
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                            Text("Powód zgłoszenia")
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            TextEditor(text: $reportReason)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(Tokens.Space.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Tokens.Palette.surfaceMuted.opacity(0.82))
                                )
                        }
                        .padding(Tokens.Space.lg)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(
                                Tokens.Palette.surface.opacity(0.84))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(
                                .white.opacity(0.36), lineWidth: 1))
                        Text("Zgłoszenie trafia do naszego zespołu moderacji. Nie informujemy o decyzjach.")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isReportPresented = false }
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
