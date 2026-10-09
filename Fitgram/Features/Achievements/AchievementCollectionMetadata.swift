import SwiftUI

enum AchievementCollectionCategory: String, CaseIterable, Identifiable {
    case all
    case levels
    case rhythm
    case nutrition
    case logging
    case lifestyle
    case activity
    case social
    case special
    case legendary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("Wszystkie")
        case .levels: return TL(pl: "Poziomy", en: "Levels", uk: "Рівні", ru: "Уровни", es: "Niveles")
        case .activity:
            return TL(
                pl: "Ruch i woda", en: "Move & water", uk: "Рух і вода", ru: "Движение и вода",
                es: "Movimiento y agua")
        case .social: return TL(pl: "Znajomi", en: "Friends", uk: "Друзі", ru: "Друзья", es: "Amigos")
        case .special: return TL(pl: "Specjalne", en: "Special", uk: "Особливі", ru: "Особые", es: "Especiales")
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
        case .levels: return "chart.bar.fill"
        case .activity: return "figure.run"
        case .social: return "person.2.fill"
        case .special: return "sparkles"
        case .rhythm: return "flame.fill"
        case .nutrition: return "bolt.heart.fill"
        case .logging: return "plus.viewfinder"
        case .lifestyle: return "leaf.fill"
        case .legendary: return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all, .levels: return Tokens.Palette.graphite
        case .activity: return Tokens.Palette.lime
        case .social: return Tokens.Palette.accent
        case .special: return Tokens.Palette.warning
        case .rhythm: return Tokens.Palette.warning
        case .nutrition: return Tokens.Palette.lime
        case .logging: return Tokens.Palette.graphite
        case .lifestyle: return Tokens.Palette.mutedGreen
        case .legendary: return Tokens.Palette.warning
        }
    }

    func filter(_ definitions: [AchievementDefinition]) -> [AchievementDefinition] {
        switch self {
        case .all:
            return definitions
        case .levels:
            return definitions.filter { $0.level != nil }
        case .activity:
            return definitions.filter { $0.group == .activity }
        case .social:
            return definitions.filter { $0.group == .social }
        case .special:
            return definitions.filter { $0.id.hasPrefix("special.") }
        case .rhythm:
            return definitions.filter { $0.id.hasPrefix("streak") || $0.id.hasPrefix("week") || $0.group == .rhythm }
        case .nutrition:
            return definitions.filter {
                $0.group == .nutrition || $0.id.hasPrefix("protein") || $0.id.hasPrefix("calories")
                    || $0.id.hasPrefix("macros")
                    || $0.id.hasPrefix("variety")
            }
        case .logging:
            return definitions.filter {
                $0.group == .logging || $0.id.hasPrefix("meal.") || $0.id.hasPrefix("source")
                    || $0.id.hasPrefix("mealtype")
                    || $0.id == "scan.first" || $0.id == "barcode.first" || $0.id == "voice.first"
                    || $0.id == "quickdb.first"
            }
        case .lifestyle:
            return definitions.filter {
                $0.group == .lifestyle || $0.id.hasPrefix("recipe") || $0.id.hasPrefix("recipes")
                    || $0.id.hasPrefix("weight")
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
    /// Collection group of a leveled track badge; nil for the rest.
    var group: AchievementGroup? {
        AchievementTracks.group(forID: id)
    }

    var rarity: AchievementRarity {
        if let level, let maxLevel {
            if level >= maxLevel - 1 { return .legendary }
            return level * 2 > maxLevel ? .rare : .common
        }
        if id.hasPrefix("special.") { return .rare }
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
