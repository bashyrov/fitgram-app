import SwiftUI

enum AchievementCollectionCategory: String, CaseIterable, Identifiable {
    case all
    case rhythm
    case nutrition
    case logging
    case lifestyle
    case legendary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("Wszystkie")
        case .rhythm: return L("Rytm")
        case .nutrition: return L("Makro")
        case .logging: return L("Dodawanie")
        case .lifestyle: return L("Styl życia")
        case .legendary: return L("Legendarne")
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .rhythm: return "flame.fill"
        case .nutrition: return "bolt.heart.fill"
        case .logging: return "plus.viewfinder"
        case .lifestyle: return "leaf.fill"
        case .legendary: return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return Tokens.Palette.primary
        case .rhythm: return Tokens.Palette.warning
        case .nutrition: return Tokens.Palette.accent
        case .logging: return Tokens.Palette.primary
        case .lifestyle: return Tokens.Palette.success
        case .legendary: return Color(red: 0.84, green: 0.54, blue: 0.10)
        }
    }

    func filter(_ definitions: [AchievementDefinition]) -> [AchievementDefinition] {
        switch self {
        case .all:
            return definitions
        case .rhythm:
            return definitions.filter { $0.id.hasPrefix("streak") || $0.id.hasPrefix("week") }
        case .nutrition:
            return definitions.filter {
                $0.id.hasPrefix("protein") || $0.id.hasPrefix("calories") || $0.id.hasPrefix("macros")
                    || $0.id.hasPrefix("variety")
            }
        case .logging:
            return definitions.filter {
                $0.id.hasPrefix("meal.") || $0.id.hasPrefix("source") || $0.id.hasPrefix("mealtype")
                    || $0.id == "scan.first" || $0.id == "barcode.first" || $0.id == "voice.first"
                    || $0.id == "quickdb.first"
            }
        case .lifestyle:
            return definitions.filter {
                $0.id.hasPrefix("recipe") || $0.id.hasPrefix("recipes") || $0.id.hasPrefix("weight")
                    || $0.id.hasPrefix("tag")
            }
        case .legendary:
            return definitions.filter { $0.rarity == .legendary || $0.rarity == .rare }
        }
    }
}

enum AchievementRarity: String, CaseIterable, Identifiable {
    case common
    case rare
    case legendary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .common: return L("Częste")
        case .rare: return L("Rzadkie")
        case .legendary: return L("Legendarne")
        }
    }

    var symbol: String {
        switch self {
        case .common: return "seal.fill"
        case .rare: return "rosette"
        case .legendary: return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .common: return Tokens.Palette.primary
        case .rare: return Tokens.Palette.accent
        case .legendary: return Tokens.Palette.warning
        }
    }
}

extension AchievementDefinition {
    var rarity: AchievementRarity {
        let isLegendary =
            id.contains(".500") || id.contains(".730") || id.contains(".1000") || id.contains(".2000")
            || id.contains(".5000") || id == "achievements.100" || id == "streak.365"
        if isLegendary {
            return .legendary
        }
        let isRare =
            id.contains(".100") || id.contains(".200") || id.contains(".250") || id.hasPrefix("achievements.")
            || id == "streak.100"
        if isRare {
            return .rare
        }
        return .common
    }
}
