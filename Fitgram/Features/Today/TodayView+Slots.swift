import SwiftUI

extension TodayView {
    /// Builds the Recommendations fresh from the user's current profile so
    /// the copy always follows the in-app language picker — caching a
    /// localised JSON would freeze the strings to the language at write time.
    var currentRecommendations: Recommendations? {
        guard let user = state.user else { return nil }
        return RuleBasedRecommendationsService.buildSync(for: user, dailyCalorieGoalKcal: state.calorieGoal)
    }

    /// Always rebuild from the rule-based generator so copy follows the
    /// in-app language picker instead of cached localised JSON.
    var todayRecommendations: Recommendations? {
        guard state.isViewingToday,
            entitlementsStore?.current.canUseOlaAdvice != false,
            let user = state.user
        else { return nil }
        return RuleBasedRecommendationsService.buildSync(for: user, dailyCalorieGoalKcal: state.calorieGoal)
    }

    var todayFact: NutritionFact? {
        guard state.isViewingToday else { return nil }
        return factSelector.factForToday(in: preferredFactCategory)
    }

    var preferredFactCategory: NutritionFact.Category {
        switch state.user?.goalKind ?? .maintain {
        case .lose:
            return .weightLoss
        case .gain:
            return .weightGain
        case .maintain:
            return .calories
        case .healthCondition:
            return .fiber
        case .justTracking:
            return .psychology
        }
    }

    func applyCalorieGoal(_ kcal: Int) {
        let clamped = max(1000, min(4500, kcal))
        Haptics.light()
        Task {
            let saved = await state.overrideCalorieGoalForVisibleDay(clamped, userRemoteID: userRemoteID)
            if saved {
                NotificationCenter.default.post(name: AppShortcutAction.mainGoalChanged, object: nil)
            }
        }
    }

    func applyMacroGoals() {
        Haptics.light()
        Task {
            let saved = await state.overrideMacroGoalsForVisibleDay(
                protein: proteinGoalDraft,
                carbs: carbsGoalDraft,
                fat: fatGoalDraft,
                userRemoteID: userRemoteID
            )
            if saved {
                NotificationCenter.default.post(name: AppShortcutAction.mainGoalChanged, object: nil)
            }
        }
    }

    /// Goal Tracking card. Three exclusive outcomes:
    /// 1. User has lose/gain goal + Premium → full card with AI tips.
    /// 2. User has lose/gain goal but no Premium → blurred peek card
    ///    (header sharp, body teasing); tap opens paywall.
    /// 3. User has no structured lose/gain goal → nothing.
    @ViewBuilder
    var goalTrackingSlot: some View {
        if state.isViewingToday, let user = state.user, shouldShowGoalSlot(for: user) {
            if let snapshot = premiumGoalSnapshot {
                GoalTrackingCard(snapshot: snapshot, tips: goalTipsForUser(user)) {
                    Haptics.light()
                    onOpenGoalTracking?()
                }
            } else {
                GoalTrackingPeekCard(
                    currentWeightKg: user.weightKg,
                    targetWeightKg: user.goalTargetWeightKg,
                    isLocked: entitlementsStore?.current.isPremium != true
                ) {
                    Haptics.light()
                    if entitlementsStore?.current.isPremium == true {
                        onOpenGoalTracking?()
                    } else {
                        paywallCoordinator?.present(.goalTracking)
                    }
                }
            }
        }
    }

    var premiumGoalSnapshot: GoalTrackingService.Snapshot? {
        guard entitlementsStore?.current.isPremium == true else { return nil }
        return goalTrackingState?.snapshot
    }

    @ViewBuilder
    var factOfDaySlot: some View {
        TodayBriefingStack(
            title: "Ciekawostka dnia",
            symbol: "lightbulb.fill",
            fact: todayFact,
            recommendations: nil,
            recommendationsUpdatedAt: nil,
            coachInsight: nil,
            isOlaLocked: false,
            upcomingEvent: nil,
            suggestedRecipe: nil,
            onOpenTips: {
                Haptics.light()
                isFactsLibraryPresented = true
            },
            onCoachAction: { kind in handleCoachAction(kind) },
            onDismissInsight: nil,
            onDismissEvent: {},
            onCookSuggested: nil
        )
    }

    /// First 3 tips from the cached `Recommendations` payload — they're
    /// already tailored to the user's goal kind, calorie/macro targets,
    /// dietary prefs, and current weight via the rule-based generator.
    func goalTipsForUser(_ user: User) -> [RecommendationTip] {
        guard let recs = RuleBasedRecommendationsService.buildSync(for: user) else { return [] }
        return Array(recs.tips.prefix(3))
    }

    /// Goal tracking block shows for every onboarded user. When there is
    /// no structured snapshot yet, the card still acts as a visible entry
    /// point under the water section instead of disappearing.
    func shouldShowGoalSlot(for user: User) -> Bool {
        user.remoteID.isEmpty == false
    }

    @ViewBuilder
    var olaAdviceSlot: some View {
        TodayBriefingStack(
            title: "Ola",
            symbol: "sparkles",
            fact: nil,
            recommendations: todayRecommendations,
            recommendationsUpdatedAt: state.user?.recommendationsGeneratedAt,
            coachInsight: canUseOlaAdvice && state.isViewingToday ? state.coachInsights.first : nil,
            isOlaLocked: state.isViewingToday && !canUseOlaAdvice,
            upcomingEvent: nil,
            suggestedRecipe: nil,
            onOpenTips: {
                Haptics.light()
                if canUseOlaAdvice {
                    isOlaTipsPresented = true
                } else {
                    paywallCoordinator?.present(.coachDebriefQuota)
                }
            },
            onCoachAction: { kind in handleCoachAction(kind) },
            onDismissInsight: onDismissInsight,
            onDismissEvent: {},
            onCookSuggested: nil
        )
    }

    @ViewBuilder
    var dailyOlaPlanSlot: some View {
        if state.isViewingToday, canUseOlaAdvice, let plan = state.dailyOlaPlan {
            DailyOlaPlanCard(
                plan: plan,
                calorieGoal: state.calorieGoal,
                proteinGoal: state.proteinGoal,
                carbsGoal: state.carbsGoal,
                fatGoal: state.fatGoal
            ) {
                Haptics.light()
                isOlaTipsPresented = true
            }
        }
    }

    @ViewBuilder
    var updatesStack: some View {
        TodayBriefingStack(
            title: "Dzisiaj",
            symbol: "calendar.badge.clock",
            fact: nil,
            recommendations: nil,
            recommendationsUpdatedAt: nil,
            coachInsight: nil,
            isOlaLocked: false,
            upcomingEvent: state.isViewingToday ? state.upcomingEvent : nil,
            suggestedRecipe: nil,
            onOpenTips: {
                Haptics.light()
                isFactsLibraryPresented = true
            },
            onCoachAction: { kind in handleCoachAction(kind) },
            onDismissInsight: nil,
            onDismissEvent: {
                Haptics.light()
                state.dismissCulturalEvent()
            },
            onCookSuggested: onCookSuggested
        )
    }

    var canUseOlaAdvice: Bool {
        entitlementsStore?.current.canUseOlaAdvice ?? true
    }

    @ViewBuilder
    var activitySection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            TL(
                                pl: "Ruch dzisiaj", en: "Today's movement", uk: "Рух сьогодні",
                                ru: "Движение сегодня", es: "Movimiento de hoy")
                        )
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                        Text(activitySummaryText)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Spacer()
                Button {
                    Haptics.light()
                    onAddWorkout()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.Palette.onPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Tokens.Palette.primary))
                        .shadow(color: Tokens.Palette.primary.opacity(0.14), radius: 10, y: 5)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(
                    Text(
                        TL(
                            pl: "Dodaj trening", en: "Add workout", uk: "Додати тренування", ru: "Добавить тренировку",
                            es: "Añadir entrenamiento")))
            }

            if state.workouts.isEmpty {
                Button {
                    Haptics.light()
                    onAddWorkout()
                } label: {
                    HStack(spacing: Tokens.Space.md) {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Tokens.Palette.accent)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Tokens.Palette.accentSoft.opacity(0.72))
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                TL(
                                    pl: "Dodaj ruch poza jedzeniem", en: "Add movement separately",
                                    uk: "Додай рух окремо від їжі", ru: "Добавь активность отдельно от еды",
                                    es: "Añade movimiento por separado")
                            )
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                            Text(
                                TL(
                                    pl: "Trening ma własny budżet kcal i nie miesza się z posiłkami.",
                                    en: "Workouts get their own kcal budget and stay separate from meals.",
                                    uk: "Тренування має власний бюджет ккал і не змішується з їжею.",
                                    ru: "Тренировка имеет свой бюджет ккал и не смешивается с едой.",
                                    es: "El entrenamiento tiene su propio presupuesto kcal y no se mezcla con comidas.")
                            )
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                    .padding(Tokens.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Tokens.Palette.surface.opacity(0.72))
                    )
                }
                .buttonStyle(PressableButtonStyle())
            } else {
                LazyVStack(spacing: Tokens.Space.sm) {
                    ForEach(state.workouts) { workout in
                        WorkoutTimelineRow(
                            workout: workout,
                            onOpen: { selectedWorkout = workout },
                            onDelete: { onDeleteWorkout?(workout) }
                        )
                    }
                }
            }
        }
        .padding(Tokens.Space.md)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Palette.surface.opacity(0.70),
                            Tokens.Palette.accentSoft.opacity(0.38),
                            Tokens.Palette.background.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var activitySummaryText: String {
        if state.workoutCaloriesBurned > 0 {
            let appliedCalories = state.workoutCaloriesAppliedToGoal
            if appliedCalories <= 0 {
                return String.localizedStringWithFormat(
                    TL(
                        pl: "%lld kcal spalonych, cel bez zmian",
                        en: "%lld kcal burned, target unchanged",
                        uk: "%lld ккал спалено, ціль без змін",
                        ru: "%lld ккал сожжено, цель без изменений",
                        es: "%lld kcal quemadas, objetivo sin cambios"),
                    Int(state.workoutCaloriesBurned.rounded())
                )
            }
            return String.localizedStringWithFormat(
                TL(
                    pl: "+%lld kcal do budżetu dnia", en: "+%lld kcal added to today's budget",
                    uk: "+%lld ккал до бюджету дня", ru: "+%lld ккал к бюджету дня",
                    es: "+%lld kcal al presupuesto del día"), Int(appliedCalories.rounded())
            )
        }
        return TL(
            pl: "Osobny blok dla treningów i spacerów", en: "Separate space for workouts and walks",
            uk: "Окремий блок для тренувань і прогулянок", ru: "Отдельный блок для тренировок и прогулок",
            es: "Bloque separado para entrenos y paseos")
    }

    @ViewBuilder
    var mealsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.isViewingToday ? L("Today") : L("Dziennik dnia"))
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(String.localizedStringWithFormat(L("%lld posiłków"), state.meals.count))
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Spacer()
                Button {
                    Haptics.light()
                    onOpenAddOptions()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.Palette.onPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Tokens.Palette.primary))
                        .shadow(color: Tokens.Palette.primary.opacity(0.14), radius: 10, y: 5)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(L("Dodaj posiłek")))
            }

            if state.meals.isEmpty {
                EmptyMealsCallout(onTap: onOpenAddOptions)
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
        .padding(Tokens.Space.md)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Palette.surface.opacity(0.76),
                            Tokens.Palette.primarySoft.opacity(0.42),
                            Tokens.Palette.background.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

private struct DailyOlaPlanCard: View {
    let plan: DailyOlaPlan
    let calorieGoal: Int
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                header
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(plan.headline)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(plan.body)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                focusStrip
                if let risk = plan.risk {
                    riskRow(risk)
                }
                firstMealRow
            }
            .padding(Tokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frostedGlass(cornerRadius: 30, fillOpacity: 0.86, borderOpacity: 0.05, glowOpacity: 0.08)
            .shadow(color: Tokens.Palette.primary.opacity(0.09), radius: 26, x: 0, y: 14)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(L("Open Ola daily plan")))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Tokens.Palette.onPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Ola today"))
                    .font(Tokens.Font.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(liveGoalSummary)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private var liveGoalSummary: String {
        String.localizedStringWithFormat(
            TL(
                pl: "Dzisiaj %lld kcal · B/W/T %lld/%lld/%lld g",
                en: "Today %lld kcal · P/C/F %lld/%lld/%lld g",
                uk: "Сьогодні %lld ккал · Б/В/Ж %lld/%lld/%lld г",
                ru: "Сегодня %lld ккал · Б/У/Ж %lld/%lld/%lld г",
                es: "Hoy %lld kcal · P/C/G %lld/%lld/%lld g"
            ),
            calorieGoal,
            proteinGoal,
            carbsGoal,
            fatGoal
        )
    }

    private var focusStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach(plan.focuses.prefix(3)) { focus in
                VStack(alignment: .leading, spacing: 3) {
                    Text(focus.title)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                    Text(focus.value)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(focus.detail)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Tokens.Space.sm)
                .padding(.vertical, Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Tokens.Palette.surfaceMuted.opacity(0.68))
                )
            }
        }
    }

    private func riskRow(_ risk: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Palette.warning)
            Text(risk)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Palette.warning.opacity(0.12))
        )
    }

    private var firstMealRow: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Palette.accent)
            Text(plan.firstMealSuggestion)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
