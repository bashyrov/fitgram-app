import SwiftUI

/// Main "Today" screen — what the user sees after sign-in once
/// onboarding is done. Plays the role the master prompt assigns to the
/// Today tab.
struct TodayView: View {
    let userRemoteID: String
    @Bindable var state: TodayState
    let onOpenProfile: () -> Void
    let onOpenScanner: () -> Void
    var onCookSuggested: ((Recipe) -> Void)?
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenWeeklyDebrief: (() -> Void)?
    var onSelectMeal: ((MealEntry) -> Void)?
    var onDismissInsight: ((CoachInsight) -> Void)?

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
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    StreakHeader(
                        greeting: state.greeting,
                        displayName: state.user?.displayName,
                        streakLength: state.streak?.currentLength ?? 0,
                        onTapProfile: onOpenProfile
                    )
                    .padding(.top, Tokens.Space.md)

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
                        progress: state.calorieProgress
                    )

                    MacroDistributionCard(
                        protein: state.totals.protein,
                        carbs: state.totals.carbs,
                        fat: state.totals.fat,
                        proteinGoal: state.user?.proteinGoalGrams ?? 120,
                        carbsGoal: state.user?.carbsGoalGrams ?? 240,
                        fatGoal: state.user?.fatGoalGrams ?? 70
                    )

                    WaterCard(
                        totalMilliliters: state.waterTotalMl,
                        goalMilliliters: WaterService.defaultDailyGoalMilliliters,
                        onAddGlass: {
                            Haptics.light()
                            Task { await state.logWaterGlass(for: userRemoteID) }
                        },
                        onUndo: {
                            Haptics.warning()
                            Task { await state.undoLastWater(for: userRemoteID) }
                        }
                    )

                    if let insight = state.coachInsights.first {
                        AIInsightCard(
                            insight: insight,
                            onAction: { kind in handleCoachAction(kind) },
                            onDismiss: onDismissInsight.map { handler in
                                { handler(insight) }
                            }
                        )
                    }

                    if let onOpenWeeklyDebrief {
                        WeeklyDebriefShortcut(onTap: onOpenWeeklyDebrief)
                    }

                    if let upcoming = state.upcomingEvent {
                        CulturalEventBanner(upcoming: upcoming)
                    }

                    if let suggested = state.suggestedRecipe, let onCookSuggested {
                        SuggestedRecipeCard(recipe: suggested) {
                            onCookSuggested(suggested)
                        }
                    }

                    mealsSection
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
            }
            .refreshable {
                await state.refresh(for: userRemoteID)
            }
        }
        .task {
            await state.refresh(for: userRemoteID)
        }
    }

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text("Dziś")
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
