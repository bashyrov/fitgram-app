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
                "Twoje tempo było zbyt agresywne — ustawiliśmy minimum kalorii, żeby chronić Twoje zdrowie. "
                    + "Rozważ wolniejszy plan."
            )
        }
        if let pace = request.paceKgPerWeek, pace >= 0.75 {
            warnings.append(
                "Tempo \(formatted(pace)) kg/tydzień jest dość intensywne. Większość ludzi osiąga "
                    + "trwałe rezultaty przy 0.25-0.5 kg/tydzień."
            )
        }
        return warnings
    }

    // MARK: - Tips

    private func tips(for request: RecommendationsRequest) -> [RecommendationTip] {
        var tips: [RecommendationTip] = []
        if let proteinTip = proteinTip(for: request) { tips.append(proteinTip) }
        tips.append(goalAnchorTip(for: request))
        tips.append(polishCuisineTip())
        tips.append(hydrationTip(waterGoalMl: request.waterGoalMl))
        if request.activityLevel == .sedentary {
            tips.append(sedentaryNudgeTip())
        }
        if !request.dietaryPreferences.isEmpty {
            tips.append(dietaryPreferenceTip(prefs: request.dietaryPreferences))
        }
        return tips
    }

    private func proteinTip(for request: RecommendationsRequest) -> RecommendationTip? {
        let proteinPerKg = Double(request.proteinGoalGrams) / request.weightKg
        guard request.goal == .lose, proteinPerKg < 1.2 else { return nil }
        return RecommendationTip(
            icon: "🍗",
            title: "Postaw na białko",
            description:
                "Przy odchudzaniu celuj w 1.5-2 g białka na kg masy ciała — twarożek, jajka, "
                + "schab i rośliny strączkowe pomogą zachować mięśnie."
        )
    }

    private func goalAnchorTip(for request: RecommendationsRequest) -> RecommendationTip {
        switch request.goal {
        case .lose:
            return RecommendationTip(
                icon: "🥗",
                title: "Połowa talerza to warzywa",
                description:
                    "Surówka z kapusty, mizeria, kiszone ogórki — polskie warzywa są "
                    + "niskokaloryczne i dają sytość. Spróbuj robić to przy każdym obiedzie."
            )
        case .gain:
            return RecommendationTip(
                icon: "🥜",
                title: "Małe wysokokaloryczne dodatki",
                description:
                    "Łyżka oliwy, garść orzechów, awokado — łatwy sposób, żeby dodać "
                    + "200-300 kcal bez czucia się przejedzonym."
            )
        case .maintain:
            return RecommendationTip(
                icon: "⚖️",
                title: "Konsystencja > perfekcja",
                description:
                    "Utrzymanie wagi to gra w średnich tygodniowych. Jeden dzień powyżej "
                    + "normy nic nie psuje — patrz na 7-dniowy obraz."
            )
        case .healthCondition:
            return RecommendationTip(
                icon: "👩‍⚕️",
                title: "Trzymaj plan dietetyka",
                description:
                    "Mealgram pomoże Ci śledzić to, co i tak masz robić. Eksportuj "
                    + "tygodniowy raport (Profil → Eksport CSV) i zabierz go na wizytę."
            )
        case .justTracking:
            return RecommendationTip(
                icon: "🔎",
                title: "Najpierw zauważ, potem zmieniaj",
                description:
                    "Przez 2 tygodnie po prostu loguj — bez celów. Wzorce, które zobaczysz, "
                    + "powiedzą Ci więcej niż jakikolwiek artykuł o dietach."
            )
        }
    }

    private func polishCuisineTip() -> RecommendationTip {
        RecommendationTip(
            icon: "🥟",
            title: "Polskie klasyki nie są wrogiem",
            description:
                "Pierogi ruskie ~250 kcal/porcja, żurek z jajkiem ~180 kcal — większość "
                + "polskich dań mieści się w zdrowej normie, jeśli pilnujesz porcji."
        )
    }

    private func hydrationTip(waterGoalMl: Int) -> RecommendationTip {
        RecommendationTip(
            icon: "💧",
            title: "Pij wodę przed posiłkiem",
            description:
                "Twoja dzienna norma to \(waterGoalMl) ml. Szklanka wody 15 minut przed "
                + "jedzeniem często wystarcza, żeby porcja była naturalnie mniejsza."
        )
    }

    private func sedentaryNudgeTip() -> RecommendationTip {
        RecommendationTip(
            icon: "🚶",
            title: "Krótkie spacery po posiłku",
            description:
                "10 minut po obiedzie obniża skok cukru i pomaga w odchudzaniu. Nie trzeba "
                + "zaczynać od siłowni — wystarczy ruch po pracy."
        )
    }

    private func dietaryPreferenceTip(prefs: [DietaryPreference]) -> RecommendationTip {
        let labels = prefs.map(\.label).joined(separator: ", ")
        return RecommendationTip(
            icon: "🌱",
            title: "Twoja dieta: \(labels)",
            description:
                "Twoja Szybka Baza i sugestie Oli filtrują się pod Twój styl. Zawsze "
                + "możesz dodać własne produkty w Profilu."
        )
    }

    // MARK: - Copy

    private func summaryCopy(for request: RecommendationsRequest) -> String {
        let kcal = request.dailyCalorieGoalKcal
        let protein = request.proteinGoalGrams
        switch request.goal {
        case .lose:
            return String(
                localized:
                    "Twój plan: \(kcal) kcal dziennie, \(protein) g białka. To bezpieczne tempo na zrównoważone odchudzanie."
            )
        case .gain:
            return String(
                localized:
                    "Twój plan: \(kcal) kcal dziennie, \(protein) g białka. Lekka nadwyżka — masa głównie z mięśni."
            )
        case .maintain:
            return String(
                localized:
                    "Twój plan: \(kcal) kcal dziennie. Cel — utrzymać wagę i zbudować zdrowe nawyki."
            )
        case .healthCondition:
            return String(
                localized:
                    "Twój plan: \(kcal) kcal i pełna kontrola makro. Trzymamy Cię na poziomie zaleceń."
            )
        case .justTracking:
            return String(
                localized:
                    "Twój plan: \(kcal) kcal jako punkt odniesienia. Loguj — odkryj, co tak naprawdę jesz."
            )
        }
    }

    private func nextStepsCopy(for request: RecommendationsRequest) -> String {
        switch request.goal {
        case .lose, .gain:
            return String(
                localized:
                    "Pierwszy krok: zaloguj dzisiejsze śniadanie. Spróbuj skanu zdjęciem — to najszybszy sposób."
            )
        case .maintain, .healthCondition, .justTracking:
            return String(
                localized:
                    "Pierwszy krok: zaloguj swoje kolejne 3 posiłki. Po tygodniu zobaczysz pierwsze wzorce."
            )
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
