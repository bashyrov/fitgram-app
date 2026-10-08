import SwiftUI

// swiftlint:disable file_length

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
                            burned: state.workoutCaloriesBurned,
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
                                    setGoalDialog(calorie: true)
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
                                setGoalDialog(water: true)
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
        .fullScreenCover(isPresented: $isWaterGoalAlertPresented) {
            TodayGoalDialog(
                icon: "drop",
                title: L("Dzienny cel wody"),
                message: L("250–8000 ml. Standard to 2000 ml."),
                value: $waterGoalDraft,
                unit: L("ml"),
                layout: .stacked,
                onSave: {
                    waterGoalStored = max(250, min(8000, waterGoalDraft))
                    Haptics.light()
                    setGoalDialog(water: false)
                },
                onDefault: {
                    waterGoalStored = WaterService.defaultDailyGoalMilliliters
                    setGoalDialog(water: false)
                },
                onCancel: { setGoalDialog(water: false) }
            )
            .presentationBackground(.clear)
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
        .fullScreenCover(isPresented: $isCalorieGoalAlertPresented) {
            TodayGoalDialog(
                icon: nil,
                title: TL(
                    pl: "Cel kalorii na ten dzień",
                    en: "Calorie goal for this day",
                    uk: "Ціль калорій на цей день",
                    ru: "Цель калорий на этот день",
                    es: "Objetivo de calorías de este día"
                ),
                message: TL(
                    pl: "1000–4500 kcal. Ta zmiana działa tylko dla tego dnia. Przyszłe normy zmienisz w Profilu.",
                    en: "1000–4500 kcal. This change applies only to this day. Future targets are edited in Profile.",
                    uk: "1000–4500 ккал. Ця зміна діє лише для цього дня. Майбутні цілі змінюються в профілі.",
                    ru:
                        "1000–4500 ккал. Это изменение действует только для этого дня. Будущие цели меняются в профиле.",
                    es: "1000–4500 kcal. Este cambio solo aplica a este día. Los objetivos futuros se editan en Perfil."
                ),
                value: $calorieGoalDraft,
                unit: L("kcal"),
                layout: .inline,
                onSave: {
                    applyCalorieGoal(calorieGoalDraft)
                    setGoalDialog(calorie: false)
                },
                onDefault: nil,
                onCancel: { setGoalDialog(calorie: false) }
            )
            .presentationBackground(.clear)
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
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                        .fill(Tokens.Mono.track)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .foregroundStyle(Tokens.Palette.ink)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(
                        text: title,
                        sub: TL(
                            pl: "Zmieniasz tylko wybrany dzień. Przyszłe cele zostają w Profilu.",
                            en: "You are changing only the selected day. Future targets stay in Profile.",
                            uk: "Ти змінюєш лише вибраний день. Майбутні цілі залишаються в профілі.",
                            ru: "Ты меняешь только выбранный день. Будущие цели остаются в профиле.",
                            es: "Solo cambias el día elegido. Los objetivos futuros quedan en Perfil."
                        )
                    )
                    .padding(.bottom, 8)
                    TodayMacroEditorRow(
                        title: L("Protein"),
                        subtitle: TL(
                            pl: "Sytość i ochrona mięśni",
                            en: "Satiety and muscle support",
                            uk: "Ситість і підтримка мʼязів",
                            ru: "Сытость и поддержка мышц",
                            es: "Saciedad y soporte muscular"
                        ),
                        symbol: "bolt",
                        color: Tokens.Mono.strong,
                        value: $protein,
                        range: 40...260
                    )
                    TodayMacroEditorRow(
                        title: L("Carbs"),
                        subtitle: TL(
                            pl: "Energia na dzień i trening",
                            en: "Energy for the day and training",
                            uk: "Енергія на день і тренування",
                            ru: "Энергия на день и тренировки",
                            es: "Energía para el día y entrenar"
                        ),
                        symbol: "flame",
                        color: Tokens.Mono.accent,
                        value: $carbs,
                        range: 40...520
                    )
                    TodayMacroEditorRow(
                        title: L("Fat"),
                        subtitle: TL(
                            pl: "Hormony, smak i stabilność",
                            en: "Hormones, flavor and steadiness",
                            uk: "Гормони, смак і стабільність",
                            ru: "Гормоны, вкус и стабильность",
                            es: "Hormonas, sabor y estabilidad"
                        ),
                        symbol: "drop",
                        color: Tokens.Mono.fat,
                        value: $fat,
                        range: 20...180
                    )
                    summaryCard
                        .padding(.top, 4)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Save"), action: onSave)
                }
            }
        }
    }

    private var title: String {
        TL(pl: "Makro dnia", en: "Daily macros", uk: "Макро дня", ru: "Макро дня", es: "Macros del día")
    }

    // Mockup: dark hero strip with a hi chart icon and the B/W/T total.
    private var summaryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Mono.hi)
            Text(
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
                )
            )
            .font(Tokens.Font.manrope(15, weight: 800))
            .foregroundStyle(Tokens.Mono.onHero)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .monoHero(padding: 16)
    }
}

/// Mockup `macro_editor_row`: card with track icon box, title + muted subtitle,
/// − value + stepper (5 g) and a coloured slider with range captions.
private struct TodayMacroEditorRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: symbol, style: .track, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.manrope(16, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    stepButton(symbol: "minus") {
                        value = max(range.lowerBound, value - 5)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        TextField("0", value: $value, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(Tokens.Font.monoNumber(20))
                            .foregroundStyle(Tokens.Palette.ink)
                            .fixedSize()
                        Text(verbatim: "g")
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    .frame(minWidth: 56)
                    stepButton(symbol: "plus") {
                        value = min(range.upperBound, value + 5)
                    }
                }
            }

            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(color)
                HStack {
                    Text(verbatim: "\(range.lowerBound) g")
                    Spacer()
                    Text(verbatim: "\(range.upperBound) g")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .monoCard(padding: 16)
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

extension TodayView {
    /// Goal dialogs are presented as a clear full-screen cover so the dim covers the
    /// floating tab bar too; the slide animation is disabled so they appear like alerts.
    func setGoalDialog(water: Bool? = nil, calorie: Bool? = nil) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let water {
                isWaterGoalAlertPresented = water
            }
            if let calorie {
                isCalorieGoalAlertPresented = calorie
            }
        }
    }
}

/// Design D "DialogCalorieGoal" / "DialogWaterGoal": centred card over a dim,
/// bordered numeric field and capsule buttons.
private struct TodayGoalDialog: View {
    enum Layout {
        /// Cancel + Save side by side (calorie goal).
        case inline
        /// Save full width, then Default + Cancel (water goal).
        case stacked
    }

    let icon: String?
    let title: String
    let message: String
    @Binding var value: Int
    let unit: String
    let layout: Layout
    let onSave: () -> Void
    let onDefault: (() -> Void)?
    let onCancel: () -> Void

    @FocusState private var isFieldFocused: Bool
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color(red: 10 / 255, green: 11 / 255, blue: 12 / 255)
                .opacity(isVisible ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)

            card
                .padding(.horizontal, 34)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
            }
            isFieldFocused = true
        }
    }

    private var card: some View {
        VStack(spacing: 12) {
            if let icon {
                MonoIconBox(systemName: icon, style: .track, size: 44)
            }
            Text(title)
                .font(Tokens.Font.manrope(17, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            valueField
            actions
                .padding(.top, 4)
        }
        .padding(.top, 22)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 30)
    }

    private var valueField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Tokens.Font.monoNumber(30))
                .foregroundStyle(Tokens.Palette.ink)
                .focused($isFieldFocused)
                .fixedSize()
            Text(verbatim: unit)
                .font(Tokens.Font.manrope(14, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Tokens.Palette.ink, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { isFieldFocused = true }
    }

    @ViewBuilder
    private var actions: some View {
        switch layout {
        case .inline:
            HStack(spacing: 8) {
                MonoButton(title: L("Cancel"), kind: .outline, height: 48, action: onCancel)
                MonoButton(title: L("Save"), kind: .dark, height: 48, action: onSave)
            }
        case .stacked:
            VStack(spacing: 8) {
                MonoButton(title: L("Save"), kind: .dark, height: 48, action: onSave)
                HStack(spacing: 8) {
                    if let onDefault {
                        MonoButton(title: L("Default"), kind: .outline, height: 44, action: onDefault)
                    }
                    MonoButton(title: L("Cancel"), kind: .ghost, height: 44, action: onCancel)
                }
            }
        }
    }
}
