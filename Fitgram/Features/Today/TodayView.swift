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
    let onAddWorkout: () -> Void
    var onOpenGoalTracking: (() -> Void)?
    var onCookSuggested: ((Recipe) -> Void)?
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenWeeklyDebrief: (() -> Void)?
    var onSelectMeal: ((MealEntry) -> Void)?
    var onDeleteWorkout: ((WorkoutEntry) -> Void)?
    var onToggleWorkoutCountsTowardGoal: ((WorkoutEntry, Bool) -> Void)?
    var onDismissInsight: ((CoachInsight) -> Void)?

    @State var isDatePickerPresented = false
    @State var isWaterGoalAlertPresented = false
    @State var waterGoalDraft: Int = WaterService.defaultDailyGoalMilliliters
    @State var isCalorieGoalAlertPresented = false
    @State var calorieGoalDraft: Int = 2100
    @State var isMacroGoalAlertPresented = false
    @State var proteinGoalDraft: Int = 120
    @State var carbsGoalDraft: Int = 240
    @State var fatGoalDraft: Int = 70
    @State var isOlaTipsPresented = false
    @State var isFactsLibraryPresented = false
    @State var hasStagedContent = false
    @State var selectedWorkout: WorkoutEntry?

    @AppStorage("water.dailyGoalMl") private var waterGoalStored = WaterService.defaultDailyGoalMilliliters
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

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
                    LazyVStack(spacing: Tokens.Space.md) {
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
                            proteinGoal: state.proteinGoal,
                            carbsGoal: state.carbsGoal,
                            fatGoal: state.fatGoal,
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
                            },
                            onEditMacroGoals: {
                                proteinGoalDraft = state.proteinGoal
                                carbsGoalDraft = state.carbsGoal
                                fatGoalDraft = state.fatGoal
                                isMacroGoalAlertPresented = true
                            }
                        )
                        .padding(.top, Tokens.Space.md)
                        .id("todayTop")
                        .todayStage(isVisible: hasStagedContent, index: 0)

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

                        dailyOlaPlanSlot
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 5)

                        olaAdviceSlot
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 6)

                        updatesStack
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 7)

                        activitySection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .todayStage(isVisible: hasStagedContent, index: 8)

                        mealsSection
                            .id(dayIdentity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .todayStage(isVisible: hasStagedContent, index: 9)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xxxl)
                    .id(accentRaw)
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
                dailyPlan: state.dailyOlaPlan,
                coachInsights: state.coachInsights,
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
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(
                workout: workout,
                onToggleCountsTowardGoal: { isEnabled in
                    onToggleWorkoutCountsTowardGoal?(workout, isEnabled)
                },
                onDelete: {
                    selectedWorkout = nil
                    onDeleteWorkout?(workout)
                },
                onDismiss: { selectedWorkout = nil }
            )
            .presentationDetents([.medium, .large])
        }
        .alert(
            TL(
                pl: "Cel kalorii na ten dzień",
                en: "Calorie goal for this day",
                uk: "Ціль калорій на цей день",
                ru: "Цель калорий на этот день",
                es: "Objetivo de calorías de este día"
            ),
            isPresented: $isCalorieGoalAlertPresented
        ) {
            TextField("kcal", value: $calorieGoalDraft, format: .number)
                .keyboardType(.numberPad)
            Button(L("Save")) { applyCalorieGoal(calorieGoalDraft) }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(
                TL(
                    pl: "1000–4500 kcal. Ta zmiana działa tylko dla tego dnia. Przyszłe normy zmienisz w Profilu.",
                    en: "1000–4500 kcal. This change applies only to this day. Future targets are edited in Profile.",
                    uk: "1000–4500 ккал. Ця зміна діє лише для цього дня. Майбутні цілі змінюються в профілі.",
                    ru:
                        "1000–4500 ккал. Это изменение действует только для этого дня. Будущие цели меняются в профиле.",
                    es: "1000–4500 kcal. Este cambio solo aplica a este día. Los objetivos futuros se editan en Perfil."
                )
            )
        }
        .sheet(isPresented: $isMacroGoalAlertPresented) {
            DailyMacroGoalEditorSheet(
                protein: $proteinGoalDraft,
                carbs: $carbsGoalDraft,
                fat: $fatGoalDraft,
                onSave: {
                    applyMacroGoals()
                    isMacroGoalAlertPresented = false
                },
                onDismiss: { isMacroGoalAlertPresented = false }
            )
            .presentationDetents([.large])
        }
    }

    var dayIdentity: Date { Calendar.current.startOfDay(for: state.viewingDate) }

    var todayBackground: some View {
        ScreenBackground(mood: .calm)
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
            .monoCard(radius: Tokens.Mono.Radius.tile, padding: nil)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct DailyMacroGoalEditorSheet: View {
    @Binding var protein: Int
    @Binding var carbs: Int
    @Binding var fat: Int
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(mood: .calm)
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        header
                        MacroTargetEditorRow(
                            title: L("Protein"),
                            subtitle: TL(
                                pl: "Sytość i ochrona mięśni",
                                en: "Satiety and muscle support",
                                uk: "Ситість і підтримка мʼязів",
                                ru: "Сытость и поддержка мышц",
                                es: "Saciedad y soporte muscular"
                            ),
                            symbol: "figure.strengthtraining.traditional",
                            color: Tokens.Palette.primary,
                            value: $protein,
                            range: 40...260
                        )
                        MacroTargetEditorRow(
                            title: L("Carbs"),
                            subtitle: TL(
                                pl: "Energia na dzień i trening",
                                en: "Energy for the day and training",
                                uk: "Енергія на день і тренування",
                                ru: "Энергия на день и тренировки",
                                es: "Energía para el día y entrenar"
                            ),
                            symbol: "bolt.fill",
                            color: Tokens.Palette.mutedGreen,
                            value: $carbs,
                            range: 40...520
                        )
                        MacroTargetEditorRow(
                            title: L("Fat"),
                            subtitle: TL(
                                pl: "Hormony, smak i stabilność",
                                en: "Hormones, flavor and steadiness",
                                uk: "Гормони, смак і стабільність",
                                ru: "Гормоны, вкус и стабильность",
                                es: "Hormonas, sabor y estabilidad"
                            ),
                            symbol: "drop.fill",
                            color: Tokens.Palette.warning,
                            value: $fat,
                            range: 20...180
                        )
                        summaryCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Save"), action: onSave)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var title: String {
        TL(pl: "Makro dnia", en: "Daily macros", uk: "Макро дня", ru: "Макро дня", es: "Macros del día")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title)
                .font(Tokens.Font.archivo(size: 34, weight: 800, width: 115))
                .foregroundStyle(Tokens.Palette.ink)
            Text(
                TL(
                    pl: "Zmieniasz tylko wybrany dzień. Przyszłe cele zostają w Profilu.",
                    en: "You are changing only the selected day. Future targets stay in Profile.",
                    uk: "Ти змінюєш лише вибраний день. Майбутні цілі залишаються в профілі.",
                    ru: "Ты меняешь только выбранный день. Будущие цели остаются в профиле.",
                    es: "Solo cambias el día elegido. Los objetivos futuros quedan en Perfil."
                )
            )
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var summaryCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            HStack {
                Label(
                    String.localizedStringWithFormat(
                        TL(
                            pl: "Razem: B/W/T %lld/%lld/%lld g",
                            en: "Total: P/C/F %lld/%lld/%lld g",
                            uk: "Разом: Б/В/Ж %lld/%lld/%lld г",
                            ru: "Итого: Б/У/Ж %lld/%lld/%lld г",
                            es: "Total: P/C/G %lld/%lld/%lld g"
                        ),
                        protein,
                        carbs,
                        fat
                    ),
                    systemImage: "chart.bar.fill"
                )
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                Spacer()
            }
        }
    }
}
