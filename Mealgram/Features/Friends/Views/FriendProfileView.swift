import OSLog
import SwiftUI

// swiftlint:disable file_length

// Rich friend profile sheet — hero header + 4 tabs (Achievements /
// Stats / Recipes / Activity). Renders only the fields the owner's
// privacy settings permit (the service is responsible for filtering).
// swiftlint:disable:next type_body_length
struct FriendProfileView: View {
    let userID: String
    let viewerID: String
    let service: any FriendService
    let onDismiss: () -> Void
    /// Optional — when present, lets the user save a top-recipe to
    /// their own library.
    var onCopyRecipe: ((PublicRecipeReference) -> Void)?

    @Environment(ToastCenter.self) private var toasts

    @State private var snapshot: FriendProfileSnapshot?
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var activeTab: Tab = .achievements
    @State private var isReactionMenuOpen: Bool = false
    @State private var isReportPresented: Bool = false
    @State private var reportReason: String = ""
    @State private var isBlockConfirmed: Bool = false

    enum Tab: Hashable, CaseIterable {
        case achievements, stats, recipes, activity

        var label: LocalizedStringKey {
            switch self {
            case .achievements: return "Odznaki"
            case .stats: return "Statystyki"
            case .recipes: return "Przepisy"
            case .activity: return "Aktywność"
            }
        }

        var symbol: String {
            switch self {
            case .achievements: return "rosette"
            case .stats: return "chart.bar.fill"
            case .recipes: return "book.closed.fill"
            case .activity: return "bolt.fill"
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
            .toolbar {
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
                }
            }
            .task { await load() }
            .confirmationDialog(
                "Wybierz reakcję",
                isPresented: $isReactionMenuOpen,
                titleVisibility: .visible
            ) {
                ForEach(PositiveReactionIntent.allCases, id: \.self) { intent in
                    Button(intent.label) {
                        Task { await send(intent: intent) }
                    }
                }
                Button("Anuluj", role: .cancel) {}
            }
            .confirmationDialog(
                "Zablokować tego użytkownika?",
                isPresented: $isBlockConfirmed,
                titleVisibility: .visible
            ) {
                Button("Zablokuj", role: .destructive) {
                    Task { await block() }
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Stracisz znajomość, a osoba ta przestanie widzieć Twój profil.")
            }
            .sheet(isPresented: $isReportPresented) {
                reportSheet
            }
        }
    }

    @ViewBuilder
    private func content(_ snapshot: FriendProfileSnapshot) -> some View {
        ScrollView {
            VStack(spacing: Tokens.Space.lg) {
                hero(snapshot)
                actionRow
                statsChips(snapshot)
                tabBar
                Group {
                    switch activeTab {
                    case .achievements: achievementsTab(snapshot)
                    case .stats: statsTab(snapshot)
                    case .recipes: recipesTab(snapshot)
                    case .activity: activityTab(snapshot)
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.xxxl)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ snapshot: FriendProfileSnapshot) -> some View {
        ZStack {
            // Soft ambient gradient backdrop
            LinearGradient(
                colors: [Tokens.Palette.primary.opacity(0.18), Tokens.Palette.accent.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: Tokens.Space.sm) {
                avatarPuck(snapshot)
                VStack(spacing: 4) {
                    Text(snapshot.displayName)
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.ink)
                    if let username = snapshot.username {
                        Text(username)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                if let bio = snapshot.bio {
                    Text(bio)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.md)
                }
                if let since = snapshot.memberSinceDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text("Z nami od \(since.formatted(.dateTime.month(.wide).year()))")
                            .font(Tokens.Font.caption)
                    }
                    .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if !snapshot.hasAnyShared {
                    privacyHint
                }
            }
            .padding(.vertical, Tokens.Space.xl)
            .padding(.horizontal, Tokens.Space.lg)
            .frame(maxWidth: .infinity)
        }
    }

    private func avatarPuck(_ snapshot: FriendProfileSnapshot) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Palette.primary.opacity(0.85),
                            Tokens.Palette.primary,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: Tokens.Palette.primary.opacity(0.4), radius: 18, y: 8)
            Text(initial(for: snapshot.displayName))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func initial(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
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
        .background(
            Capsule().fill(Tokens.Palette.background.opacity(0.6))
        )
        .padding(.top, 4)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            primaryActionButton(
                label: "Zachęć",
                symbol: "hand.thumbsup.fill",
                tint: Tokens.Palette.primary
            ) {
                isReactionMenuOpen = true
            }
            secondaryActionButton(
                label: "Pogratuluj",
                symbol: "party.popper.fill",
                tint: Tokens.Palette.accent
            ) {
                Task { await send(intent: .celebrate) }
            }
            secondaryActionButton(
                label: "Brawo",
                symbol: "rosette",
                tint: Tokens.Palette.warning
            ) {
                Task { await send(intent: .congratulate) }
            }
        }
    }

    private func primaryActionButton(
        label: LocalizedStringKey,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(Tokens.Font.bodyEmphasized)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func secondaryActionButton(
        label: LocalizedStringKey,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(Tokens.Palette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Stats chips

    @ViewBuilder
    private func statsChips(_ snapshot: FriendProfileSnapshot) -> some View {
        let items = statsChipItems(snapshot)
        if !items.isEmpty {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(items, id: \.label) { item in
                    statChip(item)
                }
            }
        }
    }

    private struct StatChipItem {
        let symbol: String
        let value: String
        let label: String
        let tint: Color
    }

    private func statsChipItems(_ snapshot: FriendProfileSnapshot) -> [StatChipItem] {
        var items: [StatChipItem] = []
        if let streak = snapshot.currentStreak {
            items.append(
                StatChipItem(
                    symbol: "flame.fill",
                    value: "\(streak)",
                    label: "Dni",
                    tint: Tokens.Palette.warning
                )
            )
        }
        if let level = snapshot.level {
            items.append(
                StatChipItem(
                    symbol: "star.fill",
                    value: "Lvl \(level.number)",
                    label: level.label,
                    tint: Tokens.Palette.primary
                )
            )
        }
        if let goal = snapshot.goalLabel {
            items.append(
                StatChipItem(
                    symbol: "target",
                    value: goal,
                    label: "Cel",
                    tint: Tokens.Palette.accent
                )
            )
        }
        return items
    }

    private func statChip(_ item: StatChipItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(item.tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            Text(item.value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(item.label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    // MARK: - Tab bar (custom pill style)

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.xs) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabPill(tab)
                }
            }
            .padding(2)
        }
    }

    private func tabPill(_ tab: Tab) -> some View {
        let isActive = activeTab == tab
        return Button {
            withAnimation(Tokens.Motion.gentle) { activeTab = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.label)
                    .font(Tokens.Font.footnote.weight(.semibold))
            }
            .foregroundStyle(isActive ? .white : Tokens.Palette.ink)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Tokens.Palette.primary, Tokens.Palette.primary.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Tokens.Palette.surface)
                    )
                    .shadow(
                        color: isActive ? Tokens.Palette.primary.opacity(0.25) : .black.opacity(0.04),
                        radius: isActive ? 8 : 4,
                        y: 2
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Tabs

    @ViewBuilder
    private func achievementsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let achievements = snapshot.achievements, !achievements.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                ],
                spacing: Tokens.Space.sm
            ) {
                ForEach(achievements, id: \.id) { ach in
                    achievementTile(ach)
                }
            }
        } else {
            placeholder(symbol: "rosette", text: "Brak odznak do pokazania")
        }
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Palette.warning.opacity(0.85), Tokens.Palette.warning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Tokens.Palette.warning.opacity(0.4), radius: 10, y: 4)
                Image(systemName: "rosette")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(achievement.title)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(Tokens.Space.sm)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private func statsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let stats = snapshot.weeklyStats {
            VStack(spacing: Tokens.Space.sm) {
                HStack(spacing: Tokens.Space.sm) {
                    bigStatTile(
                        emoji: "🔥",
                        value: "\(stats.averageDailyKcal)",
                        unit: "kcal",
                        label: "Średnia dzienna",
                        tint: Tokens.Palette.warning
                    )
                    bigStatTile(
                        emoji: "🎯",
                        value: "\(stats.daysHitGoal)",
                        unit: "/ 7",
                        label: "Dni z celem",
                        tint: Tokens.Palette.primary
                    )
                }
                bigStatTile(
                    emoji: "📸",
                    value: "\(stats.totalScans)",
                    unit: "",
                    label: "Skanów w tygodniu",
                    tint: Tokens.Palette.accent
                )
                .frame(maxWidth: .infinity)
                if !stats.topFoods.isEmpty {
                    topFoodsCard(stats.topFoods)
                }
            }
        } else {
            placeholder(symbol: "chart.bar.fill", text: "Statystyki nie są udostępniane")
        }
    }

    private func bigStatTile(
        emoji: String,
        value: String,
        unit: String,
        label: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(emoji)
                    .font(.system(size: 22))
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(unit)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private func topFoodsCard(_ foods: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Label("Top produkty", systemImage: "fork.knife")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(Array(foods.enumerated()), id: \.offset) { idx, food in
                    HStack(spacing: Tokens.Space.sm) {
                        Text("\(idx + 1).")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                            .frame(width: 24, alignment: .leading)
                        Text(food)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                    }
                    if idx < foods.count - 1 {
                        Rectangle()
                            .fill(Tokens.Palette.separator)
                            .frame(height: 0.5)
                            .padding(.leading, 24)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recipesTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let recipes = snapshot.topRecipes, !recipes.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                ForEach(recipes) { recipe in
                    recipeRow(recipe)
                }
            }
        } else {
            placeholder(symbol: "book.closed.fill", text: "Przepisy nie są udostępniane")
        }
    }

    private func recipeRow(_ recipe: PublicRecipeReference) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.success.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                if let kcal = recipe.kcalPerServing {
                    Text("\(kcal) kcal · ugotowane \(recipe.cookCount)×")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            if let onCopyRecipe {
                Button {
                    onCopyRecipe(recipe)
                    toasts.success("Zapisano do mojej książki", message: recipe.name)
                } label: {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Tokens.Palette.primarySoft))
                }
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private func activityTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let events = snapshot.recentEvents, !events.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        } else {
            placeholder(symbol: "bolt.fill", text: "Brak aktywności do pokazania")
        }
    }

    private func eventRow(_ event: FeedEvent) -> some View {
        let tint = eventTint(event.kind)
        return HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: eventSymbol(event.kind))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(event.payload)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(event.createdAt.formatted(.relative(presentation: .named)))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private func eventTint(_ kind: FeedEventKind) -> Color {
        switch kind {
        case .streakMilestone: return Tokens.Palette.warning
        case .achievementEarned: return Tokens.Palette.accent
        case .recipeCooked: return Tokens.Palette.success
        case .challengeWon: return Tokens.Palette.primary
        case .joined: return Tokens.Palette.inkMuted
        }
    }

    // MARK: - Empty + feedback

    private func placeholder(symbol: String, text: LocalizedStringKey) -> some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.surfaceMuted)
                    .frame(width: 64, height: 64)
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            Text(text)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
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
            Text(loadError ?? "Profil niedostępny.")
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

    private func eventSymbol(_ kind: FeedEventKind) -> String {
        switch kind {
        case .streakMilestone: return "flame.fill"
        case .achievementEarned: return "rosette"
        case .recipeCooked: return "book.closed.fill"
        case .challengeWon: return "trophy.fill"
        case .joined: return "person.crop.circle.badge.checkmark"
        }
    }

    private func load() async {
        isLoading = true
        do {
            snapshot = try await service.snapshot(forUserID: userID, viewer: viewerID)
        } catch {
            loadError = "Nie udało się załadować profilu."
            Logger.persistence.error("Snapshot load failed: \(String(describing: error))")
        }
        isLoading = false
    }

    private func send(intent: PositiveReactionIntent) async {
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
