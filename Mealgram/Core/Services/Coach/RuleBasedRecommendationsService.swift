import Foundation

/// Deterministic, offline fallback for the AI Coach. Generates a
/// `Recommendations` bundle from the same input the Worker would
/// receive. Picks 3-5 tips from a prioritised catalog so the user
/// always lands on something useful, even when Claude isn't reachable.
///
/// Rules are ordered by severity: safety floor warnings + pace caveats
/// come before nutritional polish. Output capped at 5 tips so the
/// onboarding results screen stays scannable.
final class RuleBasedRecommendationsService: RecommendationsServing {
    func generate(for request: RecommendationsRequest) async throws -> Recommendations {
        Self.build(for: request)
    }

    /// Synchronous variant used by `UserProfileService` to refresh the
    /// cached recommendations blob whenever a goal/macro/water override
    /// changes. The rule-based path has no I/O, so calling it from a
    /// `@MainActor` save path is fine.
    static func buildSync(for request: RecommendationsRequest) -> Recommendations {
        build(for: request)
    }

    /// Builds a `RecommendationsRequest` from the User row and returns
    /// the refreshed bundle. Returns nil if the user hasn't filled in
    /// the prerequisite biometrics yet (still on onboarding).
    static func buildSync(for user: User) -> Recommendations? {
        guard let height = user.heightCm,
            let weight = user.weightKg,
            let birth = user.birthDate
        else { return nil }
        let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        let request = RecommendationsRequest(
            biologicalSex: user.biologicalSex,
            age: age,
            heightCm: height,
            weightKg: weight,
            activityLevel: user.activityLevel,
            goal: user.goalKind,
            paceKgPerWeek: user.goalPaceKgPerWeek,
            dailyCalorieGoalKcal: user.dailyCalorieGoalKcal,
            proteinGoalGrams: user.proteinGoalGrams,
            fatGoalGrams: user.fatGoalGrams,
            carbsGoalGrams: user.carbsGoalGrams,
            fiberGoalGrams: user.fiberGoalGrams,
            waterGoalMl: user.waterGoalMl,
            dietaryPreferences: Array(user.dietaryPreferences),
            hitSafetyFloor: user.dailyCalorieGoalKcal <= 1200
        )
        return build(for: request)
    }

    private static func build(for request: RecommendationsRequest) -> Recommendations {
        let service = RuleBasedRecommendationsService()
        let warnings = service.warnings(for: request)
        let tips = Array(service.tips(for: request).prefix(5))
        return Recommendations(
            summary: service.summaryCopy(for: request),
            tips: tips,
            warnings: warnings,
            nextSteps: service.nextStepsCopy(for: request),
            source: "rule_based"
        )
    }

    // MARK: - Warnings

    private func warnings(for request: RecommendationsRequest) -> [String] {
        var warnings: [String] = []
        if request.hitSafetyFloor {
            warnings.append(
                L("Your pace was too aggressive — we have set a calorie minimum to protect your health.")
                    + L("Rozważ wolniejszy plan.")
            )
        }
        if let pace = request.paceKgPerWeek, pace >= 0.75 {
            warnings.append(
                String.localizedStringWithFormat(L("Pace %@ kg/week is quite intense. Most people reach "), formatted(pace))
                    + L("trwałe rezultaty przy 0.25-0.5 kg/tydzień.")
            )
        }
        return warnings
    }

    // MARK: - Tips

    private func tips(for request: RecommendationsRequest) -> [RecommendationTip] {
        // Rotation seed — calendar day of year. Same plan stays stable
        // throughout the day, but Ola surfaces a fresh angle every
        // morning so the onboarding-cached snapshot doesn't feel stale.
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        var tips: [RecommendationTip] = []
        if let proteinTip = proteinTip(for: request, seed: seed) { tips.append(proteinTip) }
        tips.append(goalAnchorTip(for: request, seed: seed))
        tips.append(cuisineTip(seed: seed))
        tips.append(hydrationTip(waterGoalMl: request.waterGoalMl, seed: seed))
        if request.activityLevel == .sedentary {
            tips.append(sedentaryNudgeTip(seed: seed))
        }
        if !request.dietaryPreferences.isEmpty {
            tips.append(dietaryPreferenceTip(prefs: request.dietaryPreferences))
        }
        return tips
    }

    /// Picks one option from the array using the supplied seed — gives
    /// stable-per-day rotation without external randomness.
    private static func pick<T>(_ options: [T], seed: Int) -> T {
        options[abs(seed) % options.count]
    }

    private func proteinTip(for request: RecommendationsRequest, seed: Int) -> RecommendationTip? {
        let proteinPerKg = Double(request.proteinGoalGrams) / request.weightKg
        guard request.goal == .lose, proteinPerKg < 1.2 else { return nil }
        let variants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🍗",
                title: L("Lean on protein"),
                description:
                    L("Aim for 1.5-2 g of protein per kg of body weight — cottage cheese, eggs, chicken, lentils keep muscle while fat goes.")
            ),
            RecommendationTip(
                icon: "🥚",
                title: L("Front-load protein"),
                description: L("Hitting 30-35 g at breakfast cuts the 11 AM cookie reflex more than half of users notice.")
            ),
            RecommendationTip(
                icon: "🐟",
                title: L("Two protein servings"),
                description:
                    L("Two palm-sized servings of meat / fish / tofu per day usually nails your protein target without obsessing.")
            ),
        ]
        return Self.pick(variants, seed: seed)
    }

    private func goalAnchorTip(for request: RecommendationsRequest, seed: Int) -> RecommendationTip {
        let loseVariants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🥗", title: L("Half the plate is vegetables"),
                description:
                    L("Salad, slaw, pickled cucumbers — low-calorie volume keeps you full. Try it at every lunch and dinner.")
            ),
            RecommendationTip(
                icon: "🍽", title: L("Slow the meal down"),
                description:
                    L("20 minutes per meal lets satiety signals catch up. Most over-eating is finishing the plate before your gut knows it's full.")
            ),
            RecommendationTip(
                icon: "🌅", title: L("Stop late-night snacking"),
                description: L("A loose 8 PM cut-off saves most people 200-400 kcal a day without changing what they eat.")
            ),
        ]
        let gainVariants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🥜", title: L("Small high-calorie add-ons"),
                description:
                    L("A spoon of olive oil, a handful of nuts, half an avocado — easy +200-300 kcal without feeling stuffed.")
            ),
            RecommendationTip(
                icon: "🥛", title: L("Drink your calories"),
                description:
                    L("Smoothies and milk are easier than chewing more food. A 400 kcal shake between meals adds up fast.")
            ),
        ]
        let maintainVariants: [RecommendationTip] = [
            RecommendationTip(
                icon: "⚖️", title: L("Consistency beats perfection"),
                description:
                    L("Maintenance is a weekly-average game. One above-target day doesn't break it — watch the 7-day picture.")
            ),
            RecommendationTip(
                icon: "📊", title: L("Mind the trend, not the day"),
                description: L("Daily weight swings 1-2 kg on water alone. Trust the 14-day moving average.")),
        ]
        let healthVariants: [RecommendationTip] = [
            RecommendationTip(
                icon: "👩‍⚕️", title: L("Follow your dietitian's plan"),
                description:
                    L("Mealgram helps you track what you're already supposed to do. Export weekly CSV from Profile and bring it to the visit.")
            )
        ]
        let trackingVariants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🔎", title: L("Notice first, change later"),
                description:
                    L("Just log for two weeks — no targets. The patterns you spot say more than any diet article.")),
            RecommendationTip(
                icon: "📝", title: L("Two weeks of honest logs"),
                description: L("Don't change anything yet. The data points show you what's worth nudging.")),
        ]
        switch request.goal {
        case .lose: return Self.pick(loseVariants, seed: seed)
        case .gain: return Self.pick(gainVariants, seed: seed)
        case .maintain: return Self.pick(maintainVariants, seed: seed)
        case .healthCondition: return Self.pick(healthVariants, seed: seed)
        case .justTracking: return Self.pick(trackingVariants, seed: seed)
        }
    }

    private func cuisineTip(seed: Int) -> RecommendationTip {
        let variants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🌍", title: L("Comfort food isn't the enemy"),
                description:
                    L("Most home-cooked dishes fit in your daily target if portions are sane. Mealgram tracks weight, not your culture.")
            ),
            RecommendationTip(
                icon: "🍝", title: L("Pasta is fine in portions"),
                description:
                    L("150 g cooked pasta = ~200 kcal. Half the plate vegetables and a fist of protein keeps it balanced.")
            ),
            RecommendationTip(
                icon: "🍣", title: L("Sushi math"),
                description: L("8-piece roll runs ~250-350 kcal. Two rolls + miso soup is a balanced lunch most days.")),
            RecommendationTip(
                icon: "🥙", title: L("Wraps beat sandwiches"),
                description:
                    L("A wrap with lean protein + lots of veg usually beats a hot sandwich on calories and protein-per-bite.")
            ),
        ]
        return Self.pick(variants, seed: seed)
    }

    private func hydrationTip(waterGoalMl: Int, seed: Int) -> RecommendationTip {
        let variants: [RecommendationTip] = [
            RecommendationTip(
                icon: "💧", title: L("Drink water before meals"),
                description:
                    String.localizedStringWithFormat(L("Your daily target is %lld ml. A glass 15 minutes before eating often shrinks the portion naturally."), waterGoalMl)
            ),
            RecommendationTip(
                icon: "🚰", title: L("Glass at every transition"),
                description:
                    String.localizedStringWithFormat(L("Tie water to existing habits — one at wake-up, one at lunch, one at clock-out. Hitting %lld ml gets automatic."), waterGoalMl)
            ),
            RecommendationTip(
                icon: "🥤", title: L("Thirst masquerades as hunger"),
                description:
                    L("When the 4 PM snack craving hits, try a tall glass of water first. Many 'hunger' signals dissolve in 10 minutes.")
            ),
        ]
        return Self.pick(variants, seed: seed)
    }

    private func sedentaryNudgeTip(seed: Int) -> RecommendationTip {
        let variants: [RecommendationTip] = [
            RecommendationTip(
                icon: "🚶", title: L("10-min walk after dinner"),
                description: L("Lowers the post-meal blood-sugar spike by ~20% on average. No gym required — just shoes.")),
            RecommendationTip(
                icon: "🪜", title: L("Take the stairs"),
                description:
                    L("5 floors a day = ~50 kcal extra plus a quad workout. Small habits compound across the year.")),
            RecommendationTip(
                icon: "⏰", title: L("Stand every hour"),
                description:
                    L("Even one minute of standing per hour at a desk job lifts daily energy expenditure noticeably.")),
        ]
        return Self.pick(variants, seed: seed)
    }

    private func dietaryPreferenceTip(prefs: [DietaryPreference]) -> RecommendationTip {
        let labels = prefs.map(\.label).joined(separator: ", ")
        return RecommendationTip(
            icon: "🌱",
            title: String.localizedStringWithFormat(L("Your diet: %@"), labels),
            description:
                L("Twoja Szybka Baza i sugestie Oli filtrują się pod Twój styl. Zawsze ")
                + L("możesz dodać własne produkty w Profilu.")
        )
    }

    // MARK: - Copy

    private func summaryCopy(for request: RecommendationsRequest) -> String {
        let kcal = request.dailyCalorieGoalKcal
        let protein = request.proteinGoalGrams
        switch request.goal {
        case .lose:
            return String.localizedStringWithFormat(L("Your plan: %lld kcal daily, %lld g protein. A safe pace for balanced weight loss."), kcal, protein)
        case .gain:
            return String.localizedStringWithFormat(L("Your plan: %lld kcal daily, %lld g protein. A light surplus — mass mostly from muscle."), kcal, protein)
        case .maintain:
            return String.localizedStringWithFormat(L("Your plan: %lld kcal daily. Goal — keep your weight and build healthy habits."), kcal)
        case .healthCondition:
            return String.localizedStringWithFormat(L("Your plan: %lld kcal and full macro control. We keep you at the recommended level."), kcal)
        case .justTracking:
            return String.localizedStringWithFormat(L("Your plan: %lld kcal as a reference point. Log it — discover what you really eat."), kcal)
        }
    }

    private func nextStepsCopy(for request: RecommendationsRequest) -> String {
        switch request.goal {
        case .lose, .gain:
            return L("First step: log today's breakfast. Try the photo scan — it's the fastest way.")
        case .maintain, .healthCondition, .justTracking:
            return L("First step: log your next 3 meals. After a week, you will see the first patterns.")
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
