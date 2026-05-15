import SwiftUI

/// Main "Today" screen — what the user sees after sign-in once
/// onboarding is done. Plays the role the master prompt assigns to the
/// Today tab.
struct TodayView: View {
    let userRemoteID: String
    @Bindable var state: TodayState
    let favoritesService: (any FavoritesServing)?
    let mealSaver: (any MealSaving)?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    var goalTrackingState: GoalTrackingState?
    let onOpenProfile: () -> Void
    let onOpenScanner: () -> Void
    var onOpenGoalTracking: (() -> Void)?
    var onCookSuggested: ((Recipe) -> Void)?
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenWeeklyDebrief: (() -> Void)?
    var onSelectMeal: ((MealEntry) -> Void)?
    var onDismissInsight: ((CoachInsight) -> Void)?

    @State private var isDatePickerPresented = false
    @State private var isWaterGoalAlertPresented = false
    @State private var waterGoalDraft: Int = WaterService.defaultDailyGoalMilliliters
    @State private var isCalorieGoalAlertPresented = false
    @State private var calorieGoalDraft: Int = 2100

    @AppStorage("water.dailyGoalMl") private var waterGoalStored = WaterService.defaultDailyGoalMilliliters

    @Environment(\.modelContext) private var modelContext

    private func handleCoachAction(_ kind: CoachInsight.ActionKind) {
        if let onCoachAction {
            onCoachAction(kind)
            return
        }
        // Fall back to the scanner — every action variant ultimately
        // expects something log-able.
        onOpenScanner()
    }

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        StreakHeader(
                            greeting: state.greeting,
                            displayName: state.user?.displayName,
                            streakLength: state.streak?.currentLength ?? 0,
                            onTapProfile: onOpenProfile
                        )
                        .padding(.top, Tokens.Space.md)
                        .id("todayTop")

                        dayScrubBar

                        if state.canUseFreeze, let streak = state.streak {
                            StreakFreezeCard(
                                streakLength: streak.currentLength,
                                freezesAvailable: streak.freezesAvailable
                            ) {
                                Haptics.success()
                                Task { await state.consumeFreeze(for: userRemoteID) }
                            }
                        }

                        CalorieProgressCard(
                            consumed: state.totals.calories,
                            goal: state.calorieGoal,
                            progress: state.calorieProgress,
                            onTapGoal: state.user.map { _ in
                                {
                                    calorieGoalDraft = state.calorieGoal
                                    isCalorieGoalAlertPresented = true
                                }
                            }
                        )

                        MacroDistributionCard(
                            protein: state.totals.protein,
                            carbs: state.totals.carbs,
                            fat: state.totals.fat,
                            proteinGoal: state.user?.proteinGoalGrams ?? 120,
                            carbsGoal: state.user?.carbsGoalGrams ?? 240,
                            fatGoal: state.user?.fatGoalGrams ?? 70
                        )

                        if state.isViewingToday {
                            WaterCard(
                                totalMilliliters: state.waterTotalMl,
                                goalMilliliters: waterGoalStored,
                                onAddGlass: {
                                    Haptics.light()
                                    Task { await state.logWaterGlass(for: userRemoteID) }
                                },
                                onUndo: {
                                    Haptics.warning()
                                    Task { await state.undoLastWater(for: userRemoteID) }
                                },
                                onEditGoal: {
                                    waterGoalDraft = waterGoalStored
                                    isWaterGoalAlertPresented = true
                                }
                            )
                        }

                        goalTrackingSlot

                        if state.isViewingToday,
                            let user = state.user,
                            let data = user.latestRecommendationsJSON,
                            let recs = try? JSONDecoder().decode(Recommendations.self, from: data) {
                            OlaInsightsHero(
                                recommendations: recs,
                                lastUpdated: user.recommendationsGeneratedAt
                            )
                        }

                        if state.isViewingToday,
                            let favoritesService,
                            let mealSaver,
                            let entitlementsStore,
                            let paywallCoordinator {
                            FavoritesCarousel(
                                userRemoteID: userRemoteID,
                                favoritesService: favoritesService,
                                mealSaver: mealSaver,
                                entitlementsStore: entitlementsStore,
                                paywallCoordinator: paywallCoordinator,
                                onSaved: {
                                    Task { await state.refresh(for: userRemoteID) }
                                }
                            )
                        }

                        if state.isViewingToday, let insight = state.coachInsights.first {
                            AIInsightCard(
                                insight: insight,
                                onAction: { kind in handleCoachAction(kind) },
                                onDismiss: onDismissInsight.map { handler in
                                    { handler(insight) }
                                }
                            )
                        }

                        if state.isViewingToday, let onOpenWeeklyDebrief {
                            WeeklyDebriefShortcut(onTap: onOpenWeeklyDebrief)
                        }

                        if state.isViewingToday, let upcoming = state.upcomingEvent {
                            CulturalEventBanner(upcoming: upcoming) {
                                Haptics.light()
                                state.dismissCulturalEvent()
                            }
                        }

                        suggestedRecipeCard

                        mealsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xxxl)
                }
                .refreshable {
                    await state.refresh(for: userRemoteID)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: AppShortcutAction.scrollTodayToTop)
                ) { _ in
                    withAnimation(Tokens.Motion.gentle) {
                        proxy.scrollTo("todayTop", anchor: .top)
                    }
                }
            }
        }
        .task {
            await state.refresh(for: userRemoteID)
            goalTrackingState?.refresh(for: userRemoteID)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            DateJumpSheet(
                viewingDate: state.viewingDate,
                onPick: { date in
                    Task {
                        await state.jumpToDate(date, userRemoteID: userRemoteID)
                        isDatePickerPresented = false
                    }
                },
                onToday: {
                    Task {
                        await state.jumpToToday(userRemoteID: userRemoteID)
                        isDatePickerPresented = false
                    }
                },
                onDismiss: { isDatePickerPresented = false }
            )
            .presentationDetents([.medium])
        }
        .alert("Dzienny cel wody", isPresented: $isWaterGoalAlertPresented) {
            TextField("ml", value: $waterGoalDraft, format: .number)
                .keyboardType(.numberPad)
            Button("Zapisz") {
                waterGoalStored = max(250, min(8000, waterGoalDraft))
                Haptics.light()
            }
            Button("Domyślnie") {
                waterGoalStored = WaterService.defaultDailyGoalMilliliters
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("250–8000 ml. Standard to 2000 ml.")
        }
        .alert("Dzienny cel kalorii", isPresented: $isCalorieGoalAlertPresented) {
            TextField("kcal", value: $calorieGoalDraft, format: .number)
                .keyboardType(.numberPad)
            Button("Zapisz") {
                applyCalorieGoal(calorieGoalDraft)
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("1000–4500 kcal. Pełna edycja w Profilu → Cele.")
        }
    }

    private func applyCalorieGoal(_ kcal: Int) {
        guard let user = state.user else { return }
        let clamped = max(1000, min(4500, kcal))
        user.dailyCalorieGoalKcal = clamped
        user.updatedAt = Date()
        try? modelContext.save()
        Haptics.light()
        Task { await state.refresh(for: userRemoteID) }
    }

    /// Goal Tracking card. Three exclusive outcomes:
    /// 1. User has lose/gain goal + Premium → show GoalTrackingCard.
    /// 2. User has lose/gain goal but no Premium → show upsell card.
    /// 3. Otherwise → nothing.
    @ViewBuilder
    private var goalTrackingSlot: some View {
        if state.isViewingToday, let user = state.user, shouldShowGoalSlot(for: user) {
            if entitlementsStore?.current.isPremium == true,
                let goalTrackingState,
                let snapshot = goalTrackingState.snapshot {
                GoalTrackingCard(snapshot: snapshot) {
                    Haptics.light()
                    onOpenGoalTracking?()
                }
            } else if entitlementsStore?.current.isPremium != true {
                GoalTrackingUpsellCard {
                    Haptics.light()
                    paywallCoordinator?.present(.goalTracking)
                }
            }
        }
    }

    private func shouldShowGoalSlot(for user: User) -> Bool {
        let kind = user.goalKind
        guard kind == .lose || kind == .gain else { return false }
        return user.goalStartDate != nil
    }

    @ViewBuilder
    private var suggestedRecipeCard: some View {
        if state.isViewingToday, let suggested = state.suggestedRecipe, let onCookSuggested {
            SuggestedRecipeCard(recipe: suggested) {
                onCookSuggested(suggested)
            }
        }
    }

    private var dayScrubBar: some View {
        HStack(spacing: Tokens.Space.md) {
            Button {
                Haptics.light()
                Task { await state.goToPreviousDay(userRemoteID: userRemoteID) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Poprzedni dzień"))

            Button {
                isDatePickerPresented = true
                Haptics.light()
            } label: {
                VStack(spacing: 0) {
                    Text(state.isViewingToday ? String(localized: "Dziś") : Self.dayLabel(state.viewingDate))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    if !state.isViewingToday {
                        Text("Wróć do dziś")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Wybierz datę"))

            Button {
                Haptics.light()
                Task { await state.goToNextDay(userRemoteID: userRemoteID) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(state.isViewingToday ? Tokens.Palette.inkSubtle : Tokens.Palette.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(state.isViewingToday)
            .accessibilityLabel(Text("Następny dzień"))
        }
    }

    private static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date).capitalized
    }

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text(state.isViewingToday ? String(localized: "Dziś") : String(localized: "Dziennik dnia"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("\(state.meals.count) posiłków")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }

            if state.meals.isEmpty {
                EmptyMealsCallout(onTap: onOpenScanner)
            } else {
                LazyVStack(spacing: Tokens.Space.sm) {
                    ForEach(state.meals) { meal in
                        Button {
                            onSelectMeal?(meal)
                        } label: {
                            MealTimelineRow(meal: meal)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }
}

private struct EmptyMealsCallout: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Brak posiłków dzisiaj")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Stuknij, żeby zeskanować pierwszy.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(
                        Tokens.Palette.separator,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
