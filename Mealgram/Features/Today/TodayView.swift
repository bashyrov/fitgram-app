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
    let onOpenAddOptions: () -> Void
    var onOpenGoalTracking: (() -> Void)?
    var onCookSuggested: ((Recipe) -> Void)?
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenWeeklyDebrief: (() -> Void)?
    var onSelectMeal: ((MealEntry) -> Void)?
    var onDismissInsight: ((CoachInsight) -> Void)?

    @State var isDatePickerPresented = false
    @State var isWaterGoalAlertPresented = false
    @State var waterGoalDraft: Int = WaterService.defaultDailyGoalMilliliters
    @State var isCalorieGoalAlertPresented = false
    @State var calorieGoalDraft: Int = 2100
    @State var isOlaTipsPresented = false
    @State var isFactsLibraryPresented = false
    @State var hasStagedContent = false

    @AppStorage("water.dailyGoalMl") private var waterGoalStored = WaterService.defaultDailyGoalMilliliters

    /// Day-rotating fact picker for the "Porady od Oli" sheet. The
    /// selector itself is cheap to construct — but parking it on the
    /// view keeps the chosen fact stable across re-renders.
    let factSelector = DailyFactSelector()

    func handleCoachAction(_ kind: CoachInsight.ActionKind) {
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
            todayBackground
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Tokens.Space.md) {
                        TodayDashboardHero(
                            greeting: state.greeting,
                            displayName: state.user?.displayName,
                            streakLength: state.streak?.currentLength ?? 0,
                            viewingDate: state.viewingDate,
                            isViewingToday: state.isViewingToday,
                            consumed: state.totals.calories,
                            calorieGoal: state.calorieGoal,
                            calorieProgress: state.calorieProgress,
                            protein: state.totals.protein,
                            carbs: state.totals.carbs,
                            fat: state.totals.fat,
                            proteinGoal: state.user?.proteinGoalGrams ?? 120,
                            carbsGoal: state.user?.carbsGoalGrams ?? 240,
                            fatGoal: state.user?.fatGoalGrams ?? 70,
                            waterTotalMilliliters: state.waterTotalMl,
                            waterGoalMilliliters: waterGoalStored,
                            showsWater: state.isViewingToday,
                            onTapProfile: onOpenProfile,
                            onPreviousDay: {
                                Haptics.light()
                                Task { await state.goToPreviousDay(userRemoteID: userRemoteID) }
                            },
                            onPickDate: {
                                isDatePickerPresented = true
                                Haptics.light()
                            },
                            onNextDay: {
                                Haptics.light()
                                Task { await state.goToNextDay(userRemoteID: userRemoteID) }
                            },
                            onTapGoal: state.user.map { _ in
                                {
                                    calorieGoalDraft = state.calorieGoal
                                    isCalorieGoalAlertPresented = true
                                }
                            },
                            onAddWater: {
                                Haptics.light()
                                Task { await state.logWaterGlass(for: userRemoteID) }
                            },
                            onUndoWater: {
                                Haptics.warning()
                                Task { await state.undoLastWater(for: userRemoteID) }
                            },
                            onEditWaterGoal: {
                                waterGoalDraft = waterGoalStored
                                isWaterGoalAlertPresented = true
                            }
                        )
                        .padding(.top, Tokens.Space.md)
                        .id("todayTop")
                        .todayStage(isVisible: hasStagedContent, index: 0)
                        .animation(Tokens.Motion.gentle, value: dayIdentity)
                        .animation(Tokens.Motion.gentle, value: Int(state.totals.calories.rounded()))

                        TodayQuickActionHub(
                            canUseOlaAdvice: canUseOlaAdvice,
                            onOpenAddOptions: onOpenAddOptions,
                            onOpenScanner: onOpenScanner,
                            onOpenOla: {
                                Haptics.light()
                                if canUseOlaAdvice {
                                    isOlaTipsPresented = true
                                } else {
                                    paywallCoordinator?.present(.coachDebriefQuota)
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .todayStage(isVisible: hasStagedContent, index: 1)

                        if state.canUseFreeze, let streak = state.streak {
                            StreakFreezeCard(
                                streakLength: streak.currentLength,
                                freezesAvailable: streak.freezesAvailable
                            ) {
                                Haptics.success()
                                Task { await state.consumeFreeze(for: userRemoteID) }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .todayStage(isVisible: hasStagedContent, index: 2)
                        }

                        goalTrackingSlot
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 3)

                        factOfDaySlot
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 4)

                        olaAdviceSlot
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 5)

                        updatesStack
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 6)

                        mealsSection
                            .id(dayIdentity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .todayStage(isVisible: hasStagedContent, index: 7)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xxxl)
                    .animation(Tokens.Motion.gentle, value: dayIdentity)
                    .animation(Tokens.Motion.gentle, value: state.meals.count)
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
            withAnimation(Tokens.Motion.gentle.delay(0.08)) {
                hasStagedContent = true
            }
            #if DEBUG
            if DebugBypass.initialSheet == "ola-tips" {
                try? await Task.sleep(nanoseconds: 800_000_000)
                isOlaTipsPresented = true
            }
            #endif
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
            .presentationDetents([.large])
        }
        .alert("Dzienny cel wody", isPresented: $isWaterGoalAlertPresented) {
            TextField("ml", value: $waterGoalDraft, format: .number)
                .keyboardType(.numberPad)
            Button("Save") {
                waterGoalStored = max(250, min(8000, waterGoalDraft))
                Haptics.light()
            }
            Button("Default") { waterGoalStored = WaterService.defaultDailyGoalMilliliters }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("250–8000 ml. Standard to 2000 ml.")
        }
        .sheet(isPresented: $isOlaTipsPresented) {
            OlaTipsView(
                recommendations: currentRecommendations,
                lastUpdated: state.user?.recommendationsGeneratedAt,
                onDismiss: { isOlaTipsPresented = false }
            )
        }
        .sheet(isPresented: $isFactsLibraryPresented) {
            FactsLibraryView(
                highlightedFact: todayFact,
                initialCategory: preferredFactCategory,
                onDismiss: { isFactsLibraryPresented = false }
            )
        }
        .alert("Dzienny cel kalorii", isPresented: $isCalorieGoalAlertPresented) {
            TextField("kcal", value: $calorieGoalDraft, format: .number)
                .keyboardType(.numberPad)
            Button("Save") { applyCalorieGoal(calorieGoalDraft) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("1000–4500 kcal. Pełna edycja w Profilu → Cele.")
        }
    }

    var dayIdentity: Date { Calendar.current.startOfDay(for: state.viewingDate) }

    var todayBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.52))
                .frame(width: 360, height: 360)
                .blur(radius: 104)
                .offset(x: -160, y: -240)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.24))
                .frame(width: 330, height: 330)
                .blur(radius: 112)
                .offset(x: 170, y: -60)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.10))
                .frame(width: 270, height: 270)
                .blur(radius: 105)
                .offset(x: -120, y: 420)
        }
        .ignoresSafeArea()
    }

}

private struct TodayStageModifier: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .scaleEffect(isVisible ? 1 : 0.985)
            .animation(Tokens.Motion.gentle.delay(Double(index) * 0.045), value: isVisible)
    }
}

extension View {
    fileprivate func todayStage(isVisible: Bool, index: Int) -> some View {
        modifier(TodayStageModifier(isVisible: isVisible, index: index))
    }
}

struct EmptyMealsCallout: View {
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
                    Text("No meals today")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Wybierz, jak chcesz dodać pierwszy posiłek.")
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
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.78))
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
