import Foundation
import SwiftUI

/// Saved macro strategy used by the automatic goal calculator.
/// Percent values are kcal shares: protein / carbs / fat.
enum DietMacroPreset: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case balanced
    case highProtein = "high_protein"
    case highCarb = "high_carb"
    case lowCarb = "low_carb"
    case keto

    var id: String { rawValue }

    var proteinShare: Double {
        switch self {
        case .balanced: return 0.25
        case .highProtein: return 0.35
        case .highCarb: return 0.25
        case .lowCarb: return 0.30
        case .keto: return 0.20
        }
    }

    var carbsShare: Double {
        switch self {
        case .balanced: return 0.45
        case .highProtein: return 0.35
        case .highCarb: return 0.50
        case .lowCarb: return 0.25
        case .keto: return 0.05
        }
    }

    var fatShare: Double {
        switch self {
        case .balanced: return 0.30
        case .highProtein: return 0.30
        case .highCarb: return 0.25
        case .lowCarb: return 0.45
        case .keto: return 0.75
        }
    }

    var title: String {
        switch self {
        case .balanced:
            return TL(pl: "Zbalansowana", en: "Balanced", uk: "Збалансована", ru: "Сбалансированная", es: "Equilibrada")
        case .highProtein:
            return TL(
                pl: "Wysokobiałkowa", en: "High-protein", uk: "Високобілкова", ru: "Высокобелковая",
                es: "Alta en proteína")
        case .highCarb:
            return TL(
                pl: "Energetyczna", en: "High-carb energy", uk: "Енергетична", ru: "Энергетическая", es: "Energética")
        case .lowCarb:
            return TL(
                pl: "Low-carb", en: "Low-carb", uk: "Низьковуглеводна", ru: "Низкоуглеводная",
                es: "Baja en carbohidratos")
        case .keto:
            return TL(pl: "Keto", en: "Keto", uk: "Кето", ru: "Кето", es: "Keto")
        }
    }

    var subtitle: String {
        switch self {
        case .balanced:
            return TL(
                pl: "Zdrowo i spokojnie na długi termin.",
                en: "A steady long-term healthy split.",
                uk: "Спокійний здоровий спліт на довгу дистанцію.",
                ru: "Спокойный здоровый сплит на долгий срок.",
                es: "Un reparto saludable y sostenible."
            )
        case .highProtein:
            return TL(
                pl: "Więcej sytości i ochrona mięśni na redukcji.",
                en: "More satiety and muscle retention while cutting.",
                uk: "Більше ситості та збереження м'язів на дефіциті.",
                ru: "Больше сытости и сохранение мышц на дефиците.",
                es: "Más saciedad y protección muscular en déficit."
            )
        case .highCarb:
            return TL(
                pl: "Więcej paliwa do treningu i budowy masy.",
                en: "More fuel for training and gaining.",
                uk: "Більше енергії для тренувань і набору.",
                ru: "Больше топлива для тренировок и набора.",
                es: "Más energía para entrenar y ganar masa."
            )
        case .lowCarb:
            return TL(
                pl: "Mniej skrobi, stabilniejszy apetyt.",
                en: "Less starch, steadier appetite.",
                uk: "Менше крохмалю, стабільніший апетит.",
                ru: "Меньше крахмала, стабильнее аппетит.",
                es: "Menos almidón, apetito más estable."
            )
        case .keto:
            return TL(
                pl: "Bardzo mało węgli, tylko dla świadomych użytkowników.",
                en: "Very low carb, for experienced users.",
                uk: "Дуже мало вуглеводів, для досвідчених користувачів.",
                ru: "Очень мало углеводов, для опытных пользователей.",
                es: "Muy baja en carbohidratos, para usuarios expertos."
            )
        }
    }

    var splitLabel: String {
        "\(Int((proteinShare * 100).rounded())) / \(Int((carbsShare * 100).rounded())) / \(Int((fatShare * 100).rounded()))"
    }

    var symbol: String {
        switch self {
        case .balanced: return "scale.3d"
        case .highProtein: return "figure.strengthtraining.traditional"
        case .highCarb: return "bolt.fill"
        case .lowCarb: return "leaf.fill"
        case .keto: return "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .balanced: return Tokens.Palette.primary
        case .highProtein: return Tokens.Palette.accent
        case .highCarb: return Tokens.Palette.warning
        case .lowCarb: return Tokens.Palette.success
        case .keto: return Tokens.Palette.ink
        }
    }

    static func recommended(for goal: GoalKind) -> DietMacroPreset {
        switch goal {
        case .lose: return .highProtein
        case .gain: return .highCarb
        case .maintain, .healthCondition, .justTracking: return .balanced
        }
    }
}
