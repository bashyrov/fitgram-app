import SwiftUI

extension TodayView {
    /// Builds the Recommendations fresh from the user's current profile so
    /// the copy always follows the in-app language picker — caching a
    /// localised JSON would freeze the strings to the language at write time.
    var currentRecommendations: Recommendations? {
        guard let user = state.user else { return nil }
        return RuleBasedRecommendationsService.buildSync(for: user)
    }

    /// Always rebuild from the rule-based generator so copy follows the
    /// in-app language picker instead of cached localised JSON.
    var todayRecommendations: Recommendations? {
        guard state.isViewingToday,
            entitlementsStore?.current.canUseOlaAdvice != false,
            let user = state.user
        else { return nil }
        return RuleBasedRecommendationsService.buildSync(for: user)
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
            let saved = await state.overrideCalorieGoal(clamped, userRemoteID: userRemoteID)
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
    var mealsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Text(state.isViewingToday ? L("Today") : L("Dziennik dnia"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld posiłków"), state.meals.count))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
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
    }
}
