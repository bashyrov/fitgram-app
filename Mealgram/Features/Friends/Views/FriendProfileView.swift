import OSLog
import SwiftUI

// Sheet glues 4 tabs + header + toolbar in one place — long body is intentional.
// swiftlint:disable:next type_body_length
struct FriendProfileView: View {
    /// Rich friend profile sheet — header + 4 tabs (Achievements / Stats /
    /// Recipes / Activity). Renders only the fields the owner's privacy
    /// settings permit (the service is responsible for filtering).
    let userID: String
    let viewerID: String
    let service: any FriendService
    let onDismiss: () -> Void
    /// Optional — when present, lets the user save a top-recipe to
    /// their own library.
    var onCopyRecipe: ((PublicRecipeReference) -> Void)?

    @State private var snapshot: FriendProfileSnapshot?
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var activeTab: Tab = .achievements
    @State private var isReactionMenuOpen: Bool = false
    @State private var feedback: String?
    @State private var isReportPresented: Bool = false
    @State private var reportReason: String = ""
    @State private var isBlockConfirmed: Bool = false

    enum Tab: Hashable { case achievements, stats, recipes, activity }

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
            .navigationTitle(Text(snapshot?.displayName ?? "Profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isReactionMenuOpen = true
                        } label: {
                            Label("Zachęć / Pogratuluj", systemImage: "heart.fill")
                        }
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
                        Image(systemName: "ellipsis.circle")
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    header(snapshot)
                    tabPicker
                    Group {
                        switch activeTab {
                        case .achievements: achievementsTab(snapshot)
                        case .stats: statsTab(snapshot)
                        case .recipes: recipesTab(snapshot)
                        case .activity: activityTab(snapshot)
                        }
                    }
                    if let feedback {
                        Text(feedback)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
        }
    }

    @ViewBuilder
    private func header(_ snapshot: FriendProfileSnapshot) -> some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(spacing: Tokens.Space.sm) {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text(String(snapshot.displayName.prefix(1)))
                            .font(Tokens.Font.title2)
                            .foregroundStyle(.white)
                    )
                VStack(spacing: 2) {
                    Text(snapshot.displayName)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    if let username = snapshot.username {
                        Text(username)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    if let bio = snapshot.bio {
                        Text(bio)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                HStack(spacing: Tokens.Space.lg) {
                    if let streak = snapshot.currentStreak {
                        chip(symbol: "flame.fill", value: "\(streak)", label: "Dni")
                    }
                    if let level = snapshot.level {
                        chip(symbol: "star.fill", value: "Lvl \(level.number)", label: level.label)
                    }
                    if let goal = snapshot.goalLabel {
                        chip(symbol: "target", value: goal, label: "Cel")
                    }
                }
                if let since = snapshot.memberSinceDate {
                    Text("Z nami od \(since.formatted(.dateTime.month(.wide).year()))")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if !snapshot.hasAnyShared {
                    Text("Ten profil nie udostępnia szczegółów.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func chip(symbol: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(value)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var tabPicker: some View {
        Picker("Tab", selection: $activeTab) {
            Text("Odznaki").tag(Tab.achievements)
            Text("Statystyki").tag(Tab.stats)
            Text("Przepisy").tag(Tab.recipes)
            Text("Aktywność").tag(Tab.activity)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tabs

    @ViewBuilder
    private func achievementsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let achievements = snapshot.achievements, !achievements.isEmpty {
            Card {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: Tokens.Space.sm) {
                    ForEach(achievements, id: \.id) { ach in
                        VStack(spacing: 4) {
                            Image(systemName: "rosette")
                                .font(.system(size: 28))
                                .foregroundStyle(Tokens.Palette.primary)
                            Text(ach.title)
                                .font(Tokens.Font.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
            }
        } else {
            placeholder("Brak odznak do pokazania.")
        }
    }

    @ViewBuilder
    private func statsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let stats = snapshot.weeklyStats {
            Card {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    statRow(label: "Średnia dzienna", value: "\(stats.averageDailyKcal) kcal")
                    statRow(label: "Skanów w tygodniu", value: "\(stats.totalScans)")
                    statRow(label: "Dni z trafionym celem", value: "\(stats.daysHitGoal) / 7")
                    if !stats.topFoods.isEmpty {
                        Divider().background(Tokens.Palette.separator)
                        Text("Top produkty")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        ForEach(stats.topFoods, id: \.self) { food in
                            HStack {
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(Tokens.Palette.primary)
                                Text(food).foregroundStyle(Tokens.Palette.ink)
                            }
                        }
                    }
                }
            }
        } else {
            placeholder("Statystyki nie są udostępniane.")
        }
    }

    @ViewBuilder
    private func recipesTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let recipes = snapshot.topRecipes, !recipes.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                ForEach(recipes) { recipe in
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                    .font(Tokens.Font.bodyEmphasized)
                                    .foregroundStyle(Tokens.Palette.ink)
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
                                    feedback = "Zapisano do mojej książki."
                                } label: {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                        .foregroundStyle(Tokens.Palette.primary)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            placeholder("Przepisy nie są udostępniane.")
        }
    }

    @ViewBuilder
    private func activityTab(_ snapshot: FriendProfileSnapshot) -> some View {
        if let events = snapshot.recentEvents, !events.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                ForEach(events) { event in
                    Card {
                        HStack(alignment: .top, spacing: Tokens.Space.sm) {
                            Image(systemName: eventSymbol(event.kind))
                                .foregroundStyle(Tokens.Palette.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.payload)
                                    .font(Tokens.Font.body)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text(event.createdAt.formatted(.relative(presentation: .named)))
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Spacer()
                        }
                    }
                }
            }
        } else {
            placeholder("Brak aktywności do pokazania.")
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text(value).foregroundStyle(Tokens.Palette.ink)
        }
        .font(Tokens.Font.body)
    }

    private func placeholder(_ text: String) -> some View {
        Card {
            Text(text)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Space.md)
        }
    }

    private var fallback: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Tokens.Palette.inkMuted)
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
            feedback = "Wysłano: \(intent.label)"
            Haptics.success()
        } catch {
            feedback = "Nie udało się wysłać."
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
        feedback = "Zgłoszenie wysłane."
        reportReason = ""
    }
}
