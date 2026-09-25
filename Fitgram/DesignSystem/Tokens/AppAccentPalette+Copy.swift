import SwiftUI

// Display copy for the accent palettes shown in the theme picker.
extension AppAccentPalette {
    var title: String {
        switch self {
        case .graphiteLime:
            return TL(
                pl: "Graphite Lime", en: "Graphite Lime", uk: "Graphite Lime", ru: "Graphite Lime",
                es: "Graphite Lime")
        case .ocean:
            return TL(pl: "Ocean Night", en: "Ocean Night", uk: "Ocean Night", ru: "Ocean Night", es: "Ocean Night")
        case .rose:
            return TL(
                pl: "Citrus White", en: "Citrus White", uk: "Citrus White", ru: "Citrus White",
                es: "Citrus White")
        case .amber:
            return TL(
                pl: "Daylight Lime", en: "Daylight Lime", uk: "Daylight Lime", ru: "Daylight Lime",
                es: "Daylight Lime")
        case .copperBlush:
            return TL(
                pl: "Copper Blush", en: "Copper Blush", uk: "Copper Blush", ru: "Copper Blush",
                es: "Copper Blush")
        case .copperBlushApricot:
            return TL(
                pl: "Copper Blush", en: "Copper Blush", uk: "Copper Blush", ru: "Copper Blush",
                es: "Copper Blush")
        case .copperBlushDeep:
            return TL(
                pl: "Copper Blush", en: "Copper Blush", uk: "Copper Blush", ru: "Copper Blush",
                es: "Copper Blush")
        case .oliveBerry:
            return TL(
                pl: "Olive Berry", en: "Olive Berry", uk: "Olive Berry", ru: "Olive Berry",
                es: "Olive Berry")
        case .oliveBerryOlive:
            return TL(
                pl: "Olive Berry", en: "Olive Berry", uk: "Olive Berry", ru: "Olive Berry",
                es: "Olive Berry")
        case .oliveBerryRose:
            return TL(
                pl: "Olive Berry", en: "Olive Berry", uk: "Olive Berry", ru: "Olive Berry",
                es: "Olive Berry")
        case .porcelainCoral:
            return TL(
                pl: "Porcelain Coral", en: "Porcelain Coral", uk: "Porcelain Coral",
                ru: "Porcelain Coral", es: "Porcelain Coral")
        case .porcelainCoralSky:
            return TL(
                pl: "Porcelain Coral", en: "Porcelain Coral", uk: "Porcelain Coral",
                ru: "Porcelain Coral", es: "Porcelain Coral")
        case .porcelainCoralSand:
            return TL(
                pl: "Porcelain Coral", en: "Porcelain Coral", uk: "Porcelain Coral",
                ru: "Porcelain Coral", es: "Porcelain Coral")
        case .matchaCeramic:
            return TL(
                pl: "Matcha Ceramic", en: "Matcha Ceramic", uk: "Matcha Ceramic", ru: "Matcha Ceramic",
                es: "Matcha Ceramic")
        case .graphiteMint:
            return TL(
                pl: "Graphite Mint", en: "Graphite Mint", uk: "Graphite Mint", ru: "Graphite Mint",
                es: "Graphite Mint")
        case .vanillaBlue:
            return TL(
                pl: "Vanilla Blue", en: "Vanilla Blue", uk: "Vanilla Blue", ru: "Vanilla Blue",
                es: "Vanilla Blue")
        case .cherryCream:
            return TL(
                pl: "Cherry Cream", en: "Cherry Cream", uk: "Cherry Cream", ru: "Cherry Cream",
                es: "Cherry Cream")
        case .pistachioInk:
            return TL(
                pl: "Pistachio Ink", en: "Pistachio Ink", uk: "Pistachio Ink", ru: "Pistachio Ink",
                es: "Pistachio Ink")
        case .nordicBerry:
            return TL(
                pl: "Nordic Berry", en: "Nordic Berry", uk: "Nordic Berry", ru: "Nordic Berry",
                es: "Nordic Berry")
        case .mochaLime:
            return TL(
                pl: "Mocha Lime", en: "Mocha Lime", uk: "Mocha Lime", ru: "Mocha Lime",
                es: "Mocha Lime")
        }
    }

    var subtitle: String {
        switch self {
        case .graphiteLime:
            return TL(
                pl: "Sportowy, kontrastowy", en: "Sporty, high contrast", uk: "Спортивна, контрастна",
                ru: "Спортивная, контрастная", es: "Deportiva, contrastada")
        case .ocean:
            return TL(
                pl: "Ciemny, chłodny, premium", en: "Dark, cool, premium", uk: "Темна, холодна, преміальна",
                ru: "Тёмная, холодная, премиальная", es: "Oscura, fría, premium")
        case .rose:
            return TL(
                pl: "Biała, świeża, pomarańczowa", en: "White, fresh, orange",
                uk: "Біла, свіжа, помаранчева", ru: "Белая, свежая, оранжевая",
                es: "Blanca, fresca, naranja")
        case .amber:
            return TL(
                pl: "Jasna, sportowa, świeża", en: "Light, sporty, fresh", uk: "Світла, спортивна, свіжа",
                ru: "Светлая, спортивная, свежая", es: "Clara, deportiva, fresca")
        case .copperBlush:
            return TL(
                pl: "Blush, miedź, miękka", en: "Blush, copper, soft",
                uk: "Тепла, м’яка, преміальна", ru: "Тёплая, мягкая, премиальная",
                es: "Cálida, suave, premium")
        case .copperBlushApricot:
            return TL(
                pl: "Morelowa, jasna, ciepła", en: "Apricot, light, warm",
                uk: "Абрикосова, світла, тепла", ru: "Абрикосовая, светлая, тёплая",
                es: "Albaricoque, clara, cálida")
        case .copperBlushDeep:
            return TL(
                pl: "Głębsza, kontrastowa, premium", en: "Deeper, contrast, premium",
                uk: "Глибша, контрастна, преміальна", ru: "Глубже, контрастнее, премиальная",
                es: "Más profunda, contrastada, premium")
        case .oliveBerry:
            return TL(
                pl: "Berry, oliwka, wyrazista", en: "Berry, olive, vivid",
                uk: "Ботанічна, світла, виразна", ru: "Ботаническая, светлая, выразительная",
                es: "Botánica, clara, expresiva")
        case .oliveBerryOlive:
            return TL(
                pl: "Oliwkowa, spokojna, naturalna", en: "Olive, calm, natural",
                uk: "Оливкова, спокійна, природна", ru: "Оливковая, спокойная, натуральная",
                es: "Oliva, calma, natural")
        case .oliveBerryRose:
            return TL(
                pl: "Różana, świeża, miękka", en: "Rosy, fresh, soft",
                uk: "Рожева, свіжа, м’яка", ru: "Розовая, свежая, мягкая",
                es: "Rosada, fresca, suave")
        case .porcelainCoral:
            return TL(
                pl: "Koralowa, jasna, świeża", en: "Coral, light, fresh",
                uk: "Порцелянова, спокійна, свіжа", ru: "Фарфоровая, спокойная, свежая",
                es: "Porcelana, calma, fresca")
        case .porcelainCoralSky:
            return TL(
                pl: "Błękitna, spokojna, premium", en: "Blue, calm, premium",
                uk: "Блакитна, спокійна, преміальна", ru: "Голубая, спокойная, премиальная",
                es: "Azul, calma, premium")
        case .porcelainCoralSand:
            return TL(
                pl: "Piaskowa, ciepła, delikatna", en: "Sandy, warm, delicate",
                uk: "Пісочна, тепла, делікатна", ru: "Песочная, тёплая, деликатная",
                es: "Arena, cálida, delicada")
        case .matchaCeramic:
            return TL(
                pl: "Ceramiczna, matcha, spokojna", en: "Ceramic, matcha, calm",
                uk: "Керамічна, матча, спокійна", ru: "Керамическая, матча, спокойная",
                es: "Cerámica, matcha, calma")
        case .graphiteMint:
            return TL(
                pl: "Ciemna, miętowa, premium", en: "Dark, mint, premium",
                uk: "Темна, м’ятна, преміальна", ru: "Тёмная, мятная, премиальная",
                es: "Oscura, menta, premium")
        case .vanillaBlue:
            return TL(
                pl: "Wanilia, błękit, iOS", en: "Vanilla, blue, iOS",
                uk: "Ваніль, блакить, iOS", ru: "Ваниль, голубой, iOS",
                es: "Vainilla, azul, iOS")
        case .cherryCream:
            return TL(
                pl: "Kremowa, wiśniowa, lifestyle", en: "Cream, cherry, lifestyle",
                uk: "Кремова, вишнева, lifestyle", ru: "Кремовая, вишнёвая, lifestyle",
                es: "Crema, cereza, lifestyle")
        case .pistachioInk:
            return TL(
                pl: "Ciemna zieleń, pistacja", en: "Dark green, pistachio",
                uk: "Темна зелень, фісташка", ru: "Тёмная зелень, фисташка",
                es: "Verde oscuro, pistacho")
        case .nordicBerry:
            return TL(
                pl: "Nordycka, chłodna, berry", en: "Nordic, cool, berry",
                uk: "Нордична, холодна, ягідна", ru: "Нордическая, холодная, ягодная",
                es: "Nórdica, fría, berry")
        case .mochaLime:
            return TL(
                pl: "Mocha, limonka, kontrast", en: "Mocha, lime, contrast",
                uk: "Мока, лайм, контраст", ru: "Мокко, лайм, контраст",
                es: "Mocha, lima, contraste")
        }
    }
}
