import Foundation

/// Deterministic, offline fallback for the AI Coach. Generates a
/// `Recommendations` bundle from the same input the Worker would
/// receive. Picks 3-5 tips from a prioritised catalog so the user
/// always lands on something useful, even when Claude isn't reachable.
///
/// Rules are ordered by severity: safety floor warnings + pace
/// caveats come before nutritional polish. Output capped at 5 tips so
/// the onboarding results screen stays scannable.
final class RuleBasedRecommendationsService: RecommendationsServing {
    func generate(for request: RecommendationsRequest) async throws -> Recommendations {
        var tips: [Recommendations.Tip] = []
        var warnings: [String] = []

        // 1. Safety floor — runs first because the rest of the plan is
        //    suspect if we capped kcal.
        if request.hitSafetyFloor {
            warnings.append(
                "Twoje tempo było zbyt agresywne — ustawiliśmy minimum kalorii, żeby chronić Twoje zdrowie. Rozważ wolniejszy plan."
            )
        }

        // 2. Pace warning — 0.75+ kg/wk is generally too aggressive for
        //    most non-clinical adults.
        if let pace = request.paceKgPerWeek, pace >= 0.75 {
            warnings.append(
                "Tempo \(formatted(pace)) kg/tydzień jest dość intensywne. Większość ludzi osiąga trwałe rezultaty przy 0.25-0.5 kg/tydzień."
            )
        }

        // 3. Protein adequacy — under 1.2 g/kg means we'll struggle to
        //    keep lean mass on a cut.
        let proteinPerKg = Double(request.proteinGoalGrams) / request.weightKg
        if request.goal == .lose, proteinPerKg < 1.2 {
            tips.append(
                .init(
                    icon: "🍗",
                    title: "Postaw na białko",
                    description:
                        "Przy odchudzaniu celuj w 1.5-2 g białka na kg masy ciała — twarożek, jajka, schab i rośliny strączkowe pomogą zachować mięśnie."
                )
            )
        }

        // 4. Goal-specific anchor tip.
        switch request.goal {
        case .lose:
            tips.append(
                .init(
                    icon: "🥗",
                    title: "Połowa talerza to warzywa",
                    description:
                        "Surówka z kapusty, mizeria, kiszone ogórki — polskie warzywa są niskokaloryczne i dają sytość. Spróbuj robić to przy każdym obiedzie."
                )
            )
        case .gain:
            tips.append(
                .init(
                    icon: "🥜",
                    title: "Małe wysokokaloryczne dodatki",
                    description:
                        "Łyżka oliwy, garść orzechów, awokado — łatwy sposób, żeby dodać 200-300 kcal bez czucia się przejedzonym."
                )
            )
        case .maintain:
            tips.append(
                .init(
                    icon: "⚖️",
                    title: "Konsystencja > perfekcja",
                    description:
                        "Utrzymanie wagi to gra w średnich tygodniowych. Jeden dzień powyżej normy nic nie psuje — patrz na 7-dniowy obraz."
                )
            )
        case .healthCondition:
            tips.append(
                .init(
                    icon: "👩‍⚕️",
                    title: "Trzymaj plan dietetyka",
                    description:
                        "Mealgram pomoże Ci śledzić to, co i tak masz robić. Eksportuj tygodniowy raport (Profil → Eksport CSV) i zabierz go na wizytę."
                )
            )
        case .justTracking:
            tips.append(
                .init(
                    icon: "🔎",
                    title: "Najpierw zauważ, potem zmieniaj",
                    description:
                        "Przez 2 tygodnie po prostu loguj — bez celów. Wzorce, które zobaczysz, powiedzą Ci więcej niż jakikolwiek artykuł o dietach."
                )
            )
        }

        // 5. Polish cuisine tip — always present; the user signed up
        //    for a PL-market app so this is on-brand.
        tips.append(
            .init(
                icon: "🥟",
                title: "Polskie klasyki nie są wrogiem",
                description:
                    "Pierogi ruskie ~250 kcal/porcja, żurek z jajkiem ~180 kcal — większość polskich dań mieści się w zdrowej normie, jeśli pilnujesz porcji."
            )
        )

        // 6. Hydration prompt — universal.
        tips.append(
            .init(
                icon: "💧",
                title: "Pij wodę przed posiłkiem",
                description:
                    "Twoja dzienna norma to \(request.waterGoalMl) ml. Szklanka wody 15 minut przed jedzeniem często wystarcza, żeby porcja była naturalnie mniejsza."
            )
        )

        // 7. Activity nudge for sedentary users.
        if request.activityLevel == .sedentary {
            tips.append(
                .init(
                    icon: "🚶",
                    title: "Krótkie spacery po posiłku",
                    description:
                        "10 minut po obiedzie obniża skok cukru i pomaga w odchudzaniu. Nie trzeba zaczynać od siłowni — wystarczy ruch po pracy."
                )
            )
        }

        // 8. Dietary preference courtesy tip if user flagged any.
        if !request.dietaryPreferences.isEmpty {
            let labels = request.dietaryPreferences.map(\.label).joined(separator: ", ")
            tips.append(
                .init(
                    icon: "🌱",
                    title: "Twoja dieta: \(labels)",
                    description:
                        "Twoja Szybka Baza i sugestie Oli filtrują się pod Twój styl. Zawsze możesz dodać własne produkty w Profilu."
                )
            )
        }

        let limitedTips = Array(tips.prefix(5))
        let summary = summaryCopy(for: request)
        let nextSteps = nextStepsCopy(for: request)

        return Recommendations(
            summary: summary,
            tips: limitedTips,
            warnings: warnings,
            nextSteps: nextSteps,
            source: "rule_based"
        )
    }

    private func summaryCopy(for request: RecommendationsRequest) -> String {
        switch request.goal {
        case .lose:
            return String(
                localized:
                    "Twój plan: \(request.dailyCalorieGoalKcal) kcal dziennie, \(request.proteinGoalGrams) g białka. To bezpieczne tempo na zrównoważone odchudzanie."
            )
        case .gain:
            return String(
                localized:
                    "Twój plan: \(request.dailyCalorieGoalKcal) kcal dziennie, \(request.proteinGoalGrams) g białka. Lekka nadwyżka — masa będzie głównie z mięśni, nie z tłuszczu."
            )
        case .maintain:
            return String(
                localized:
                    "Twój plan: \(request.dailyCalorieGoalKcal) kcal dziennie. Cel — utrzymać wagę i zbudować zdrowe nawyki."
            )
        case .healthCondition:
            return String(
                localized:
                    "Twój plan: \(request.dailyCalorieGoalKcal) kcal i pełna kontrola makro. Skupimy się na tym, żeby trzymać Cię na poziomie zaleceń."
            )
        case .justTracking:
            return String(
                localized:
                    "Twój plan: \(request.dailyCalorieGoalKcal) kcal jako punkt odniesienia. Loguj — odkryj, co tak naprawdę jesz."
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
